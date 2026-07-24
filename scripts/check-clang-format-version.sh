#!/usr/bin/env bash
set -euo pipefail

readonly expected_version="clang-format version 22.1.8"
readonly expected_provenance=\
"${expected_version} (https://github.com/llvm/llvm-project ca7933e47d3a3451d81e72ac174dcb5aa28b59d1)"
readonly actual_version="${1:-$(/opt/llvm-22.1.8/bin/clang-format --version)}"

case "${actual_version}" in
  "${expected_version}"|"${expected_provenance}") ;;
  *)
    printf 'unexpected clang-format version: <%s>\n' "${actual_version}" >&2
    exit 1
    ;;
esac
