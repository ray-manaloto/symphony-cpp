#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly repository_root
readonly profile="${1:-gcc}"

case "${profile}" in
  gcc)
    readonly config="${repository_root}/.devcontainer/devcontainer.json"
    readonly preset="gcc-debug"
    ;;
  gcc-sanitizers)
    readonly config="${repository_root}/.devcontainer/devcontainer.json"
    readonly preset="gcc-sanitizers"
    ;;
  gcc-release)
    readonly config="${repository_root}/.devcontainer/devcontainer.json"
    readonly preset="gcc-release"
    ;;
  clang-p2996)
    readonly config="${repository_root}/.devcontainer/clang-p2996/devcontainer.json"
    readonly preset="clang-reflection"
    ;;
  analysis)
    readonly config="${repository_root}/.devcontainer/analysis/devcontainer.json"
    readonly preset="clang-analysis"
    ;;
  *)
    echo "usage: $0 {gcc|gcc-release|gcc-sanitizers|clang-p2996|analysis}" >&2
    exit 2
    ;;
esac

command -v devcontainer >/dev/null

readonly required_cli_version="$(
  tr -d '[:space:]' < "${repository_root}/.devcontainer/devcontainer-cli.version"
)"
readonly actual_cli_version="$(devcontainer --version)"
if [[ "${actual_cli_version}" != "${required_cli_version}" ]]; then
  printf 'Dev Container CLI %s is required; found %s at %s\n' \
    "${required_cli_version}" "${actual_cli_version}" "$(command -v devcontainer)" >&2
  exit 1
fi

printf 'Dev Container profile: %s; CLI: %s\n' "${profile}" "${actual_cli_version}"

devcontainer up \
  --workspace-folder "${repository_root}" \
  --config "${config}"

if [[ "${profile}" == "analysis" ]]; then
  devcontainer exec \
    --workspace-folder "${repository_root}" \
    --config "${config}" \
    bash -lc "./scripts/check-format.sh \
      && cmake --preset ${preset} \
      && ./scripts/check-tidy.sh"
else
  devcontainer exec \
    --workspace-folder "${repository_root}" \
    --config "${config}" \
    bash -lc "cmake --preset ${preset} \
      && cmake --build --preset ${preset} \
      && ctest --preset ${preset}"
fi
