#!/usr/bin/env bash
set -euo pipefail

repository_root="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/.."
  pwd
)"
readonly repository_root
configure_log_override="${SYMPHONY_CMAKE_CONFIGURE_LOG:-}"
if [[ -z "${configure_log_override}" ]]; then
  configure_log="${repository_root}/build/clang-reflection/CMakeFiles/CMakeConfigureLog.yaml"
  rm -f -- "${configure_log}"
else
  configure_log="${configure_log_override}"
  if [[ -e "${configure_log}" ]]; then
    echo "test configure-log override must not exist before invocation" >&2
    exit 64
  fi
fi
readonly configure_log

cd "${repository_root}"
if cmake --workflow --fresh --preset clang-reflection; then
  link_commands_file="$(mktemp)"
  readonly link_commands_file
  if ninja -C build/clang-reflection -t commands symphony_p2996_tests \
      >"${link_commands_file}" &&
      python3 ./scripts/check-p2996-compile-commands.py \
        build/clang-reflection/compile_commands.json \
        "${link_commands_file}"; then
    rm -f "${link_commands_file}"
    exit 0
  else
    readonly command_validation_status=$?
    rm -f "${link_commands_file}"
    exit "${command_validation_status}"
  fi
else
  readonly workflow_status=$?
fi

if [[ -f "${configure_log}" ]]; then
  echo "bounded clang-reflection configure diagnostics:" >&2
  if ! tail -n 240 "${configure_log}" |
    awk -f ./scripts/redact-build-log.awk >&2; then
    echo "failed to render clang-reflection configure diagnostics" >&2
  fi
else
  echo "clang-reflection failed without a current-attempt configure log" >&2
fi

exit "${workflow_status}"
