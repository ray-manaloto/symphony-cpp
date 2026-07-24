#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

readonly containerfile=containers/Containerfile
readonly cmake_installer=scripts/install-cmake.sh
readonly workflow=.github/workflows/compiler-matrix.yml
readonly devcontainer_configs=(
  .devcontainer/devcontainer.json
  .devcontainer/clang-p2996/devcontainer.json
  .devcontainer/analysis/devcontainer.json
)

bash -n "${cmake_installer}"

stage_block() {
  local stage="$1"
  awk -v target="${stage}" '
    $0 ~ ("^FROM .* AS " target "$") {
      printing = 1
    }
    printing && seen && /^FROM / {
      exit
    }
    printing {
      print
      seen = 1
    }
  ' "${containerfile}"
}

workflow_step_block() {
  local step="$1"
  awk -v target="${step}" '
    $0 == "      - name: " target {
      printing = 1
    }
    printing && seen && /^      - (name:|uses:)/ {
      exit
    }
    printing {
      print
      seen = 1
    }
  ' <<<"${llvm_analysis_job}"
}

workflow_job_block() {
  local job="$1"
  awk -v target="${job}" '
    $0 == "  " target ":" {
      printing = 1
    }
    printing && seen && /^  [[:alnum:]_-]+:/ {
      exit
    }
    printing {
      print
      seen = 1
    }
  ' "${workflow}"
}

grep -Fq \
  'ARG CODEX_BASE=ghcr.io/openai/codex-universal@sha256:905e512f36460e1be4cfedb30928a8a28299edb0fcd5de7998ceaa72d27fe304' \
  "${containerfile}"
grep -Fq \
  '# syntax=docker/dockerfile:1.10@sha256:865e5dd094beca432e8c0a1d5e1c465db5f998dca4e439981029b3b81fb39ed5' \
  "${containerfile}"

grep -Fq 'x86_64)' "${cmake_installer}"
grep -Fq 'readonly CMAKE_PLATFORM=linux-x86_64' "${cmake_installer}"
grep -Fq \
  'readonly CMAKE_SHA256=3864eb649b4466ae126a64bbde1657adad78efbbaa068bf38201de5cf1b5349f' \
  "${cmake_installer}"
grep -Fq 'aarch64 | arm64)' "${cmake_installer}"
grep -Fq 'readonly CMAKE_PLATFORM=linux-aarch64' "${cmake_installer}"
grep -Fq \
  'readonly CMAKE_SHA256=e98bb53e0b00a8f672424517d34c05bb9b94fd1c888c89e0b81bc8df51d1a94b' \
  "${cmake_installer}"

grep -Fq 'amd64) llvm_target=X86' "${containerfile}"
grep -Fq 'arm64) llvm_target=AArch64' "${containerfile}"
grep -Fq \
  'amd64) llvm_platform=X64; llvm_sha256=df0e1ecf16caf3489a272a5eea4eec9b0d82878f6477fa309504f918a0006384' \
  "${containerfile}"
grep -Fq \
  'arm64) llvm_platform=ARM64; llvm_sha256=805efad2bb91cb4967fa569e0881d10c0f69c04461cf671cccbae19f547acc34' \
  "${containerfile}"

if grep -Fq 'libc6,x86-64' "${containerfile}"; then
  echo "toolchain runtime contract still depends on an AMD64 ldconfig presentation string" >&2
  exit 1
fi

gcc_runtime="$(stage_block symphony-gcc-runtime)"
grep -Fq 'ARG SOURCE_REVISION=unknown' <<<"${gcc_runtime}"
grep -Fq 'org.opencontainers.image.revision="${SOURCE_REVISION}"' <<<"${gcc_runtime}"
grep -Fq 'ENTRYPOINT []' <<<"${gcc_runtime}"

analysis_runtime="$(stage_block symphony-analysis)"
grep -Fq 'FROM symphony-gcc-runtime AS symphony-analysis' <<<"${analysis_runtime}"
grep -Fq 'ARG SOURCE_REVISION=unknown' <<<"${analysis_runtime}"
grep -Fq 'org.opencontainers.image.revision="${SOURCE_REVISION}"' <<<"${analysis_runtime}"

