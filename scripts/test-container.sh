#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_SCRIPT="${SCRIPT_DIR}/run-codex-container.sh"

if [ ! -x "${RUN_SCRIPT}" ]; then
  echo "run script missing: ${RUN_SCRIPT}" >&2
  exit 1
fi

TMP_WORKSPACE="$(mktemp -d)"
trap 'rm -rf "${TMP_WORKSPACE}"' EXIT

HOST_CODEX_DIR="${HOST_CODEX_DIR:-$HOME/.codex}"

HOST_CODEX_DIR="${HOST_CODEX_DIR}" \
  "${RUN_SCRIPT}" "${TMP_WORKSPACE}" bash -lc '
    set -euo pipefail
    echo "user=$(id -u):$(id -g)"
    echo "whoami=$(whoami)"
    echo "HOME=${HOME}"
    echo "CODEX_HOME=${CODEX_HOME:-}"
    sudo -n id -u
    test "${HOME}" = "/codex-home"
    test "${CODEX_HOME}" = "/codex-home/.codex"
    test -f "${CODEX_HOME}/auth.json"
    touch /workspace/ownership-check.txt
    stat -c "%u:%g" /workspace/ownership-check.txt
    command -v codex >/dev/null
    codex login status 2>&1 | grep -q "Logged in"
    if [ -n "${WAYLAND_DISPLAY:-}" ]; then
      test -S "${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}" || true
      echo "wayland_env_present=yes"
    else
      echo "wayland_env_present=no"
    fi
  '

OWNER="$(stat -c '%u:%g' "${TMP_WORKSPACE}/ownership-check.txt")"
EXPECTED="$(id -u):$(id -g)"

if [ "${OWNER}" != "${EXPECTED}" ]; then
  echo "ownership mismatch: expected ${EXPECTED}, got ${OWNER}" >&2
  exit 1
fi

echo "container test passed (owner ${OWNER})"
