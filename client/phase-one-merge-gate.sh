#!/usr/bin/env bash

set -euo pipefail

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

usage() {
  cat <<'EOF'
Usage:
  ./client/phase-one-merge-gate.sh
  ./client/phase-one-merge-gate.sh --help

Purpose:
  Run the phase-one client merge gate against the current repository reality.
  The gate is intentionally limited to the already-implemented backend/client
  baseline. It does not add new gameplay checks or replace GUI walkthroughs.

Environment overrides:
  BACKEND_URL=http://127.0.0.1:8000
  BEARER_TOKEN=test-token-2001
  MERGE_GATE_HOST=127.0.0.1
  MERGE_GATE_PORT=8000
  GODOT_BIN=godot
  PHP_BIN=php
  COMPOSER_BIN=composer

Gate stages:
  1. backend diagnose (interop)
  2. backend contract drift check
  3. client headless boot smoke
  4. client main scene smoke
  5. client online smoke against the real backend
  6. backend acceptance suite

Recommended follow-up checks after this script:
  php ./backend/artisan phase-one:diagnose --profile=acceptance --json
  godot --headless --path . --script ./client/scripts/phase_one_online_smoke.gd -- \
    --base-url=http://127.0.0.1:8000 --bearer-token=test-token-2001
  git show HEAD:client/phase-one-merge-gate.sh | sed -n '1,40p'
  git show HEAD:client/scripts/phase_one_online_smoke.gd | sed -n '1,60p'

Not covered:
  - non-headless GUI walkthrough
  - git commit / push
EOF
}

log_step() {
  printf '[client-merge-gate] %s\n' "$1"
}

log_note() {
  printf '[client-merge-gate] note=%s\n' "$1"
}

run_step() {
  local step_label="$1"
  shift

  log_step "start ${step_label}"
  "$@"
  log_step "done ${step_label}"
}

parse_args() {
  if [[ $# -eq 0 ]]; then
    return 0
  fi

  case "${1}" in
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
}

print_runtime_context() {
  log_note "repo=${REPO_ROOT}"
  log_note "backend_url=${BACKEND_URL}"
  log_note "main_scene=${MAIN_SCENE}"
  log_note "online_smoke_script=${ONLINE_SMOKE_SCRIPT}"
  log_note "server_log=${SERVER_LOG}"
}

print_scope_notes() {
  log_note "coverage=interop_diagnose,contract_drift,headless_boot,main_scene,online_smoke,backend_acceptance"
  log_note "follow_up=acceptance_diagnose_json,gui_walkthrough,raw_commit_review"
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

cleanup() {
  if [[ "${STARTED_SERVER}" -eq 1 && -n "${SERVER_PID}" ]]; then
    log_step "stopping temporary backend pid=${SERVER_PID}"
    kill "${SERVER_PID}" >/dev/null 2>&1 || true
    wait "${SERVER_PID}" 2>/dev/null || true
  fi
}

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

check_backend_alive() {
  curl -fsS "${BACKEND_URL}${READY_ENDPOINT}" >/dev/null 2>&1
}

wait_for_backend() {
  local attempt
  for attempt in $(seq 1 30); do
    if check_backend_alive; then
      return 0
    fi
    sleep 1
  done

  printf '[client-merge-gate] backend did not become ready at %s\n' "${BACKEND_URL}" >&2
  return 1
}

start_backend_if_needed() {
  if check_backend_alive; then
    log_step "reusing existing backend at ${BACKEND_URL}"
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

  log_note "temporary_backend_pid=${SERVER_PID}"
  wait_for_backend
}

run_backend_diagnose_interop() {
  run_backend_command "${PHP_BIN}" artisan phase-one:diagnose --profile=interop --json
}

run_backend_contract_drift() {
  run_backend_command "${PHP_BIN}" artisan phase-one:contract-drift-check --json
}

run_client_headless_boot_smoke() {
  run_godot_command --quit
}

run_client_main_scene_smoke() {
  run_godot_command --scene "${MAIN_SCENE}" --quit-after 1
}

run_client_online_smoke() {
  run_godot_command --script "${ONLINE_SMOKE_SCRIPT}" -- \
    --base-url="${BACKEND_URL}" \
    --bearer-token="${BEARER_TOKEN}"
}

run_backend_acceptance() {
  run_backend_command "${COMPOSER_BIN}" phase-one:acceptance
}

run_backend_gate_checks() {
  run_step "backend diagnose (interop)" run_backend_diagnose_interop
  run_step "backend contract drift" run_backend_contract_drift
}

run_client_gate_checks() {
  run_step "client headless boot smoke" run_client_headless_boot_smoke
  run_step "client main scene smoke" run_client_main_scene_smoke

  start_backend_if_needed
  run_step "client online smoke" run_client_online_smoke
}

print_follow_up_checks() {
  log_note "recommended_next=php ./backend/artisan phase-one:diagnose --profile=acceptance --json"
  log_note "recommended_next=review raw commit text with git show HEAD:... | sed -n"
  log_note "recommended_next=run non-headless GUI walkthrough before final merge"
}

main() {
  parse_args "$@"
  trap cleanup EXIT

  require_runtime_commands
  print_runtime_context
  print_scope_notes

  run_backend_gate_checks
  run_client_gate_checks

  cleanup
  STARTED_SERVER=0
  SERVER_PID=""

  run_step "backend acceptance" run_backend_acceptance
  print_follow_up_checks
  log_step "success"
}

main "$@"
