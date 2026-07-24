#!/usr/bin/env bash
set -euo pipefail

readonly tidy_config="${1:-.clang-tidy}"
readonly tidy_runner="${2:-scripts/check-tidy.sh}"
readonly project_root="${3:-.}"

test "$(grep -Ec '^[[:space:]]*WarningsAsErrors:' "${tidy_config}")" = 1
warnings_as_errors="$(
  sed -n 's/^[[:space:]]*WarningsAsErrors:[[:space:]]*//p' "${tidy_config}"
)"
readonly warnings_as_errors
if [[ "${warnings_as_errors}" != "''" && "${warnings_as_errors}" != '""' ]]; then
  echo "clang-tidy report-only baseline has nonempty WarningsAsErrors" >&2
  exit 1
fi
if grep -Eq -- '(^|[[:space:]])-{1,2}warnings-as-errors(=|[[:space:]])' "${tidy_runner}"; then
  echo "clang-tidy runner promotes report-only warnings to errors" >&2
  exit 1
fi
if grep -Eq -- '(^|[[:space:]])-{1,2}config(-file)?(=|[[:space:]])' "${tidy_runner}"; then
  echo "clang-tidy runner overrides the project configuration" >&2
  exit 1
fi

for source_root in include src tests; do
  if [[ -d "${project_root}/${source_root}" ]] &&
      find "${project_root}/${source_root}" -name .clang-tidy -print -quit | grep -q .; then
    echo "nested .clang-tidy overrides the report-only project policy" >&2
    exit 1
  fi
done
