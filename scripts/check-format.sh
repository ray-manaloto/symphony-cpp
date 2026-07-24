#!/usr/bin/env bash
set -euo pipefail

readonly clang_format=/opt/llvm-22.1.8/bin/clang-format

./scripts/check-clang-format-version.sh "$("${clang_format}" --version)"

git ls-files -z --cached --others --exclude-standard -- \
  ':(glob)include/**/*.h' \
  ':(glob)include/**/*.hh' \
  ':(glob)include/**/*.hpp' \
  ':(glob)src/**/*.cc' \
  ':(glob)src/**/*.cpp' \
  ':(glob)src/**/*.cxx' \
  ':(glob)tests/**/*.cc' \
  ':(glob)tests/**/*.cpp' \
  ':(glob)tests/**/*.cxx' |
  xargs -0 -r "${clang_format}" \
    --dry-run \
    --Werror \
    --style=file \
    --fallback-style=none
