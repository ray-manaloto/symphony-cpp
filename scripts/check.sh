#!/usr/bin/env bash
set -euo pipefail

cmake --preset gcc-debug
cmake --build --preset gcc-debug
ctest --preset gcc-debug

