#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# Paths and runtime defaults
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BACKEND_DIR="${REPO_ROOT}/backend"

MAIN_SCENE="res://client/scenes/PhaseOneClient.tscn"
ONLINE_SMOKE_SCRIPT="./client/scripts/phase_one_online_smoke.gd"
READY_ENDPOINT="/up"

MERGE_GATE_HOST="${MERGE_GATE_HOST:-127.0.0.1}"
MERGE_GATE_PORT="${MERGE_GATE_PORT:-8000}"
BACKEND_URL="${BACKEND_URL:-http://${MERGE_GATE_HOST}:${MERGE_GATE_PORT}}"
BEARER_TOKEN="${BEARER_TOKEN:-test-token-2001}"
GODOT_BIN="${GODOT_BIN:-godot}"
PHP_BIN="${PHP_BIN:-php}"
COMPOSER_BIN="${COMPOSER_BIN:-composer}"

STARTED_SERVER=0
SERVER_PID=""
SERVER_LOG="${BACKEND_DIR}/storage/logs/client-merge-gate-server.log"


# ------------------------------------------------------------------------------
# CLI helpers
# ------------------------------------------------------------------------------
usage() {
  cat <<'EOF'
Usage:
  ./client/phase-one-merge-gate.sh
  ./client/phase-one-merge-gate.sh --help

Runs:
  1. backend interop diagnose
  2. backend contract drift check
  3. client headless boot smoke
  4. client main-scene smoke
  5. client online smoke
  6. backend acceptance

Environment overrides:
  BACKEND_URL=http://127.0.0.1:8000
  BEARER_TOKEN=test-token-2001
  MERGE_GATE_HOST=127.0.0.1
  MERGE_GATE_PORT=8000
  GODOT_BIN=godot
  PHP_BIN=php
  COMPOSER_BIN=composer

Notes:
  - The gate stays inside the current phase-one backend/client baseline.
  - No new backend interface is introduced by this script.
  - GUI walkthrough is still a separate merge check and is not replaced here.
EOF
}


# ------------------------------------------------------------------------------
# Logging and execution helpers
# ------------------------------------------------------------------------------
log_step() {
  printf '[client-merge-gate] %s\n' "$1"
}

run_step() {
  local label="$1"
  shift

  log_step "start ${label}"
  "$@"
  log_step "done ${label}"
}

ensure_command() {
  local command_name="$1"

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    printf '[client-merge-gate] missing command: %s\n' "${command_name}" >&2
    exit 1
  fi
}

require_runtime_commands() {
  ensure_command curl
  ensure_command "${GODOT_BIN}"
  ensure_command "${PHP_BIN}"
  ensure_command "${COMPOSER_BIN}"
}

print_runtime_context() {
  log_step "repo_root=${REPO_ROOT}"
  log_step "backend_dir=${BACKEND_DIR}"
  log_step "backend_url=${BACKEND_URL}"
  log_step "main_scene=${MAIN_SCENE}"
  log_step "online_smoke_script=${ONLINE_SMOKE_SCRIPT}"
  log_step "server_log=${SERVER_LOG}"
}


# ------------------------------------------------------------------------------
# Backend lifecycle helpers
# ------------------------------------------------------------------------------
cleanup() {
  if [[ "${STARTED_SERVER}" -eq 1 && -n "${SERVER_PID}" ]]; then
    log_step "stopping temporary backend pid=${SERVER_PID}"
    kill "${SERVER_PID}" >/dev/null 2>&1 || true
    wait "${SERVER_PID}" 2>/dev/null || true
  fi
}

backend_is_alive() {
  curl -fsS "${BACKEND_URL}${READY_ENDPOINT}" >/dev/null 2>&1
}

wait_for_backend() {
  local attempt

  for attempt in $(seq 1 30); do
    if backend_is_alive; then
      return 0
    fi
    sleep 1
  done

  printf '[client-merge-gate] backend did not become ready at %s\n' "${BACKEND_URL}" >&2
  return 1
}

start_backend_if_needed() {
  if backend_is_alive; then
    log_step "backend already running at ${BACKEND_URL}"
    return 0
  fi

  mkdir -p "$(dirname "${SERVER_LOG}")"
  log_step "starting temporary backend at ${BACKEND_URL}"

  (
    cd "${BACKEND_DIR}"
    "${PHP_BIN}" artisan serve \
      --host="${MERGE_GATE_HOST}" \
      --port="${MERGE_GATE_PORT}" \
      >"${SERVER_LOG}" 2>&1 &
    echo $! >"${SERVER_LOG}.pid"
  )

  SERVER_PID="$(cat "${SERVER_LOG}.pid")"
  rm -f "${SERVER_LOG}.pid"
  STARTED_SERVER=1

  log_step "temporary backend pid=${SERVER_PID}"
  wait_for_backend
}

stop_temporary_backend_before_acceptance() {
  if [[ "${STARTED_SERVER}" -eq 1 ]]; then
    log_step "stopping temporary backend before backend acceptance"
    cleanup
    STARTED_SERVER=0
    SERVER_PID=""
  fi
}


# ------------------------------------------------------------------------------
# Command wrappers
# ------------------------------------------------------------------------------
run_backend_command() {
  (
    cd "${BACKEND_DIR}"
    "$@"
  )
}

run_godot_command() {
  (
    cd "${REPO_ROOT}"
    "${GODOT_BIN}" --headless --path . "$@"
  )
}


# ------------------------------------------------------------------------------
# Concrete gate stages
# ------------------------------------------------------------------------------
run_client_project_boot_smoke() {
  # Minimal project boot: validates that the Godot project loads headlessly.
  run_godot_command --quit
}

run_client_main_scene_smoke() {
  # Main-scene smoke: loads the real phase-one client scene once in headless mode.
  run_godot_command --scene "${MAIN_SCENE}" --quit-after 1
}

run_client_online_smoke() {
  # Online smoke: runs the real client smoke script against the current backend.
  run_godot_command --script "${ONLINE_SMOKE_SCRIPT}" -- \
    --base-url="${BACKEND_URL}" \
    --bearer-token="${BEARER_TOKEN}"
}

run_backend_interop_diagnose() {
  run_backend_command "${PHP_BIN}" artisan phase-one:diagnose --profile=interop --json
}

run_backend_contract_drift_check() {
  run_backend_command "${PHP_BIN}" artisan phase-one:contract-drift-check --json
}

run_backend_acceptance_suite() {
  run_backend_command "${COMPOSER_BIN}" phase-one:acceptance
}


# ------------------------------------------------------------------------------
# Main flow
# ------------------------------------------------------------------------------
main() {
  case "${1:-}" in
    "")
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n\n' "${1}" >&2
      usage >&2
      exit 1
      ;;
  esac

  trap cleanup EXIT

  require_runtime_commands
  print_runtime_context

  run_step "backend interop diagnose" run_backend_interop_diagnose
  run_step "backend contract drift check" run_backend_contract_drift_check
  run_step "client headless boot smoke" run_client_project_boot_smoke
  run_step "client main-scene smoke" run_client_main_scene_smoke

  start_backend_if_needed
  run_step "client online smoke" run_client_online_smoke

  stop_temporary_backend_before_acceptance
  run_step "backend acceptance" run_backend_acceptance_suite

  log_step "success"
}

main "$@"
