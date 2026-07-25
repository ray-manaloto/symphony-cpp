#!/usr/bin/env bash
set -euo pipefail

readonly pathspecs=(
  ':(glob)include/**/*.h'
  ':(glob)include/**/*.hh'
  ':(glob)include/**/*.hpp'
  ':(glob)include/**/*.cc'
  ':(glob)include/**/*.cpp'
  ':(glob)include/**/*.cxx'
  ':(glob)src/**/*.h'
  ':(glob)src/**/*.hh'
  ':(glob)src/**/*.hpp'
  ':(glob)src/**/*.cc'
  ':(glob)src/**/*.cpp'
  ':(glob)src/**/*.cxx'
  ':(glob)tests/**/*.h'
  ':(glob)tests/**/*.hh'
  ':(glob)tests/**/*.hpp'
  ':(glob)tests/**/*.cc'
  ':(glob)tests/**/*.cpp'
  ':(glob)tests/**/*.cxx'
  ':(exclude)tests/fixtures/p2996_reflection_probe.cpp'
)

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git ls-files -z --cached --others --exclude-standard -- "${pathspecs[@]}"
  exit
fi

for source_directory in include src tests; do
  [[ -d "${source_directory}" ]] || continue
  find "${source_directory}" -type f \
    \( -name '*.h' -o -name '*.hh' -o -name '*.hpp' \
    -o -name '*.cc' -o -name '*.cpp' -o -name '*.cxx' \) \
    ! -path 'tests/fixtures/p2996_reflection_probe.cpp' \
    -print0
done
