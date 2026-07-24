#!/usr/bin/env bash
set -euo pipefail

readonly verifier=./scripts/check-clang-format-version.sh
readonly source_lister="${PWD}/scripts/list-format-sources.sh"
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

fixture_root="$(mktemp -d)"
readonly fixture_root
trap 'rm -rf "${fixture_root}"' EXIT
mkdir -p "${fixture_root}/include/project" "${fixture_root}/src" "${fixture_root}/tests"
touch "${fixture_root}/include/project/api.hpp" \
  "${fixture_root}/src/main.cpp" \
  "${fixture_root}/src/private.hpp" \
  "${fixture_root}/src/ignored.md" \
  "${fixture_root}/tests/main_tests.cxx" \
  "${fixture_root}/tests/support.hh"
git_free_sources="$(
  cd "${fixture_root}"
  "${source_lister}" | tr '\0' '\n' | LC_ALL=C sort
)"
readonly git_free_sources
expected_sources="$(
  printf '%s\n' \
    include/project/api.hpp \
    src/main.cpp \
    src/private.hpp \
    tests/main_tests.cxx \
    tests/support.hh
)"
readonly expected_sources
test "${git_free_sources}" = "${expected_sources}"

(
  cd "${fixture_root}"
  git init --quiet
  mkdir ignored
  touch ignored/generated.cpp
  printf '%s\n' '/ignored/' >.gitignore
  git add .
)
git_sources="$(
  cd "${fixture_root}"
  "${source_lister}" | tr '\0' '\n' | LC_ALL=C sort
)"
readonly git_sources
test "${git_sources}" = "${git_free_sources}"
