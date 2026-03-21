#!/usr/bin/env bash

set -euo pipefail

# Usage: run from the repository root with ./client/phase-one-merge-gate.sh
#
# This gate intentionally stays focused on "can the current phase-one client be
# reviewed, smoken, and handed off" rather than adding any new gameplay checks.

# Resolve repository-relative paths once so the script works from any cwd.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BACKEND_DIR="${REPO_ROOT}/backend"
MAIN_SCENE="res://client/scenes/PhaseOneClient.tscn"
ONLINE_SMOKE_SCRIPT="./client/scripts/phase_one_online_smoke.gd"

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

Optional environment overrides:
  BACKEND_URL=http://127.0.0.1:8000
  BEARER_TOKEN=test-token-2001
  MERGE_GATE_HOST=127.0.0.1
  MERGE_GATE_PORT=8000
  GODOT_BIN=godot
  PHP_BIN=php
  COMPOSER_BIN=composer

The script runs, in order:
  1. backend phase-one interop diagnose
  2. backend contract drift guard
  3. Godot project boot smoke
  4. Godot main-scene headless smoke
  5. client online smoke against the real backend
  6. backend phase-one acceptance suite

Useful follow-up checks:
  git show HEAD:client/phase-one-merge-gate.sh | wc -l
  git show HEAD:client/scripts/phase_one_online_smoke.gd | wc -l
EOF
}

log_step() {
  echo "[client-merge-gate] $1"
}

run_step() {
  local step_label="$1"
  shift

  log_step "${step_label}"
  "$@"
}

print_runtime_context() {
  log_step "repo=${REPO_ROOT}"
  log_step "backend_url=${BACKEND_URL}"
  log_step "godot_bin=${GODOT_BIN}"
  log_step "server_log=${SERVER_LOG}"
}

ensure_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log_step "missing command: $1" >&2
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
    log_step "stopping merge-gate backend pid=${SERVER_PID}"
    kill "${SERVER_PID}" >/dev/null 2>&1 || true
    wait "${SERVER_PID}" 2>/dev/null || true
  fi
}

# Keep backend invocations anchored to backend/ so artisan and composer behave
# the same way whether the script starts them or the developer does.
run_backend_command() {
  (
    cd "${BACKEND_DIR}"
    "$@"
  )
}

# Keep Godot invocations anchored to the repository root so scene/script paths
# stay identical between local runs and CI-like headless runs.
run_godot_command() {
  (
    cd "${REPO_ROOT}"
    "${GODOT_BIN}" --headless --path . "$@"
  )
}

run_client_project_boot_smoke() {
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

run_backend_interop_diagnose() {
  run_backend_command "${PHP_BIN}" artisan phase-one:diagnose --profile=interop --json
}

run_backend_contract_drift_check() {
  run_backend_command "${PHP_BIN}" artisan phase-one:contract-drift-check --json
}

run_backend_acceptance_suite() {
  run_backend_command "${COMPOSER_BIN}" phase-one:acceptance
}

wait_for_backend() {
  local attempt
  for attempt in $(seq 1 30); do
    if curl -fsS "${BACKEND_URL}/up" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done

  log_step "backend did not become ready at ${BACKEND_URL}" >&2
  return 1
}

start_backend_if_needed() {
  if curl -fsS "${BACKEND_URL}/up" >/dev/null 2>&1; then
    log_step "backend already online at ${BACKEND_URL}; reusing existing server"
    return 0
  fi

  mkdir -p "$(dirname "${SERVER_LOG}")"
  log_step "starting backend at ${BACKEND_URL}"
  (
    cd "${BACKEND_DIR}"
    "${PHP_BIN}" artisan serve --host="${MERGE_GATE_HOST}" --port="${MERGE_GATE_PORT}" \
      >"${SERVER_LOG}" 2>&1 &
    echo $! >"${SERVER_LOG}.pid"
  )

  SERVER_PID="$(cat "${SERVER_LOG}.pid")"
  rm -f "${SERVER_LOG}.pid"
  STARTED_SERVER=1

  log_step "merge gate started backend pid=${SERVER_PID}"
  wait_for_backend
}

main() {
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
    return 0
  fi

  trap cleanup EXIT

  require_runtime_commands

  print_runtime_context

  run_step "backend interop diagnose" run_backend_interop_diagnose

  run_step "backend contract drift" run_backend_contract_drift_check

  run_step "client project boot smoke" run_client_project_boot_smoke

  run_step "client main scene smoke" run_client_main_scene_smoke

  start_backend_if_needed

  run_step "client online smoke" run_client_online_smoke

  cleanup
  STARTED_SERVER=0
  SERVER_PID=""

  run_step "backend acceptance" run_backend_acceptance_suite

  log_step "success"
}

main "$@"
