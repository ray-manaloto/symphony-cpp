#!/usr/bin/env bash
set -euo pipefail

readonly profile="${1:-}"

case "${profile}" in
  gcc)
    test "$(/opt/gcc-16.1/bin/g++ -dumpfullversion)" = "16.1.0"
    ./scripts/bootstrap-vcpkg.sh
    .build/vcpkg/vcpkg install --clean-after-build
    ;;
  clang-p2996)
    test -x /opt/clang-p2996/bin/clang++
    ./scripts/bootstrap-vcpkg.sh
    .build/vcpkg/vcpkg install \
      --triplet x64-linux-clang-p2996 \
      --overlay-triplets vcpkg-triplets \
      --clean-after-build
    ;;
  analysis)
    test "$(/opt/llvm-22.1.8/bin/clang++ --version |
      sed -n 's/^clang version \([^ ]*\).*$/\1/p' |
      head -n 1)" = "22.1.8"
    ./scripts/bootstrap-vcpkg.sh
    .build/vcpkg/vcpkg install \
      --triplet x64-linux-clang-analysis \
      --overlay-triplets vcpkg-triplets \
      --clean-after-build
    ;;
  *)
    echo "usage: $0 {gcc|clang-p2996|analysis}" >&2
    exit 2
    ;;
esac
