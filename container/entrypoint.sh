#!/usr/bin/env bash
set -euo pipefail

HOST_UID="${HOST_UID:-1000}"
HOST_GID="${HOST_GID:-1000}"
HOST_USER="${HOST_USER:-codex}"
HOME_DIR="/codex-home"

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "entrypoint must start as root" >&2
    exit 1
  fi
}

ensure_group() {
  getent group "${HOST_GID}" >/dev/null 2>&1 || \
    groupadd --gid "${HOST_GID}" "${HOST_USER}" >/dev/null 2>&1 || true
}

ensure_user() {
  getent passwd "${HOST_UID}" >/dev/null 2>&1 || \
    useradd --uid "${HOST_UID}" --gid "${HOST_GID}" --home-dir "${HOME_DIR}" \
      --shell /bin/bash --create-home "${HOST_USER}" >/dev/null 2>&1 || true
}

main() {
  require_root
  ensure_group
  ensure_user

  USER_NAME="$(getent passwd "${HOST_UID}" | cut -d: -f1)"
  if [ -z "${USER_NAME}" ]; then
    echo "failed to resolve user for uid ${HOST_UID}" >&2
    exit 1
  fi

  usermod -aG sudo "${USER_NAME}" >/dev/null 2>&1 || true
  mkdir -p "${HOME_DIR}" /workspace
  chown -R "${HOST_UID}:${HOST_GID}" "${HOME_DIR}" /workspace || true

  if [ "$#" -eq 0 ]; then
    set -- codex --dangerously-bypass-approvals-and-sandbox
  fi

  exec gosu "${HOST_UID}:${HOST_GID}" env \
    HOME="${HOME_DIR}" \
    CODEX_HOME="${HOME_DIR}/.codex" \
    USER="${USER_NAME}" \
    LOGNAME="${USER_NAME}" \
    "$@"
}

main "$@"
