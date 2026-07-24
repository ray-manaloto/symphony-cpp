#!/usr/bin/env bash
set -euo pipefail

readonly containerfile=containers/Containerfile
readonly cmake_installer=scripts/install-cmake.sh
readonly workflow=.github/workflows/compiler-matrix.yml

bash -n "${cmake_installer}"

grep -Fq \
  'ARG CODEX_BASE=ghcr.io/openai/codex-universal@sha256:905e512f36460e1be4cfedb30928a8a28299edb0fcd5de7998ceaa72d27fe304' \
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

grep -Fq 'default: amd64' "${workflow}"
grep -Fq "runs-on: \${{ inputs.architecture == 'arm64' && 'ubuntu-24.04-arm' || 'ubuntu-24.04' }}" \
  "${workflow}"
grep -Fq 'platforms: ${{ env.TOOLCHAIN_PLATFORM }}' "${workflow}"
grep -Fq 'scope=symphony-gcc16-${{ inputs.architecture }}-min-v2' "${workflow}"
grep -Fq 'if: ${{ inputs.architecture == '\''arm64'\'' && inputs.lineage != '\''gcc16'\'' }}' \
  "${workflow}"
grep -Fq 'if: ${{ false }}' "${workflow}"

if grep -Fq 'setup-qemu-action' "${workflow}"; then
  echo "native compiler qualification must not install QEMU" >&2
  exit 1
fi
