#!/usr/bin/env bash
set -euo pipefail

readonly profile="${1:-}"
./scripts/devcontainer-setup.sh "${profile}"

# A developer's mounted dotfiles may provide unrelated global tools. The repository lock is
# intentionally complete only for this project, so isolate project installation from that config.
export MISE_GLOBAL_CONFIG_FILE=/dev/null
mise trust .mise.toml
mise install --locked
pre-commit install