clang_runtime="$(stage_block symphony-ci-clang)"
grep -Fq 'ARG SOURCE_REVISION=unknown' <<<"${clang_runtime}"
grep -Fq 'org.opencontainers.image.revision="${SOURCE_REVISION}"' <<<"${clang_runtime}"
grep -Fq 'ENTRYPOINT []' <<<"${clang_runtime}"

grep -Fq 'default: amd64' "${workflow}"
grep -Fq "runs-on: \${{ inputs.architecture == 'arm64' && 'ubuntu-24.04-arm' || 'ubuntu-24.04' }}" \
  "${workflow}"
grep -Fq 'platforms: ${{ env.TOOLCHAIN_PLATFORM }}' "${workflow}"
grep -Fq 'scope=symphony-gcc16-${{ inputs.architecture }}-min-v3' "${workflow}"
grep -Fq 'if: ${{ inputs.architecture == '\''arm64'\'' && inputs.lineage != '\''gcc16'\'' }}' \
  "${workflow}"
grep -Fq 'target: symphony-gcc-validation' "${workflow}"
grep -Fq 'target: symphony-clang-validation' "${workflow}"
llvm_analysis_job="$(workflow_job_block llvm-analysis)"
analysis_base_step="$(
  workflow_step_block "Persist stable LLVM analysis base before source validation"
)"
analysis_validation_step="$(
  workflow_step_block "Build and validate LLVM analysis without loading it"
)"
for step in "${analysis_base_step}" "${analysis_validation_step}"; do
  grep -Fxq \
    '        uses: docker/build-push-action@53b7df96c91f9c12dcc8a07bcb9ccacbed38856a' \
    <<<"${step}"
  grep -Fxq '          context: .' <<<"${step}"
  grep -Fxq '          file: containers/Containerfile' <<<"${step}"
  grep -Fxq '          platforms: linux/amd64' <<<"${step}"
  grep -Fxq '          builder: ${{ steps.buildx.outputs.name }}' <<<"${step}"
  grep -Fxq '          outputs: type=cacheonly' <<<"${step}"
  grep -Fxq '          load: false' <<<"${step}"
  grep -Fxq '          push: false' <<<"${step}"
  grep -Fxq '          cache-from: type=gha,scope=symphony-llvm-analysis-min-v2' <<<"${step}"
  grep -Fxq \
    '          cache-to: type=gha,mode=min,scope=symphony-llvm-analysis-min-v2,timeout=30m' \
    <<<"${step}"
  for key in uses context file target platforms outputs load push builder cache-from cache-to; do
    test "$(grep -Ec "^[[:space:]]+${key}:" <<<"${step}")" = "1"
  done
done
grep -Fxq '          target: symphony-analysis' <<<"${analysis_base_step}"
grep -Fxq '          target: symphony-analysis-validation' <<<"${analysis_validation_step}"
setup_buildx_line="$(
  grep -Fn \
    '      - uses: docker/setup-buildx-action@bb05f3f5519dd87d3ba754cc423b652a5edd6d2c' \
    <<<"${llvm_analysis_job}" |
    cut -d: -f1
)"
setup_buildx_id_line="$(
  grep -Fn '        id: buildx' <<<"${llvm_analysis_job}" |
    cut -d: -f1
)"
base_step_line="$(
  grep -Fn \
    '      - name: Persist stable LLVM analysis base before source validation' \
    <<<"${llvm_analysis_job}" |
    cut -d: -f1
)"
restore_ccache_line="$(
  grep -Fn '      - name: Restore bounded analysis compiler cache' <<<"${llvm_analysis_job}" |
    cut -d: -f1
)"
bridge_ccache_line="$(
  grep -Fn '      - name: Bridge analysis compiler cache into BuildKit' <<<"${llvm_analysis_job}" |
    cut -d: -f1
)"
validation_step_line="$(
  grep -Fn \
    '      - name: Build and validate LLVM analysis without loading it' \
    <<<"${llvm_analysis_job}" |
    cut -d: -f1
)"
test "${setup_buildx_line}" -lt "${setup_buildx_id_line}"
test "${setup_buildx_id_line}" -lt "${base_step_line}"
test "${base_step_line}" -lt "${restore_ccache_line}"
test "${restore_ccache_line}" -lt "${bridge_ccache_line}"
test "${bridge_ccache_line}" -lt "${validation_step_line}"
test "$(grep -Fc 'outputs: type=cacheonly' "${workflow}")" = "4"
test "$(grep -Fc 'load: false' "${workflow}")" = "4"
test "$(grep -Fc 'version: v0.35.0' "${workflow}")" = "3"
grep -Fq \
  'uses: reproducible-containers/buildkit-cache-dance@5422eac04292c961a382e0f584ea0f03ad9da723' \
  "${workflow}"
