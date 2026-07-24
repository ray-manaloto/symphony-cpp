#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly repo_root
readonly image="${OPENSYMPHONY_IMAGE:-symphony-opensymphony:local}"

docker buildx build \
  --file "${repo_root}/containers/OpenSymphony.Containerfile" \
  --target symphony-orchestrator \
  --platform linux/amd64 \
  --progress plain \
  --load \
  --tag "${image}" \
  "${repo_root}"

test "$(
  docker image inspect \
    --format '{{ index .Config.Labels "dev.opensymphony.upstream-tests" }}' \
    "${image}"
)" = "passed"
image_id="$(docker image inspect --format '{{.Id}}' "${image}")"
printf 'Built validated local OpenSymphony image: %s (%s)\n' "${image}" "${image_id}"
