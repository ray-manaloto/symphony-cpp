#!/usr/bin/env bash
set -euo pipefail

./scripts/test-opensymphony-container.sh
cmake --preset gcc-debug
cmake --build --preset gcc-debug
ctest --preset gcc-debug
