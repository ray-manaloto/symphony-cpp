# syntax=docker/dockerfile:1.10@sha256:865e5dd094beca432e8c0a1d5e1c465db5f998dca4e439981029b3b81fb39ed5

# `runtime-base` is a required BuildKit named context. The focused Bake graph
# supplies it from the generic runtime target; this file never constructs or
# publishes a reusable toolchain image.
FROM scratch AS runtime-base
FROM runtime-base AS gcc16-validation-execution
ARG TARGETARCH
USER root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN test "$(dpkg --print-architecture)" = "${TARGETARCH}" \
 && test "$(g++ -dumpfullversion)" = "16.1.0" \
 && test "$(cmake --version | head -n 1)" = "cmake version 4.4.0" \
 && command -v ninja \
 && command -v ccache \
 && printf '%s\n' '#include <iostream>' \
      'int main() { std::cout << 16; }' \
      | g++ -std=c++26 -freflection -x c++ - -o /tmp/gcc-runtime-check \
 && ldd /tmp/gcc-runtime-check \
      | grep -F 'libstdc++.so.6 => /opt/gcc-16.1/lib64/libstdc++.so.6' \
 && test "$(/tmp/gcc-runtime-check)" = "16" \
 && rm /tmp/gcc-runtime-check

RUN --mount=type=bind,source=.,target=/workspaces/symphony-cpp,rw \
    --mount=type=cache,id=gcc-${TARGETARCH}-ccache,target=/var/cache/ccache,sharing=locked \
    --mount=type=cache,id=gcc-${TARGETARCH}-vcpkg-archives,target=/var/cache/vcpkg,sharing=locked \
    --mount=type=cache,id=gcc-${TARGETARCH}-vcpkg-root,target=/workspaces/symphony-cpp/.build/vcpkg,sharing=locked \
    --mount=type=cache,id=gcc-${TARGETARCH}-vcpkg-installed,target=/workspaces/symphony-cpp/vcpkg_installed,sharing=locked \
    --mount=type=cache,id=gcc-${TARGETARCH}-build,target=/workspaces/symphony-cpp/build,sharing=locked \
    cd /workspaces/symphony-cpp \
 && export CCACHE_DIR=/var/cache/ccache \
           CCACHE_COMPILERCHECK=content \
           VCPKG_DEFAULT_BINARY_CACHE=/var/cache/vcpkg \
 && ccache --max-size=750M \
 && ccache --zero-stats \
 && ./scripts/devcontainer-setup.sh gcc \
 && cmake --workflow --preset gcc-debug \
 && cmake --workflow --preset gcc-release \
 && cmake --workflow --preset gcc-sanitizers \
 && cmake --workflow --preset gcc-tsan \
 && ccache --show-stats \
 && vcpkg_cache_bytes="$(du -sb /var/cache/vcpkg | cut -f1)" \
 && vcpkg_cache_files="$(find /var/cache/vcpkg -type f | wc -l)" \
 && printf 'vcpkg-cache bytes=%s files=%s\n' \
      "${vcpkg_cache_bytes}" "${vcpkg_cache_files}" \
 && install -d /validation \
 && printf '%s\n' passed >/validation/gcc16

FROM scratch AS gcc16-validation
COPY --from=gcc16-validation-execution /validation/gcc16 /gcc16-validation-passed
