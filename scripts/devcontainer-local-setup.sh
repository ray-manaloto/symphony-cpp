#!/usr/bin/env bash
set -euo pipefail

readonly profile="${1:-}"
./scripts/devcontainer-setup.sh "${profile}"

mise trust .mise.toml
mise install --locked
pre-commit install
