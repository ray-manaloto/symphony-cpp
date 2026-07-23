#!/usr/bin/env bash
set -euo pipefail

mode="${1:-dry-run}"
image="${OPENSYMPHONY_IMAGE:-ghcr.io/ray-manaloto/symphony-orchestrator@sha256:65be3f2e87f57c9698567a3d6830ab93bd70c6268d8a36fcf1b5dad094ba6982}"

case "${mode}" in
  login)
    exec docker run --rm --interactive --tty \
      --entrypoint codex \
      --volume symphony-codex-auth:/home/orchestrator/.codex \
      "${image}" login --device-auth
    ;;
  dry-run|run)
    if [[ -z "${LINEAR_API_KEY:-}" ]]; then
      echo "LINEAR_API_KEY must be injected for this command by the configured secret manager" >&2
      exit 2
    fi

    run_args=(run --config /orchestrator/config.yaml)
    if [[ "${mode}" == "dry-run" ]]; then
      run_args+=(--dry-run)
    fi

    exec docker run --rm --interactive \
      --env LINEAR_API_KEY \
      --publish 127.0.0.1:2468:2468 \
      --read-only \
      --tmpfs /tmp:rw,noexec,nosuid,size=256m \
      --volume "${PWD}:/target:ro" \
      --volume "${PWD}/ops/opensymphony/config.yaml:/orchestrator/config.yaml:ro" \
      --volume symphony-codex-auth:/home/orchestrator/.codex \
      --volume "${PWD}/ops/opensymphony/codex-config.toml:/home/orchestrator/.codex/config.toml:ro" \
      --volume symphony-opensymphony-workspaces:/workspaces \
      "${image}" "${run_args[@]}"
    ;;
  *)
    echo "usage: $0 {dry-run|run|login}" >&2
    exit 2
    ;;
esac
