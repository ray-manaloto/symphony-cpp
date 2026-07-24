#!/usr/bin/env bash
set -euo pipefail

readonly clang_format=/opt/llvm-22.1.8/bin/clang-format

./scripts/check-clang-format-version.sh "$("${clang_format}" --version)"

./scripts/list-format-sources.sh |
  xargs -0 -r "${clang_format}" \
    --dry-run \
    --Werror \
    --style=file \
    --fallback-style=none
