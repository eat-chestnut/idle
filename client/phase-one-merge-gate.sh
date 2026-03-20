#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BACKEND_DIR="${REPO_ROOT}/backend"

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

ensure_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[client-merge-gate] missing command: $1" >&2
    exit 1
  fi
}

cleanup() {
  if [[ "${STARTED_SERVER}" -eq 1 && -n "${SERVER_PID}" ]]; then
    kill "${SERVER_PID}" >/dev/null 2>&1 || true
    wait "${SERVER_PID}" 2>/dev/null || true
  fi
}

wait_for_backend() {
  local attempt
  for attempt in $(seq 1 30); do
    if curl -fsS "${BACKEND_URL}/up" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done

  echo "[client-merge-gate] backend did not become ready at ${BACKEND_URL}" >&2
  return 1
}

start_backend_if_needed() {
  if curl -fsS "${BACKEND_URL}/up" >/dev/null 2>&1; then
    echo "[client-merge-gate] backend already online at ${BACKEND_URL}"
    return 0
  fi

  echo "[client-merge-gate] starting backend at ${BACKEND_URL}"
  (
    cd "${BACKEND_DIR}"
    "${PHP_BIN}" artisan serve --host="${MERGE_GATE_HOST}" --port="${MERGE_GATE_PORT}" \
      >"${SERVER_LOG}" 2>&1 &
    echo $! >"${SERVER_LOG}.pid"
  )

  SERVER_PID="$(cat "${SERVER_LOG}.pid")"
  rm -f "${SERVER_LOG}.pid"
  STARTED_SERVER=1

  wait_for_backend
}

trap cleanup EXIT

ensure_command curl
ensure_command "${GODOT_BIN}"
ensure_command "${PHP_BIN}"
ensure_command "${COMPOSER_BIN}"

echo "[client-merge-gate] repo=${REPO_ROOT}"
echo "[client-merge-gate] backend_url=${BACKEND_URL}"

cd "${BACKEND_DIR}"

echo "[client-merge-gate] backend interop diagnose"
"${PHP_BIN}" artisan phase-one:diagnose --profile=interop --json

echo "[client-merge-gate] backend contract drift"
"${PHP_BIN}" artisan phase-one:contract-drift-check --json

echo "[client-merge-gate] client project boot smoke"
"${GODOT_BIN}" --headless --path "${REPO_ROOT}" --quit

echo "[client-merge-gate] client main scene smoke"
"${GODOT_BIN}" --headless --path "${REPO_ROOT}" --scene res://client/scenes/PhaseOneClient.tscn --quit-after 1

start_backend_if_needed

echo "[client-merge-gate] client online smoke"
"${GODOT_BIN}" --headless --path "${REPO_ROOT}" --script "${REPO_ROOT}/client/scripts/phase_one_online_smoke.gd" -- \
  --base-url="${BACKEND_URL}" \
  --bearer-token="${BEARER_TOKEN}"

cleanup
STARTED_SERVER=0
SERVER_PID=""

echo "[client-merge-gate] backend acceptance"
"${COMPOSER_BIN}" phase-one:acceptance

echo "[client-merge-gate] success"
