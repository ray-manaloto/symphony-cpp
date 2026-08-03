#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "${BASH_SOURCE[0]%/*}/.." && pwd -P)"
readonly repo_root
readonly -a input_paths=(
  .github/workflows/opensymphony-v2113-evaluation.yml
  containers/OpenSymphony-v2113-evaluation.Containerfile
  containers/opensymphony-v2113-evaluation.bake.hcl
  ops/opensymphony/evaluation/v2.11.3/input-manifest-v1.json
  scripts/build-opensymphony-v2113-evaluation.sh
  scripts/opensymphony-v2113-build-input-id.sh
  scripts/run-opensymphony-v2113-github-actions.sh
  scripts/test-opensymphony-v2113-build.sh
  scripts/test-opensymphony-v2113-github-actions.mjs
  scripts/test-opensymphony-v2113-upstream.sh
)

fail() {
  printf 'OpenSymphony v2.11.3 build-input identity failed: %s\n' "$*" >&2
  return 1
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "required command is unavailable: $1"
  fi
}

require_lower_sha256() {
  local value="$1"
  local label="$2"
  if [[ ! "${value}" =~ ^[0-9a-f]{64}$ ]]; then
    fail "invalid ${label}: expected exactly 64 lowercase hexadecimal characters"
  fi
}

input_mode() {
  local host_os="$2"
  case "${host_os}" in
    Linux) stat -c '%a' -- "$1" ;;
    Darwin) stat -f '%Lp' "$1" ;;
  esac
}

input_sha256_output() {
  local host_os="$2"
  case "${host_os}" in
    Linux) sha256sum -- "$1" ;;
    Darwin) shasum -a 256 -- "$1" ;;
  esac
}

stream_sha256_output() {
  local host_os="$1"
  case "${host_os}" in
    Linux) sha256sum ;;
    Darwin) shasum -a 256 ;;
  esac
}

serialize_inputs() {
  local host_os="$1"
  local input_path mode hash_output sha256

  cd "${repo_root}" || fail "repository root is unavailable: ${repo_root}"
  printf 'opensymphony-v2113-evaluation-build-input-v2\0'
  for input_path in "${input_paths[@]}"; do
    if [[ ! -f "${input_path}" ]]; then
      fail "required build-input file is unavailable: ${input_path}"
      return 1
    fi
    if ! mode="$(input_mode "${input_path}" "${host_os}")"; then
      fail "stat failed for ${input_path}"
      return 1
    fi
    if [[ ! "${mode}" =~ ^(644|755)$ ]]; then
      fail "invalid mode for ${input_path}: ${mode}"
      return 1
    fi
    if ! hash_output="$(input_sha256_output "${input_path}" "${host_os}")"; then
      fail "file SHA-256 command failed for ${input_path}"
      return 1
    fi
    if ! read -r sha256 _ <<<"${hash_output}"; then
      fail "invalid file SHA-256 for ${input_path}: command emitted no digest"
      return 1
    fi
    if ! require_lower_sha256 "${sha256}" "file SHA-256 for ${input_path}"; then
      return 1
    fi
    printf '%s\0%s\0%s\n' "${input_path}" "${mode}" "${sha256}"
  done
}

hash_serialized_inputs() {
  local host_os="$1"
  local hash_output sha256
  if ! hash_output="$(stream_sha256_output "${host_os}")"; then
    fail "final SHA-256 command failed"
    return 1
  fi
  if ! read -r sha256 _ <<<"${hash_output}"; then
    fail "invalid final SHA-256: command emitted no digest"
    return 1
  fi
  if ! require_lower_sha256 "${sha256}" "final SHA-256"; then
    return 1
  fi
  printf '%s\n' "${sha256}"
}

main() {
  local host_os final_sha256

  require_command uname || return 1
  if ! host_os="$(uname -s)"; then
    fail "uname -s failed"
    return 1
  fi
  case "${host_os}" in
    Linux)
      require_command stat || return 1
      require_command sha256sum || return 1
      ;;
    Darwin)
      require_command stat || return 1
      require_command shasum || return 1
      ;;
    *)
      fail "unsupported host OS ${host_os}"
      return 1
      ;;
  esac

  if ! final_sha256="$(serialize_inputs "${host_os}" | hash_serialized_inputs "${host_os}")"; then
    return 1
  fi
  if ! require_lower_sha256 "${final_sha256}" "final SHA-256"; then
    return 1
  fi
  printf '%s\n' "${final_sha256}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
