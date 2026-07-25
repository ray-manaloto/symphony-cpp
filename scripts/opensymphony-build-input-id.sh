#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly repo_root
readonly gcc16_artifact_context="${GCC16_ARTIFACT_CONTEXT:-docker-image://ghcr.io/ray-manaloto/symphony-toolchain-gcc:16.1.0-amd64-6b1431c2581c93d174792a530acd054c06979d9185117aefca7f03a46830f51d@sha256:30cf91ffd71a925d11e687b31b7d298ca8b30b715b12d547ba4c1a8c4091c890}"
if [[ ! "${gcc16_artifact_context}" =~ ^docker-image://[^@[:space:]]+@sha256:[0-9a-f]{64}$ ]]; then
  echo "GCC16_ARTIFACT_CONTEXT must be an exact docker-image reference pinned by sha256 digest" >&2
  exit 64
fi
readonly inputs=(
  .dockerignore
  containers/Containerfile
  containers/OpenSymphony.Containerfile
  containers/OpenSymphony.Containerfile.dockerignore
  containers/opensymphony-local.bake.hcl
  containers/validation/gcc16-runtime-candidate.Containerfile
  containers/validation/gcc16-runtime-candidate.Containerfile.dockerignore
  scripts/install-cmake.sh
  tests/fixtures/p2996_reflection_probe.cpp
)

(
  cd "${repo_root}"
  printf 'opensymphony-build-input-v1\0'
  printf 'gcc16-artifact-context\0%s\0' "${gcc16_artifact_context}"
  for input in "${inputs[@]}"; do
    test -f "${input}"
    printf '%s\0' "${input}"
    shasum -a 256 "${input}"
  done
) | shasum -a 256 | awk '{print $1}'