grep -Fq \
  'uses: actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9' \
  "${workflow}"
grep -Fq \
  'utility-image: ghcr.io/containerd/busybox@sha256:52f73a0a43a16cf37cd0720c90887ce972fe60ee06a687ee71fb93a7ca601df7' \
  "${workflow}"

test "$(grep -Fc 'push: false' "${workflow}")" = "4"
test "$(grep -Ec '^permissions:$' "${workflow}")" = "1"
test "$(grep -Ec '^[[:space:]]*permissions:' "${workflow}")" = "1"
test "$(grep -Ec '^  contents: read$' "${workflow}")" = "1"
if grep -Eq '(^|[[:space:]])write-all([[:space:]]|$)' "${workflow}"; then
  echo "compiler validation workflow must not request write-all permission" >&2
  exit 1
fi
if grep -Eq '^[[:space:]]+[[:alnum:]_-]+:[[:space:]]+write([[:space:]]|$)' "${workflow}"; then
  echo "compiler validation workflow must not request write permissions" >&2
  exit 1
fi
if grep -Fq '${{ secrets.' "${workflow}"; then
  echo "compiler validation workflow must not consume repository secrets" >&2
  exit 1
fi
if grep -Eq '^[[:space:]]+push:[[:space:]]+true([[:space:]]|$)' "${workflow}"; then
  echo "compiler validation workflow must not push images" >&2
  exit 1
fi
if grep -Eq '(^|[[:space:]])docker[[:space:]]+(buildx[[:space:]]+)?push([[:space:]]|$)|(^|[[:space:]])--push([[:space:]]|$)' \
  "${workflow}"; then
  echo "compiler validation workflow must not contain raw image-push commands" >&2
  exit 1
fi
if grep -E '^[[:space:]]+outputs:' "${workflow}" |
  grep -Fvx '          outputs: type=cacheonly' >/dev/null; then
  echo "compiler validation workflow must use only the cache-only exporter" >&2
  exit 1
fi
if grep -Fq 'continue-on-error:' "${workflow}"; then
  echo "compiler validation workflow must fail closed" >&2
  exit 1
fi
if grep -Fq 'load: true' "${workflow}"; then
  echo "validation jobs must not import large toolchain images into Docker Engine" >&2
  exit 1
fi
if grep -Fq 'type=docker' "${workflow}"; then
  echo "validation jobs must use the cache-only exporter" >&2
  exit 1
fi
if grep -Eq '^  publish:' "${workflow}"; then
  echo "publication must remain absent until a direct-push digest ceremony is reviewed" >&2
  exit 1
fi

if grep -Fq 'setup-qemu-action' "${workflow}"; then
  echo "native compiler qualification must not install QEMU" >&2
  exit 1
fi

for config in "${devcontainer_configs[@]}"; do
  grep -Fq '"postCreateCommand": "./scripts/devcontainer-local-setup.sh ' "${config}"
  grep -Fq 'source=symphony-cpp-mise,target=/root/.local/share/mise,type=volume' "${config}"
  grep -Fq 'source=symphony-cpp-pre-commit,target=/root/.cache/pre-commit,type=volume' "${config}"
done
