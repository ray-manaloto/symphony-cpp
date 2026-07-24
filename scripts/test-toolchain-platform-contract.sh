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
grep -Fq 'target: symphony-analysis-validation' "${workflow}"
test "$(grep -Fc 'outputs: type=cacheonly' "${workflow}")" = "3"
test "$(grep -Fc 'load: false' "${workflow}")" = "3"
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

test "$(grep -Fc 'push: false' "${workflow}")" = "3"
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
