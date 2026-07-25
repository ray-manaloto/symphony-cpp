# syntax=docker/dockerfile:1.10@sha256:865e5dd094beca432e8c0a1d5e1c465db5f998dca4e439981029b3b81fb39ed5

# The workflow must replace this empty sentinel with one exact, digest-pinned
# generic runtime child. A missing named context therefore fails closed.
FROM scratch AS runtime-base
FROM runtime-base AS gcc16-runtime-candidate-validation-execution
ARG TARGETARCH
USER root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN --network=none \
    echo "phase=runtime-toolchain-smoke architecture=${TARGETARCH}" \
 && test "$(dpkg --print-architecture)" = "${TARGETARCH}" \
 && test "$(/opt/gcc-16.1/bin/g++ -dumpfullversion)" = "16.1.0" \
 && test "$(cmake --version | head -n 1)" = "cmake version 4.4.0" \
 && command -v ninja \
 && command -v ccache \
 && test "$(command -v gcc)" = "/opt/gcc-16.1/bin/gcc" \
 && test "$(command -v g++)" = "/opt/gcc-16.1/bin/g++" \
 && test "${CC}" = "/opt/gcc-16.1/bin/gcc" \
 && test "${CXX}" = "/opt/gcc-16.1/bin/g++" \
 && test -z "${LD_LIBRARY_PATH+x}"

RUN --network=none \
    --mount=type=bind,source=tests/fixtures/p2996_reflection_probe.cpp,target=/tmp/gcc16-reflection-probe.cpp,ro \
    echo "phase=cxx26-reflection-compile-and-run" \
 && /opt/gcc-16.1/bin/g++ \
      -std=c++26 -freflection \
      /tmp/gcc16-reflection-probe.cpp \
      -o /tmp/gcc16-reflection-probe \
 && env -u LD_LIBRARY_PATH ldd /tmp/gcc16-reflection-probe \
      | tee /tmp/gcc16-runtime-links \
 && grep -Fq \
      'libstdc++.so.6 => /opt/gcc-16.1/lib64/libstdc++.so.6' \
      /tmp/gcc16-runtime-links \
 && grep -Fq \
      'libgcc_s.so.1 => /opt/gcc-16.1/lib64/libgcc_s.so.1' \
      /tmp/gcc16-runtime-links \
 && env -u LD_LIBRARY_PATH /tmp/gcc16-reflection-probe \
 && rm /tmp/gcc16-reflection-probe /tmp/gcc16-runtime-links \
 && mkdir -p /validation \
 && printf '%s\n' passed >/validation/gcc16-runtime-candidate-execution

FROM ghcr.io/containerd/busybox@sha256:52f73a0a43a16cf37cd0720c90887ce972fe60ee06a687ee71fb93a7ca601df7 AS gcc16-runtime-candidate-rootfs-audit
SHELL ["/bin/sh", "-eu", "-c"]

# The candidate must not use its own shell or filesystem tools to attest to its
# cleanliness. Inspect its merged rootfs from a pinned utility image instead.
RUN --network=none \
    --mount=type=bind,from=runtime-base,source=/,target=/candidate,ro \
    echo "phase=merged-rootfs-contamination-audit" \
 && for forbidden_path in \
      /opt/symphony-cpp-seed \
      /workspaces/symphony-cpp \
      /tmp/gcc \
      /tmp/llvm-build \
      /tmp/llvm-project \
      /tmp/install-cmake.sh \
      /usr/local/bin/opensymphony \
      /opt/opensymphony \
      /root/.docker/config.json \
      /root/.config/gh/hosts.yml \
      /root/.npmrc; do \
      candidate_path="/candidate${forbidden_path}"; \
      if test -e "${candidate_path}" || test -L "${candidate_path}"; then \
        echo "forbidden runtime path: ${forbidden_path}" >&2; \
        exit 1; \
      fi; \
      echo "absent=${forbidden_path}"; \
    done \
 && forbidden_directory="$( \
      find /candidate -xdev -type d \
        \( -name symphony-cpp \
        -o -name vcpkg_installed \
        -o -name .opensymphony \) \
        -print -quit \
    )" \
 && if [ -n "${forbidden_directory}" ]; then \
      echo "forbidden runtime directory: ${forbidden_directory}" >&2; \
      exit 1; \
    fi \
 && secret_file="$( \
      find /candidate -xdev \
        \( -path '/candidate/root/.ssh/*' \
        -o -path '/candidate/root/.docker/config.json' \
        -o -path '/candidate/root/.config/gh/hosts.yml' \
        -o -path '/candidate/root/.codex/auth.json' \
        -o -path '/candidate/root/.aws/credentials' \
        -o -path '/candidate/root/.config/gcloud/*credentials*' \
        -o -path '/candidate/root/.azure/*' \
        -o -path '/candidate/run/secrets/*' \
        -o -path '/candidate/root/.netrc' \
        -o -path '/candidate/root/.git-credentials' \) \
        -print -quit \
    )" \
 && if [ -n "${secret_file}" ]; then \
      echo "forbidden runtime credential or secret path: ${secret_file}" >&2; \
      exit 1; \
    fi \
 && if test -d /candidate/var/cache/vcpkg \
      && find /candidate/var/cache/vcpkg -mindepth 1 -print -quit \
        | grep -q .; then \
      echo "forbidden vcpkg binary archive content" >&2; \
      exit 1; \
    fi \
 && echo "phase=merged-rootfs-contamination-audit result=passed" \
 && mkdir -p /validation \
 && printf '%s\n' passed >/validation/gcc16-runtime-candidate-rootfs

FROM scratch AS gcc16-runtime-candidate-validation
COPY --from=gcc16-runtime-candidate-validation-execution \
  /validation/gcc16-runtime-candidate-execution \
  /gcc16-runtime-candidate-execution-passed
COPY --from=gcc16-runtime-candidate-rootfs-audit \
  /validation/gcc16-runtime-candidate-rootfs \
  /gcc16-runtime-candidate-rootfs-audit-passed
