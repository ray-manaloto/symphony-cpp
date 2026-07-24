#!/usr/bin/env bash
set -euo pipefail

mode="${1:-dry-run}"
shift || true

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
image="${OPENSYMPHONY_IMAGE:-symphony-opensymphony:local}"
state_volume="${OPENSYMPHONY_STATE_VOLUME:-symphony-opensymphony-state}"
auth_volume="${OPENSYMPHONY_CODEX_AUTH_VOLUME:-symphony-codex-auth}"
workspaces_volume="${OPENSYMPHONY_WORKSPACES_VOLUME:-symphony-opensymphony-workspaces}"
tools_volume="${OPENSYMPHONY_TOOLS_VOLUME:-symphony-opensymphony-tools}"
ccache_volume="${OPENSYMPHONY_CCACHE_VOLUME:-symphony-opensymphony-gcc16-ccache}"
vcpkg_archives_volume="${OPENSYMPHONY_VCPKG_ARCHIVES_VOLUME:-symphony-opensymphony-vcpkg-archives}"
uv_cache_volume="${OPENSYMPHONY_UV_CACHE_VOLUME:-symphony-opensymphony-uv-cache}"
runtime_cpus="${OPENSYMPHONY_RUNTIME_CPUS:-6}"
runtime_memory="${OPENSYMPHONY_RUNTIME_MEMORY:-16g}"
container_network="${OPENSYMPHONY_NETWORK:-}"

if [[ -n "${container_network}" ]] &&
  [[ ! "${container_network}" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*$ ]]; then
  echo "unsafe OpenSymphony Docker network name" >&2
  exit 2
fi
network_args=()
if [[ -n "${container_network}" ]]; then
  network_args+=(--network "${container_network}")
fi

require_linear_key() {
  if [[ -z "${LINEAR_API_KEY:-}" ]]; then
    echo "LINEAR_API_KEY must be injected for this command by the configured secret manager" >&2
    exit 2
  fi
}

require_issue() {
  local issue="${1:-}"
  if [[ ! "${issue}" =~ ^[A-Za-z][A-Za-z0-9]*-[0-9]+$ ]]; then
    echo "a fixture issue identifier such as GUI-5 is required" >&2
    exit 2
  fi
  printf '%s' "${issue}"
}

