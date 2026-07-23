#!/usr/bin/env bash
set -euo pipefail

readonly llvm_root=/opt/llvm-22.1.8
readonly clang_tidy="${llvm_root}/bin/clang-tidy"
readonly run_clang_tidy="${llvm_root}/bin/run-clang-tidy"
readonly build_directory=build/clang-analysis
readonly header_filter='(^|.*/)symphony-cpp/(include|src|tests)/'
readonly source_filter='^(.*symphony-cpp/)?src/.*\.(cc|cpp|cxx)$'

test "$("${clang_tidy}" --version |
  sed -n 's/^[[:space:]]*LLVM version \([^ ]*\).*$/\1/p')" = "22.1.8"
test -x "${run_clang_tidy}"
"${clang_tidy}" --verify-config

test -f "${build_directory}/compile_commands.json"
"${run_clang_tidy}" \
  -p "${build_directory}" \
  -j 4 \
  -header-filter="${header_filter}" \
  "${source_filter}"
