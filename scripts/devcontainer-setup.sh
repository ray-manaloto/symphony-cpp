#!/usr/bin/env bash
set -euo pipefail

redact_and_bound_vcpkg_log() {
  awk '
    {
      lower = tolower($0)
      if (lower ~ /[[:alnum:]_]*(api[_-]?key|token|secret|password|passwd)[[:alnum:]_-]*[[:space:]]*[:=]/ ||
          lower ~ /authorization[[:space:]]*[:=]/ ||
          lower ~ /bearer[[:space:]]+[^[:space:]]/) {
        print "[redacted secret-bearing build log line]"
      } else if (length($0) > 300) {
        print substr($0, 1, 300) "..."
      } else {
        print
      }
    }
  '
}

show_vcpkg_failure_logs() {
  local marker="$1"
  local buildtrees=.build/vcpkg/buildtrees
  local index
  local insert_at
  local log_path
  local -a ranked_logs=()
  [[ -d "${buildtrees}" ]] || return 0

  while IFS= read -r -d '' log_path; do
    insert_at="${#ranked_logs[@]}"
    for ((index = 0; index < ${#ranked_logs[@]}; ++index)); do
      if [[ "${log_path}" -nt "${ranked_logs[index]}" ]]; then
        insert_at="${index}"
        break
      fi
    done
    ranked_logs=(
      "${ranked_logs[@]:0:insert_at}"
      "${log_path}"
      "${ranked_logs[@]:insert_at}"
    )
    if [[ "${#ranked_logs[@]}" -gt 6 ]]; then
      ranked_logs=("${ranked_logs[@]:0:6}")
    fi
  done < <(
    find "${buildtrees}" -type f \
      \( -name '*-out.log' -o -name '*-err.log' -o -name 'stdout-*.log' \) \
      -size +0c -newer "${marker}" -print0
  )

  if [[ "${#ranked_logs[@]}" -eq 0 ]]; then
    echo "current vcpkg attempt produced no nonempty build logs" >&2
    return 0
  fi

  echo "newest nonempty vcpkg build logs from current attempt:" >&2
  for log_path in "${ranked_logs[@]}"; do
    echo "===== ${log_path} =====" >&2
    tail -n 120 "${log_path}" | redact_and_bound_vcpkg_log >&2
  done
}

run_vcpkg_install() {
  local marker
  local status
  marker="$(mktemp)"
  if .build/vcpkg/vcpkg install "$@"; then
    rm -f "${marker}"
    return 0
  else
    status=$?
  fi
  show_vcpkg_failure_logs "${marker}" || true
  rm -f "${marker}"
  return "${status}"
}

main() {
  local profile="${1:-}"
  case "${profile}" in
    gcc)
      test "$(/opt/gcc-16.1/bin/g++ -dumpfullversion)" = "16.1.0"
      ./scripts/bootstrap-vcpkg.sh
      run_vcpkg_install --clean-after-build
      ;;
    clang-p2996)
      test -x /opt/clang-p2996/bin/clang++
      ./scripts/bootstrap-vcpkg.sh
      run_vcpkg_install \
        --triplet x64-linux-clang-p2996 \
        --overlay-triplets vcpkg-triplets \
        --clean-after-build
      ;;
    analysis)
      test "$(/opt/llvm-22.1.8/bin/clang++ --version |
        sed -n 's/^clang version \([^ ]*\).*$/\1/p' |
        head -n 1)" = "22.1.8"
      ./scripts/bootstrap-vcpkg.sh
      run_vcpkg_install \
        --triplet x64-linux-clang-analysis \
        --overlay-triplets vcpkg-triplets \
        --clean-after-build
      ;;
    *)
      echo "usage: $0 {gcc|clang-p2996|analysis}" >&2
      return 2
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
