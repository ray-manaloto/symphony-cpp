#!/usr/bin/env bash
set -euo pipefail

readonly VCPKG_COMMIT=4493042c759d3bdff26164695dbee500d1e696c8
readonly REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly VCPKG_ROOT="${REPOSITORY_ROOT}/.build/vcpkg"

if [[ ! -d "${VCPKG_ROOT}/.git" ]]; then
  git clone --filter=blob:none https://github.com/microsoft/vcpkg.git "${VCPKG_ROOT}"
fi

git -C "${VCPKG_ROOT}" fetch --depth 1 origin "${VCPKG_COMMIT}"
git -C "${VCPKG_ROOT}" checkout --detach "${VCPKG_COMMIT}"
test "$(git -C "${VCPKG_ROOT}" rev-parse HEAD)" = "${VCPKG_COMMIT}"
"${VCPKG_ROOT}/bootstrap-vcpkg.sh" -disableMetrics
