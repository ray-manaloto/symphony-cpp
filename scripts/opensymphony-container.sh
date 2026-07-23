#!/usr/bin/env bash
set -euo pipefail

mode="${1:-dry-run}"
shift || true

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
image="${OPENSYMPHONY_IMAGE:-ghcr.io/ray-manaloto/symphony-orchestrator@sha256:65be3f2e87f57c9698567a3d6830ab93bd70c6268d8a36fcf1b5dad094ba6982}"
state_volume="${OPENSYMPHONY_STATE_VOLUME:-symphony-opensymphony-state}"
auth_volume="${OPENSYMPHONY_CODEX_AUTH_VOLUME:-symphony-codex-auth}"
workspaces_volume="${OPENSYMPHONY_WORKSPACES_VOLUME:-symphony-opensymphony-workspaces}"

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

common_args=(
  --rm
  --interactive
  --read-only
  --tmpfs "/tmp:rw,noexec,nosuid,size=256m"
  --volume "${repo_root}:/target:ro"
  --volume "${repo_root}/WORKFLOW.md:/orchestrator/WORKFLOW.md:ro"
  --volume "${repo_root}/ops/opensymphony/config.yaml:/orchestrator/config.yaml:ro"
  --volume "${auth_volume}:/home/orchestrator/.codex"
  --volume "${repo_root}/ops/opensymphony/codex-config.toml:/home/orchestrator/.codex/config.toml:ro"
  --volume "${workspaces_volume}:/workspaces"
  --volume "${state_volume}:/target/.opensymphony"
)

case "${mode}" in
  login)
    if (( $# != 0 )); then
      echo "login accepts no additional arguments" >&2
      exit 2
    fi
    exec docker run --rm --interactive --tty \
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
    exec docker run --rm --read-only \
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
      "${image}" memory --config /orchestrator/config.yaml status
    ;;
  memory-context)
    issue="$(require_issue "${1:-}")"
    if (( $# != 1 )); then
      echo "memory-context accepts exactly one issue identifier" >&2
      exit 2
    fi
    require_linear_key
    exec docker run "${common_args[@]}" \
      --env LINEAR_API_KEY \
      "${image}" memory --config /orchestrator/config.yaml context --issue "${issue}"
    ;;
  doctor)
    if (( $# != 0 )); then
      echo "doctor accepts no additional arguments" >&2
      exit 2
    fi
    require_linear_key
    exec docker run "${common_args[@]}" \
      --env LINEAR_API_KEY \
      "${image}" doctor --config /orchestrator/config.yaml
    ;;
  dry-run|run)
    if (( $# != 0 )); then
      echo "${mode} accepts no additional arguments" >&2
      exit 2
    fi
    require_linear_key
    run_args=(run --config /orchestrator/config.yaml)
    if [[ "${mode}" == "dry-run" ]]; then
      run_args+=(--dry-run)
    fi

    exec docker run "${common_args[@]}" \
      --env LINEAR_API_KEY \
      --publish 127.0.0.1:2468:2468 \
      "${image}" "${run_args[@]}"
    ;;
  tui)
    if (( $# != 0 )); then
      echo "tui accepts no additional arguments" >&2
      exit 2
    fi
    exec docker run --rm --interactive --tty \
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
    exec docker run "${common_args[@]}" \
      --env LINEAR_API_KEY \
      "${image}" debug --config /orchestrator/config.yaml "${issue}"
    ;;
  *)
    echo "usage: $0 {login|memory-init|preflight|memory-status|memory-context ISSUE|doctor|dry-run|run|tui|debug ISSUE}" >&2
    exit 2
    ;;
esac
