#!/usr/bin/env bash
set -euo pipefail

unset LINEAR_API_KEY

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly repo_root
readonly gcc16_artifact_context="docker-image://ghcr.io/ray-manaloto/symphony-toolchain-gcc:16.1.0-amd64-6b1431c2581c93d174792a530acd054c06979d9185117aefca7f03a46830f51d@sha256:30cf91ffd71a925d11e687b31b7d298ca8b30b715b12d547ba4c1a8c4091c890"
build_input_sha256="$(
  GCC16_ARTIFACT_CONTEXT="${gcc16_artifact_context}" \
    "${repo_root}/scripts/opensymphony-build-input-id.sh"
)"
alternate_build_input_sha256="$(
  GCC16_ARTIFACT_CONTEXT="docker-image://example.invalid/gcc@sha256:$(printf '0%.0s' {1..64})" \
    "${repo_root}/scripts/opensymphony-build-input-id.sh"
)"
source_revision="$(git -C "${repo_root}" rev-parse HEAD)"
readonly build_input_sha256
readonly alternate_build_input_sha256
readonly source_revision
test "${alternate_build_input_sha256}" != "${build_input_sha256}"
if GCC16_ARTIFACT_CONTEXT=not-pinned \
    "${repo_root}/scripts/opensymphony-build-input-id.sh" >/dev/null 2>&1; then
  echo "OpenSymphony build-input identity accepted an unpinned GCC context" >&2
  exit 1
fi

graph="$(
  cd "${repo_root}"
  GCC16_ARTIFACT_CONTEXT="${gcc16_artifact_context}" \
    BUILD_INPUT_SHA256="${build_input_sha256}" \
    SOURCE_REVISION="${source_revision}" \
    docker buildx bake \
      --file containers/opensymphony-local.bake.hcl \
      --print \
      opensymphony-candidate-local \
      opensymphony-validated-local
)"
readonly graph

jq -e \
  --arg gcc_context "${gcc16_artifact_context}" \
  --arg build_input "${build_input_sha256}" \
  --arg source_revision "${source_revision}" \
  '
    (.target | keys) == [
      "opensymphony-candidate-local",
      "opensymphony-gcc-runtime",
      "opensymphony-gcc-runtime-validation",
      "opensymphony-validated-local"
    ] and
    .target["opensymphony-gcc-runtime"] == {
      context: ".",
      contexts: {"gcc16-artifact-input": $gcc_context},
      dockerfile: "containers/Containerfile",
      args: {SOURCE_REVISION: $source_revision},
      target: "symphony-gcc-runtime",
      platforms: ["linux/amd64"],
      output: [{type: "cacheonly"}]
    } and
    .target["opensymphony-gcc-runtime-validation"] == {
      context: ".",
      contexts: {"runtime-base": "target:opensymphony-gcc-runtime"},
      dockerfile: "containers/validation/gcc16-runtime-candidate.Containerfile",
      target: "gcc16-runtime-candidate-validation",
      platforms: ["linux/amd64"],
      output: [{type: "cacheonly"}]
    } and
    (
      .target["opensymphony-candidate-local"] |
      .context == "." and
      .contexts == {
        "symphony-cpp-base": "target:opensymphony-gcc-runtime",
        "symphony-cpp-base-validation":
          "target:opensymphony-gcc-runtime-validation"
      } and
      .dockerfile == "containers/OpenSymphony.Containerfile" and
      .args == {
        BUILD_INPUT_SHA256: $build_input,
        SOURCE_REVISION: $source_revision
      } and
      .tags == ["symphony-opensymphony:local"] and
      .target == "symphony-orchestrator-candidate" and
      .platforms == ["linux/amd64"] and
      .output == [{type: "docker"}]
    ) and
    (
      .target["opensymphony-validated-local"] |
      .context == "." and
      .contexts == {
        "symphony-cpp-base": "target:opensymphony-gcc-runtime",
        "symphony-cpp-base-validation":
          "target:opensymphony-gcc-runtime-validation"
      } and
      .dockerfile == "containers/OpenSymphony.Containerfile" and
      .args == {
        BUILD_INPUT_SHA256: $build_input,
        SOURCE_REVISION: $source_revision
      } and
      .tags == ["symphony-opensymphony:local"] and
      .target == "symphony-orchestrator" and
      .platforms == ["linux/amd64"] and
      .output == [{type: "docker"}]
    )
  ' <<<"${graph}" >/dev/null

echo "OpenSymphony local Bake graph contract passed"
