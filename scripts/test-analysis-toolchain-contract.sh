#!/usr/bin/env bash
set -euo pipefail

readonly verifier=./scripts/check-clang-format-version.sh
readonly pinned_commit=ca7933e47d3a3451d81e72ac174dcb5aa28b59d1

"${verifier}" "clang-format version 22.1.8"
"${verifier}" \
  "clang-format version 22.1.8 (https://github.com/llvm/llvm-project ${pinned_commit})"

if "${verifier}" "clang-format version 22.1.9" 2>/dev/null; then
  echo "accepted a different clang-format version" >&2
  exit 1
fi

if "${verifier}" "clang-format version 22.1.8 (untrusted provenance)" 2>/dev/null; then
  echo "accepted an unrecognized clang-format provenance suffix" >&2
  exit 1
fi

if "${verifier}" \
  "clang-format version 22.1.8 (https://github.com/llvm/llvm-project deadbeef)" 2>/dev/null; then
  echo "accepted a different LLVM source revision" >&2
  exit 1
fi
