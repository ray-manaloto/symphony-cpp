#!/usr/bin/env bash
set -euo pipefail

readonly CMAKE_VERSION=4.4.0
readonly CMAKE_SHA256=3864eb649b4466ae126a64bbde1657adad78efbbaa068bf38201de5cf1b5349f
readonly CMAKE_ARCHIVE="cmake-${CMAKE_VERSION}-linux-x86_64.tar.gz"
readonly CMAKE_URL="https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/${CMAKE_ARCHIVE}"
readonly CMAKE_ROOT="/opt/cmake-${CMAKE_VERSION}"
readonly CMAKE_EXTRACTED_ROOT="/opt/cmake-${CMAKE_VERSION}-linux-x86_64"

if [[ "$(uname -m)" != "x86_64" ]]; then
  echo "CMake ${CMAKE_VERSION} installer supports only the linux/amd64 development image" >&2
  exit 64
fi

if [[ ! -x "${CMAKE_EXTRACTED_ROOT}/bin/cmake" ]]; then
  readonly temporary_directory="$(mktemp -d)"
  trap 'rm -rf "${temporary_directory}"' EXIT
  curl --fail --location --proto '=https' --tlsv1.2 \
    --output "${temporary_directory}/${CMAKE_ARCHIVE}" \
    "${CMAKE_URL}"
  echo "${CMAKE_SHA256}  ${temporary_directory}/${CMAKE_ARCHIVE}" |
    sha256sum --check -
  tar -xzf "${temporary_directory}/${CMAKE_ARCHIVE}" -C /opt
fi

ln -sfn "${CMAKE_EXTRACTED_ROOT}" "${CMAKE_ROOT}"
for tool in cmake cpack ctest; do
  ln -sfn "${CMAKE_ROOT}/bin/${tool}" "/usr/local/bin/${tool}"
done

test "$(cmake --version | head -n 1)" = "cmake version ${CMAKE_VERSION}"
