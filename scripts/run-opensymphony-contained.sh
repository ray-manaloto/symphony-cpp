#!/usr/bin/env bash
set -euo pipefail

mode="${1:-}"
if [[ "${mode}" != "doctor" && "${mode}" != "dry-run" ]] || (( $# != 1 )); then
  echo "usage: $0 {doctor|dry-run}" >&2
  exit 2
fi
if [[ -z "${LINEAR_API_KEY:-}" ]]; then
  echo "LINEAR_API_KEY must be injected into this exact contained ceremony" >&2
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
owner_token="live-${mode}-$$-${RANDOM}-${RANDOM}"
export OPENSYMPHONY_ACCEPTANCE_OWNER_TOKEN="${owner_token}"
suffix="${owner_token}"
auth_volume="symphony-codex-auth-acceptance-${suffix}"
state_volume="symphony-opensymphony-state-acceptance-${suffix}"
workspaces_volume="symphony-opensymphony-workspaces-acceptance-${suffix}"
tools_volume="symphony-opensymphony-tools-acceptance-${suffix}"
ccache_volume="symphony-opensymphony-gcc16-ccache-acceptance-${suffix}"
vcpkg_archives_volume="symphony-opensymphony-vcpkg-archives-acceptance-${suffix}"
uv_cache_volume="symphony-opensymphony-uv-cache-acceptance-${suffix}"
volumes=(
  "${auth_volume}"
  "${state_volume}"
  "${workspaces_volume}"
  "${tools_volume}"
  "${ccache_volume}"
  "${vcpkg_archives_volume}"
  "${uv_cache_volume}"
)
created_volumes=()

cleanup() {
  result=$?
  trap - EXIT
  for volume in "${created_volumes[@]}"; do
    if [[ "$(
      docker volume inspect \
        --format '{{ index .Labels "dev.symphony.acceptance-run" }}' \
        "${volume}" 2>/dev/null
    )" != "${owner_token}" ]]; then
      echo "refusing to remove a contained volume without the expected owner token: ${volume}" >&2
      result=1
      continue
    fi
    if ! docker volume rm "${volume}" >/dev/null 2>&1; then
      result=1
    fi
  done
  exit "${result}"
}
trap cleanup EXIT

for volume in "${volumes[@]}"; do
  if docker volume inspect "${volume}" >/dev/null 2>&1; then
    echo "refusing to reuse pre-existing contained volume: ${volume}" >&2
    exit 2
  fi
done
for volume in "${volumes[@]}"; do
  docker volume create \
    --label "dev.symphony.acceptance-suffix=${suffix}" \
    --label "dev.symphony.acceptance-owner=run-opensymphony-contained" \
    --label "dev.symphony.acceptance-run=${owner_token}" \
    "${volume}" >/dev/null
  if [[ "$(
    docker volume inspect \
      --format '{{ index .Labels "dev.symphony.acceptance-run" }}' \
      "${volume}" 2>/dev/null
  )" != "${owner_token}" ]]; then
    echo "failed to prove contained-volume ownership: ${volume}" >&2
    exit 2
  fi
  created_volumes+=("${volume}")
done

OPENSYMPHONY_ACCEPTANCE_SUFFIX="${suffix}" \
  OPENSYMPHONY_ACCEPTANCE_RESOURCES_VERIFIED=true \
  OPENSYMPHONY_ACCEPTANCE_OWNER_TOKEN="${owner_token}" \
  OPENSYMPHONY_CODEX_AUTH_VOLUME="${auth_volume}" \
  OPENSYMPHONY_STATE_VOLUME="${state_volume}" \
  OPENSYMPHONY_WORKSPACES_VOLUME="${workspaces_volume}" \
  OPENSYMPHONY_TOOLS_VOLUME="${tools_volume}" \
  OPENSYMPHONY_CCACHE_VOLUME="${ccache_volume}" \
  OPENSYMPHONY_VCPKG_ARCHIVES_VOLUME="${vcpkg_archives_volume}" \
  OPENSYMPHONY_UV_CACHE_VOLUME="${uv_cache_volume}" \
  "${repo_root}/scripts/opensymphony-container.sh" "${mode}"
