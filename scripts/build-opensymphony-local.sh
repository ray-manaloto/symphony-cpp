#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly repo_root
readonly image="${OPENSYMPHONY_IMAGE:-symphony-opensymphony:candidate}"

docker buildx build \
  --file "${repo_root}/containers/OpenSymphony.Containerfile" \
  --target symphony-orchestrator-candidate \
  --platform linux/amd64 \
  --load \
  --tag "${image}" \
  "${repo_root}"

docker run --rm --platform linux/amd64 \
  --entrypoint opensymphony \
  "${image}" --help >/dev/null
test "$(
  docker run --rm --platform linux/amd64 \
    --entrypoint sh \
    "${image}" \
    -euc 'printf "%s %s %s" "$(g++ -dumpfullversion)" "$(cmake --version | head -n 1)" "$(codex --version)"'
)" = "16.1.0 cmake version 4.4.0 codex-cli 0.145.0"
test "$(
  docker image inspect \
    --format '{{ index .Config.Labels "dev.opensymphony.upstream-tests" }}' \
    "${image}"
)" = "unverified-candidate"

image_id="$(docker image inspect --format '{{.Id}}' "${image}")"
printf 'Built unvalidated local OpenSymphony acceptance candidate: %s (%s)\n' \
  "${image}" "${image_id}"
printf 'Do not use it operationally; the validated image requires test-opensymphony-upstream.sh.\n'
