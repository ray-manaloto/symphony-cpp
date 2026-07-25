# syntax=docker/dockerfile:1.10@sha256:865e5dd094beca432e8c0a1d5e1c465db5f998dca4e439981029b3b81fb39ed5

# `runtime-base` is a required BuildKit named context. The focused Bake graph
# supplies it from the generic runtime target; this file never constructs or
# publishes a reusable toolchain image.
FROM scratch AS runtime-base
FROM runtime-base AS p2996-validation-execution
USER root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN test "$(dpkg --print-architecture)" = "amd64" \
 && test -x /opt/clang-p2996/bin/clang++ \
 && test -x /opt/clang-p2996/bin/ld.lld \
 && test -f /opt/clang-p2996/include/c++/v1/meta \
 && test "$(cmake --version | head -n 1)" = "cmake version 4.4.0" \
 && command -v ninja \
 && command -v ccache

RUN --mount=type=bind,source=.,target=/workspaces/symphony-cpp,rw \
    --mount=type=cache,id=clang-p2996-ccache,target=/var/cache/ccache,sharing=locked \
    --mount=type=cache,id=clang-p2996-vcpkg-archives,target=/var/cache/vcpkg,sharing=locked \
    --mount=type=cache,id=clang-p2996-vcpkg-root,target=/workspaces/symphony-cpp/.build/vcpkg,sharing=locked \
    --mount=type=cache,id=clang-p2996-vcpkg-installed,target=/workspaces/symphony-cpp/vcpkg_installed,sharing=locked \
    --mount=type=cache,id=clang-p2996-build,target=/workspaces/symphony-cpp/build,sharing=locked \
    cd /workspaces/symphony-cpp \
 && export CCACHE_DIR=/var/cache/ccache \
           CCACHE_COMPILERCHECK=content \
           VCPKG_DEFAULT_BINARY_CACHE=/var/cache/vcpkg \
 && ccache --max-size=750M \
 && ccache --zero-stats \
 && /opt/clang-p2996/bin/clang++ \
      -std=c++26 -stdlib=libc++ -freflection -fexpansion-statements \
      -fuse-ld=lld tests/fixtures/p2996_reflection_probe.cpp \
      -Wl,-rpath,/opt/clang-p2996/lib/x86_64-unknown-linux-gnu \
      -Wl,-rpath,/opt/clang-p2996/lib \
      -o /tmp/p2996-reflection-probe \
 && /opt/clang-p2996/bin/clang++ \
      -std=c++26 -stdlib=libc++ -freflection -fexpansion-statements \
      -fuse-ld=lld tests/fixtures/p2996_reflection_probe.cpp \
      -Wl,-rpath,/opt/clang-p2996/lib/x86_64-unknown-linux-gnu \
      -Wl,-rpath,/opt/clang-p2996/lib \
      -o /tmp/p2996-link-probe -### 2>&1 \
      | tee /tmp/p2996-linker-trace \
      | grep -Fq '"/opt/clang-p2996/bin/ld.lld"' \
 && ldd /tmp/p2996-reflection-probe \
      | tee /tmp/p2996-runtime-links \
      | grep -Eq 'libc\+\+\.so\.1 => /opt/clang-p2996/' \
 && grep -Eq 'libc\+\+abi\.so\.1 => /opt/clang-p2996/' /tmp/p2996-runtime-links \
 && grep -Eq 'libunwind\.so\.1 => /opt/clang-p2996/' /tmp/p2996-runtime-links \
 && /tmp/p2996-reflection-probe \
 && rm /tmp/p2996-reflection-probe /tmp/p2996-linker-trace /tmp/p2996-runtime-links \
 && ./scripts/devcontainer-setup.sh clang-p2996 \
 && ./scripts/run-clang-reflection-workflow.sh \
 && ccache --show-stats \
 && install -d /validation \
 && printf '%s\n' passed >/validation/clang-p2996

FROM scratch AS clang-p2996-validation
COPY --from=p2996-validation-execution /validation/clang-p2996 /clang-p2996-validation-passed