require_acceptance_volumes() {
  local suffix="${OPENSYMPHONY_ACCEPTANCE_SUFFIX:-}"
  local owner_token="${OPENSYMPHONY_ACCEPTANCE_OWNER_TOKEN:-}"
  if [[ "${OPENSYMPHONY_ACCEPTANCE_RESOURCES_VERIFIED:-}" != "true" ]]; then
    echo "doctor and dry-run require the owned contained-resource ceremony" >&2
    exit 2
  fi
  if [[ -z "${suffix}" ]] || [[ ! "${suffix}" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*$ ]]; then
    echo "dry-run requires a safe OPENSYMPHONY_ACCEPTANCE_SUFFIX" >&2
    exit 2
  fi
  if [[ -z "${owner_token}" ]] || [[ ! "${owner_token}" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*$ ]]; then
    echo "doctor and dry-run require a safe contained-resource owner token" >&2
    exit 2
  fi

  local expected=(
    "symphony-opensymphony-state-acceptance-${suffix}"
    "symphony-codex-auth-acceptance-${suffix}"
    "symphony-opensymphony-workspaces-acceptance-${suffix}"
    "symphony-opensymphony-tools-acceptance-${suffix}"
    "symphony-opensymphony-gcc16-ccache-acceptance-${suffix}"
    "symphony-opensymphony-vcpkg-archives-acceptance-${suffix}"
    "symphony-opensymphony-uv-cache-acceptance-${suffix}"
  )
  local actual=(
    "${state_volume}"
    "${auth_volume}"
    "${workspaces_volume}"
    "${tools_volume}"
    "${ccache_volume}"
    "${vcpkg_archives_volume}"
    "${uv_cache_volume}"
  )
  local index
  for index in "${!expected[@]}"; do
    if [[ "${actual[$index]}" != "${expected[$index]}" ]]; then
      echo "dry-run requires exact disposable acceptance volumes for suffix ${suffix}" >&2
      exit 2
    fi
    if [[ "$(
      docker volume inspect \
        --format '{{ index .Labels "dev.symphony.acceptance-run" }}' \
        "${actual[$index]}" 2>/dev/null
    )" != "${owner_token}" ]]; then
      echo "doctor and dry-run require owned disposable volumes" >&2
      exit 2
    fi
  done
}

common_args=(
  --rm
  --interactive
  --workdir /target
  --cpus "${runtime_cpus}"
  --memory "${runtime_memory}"
  --memory-swap "${runtime_memory}"
  --read-only
  --cap-drop ALL
  --security-opt no-new-privileges
  --pids-limit 2048
  --tmpfs "/tmp:rw,noexec,nosuid,size=256m"
  --env CCACHE_DIR=/home/orchestrator/.cache/ccache
  --env UV_CACHE_DIR=/home/orchestrator/.cache/uv
  --env VCPKG_DEFAULT_BINARY_CACHE=/home/orchestrator/.cache/vcpkg/archives
  --volume "${repo_root}:/target:ro"
  --volume "${repo_root}/WORKFLOW.md:/orchestrator/WORKFLOW.md:ro"
  --volume "${repo_root}/ops/opensymphony/config.yaml:/orchestrator/config.yaml:ro"
  --volume "${auth_volume}:/home/orchestrator/.codex"
  --volume "${tools_volume}:/home/orchestrator/.opensymphony"
  --volume "${ccache_volume}:/home/orchestrator/.cache/ccache"
  --volume "${vcpkg_archives_volume}:/home/orchestrator/.cache/vcpkg/archives"
  --volume "${uv_cache_volume}:/home/orchestrator/.cache/uv"
  --volume "${repo_root}/ops/opensymphony/codex-config.toml:/home/orchestrator/.codex/config.toml:ro"
  --volume "${workspaces_volume}:/workspaces"
  --volume "${state_volume}:/target/.opensymphony"
)
if (( ${#network_args[@]} > 0 )); then
  common_args+=("${network_args[@]}")
fi

run_with_linear_key() {
  local entrypoint="$1"
  shift
  printf '%s\n' "${LINEAR_API_KEY}" |
    docker run "${common_args[@]}" \
      --entrypoint sh \
      "${image}" \
      -euc 'IFS= read -r LINEAR_API_KEY
export LINEAR_API_KEY
exec "$@"' sh "${entrypoint}" "$@"
}

case "${mode}" in
  login)
    if (( $# != 0 )); then
      echo "login accepts no additional arguments" >&2
      exit 2
    fi
    login_args=(
      --rm
      --interactive
      --tty
      --read-only
      --cpus "${runtime_cpus}"
      --memory "${runtime_memory}"
      --memory-swap "${runtime_memory}"
      --cap-drop ALL
      --security-opt no-new-privileges
      --pids-limit 512
      --tmpfs "/tmp:rw,noexec,nosuid,size=256m"
    )
    if (( ${#network_args[@]} > 0 )); then
      login_args+=("${network_args[@]}")
    fi
    exec docker run "${login_args[@]}" \
      --entrypoint codex \
      --volume "${auth_volume}:/home/orchestrator/.codex" \
      "${image}" login --device-auth
    ;;
  preflight)
    if (( $# != 0 )); then
      echo "preflight accepts no additional arguments" >&2
      exit 2
    fi
    exec docker run "${common_args[@]}" \
      --entrypoint sh \
      "${image}" \
      -euc '
        command -v opensymphony >/dev/null
        command -v codex >/dev/null
        command -v git >/dev/null
        test -r /orchestrator/config.yaml
        test -r /target/WORKFLOW.md
        test -r /target/.opensymphony/memory/memory.yaml
        test -w /target/.opensymphony/memory
        test -w /workspaces
        opensymphony --help >/dev/null
        codex --version
        codex login status
        codex --strict-config app-server --help >/dev/null
        codex app-server generate-json-schema \
          --experimental \
          --out /tmp/codex-app-server-schema
        grep -R -F -q "\"thread/start\"" /tmp/codex-app-server-schema
        grep -R -F -q "\"turn/start\"" /tmp/codex-app-server-schema
        doctor_output="$(
          LINEAR_API_KEY=fixture-readiness-placeholder \
            opensymphony doctor --config /orchestrator/config.yaml 2>&1 || true
        )"
        printf "%s\n" "${doctor_output}" | grep -F -q "[PASS] config:"
        printf "%s\n" "${doctor_output}" | grep -F -q "[PASS] workflow:"
        printf "%s\n" "${doctor_output}" | grep -F -q "[PASS] workflow-prompt:"
      '
    ;;
  memory-init)
    if (( $# != 0 )); then
      echo "memory-init accepts no additional arguments" >&2
      exit 2
    fi
    memory_init_args=(
      --rm
      --read-only
      --cpus "${runtime_cpus}"
      --memory "${runtime_memory}"
      --memory-swap "${runtime_memory}"
      --cap-drop ALL
      --cap-add CHOWN
      --cap-add DAC_OVERRIDE
      --cap-add FOWNER
      --security-opt no-new-privileges
      --pids-limit 512
      --tmpfs "/tmp:rw,noexec,nosuid,size=64m"
    )
    if (( ${#network_args[@]} > 0 )); then
      memory_init_args+=("${network_args[@]}")
    fi
    exec docker run "${memory_init_args[@]}" \
      --user 0:0 \
      --entrypoint sh \
      --volume "${state_volume}:/state" \
      --volume "${repo_root}/.opensymphony/memory/memory.yaml:/seed/memory.yaml:ro" \
      "${image}" \
      -euc '
        install -d -o 10001 -g 10001 -m 0700 /state/memory
        if [ ! -e /state/memory/memory.yaml ]; then
          install -o 10001 -g 10001 -m 0600 /seed/memory.yaml /state/memory/memory.yaml
        fi
        legacy_root_count="$(grep -c "^  public_root: docs$" /state/memory/memory.yaml || true)"
        legacy_visibility_count="$(
          grep -c "^  default_visibility: public$" /state/memory/memory.yaml || true
        )"
        legacy_target_count="$(
          grep -c -E "^[[:space:]]+docs_target: docs/" /state/memory/memory.yaml || true
        )"
        if [ "${legacy_root_count}" -gt 1 ] || [ "${legacy_visibility_count}" -gt 1 ]; then
          echo "memory policy contains ambiguous legacy documentation settings" >&2
          exit 1
        fi
        if [ "${legacy_root_count}" -eq 1 ]; then
          if [ "${legacy_visibility_count}" -ne 1 ]; then
            echo "memory policy legacy documentation settings are incomplete" >&2
            exit 1
          fi
        fi
        if [ "${legacy_root_count}" -eq 1 ] || [ "${legacy_target_count}" -gt 0 ]; then
          if [ ! -e /state/memory/memory.yaml.pre-private-doc-staging ]; then
            cp -p /state/memory/memory.yaml \
              /state/memory/memory.yaml.pre-private-doc-staging
          fi
        fi
        if [ "${legacy_root_count}" -eq 1 ]; then
          sed -i \
            -e "s|^  public_root: docs$|  public_root: .opensymphony/memory/generated-docs|" \
            -e "s|^  default_visibility: public$|  default_visibility: private|" \
            /state/memory/memory.yaml
        fi
        if [ "${legacy_target_count}" -gt 0 ]; then
          sed -i -E \
            "s|^([[:space:]]+docs_target: )docs/|\\1.opensymphony/memory/generated-docs/|" \
            /state/memory/memory.yaml
        fi
        chown -R 10001:10001 /state
      '
    ;;
  memory-status)
    if (( $# != 0 )); then
      echo "memory-status accepts no additional arguments" >&2
      exit 2
    fi
    exec docker run "${common_args[@]}" \
      "${image}" memory --config /target/.opensymphony/memory/memory.yaml status
    ;;
  memory-context)
    issue="$(require_issue "${1:-}")"
    if (( $# != 1 )); then
      echo "memory-context accepts exactly one issue identifier" >&2
      exit 2
    fi
    require_linear_key
    run_with_linear_key opensymphony \
      memory --config /target/.opensymphony/memory/memory.yaml context --issue "${issue}"
    ;;
  doctor)
    if (( $# != 0 )); then
      echo "doctor accepts no additional arguments" >&2
      exit 2
    fi
    require_linear_key
    require_acceptance_volumes
    run_with_linear_key opensymphony doctor --config /orchestrator/config.yaml
    ;;
  dry-run|run)
    if (( $# != 0 )); then
      echo "${mode} accepts no additional arguments" >&2
      exit 2
    fi
    require_linear_key
    run_args=(run --config /orchestrator/config.yaml)
    if [[ "${mode}" == "dry-run" ]]; then
      require_acceptance_volumes
      run_args+=(--dry-run)
    fi

    printf '%s\n' "${LINEAR_API_KEY}" |
      exec docker run "${common_args[@]}" \
      --entrypoint sh \
      --publish 127.0.0.1:2468:2468 \
      "${image}" \
      -euc 'IFS= read -r LINEAR_API_KEY
export LINEAR_API_KEY
exec opensymphony "$@"' sh "${run_args[@]}"
    ;;
  tui)
    if (( $# != 0 )); then
      echo "tui accepts no additional arguments" >&2
      exit 2
    fi
    tui_args=(
      --rm
      --interactive
      --tty
      --read-only
      --cpus "${runtime_cpus}"
      --memory "${runtime_memory}"
      --memory-swap "${runtime_memory}"
      --cap-drop ALL
      --security-opt no-new-privileges
      --pids-limit 512
      --tmpfs "/tmp:rw,noexec,nosuid,size=64m"
    )
    if (( ${#network_args[@]} > 0 )); then
      tui_args+=("${network_args[@]}")
    fi
    exec docker run "${tui_args[@]}" \
      --add-host host.docker.internal:host-gateway \
      "${image}" tui --url http://host.docker.internal:2468/
    ;;
  debug)
    issue="$(require_issue "${1:-}")"
    if (( $# != 1 )); then
      echo "debug accepts exactly one issue identifier" >&2
      exit 2
    fi
    require_linear_key
    run_with_linear_key opensymphony \
      debug --config /orchestrator/config.yaml "${issue}"
    ;;
  *)
    echo "usage: $0 {login|memory-init|preflight|memory-status|memory-context ISSUE|doctor|dry-run|run|tui|debug ISSUE}" >&2
    exit 2
    ;;
esac
