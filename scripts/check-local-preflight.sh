#!/usr/bin/env bash
set -euo pipefail

readonly mode="${1:-quick}"
case "${mode}" in
  quick | pre-push | docker) ;;
  *)
    echo "usage: $0 [quick|pre-push|docker]" >&2
    exit 64
    ;;
esac

test "$(actionlint -version | head -n 1)" = "1.7.12"
test "$(zizmor --version)" = "zizmor 1.28.0"
test "$(check-jsonschema --version)" = "check-jsonschema, version 0.37.4"
test "$(pre-commit --version)" = "pre-commit 4.6.1"
test "$(
  shellcheck --version |
    sed -n 's/^version: //p'
)" = "0.11.0"

git diff --cached --check
git diff --check
pre-commit validate-config .pre-commit-config.yaml
bash -n scripts/*.sh
shellcheck --severity=warning scripts/*.sh
actionlint -no-color .github/workflows/*.yml
check-jsonschema \
  --builtin-schema vendor.github-workflows \
  .github/workflows/*.yml
check-jsonschema \
  --builtin-schema custom.github-workflows-require-timeout \
  .github/workflows/*.yml
zizmor \
  --offline \
  --strict-collection \
  --persona regular \
  --min-confidence high \
  --format plain \
  --color never \
  .github/workflows/*.yml

javascript_index=0
while IFS= read -r -d '' javascript_file; do
  javascript_index=$((javascript_index + 1))
  if ! git show ":${javascript_file}" 2>/dev/null |
    node --check --input-type=module - >/dev/null 2>&1; then
    echo "JavaScript syntax check failed for indexed module ${javascript_index}" >&2
    exit 1
  fi
done < <(git ls-files -z --cached -- '*.mjs')

javascript_worktree_index=0
while IFS= read -r -d '' javascript_file; do
  [[ -f "${javascript_file}" ]] || continue
  javascript_worktree_index=$((javascript_worktree_index + 1))
  if ! node --check -- "${javascript_file}" >/dev/null 2>&1; then
    echo "JavaScript syntax check failed for working-tree module ${javascript_worktree_index}" >&2
    exit 1
  fi
done < <(git ls-files -z --cached --others --exclude-standard -- '*.mjs')

node scripts/check-dependency-policy.mjs
./scripts/test-analysis-toolchain-contract.sh
./scripts/test-p2996-compile-commands.sh
./scripts/test-toolchain-platform-contract.sh

while IFS= read -r json_file; do
  node -e '
    const fs = require("node:fs");
    JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
  ' "${json_file}"
done < <(git ls-files '*.json')

run_docker_checks=false
if [[ "${mode}" == "docker" ]]; then
  if ! command -v docker >/dev/null || ! docker buildx version >/dev/null 2>&1; then
    echo "Docker Buildx is required for strict docker preflight" >&2
    exit 1
  fi
  run_docker_checks=true
elif [[ "${mode}" == "pre-push" ]]; then
  if command -v docker >/dev/null && docker buildx version >/dev/null 2>&1; then
    run_docker_checks=true
  else
    echo "Docker Buildx unavailable; completed non-Docker push checks" >&2
  fi
fi

if [[ "${run_docker_checks}" == true ]]; then
  readonly containerfile=containers/Containerfile
  readonly clang_p2996_artifact_context="docker-image://ghcr.io/ray-manaloto/symphony-toolchain-clang-p2996:7220baffd57ea5b0f8cf59bee494dd5b7cc2b748-amd64-77b98dd8970c509c9492ad30e19a4ce6dbb6474fc14b167b9aed6094fd9bc276@sha256:d054fa3bcde2091b69950c321a06ba35f9f4a628ad69c5e95849020d9cfe9e68"
  readonly static_runtime_context="docker-image://ghcr.io/openai/codex-universal@sha256:905e512f36460e1be4cfedb30928a8a28299edb0fcd5de7998ceaa72d27fe304"
  for missing_context_case in \
    "containers/validation/gcc16.Containerfile:gcc16-validation" \
    "containers/validation/gcc16-runtime-candidate.Containerfile:gcc16-runtime-candidate-validation" \
    "containers/validation/clang-p2996.Containerfile:clang-p2996-validation"; do
    missing_context_dockerfile="${missing_context_case%%:*}"
    missing_context_target="${missing_context_case##*:}"
    set +e
    missing_context_output="$(
      docker buildx build \
        --file "${missing_context_dockerfile}" \
        --platform linux/amd64 \
        --target "${missing_context_target}" \
        --output type=cacheonly \
        . 2>&1
    )"
    missing_context_status=$?
    set -e
    if [[ "${missing_context_status}" -eq 0 ]]; then
      echo "${missing_context_dockerfile} accepted a missing runtime-base context" >&2
      exit 1
    fi
    if grep -Fq 'docker.io/library/runtime-base' <<<"${missing_context_output}"; then
      echo "${missing_context_dockerfile} resolved a mutable runtime-base fallback" >&2
      exit 1
    fi
  done
  docker buildx build \
    --file "${containerfile}" \
    --platform linux/amd64 \
    --target gcc16-artifact \
    --call=check \
    .
  for architecture in amd64 arm64; do
    docker buildx build \
      --file "${containerfile}" \
      --platform "linux/${architecture}" \
      --target symphony-gcc-runtime \
      --build-context "gcc16-artifact-input=${static_runtime_context}" \
      --call=check \
      .
    docker buildx build \
      --file containers/validation/gcc16.Containerfile \
      --platform "linux/${architecture}" \
      --target gcc16-validation \
      --build-context "runtime-base=${static_runtime_context}" \
      --call=check \
      .
  done
  docker buildx build \
    --file containers/validation/gcc16-runtime-candidate.Containerfile \
    --platform linux/amd64 \
    --target gcc16-runtime-candidate-validation \
    --build-context "runtime-base=${static_runtime_context}" \
    --call=check \
    .
  for analysis_target in symphony-analysis-format-validation symphony-analysis-source-validation; do
    docker buildx build \
      --file "${containerfile}" \
      --platform linux/amd64 \
      --target "${analysis_target}" \
      --build-context "gcc16-artifact-input=${static_runtime_context}" \
      --call=check \
      .
  done
  docker buildx build \
    --file "${containerfile}" \
    --platform linux/amd64 \
    --target symphony-ci-clang \
    --build-context "clang-p2996-artifact-input=${clang_p2996_artifact_context}" \
    --call=check \
    .
  docker buildx build \
    --file containers/validation/clang-p2996.Containerfile \
    --platform linux/amd64 \
    --target clang-p2996-validation \
    --build-context "runtime-base=${static_runtime_context}" \
    --call=check \
    .
  for invalid_artifact_context in \
    "" \
    "docker-image://example.invalid/compiler:mutable" \
    "docker-image://example.invalid/compiler@sha256:1234"; do
    if CLANG_P2996_ARTIFACT_CONTEXT="${invalid_artifact_context}" \
      docker buildx bake \
        --file containers/p2996-separated.bake.hcl \
        --print \
        clang-p2996-validation >/dev/null 2>&1; then
      echo "p2996 Bake graph accepted an inexact artifact context" >&2
      exit 1
    fi
  done
  resolved_p2996_bake="$(
    CLANG_P2996_ARTIFACT_CONTEXT="${clang_p2996_artifact_context}" \
      docker buildx bake \
        --file containers/p2996-separated.bake.hcl \
        --print \
        clang-p2996-validation
  )"
  jq -e \
    --arg artifact_context "${clang_p2996_artifact_context}" \
    '
      (.target | keys | sort) ==
        ["clang-p2996-runtime", "clang-p2996-validation"] and
      .target["clang-p2996-runtime"].contexts["clang-p2996-artifact-input"] ==
        $artifact_context and
      .target["clang-p2996-runtime"].output == [{"type": "cacheonly"}] and
      .target["clang-p2996-validation"].contexts["runtime-base"] ==
        "target:clang-p2996-runtime" and
      .target["clang-p2996-validation"].output == [{"type": "cacheonly"}] and
      ([.target[] | has("tags") or has("cache-to")] | any) == false
    ' <<<"${resolved_p2996_bake}" >/dev/null
  CLANG_P2996_ARTIFACT_CONTEXT="${clang_p2996_artifact_context}" \
    docker buildx bake \
      --file containers/bake.hcl \
      --print \
      symphony-ci-clang >/dev/null
  if GCC16_ARTIFACT_CONTEXT="docker-image://example.invalid/compiler:mutable" \
    GCC16_ARCH=amd64 \
    docker buildx bake \
      --file containers/gcc16-separated.bake.hcl \
      --print \
      gcc16-validation >/dev/null 2>&1; then
    echo "GCC Bake graph accepted an inexact artifact context" >&2
    exit 1
  fi
  if GCC16_ARTIFACT_CONTEXT="${static_runtime_context}" \
    GCC16_ARCH=ppc64le \
    docker buildx bake \
      --file containers/gcc16-separated.bake.hcl \
      --print \
      gcc16-validation >/dev/null 2>&1; then
    echo "GCC Bake graph accepted an unsupported architecture" >&2
    exit 1
  fi
  for architecture in amd64 arm64; do
    resolved_gcc16_bake="$(
      GCC16_ARTIFACT_CONTEXT="${static_runtime_context}" \
        GCC16_ARCH="${architecture}" \
        docker buildx bake \
          --file containers/gcc16-separated.bake.hcl \
          --print \
          gcc16-validation
    )"
    jq -e \
      --arg architecture "${architecture}" \
      --arg artifact_context "${static_runtime_context}" \
      '
        (.target | keys | sort) ==
          ["gcc16-runtime", "gcc16-validation"] and
        .target["gcc16-runtime"].platforms == ["linux/" + $architecture] and
        .target["gcc16-runtime"].contexts["gcc16-artifact-input"] ==
          $artifact_context and
        .target["gcc16-runtime"].output == [{"type": "cacheonly"}] and
        .target["gcc16-validation"].platforms == ["linux/" + $architecture] and
        .target["gcc16-validation"].contexts["runtime-base"] ==
          "target:gcc16-runtime" and
        .target["gcc16-validation"].output == [{"type": "cacheonly"}] and
        ([.target[] | has("tags") or has("cache-to")] | any) == false
      ' <<<"${resolved_gcc16_bake}" >/dev/null
  done
  for invalid_runtime_context in \
    "" \
    "docker-image://example.invalid/runtime:mutable" \
    "docker-image://example.invalid/runtime@sha256:1234"; do
    if RUNTIME_BASE_CONTEXT="${invalid_runtime_context}" \
      RUNTIME_ARCH=amd64 \
      docker buildx bake \
        --file containers/gcc16-runtime-candidate.bake.hcl \
        --print \
        gcc16-runtime-candidate-validation >/dev/null 2>&1; then
      echo "GCC runtime candidate graph accepted an inexact runtime context" >&2
      exit 1
    fi
  done
  if RUNTIME_BASE_CONTEXT="${static_runtime_context}" \
    RUNTIME_ARCH=ppc64le \
    docker buildx bake \
      --file containers/gcc16-runtime-candidate.bake.hcl \
      --print \
      gcc16-runtime-candidate-validation >/dev/null 2>&1; then
    echo "GCC runtime candidate graph accepted an unsupported architecture" >&2
    exit 1
  fi
  resolved_runtime_candidate_bake="$(
    RUNTIME_BASE_CONTEXT="${static_runtime_context}" \
      RUNTIME_ARCH=amd64 \
      docker buildx bake \
        --file containers/gcc16-runtime-candidate.bake.hcl \
        --print \
        gcc16-runtime-candidate-validation
  )"
  jq -e \
    --arg runtime_context "${static_runtime_context}" \
    '
      (.target | keys) == ["gcc16-runtime-candidate-validation"] and
      .target["gcc16-runtime-candidate-validation"].platforms ==
        ["linux/amd64"] and
      .target["gcc16-runtime-candidate-validation"].contexts["runtime-base"] ==
        $runtime_context and
      .target["gcc16-runtime-candidate-validation"].output ==
        [{"type": "cacheonly"}] and
      ([.target[] |
        has("tags") or has("cache-to") or has("cache-from")
      ] | any) == false
    ' <<<"${resolved_runtime_candidate_bake}" >/dev/null
  GCC16_ARTIFACT_CONTEXT="${static_runtime_context}" \
    docker buildx bake \
      --file containers/bake.hcl \
      --print \
      symphony-gcc-runtime \
      symphony-analysis >/dev/null
fi
