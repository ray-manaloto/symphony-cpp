#!/usr/bin/env bash
set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly profile="${1:-gcc}"

case "${profile}" in
  gcc)
    readonly config="${repository_root}/.devcontainer/devcontainer.json"
    readonly preset="gcc-debug"
    ;;
  clang-p2996)
    readonly config="${repository_root}/.devcontainer/clang-p2996/devcontainer.json"
    readonly preset="clang-reflection"
    ;;
  *)
    echo "usage: $0 {gcc|clang-p2996}" >&2
    exit 2
    ;;
esac

command -v devcontainer >/dev/null

devcontainer up \
  --workspace-folder "${repository_root}" \
  --config "${config}"

devcontainer exec \
  --workspace-folder "${repository_root}" \
  --config "${config}" \
  bash -lc "cmake --preset ${preset} \
    && cmake --build --preset ${preset} \
    && ctest --preset ${preset}"
