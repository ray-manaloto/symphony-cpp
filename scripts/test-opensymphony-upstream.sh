#!/usr/bin/env bash
set -euo pipefail

unset LINEAR_API_KEY

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly repo_root
readonly image="${OPENSYMPHONY_IMAGE:-symphony-opensymphony:local}"
readonly gcc16_artifact_context="${GCC16_ARTIFACT_CONTEXT:-docker-image://ghcr.io/ray-manaloto/symphony-toolchain-gcc:16.1.0-amd64-6b1431c2581c93d174792a530acd054c06979d9185117aefca7f03a46830f51d@sha256:30cf91ffd71a925d11e687b31b7d298ca8b30b715b12d547ba4c1a8c4091c890}"
source_revision="$(git -C "${repo_root}" rev-parse HEAD)"
build_input_sha256="$("${repo_root}/scripts/opensymphony-build-input-id.sh")"
readonly source_revision
readonly build_input_sha256

(
  cd "${repo_root}"
  GCC16_ARTIFACT_CONTEXT="${gcc16_artifact_context}" \
    BUILD_INPUT_SHA256="${build_input_sha256}" \
    OPENSYMPHONY_IMAGE="${image}" \
    SOURCE_REVISION="${source_revision}" \
    docker buildx bake \
      --file containers/opensymphony-local.bake.hcl \
      --progress plain \
      opensymphony-validated-local
)

image_id="$(docker image inspect --format '{{.Id}}' "${image}")"
readonly image_id
if [[ ! "${image_id}" =~ ^sha256:[0-9a-f]{64}$ ]]; then
  echo "validated image did not resolve to exactly one immutable local image ID" >&2
  exit 1
fi
test "$(
  docker image inspect \
    --format '{{ index .Config.Labels "dev.opensymphony.build-input.sha256" }}' \
    "${image_id}"
)" = "${build_input_sha256}"
test "$(
  docker image inspect \
    --format '{{ index .Config.Labels "dev.opensymphony.upstream-tests" }}' \
    "${image_id}"
)" = "passed"
test "$(
  docker image inspect \
    --format '{{ index .Config.Labels "dev.opensymphony.source.commit" }}' \
    "${image_id}"
)" = "0cc21ddda5d1853a8fbd11add578b43b6ebd6fcb"
test "$(
  docker image inspect \
    --format '{{ index .Config.Labels "dev.symphony.source.revision" }}' \
    "${image_id}"
)" = "${source_revision}"
docker run --rm --pull=never --platform linux/amd64 \
  --entrypoint opensymphony \
  "${image_id}" --help >/dev/null
test "$(
  docker run --rm --pull=never --platform linux/amd64 \
    --entrypoint sh \
    "${image_id}" \
    -euc 'printf "%s %s %s" "$(g++ -dumpfullversion)" "$(cmake --version | head -n 1)" "$(codex --version)"'
)" = "16.1.0 cmake version 4.4.0 codex-cli 0.145.0"
printf 'Built validated local OpenSymphony image: %s (%s)\n' "${image}" "${image_id}"
