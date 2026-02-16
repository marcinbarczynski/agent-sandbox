#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-codex-sandbox:latest}"
CONTAINER_PREFIX="${CONTAINER_NAME:-codex-sandbox}"
HOST_CODEX_DIR="${HOST_CODEX_DIR:-$HOME/.codex}"
WORKSPACE_DIR_DEFAULT="${PWD}"
DISPLAY_ARGS=()

require_podman() {
  if ! command -v podman >/dev/null 2>&1; then
    echo "podman is required" >&2
    exit 1
  fi
}

latest_source_epoch() {
  stat -c '%Y' Containerfile container/entrypoint.sh 2>/dev/null | sort -nr | head -n1
}

image_created_epoch() {
  local created
  created="$(podman image inspect --format '{{.Created}}' "${IMAGE_NAME}" 2>/dev/null || true)"
  if [ -z "${created}" ]; then
    return 1
  fi

  date -d "${created}" +%s 2>/dev/null || return 1
}

need_build() {
  local image_epoch src_epoch

  if ! podman image exists "${IMAGE_NAME}"; then
    return 0
  fi

  image_epoch="$(image_created_epoch || true)"
  if [ -z "${image_epoch}" ]; then
    return 0
  fi

  src_epoch="$(latest_source_epoch || true)"
  [ -n "${src_epoch}" ] && [ "${src_epoch}" -gt "${image_epoch}" ]
}

append_wayland_args() {
  if [ -n "${WAYLAND_DISPLAY:-}" ] && [ -n "${XDG_RUNTIME_DIR:-}" ]; then
    DISPLAY_ARGS+=(
      -e "WAYLAND_DISPLAY=${WAYLAND_DISPLAY}"
      -e "XDG_RUNTIME_DIR=/tmp/xdg-runtime"
      -v "${XDG_RUNTIME_DIR}:/tmp/xdg-runtime:rw,rslave"
    )
  fi
}

append_x11_args() {
  local host_xauthority
  if [ -z "${DISPLAY:-}" ] || [ ! -d /tmp/.X11-unix ]; then
    return
  fi

  DISPLAY_ARGS+=(
    -e "DISPLAY=${DISPLAY}"
    -v /tmp/.X11-unix:/tmp/.X11-unix:rw,rslave
  )

  host_xauthority="${XAUTHORITY:-$HOME/.Xauthority}"
  if [ -f "${host_xauthority}" ]; then
    DISPLAY_ARGS+=(
      -e "XAUTHORITY=/tmp/.Xauthority"
      -v "${host_xauthority}:/tmp/.Xauthority:ro"
    )
  fi
}

main() {
  local -a tty_args=() gpu_args=()
  local -a cmd=(codex --dangerously-bypass-approvals-and-sandbox)
  local workspace_dir workspace_base workspace_safe prefix_safe random_suffix container_name

  require_podman

  workspace_dir="${1:-${WORKSPACE_DIR_DEFAULT}}"
  if [ "$#" -gt 0 ]; then
    shift
  fi

  mkdir -p "${workspace_dir}" "${HOST_CODEX_DIR}"
  workspace_dir="$(cd "${workspace_dir}" && pwd)"

  workspace_base="$(basename "${workspace_dir}")"
  workspace_safe="$(printf '%s' "${workspace_base}" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9_.-]+/-/g; s/^[^a-z0-9]+//; s/[^a-z0-9]+$//')"
  if [ -z "${workspace_safe}" ]; then
    workspace_safe="workspace"
  fi

  prefix_safe="$(printf '%s' "${CONTAINER_PREFIX}" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9_.-]+/-/g; s/^[^a-z0-9]+//; s/[^a-z0-9]+$//')"
  if [ -z "${prefix_safe}" ]; then
    prefix_safe="codex-sandbox"
  fi

  random_suffix="$(printf '%04x%04x' "$RANDOM" "$RANDOM")"
  random_suffix="${random_suffix:0:6}"
  container_name="${prefix_safe}-${workspace_safe}-${random_suffix}"

  if need_build; then
    podman build -t "${IMAGE_NAME}" -f Containerfile .
  fi

  DISPLAY_ARGS=()
  append_wayland_args
  append_x11_args

  if [ -e /dev/dri ]; then
    gpu_args+=(--device /dev/dri)
  fi

  if [ -t 0 ] && [ -t 1 ]; then
    tty_args=(-it)
  fi

  if [ "$#" -gt 0 ]; then
    cmd=("$@")
  fi

  exec podman run --rm \
    "${tty_args[@]}" \
    --name "${container_name}" \
    --user root \
    --userns keep-id \
    --security-opt label=disable \
    -e "HOST_UID=$(id -u)" \
    -e "HOST_GID=$(id -g)" \
    -e "HOST_USER=${USER:-codex}" \
    -e "HOME=/codex-home" \
    -e "CODEX_HOME=/codex-home/.codex" \
    -v "${HOST_CODEX_DIR}:/codex-home/.codex:O" \
    -v "${workspace_dir}:/workspace:rw,rslave" \
    "${DISPLAY_ARGS[@]}" \
    "${gpu_args[@]}" \
    "${IMAGE_NAME}" \
    "${cmd[@]}"
}

main "$@"
