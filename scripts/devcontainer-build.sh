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
  analysis-rtsan)
    readonly config="${repository_root}/.devcontainer/analysis/devcontainer.json"
    readonly preset="clang-rtsan"
    ;;
  *)
    echo "usage: $0 {gcc|gcc-release|gcc-sanitizers|clang-p2996|analysis|analysis-rtsan}" >&2
    exit 2
    ;;
esac

command -v devcontainer >/dev/null

required_cli_version="$(
  tr -d '[:space:]' < "${repository_root}/.devcontainer/devcontainer-cli.version"
)"
readonly required_cli_version
actual_cli_version="$(devcontainer --version)"
readonly actual_cli_version
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
      && cmake --fresh --preset ${preset} \
      && ./scripts/check-tidy.sh"
elif [[ "${profile}" == "analysis-rtsan" ]]; then
  devcontainer exec \
    --workspace-folder "${repository_root}" \
    --config "${config}" \
    bash -lc "cmake --workflow --fresh --preset ${preset} \
      && python3 ./scripts/check-analysis-compile-commands.py \
        build/clang-rtsan/compile_commands.json --require-rtsan-fixtures"
elif [[ "${profile}" == "clang-p2996" ]]; then
  devcontainer exec \
    --workspace-folder "${repository_root}" \
    --config "${config}" \
    bash -lc "./scripts/run-clang-reflection-workflow.sh"
else
  devcontainer exec \
    --workspace-folder "${repository_root}" \
    --config "${config}" \
    bash -lc "cmake --preset ${preset} \
      && cmake --build --preset ${preset} \
      && ctest --preset ${preset}"
fi
