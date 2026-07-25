# syntax=docker/dockerfile:1.10@sha256:865e5dd094beca432e8c0a1d5e1c465db5f998dca4e439981029b3b81fb39ed5

ARG RUST_IMAGE=rust:1.93.0-bookworm@sha256:d0a4aa3ca2e1088ac0c81690914a0d810f2eee188197034edf366ed010a2b382

# The local Bake graph must replace both empty sentinels with the clean generic
# GCC runtime and its independently produced validation markers. Omitted named
# contexts therefore fail closed without resolving a mutable registry fallback.
FROM scratch AS symphony-cpp-base
FROM scratch AS symphony-cpp-base-validation

FROM ${RUST_IMAGE} AS builder-base

ARG OPENSYMPHONY_REPOSITORY=https://github.com/kumanday/OpenSymphony.git
ARG OPENSYMPHONY_COMMIT=0cc21ddda5d1853a8fbd11add578b43b6ebd6fcb
ARG TARGETARCH

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
        clang \
        cmake \
        ninja-build \
        pkg-config \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git clone --filter=blob:none --no-checkout "${OPENSYMPHONY_REPOSITORY}" opensymphony \
    && git -C opensymphony checkout --detach "${OPENSYMPHONY_COMMIT}" \
    && test "$(git -C opensymphony rev-parse HEAD)" = "${OPENSYMPHONY_COMMIT}"

WORKDIR /src/opensymphony
RUN groupadd --gid 10001 orchestrator \
    && useradd --uid 10001 --gid 10001 --create-home --shell /bin/bash orchestrator \
    && chown -R orchestrator:orchestrator /src/opensymphony \
    && install -d --owner=orchestrator --group=orchestrator \
        /opt/opensymphony/bin \
        /opt/licenses
USER orchestrator
ENV CARGO_HOME=/home/orchestrator/.cargo

FROM builder-base AS upstream-tests
RUN --mount=type=cache,id=opensymphony-${OPENSYMPHONY_COMMIT}-${TARGETARCH}-cargo-registry,target=/home/orchestrator/.cargo/registry,uid=10001,gid=10001,sharing=locked \
    --mount=type=cache,id=opensymphony-${OPENSYMPHONY_COMMIT}-${TARGETARCH}-cargo-git,target=/home/orchestrator/.cargo/git,uid=10001,gid=10001,sharing=locked \
    --mount=type=cache,id=opensymphony-${OPENSYMPHONY_COMMIT}-${TARGETARCH}-cargo-target,target=/src/opensymphony/target,uid=10001,gid=10001,sharing=locked \
    cargo test --locked --workspace --no-run
RUN --mount=type=cache,id=opensymphony-${OPENSYMPHONY_COMMIT}-${TARGETARCH}-cargo-registry,target=/home/orchestrator/.cargo/registry,uid=10001,gid=10001,sharing=locked \
    --mount=type=cache,id=opensymphony-${OPENSYMPHONY_COMMIT}-${TARGETARCH}-cargo-git,target=/home/orchestrator/.cargo/git,uid=10001,gid=10001,sharing=locked \
    --mount=type=cache,id=opensymphony-${OPENSYMPHONY_COMMIT}-${TARGETARCH}-cargo-target,target=/src/opensymphony/target,uid=10001,gid=10001,sharing=locked \
    cargo test --locked --workspace -- --test-threads=1

FROM builder-base AS candidate-builder
RUN --mount=type=cache,id=opensymphony-${OPENSYMPHONY_COMMIT}-${TARGETARCH}-cargo-registry,target=/home/orchestrator/.cargo/registry,uid=10001,gid=10001,sharing=locked \
    --mount=type=cache,id=opensymphony-${OPENSYMPHONY_COMMIT}-${TARGETARCH}-cargo-git,target=/home/orchestrator/.cargo/git,uid=10001,gid=10001,sharing=locked \
    --mount=type=cache,id=opensymphony-${OPENSYMPHONY_COMMIT}-${TARGETARCH}-cargo-target,target=/src/opensymphony/target,uid=10001,gid=10001,sharing=locked \
    cargo build --locked --release \
    && install -D --mode=0755 target/release/opensymphony /opt/opensymphony/bin/opensymphony \
    && install -D --mode=0644 LICENSE /opt/licenses/OpenSymphony-LICENSE

FROM upstream-tests AS validated-builder
RUN --mount=type=cache,id=opensymphony-${OPENSYMPHONY_COMMIT}-${TARGETARCH}-cargo-registry,target=/home/orchestrator/.cargo/registry,uid=10001,gid=10001,sharing=locked \
    --mount=type=cache,id=opensymphony-${OPENSYMPHONY_COMMIT}-${TARGETARCH}-cargo-git,target=/home/orchestrator/.cargo/git,uid=10001,gid=10001,sharing=locked \
    --mount=type=cache,id=opensymphony-${OPENSYMPHONY_COMMIT}-${TARGETARCH}-cargo-target,target=/src/opensymphony/target,uid=10001,gid=10001,sharing=locked \
    cargo build --locked --release \
    && install -D --mode=0755 target/release/opensymphony /opt/opensymphony/bin/opensymphony \
    && install -D --mode=0644 LICENSE /opt/licenses/OpenSymphony-LICENSE

FROM symphony-cpp-base AS runtime-tools

ARG CODEX_CLI_VERSION=0.145.0
ARG NODE_VERSION=24.15.0

RUN node_source="/root/.nvm/versions/node/v${NODE_VERSION}" \
    && test -x "${node_source}/bin/node" \
    && test "$("${node_source}/bin/node" --version)" = "v${NODE_VERSION}" \
    && install -d /opt/node /opt/tools/bin \
    && cp --archive "${node_source}/." /opt/node/ \
    && install --mode=0755 "$(readlink -f /root/.local/bin/uv)" /opt/tools/bin/uv

ENV PATH="/opt/node/bin:/opt/tools/bin:${PATH}"
RUN test "$(node --version)" = "v${NODE_VERSION}" \
    && test "$(uv --version)" = "uv 0.7.22" \
    && npm install --global --prefix /opt/node --omit=dev "@openai/codex@${CODEX_CLI_VERSION}" \
    && test "$(codex --version)" = "codex-cli ${CODEX_CLI_VERSION}" \
    && npm cache clean --force

FROM symphony-cpp-base AS orchestrator-runtime

ARG CODEX_CLI_VERSION=0.145.0
ARG BUILD_INPUT_SHA256
ARG OPENSYMPHONY_COMMIT=0cc21ddda5d1853a8fbd11add578b43b6ebd6fcb
ARG SOURCE_REVISION

RUN --network=none \
    --mount=type=bind,from=symphony-cpp-base-validation,source=/gcc16-runtime-candidate-execution-passed,target=/tmp/gcc16-runtime-candidate-execution-passed,ro \
    --mount=type=bind,from=symphony-cpp-base-validation,source=/gcc16-runtime-candidate-rootfs-audit-passed,target=/tmp/gcc16-runtime-candidate-rootfs-audit-passed,ro \
    test -s /tmp/gcc16-runtime-candidate-execution-passed \
 && test -s /tmp/gcc16-runtime-candidate-rootfs-audit-passed

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
        ca-certificates \
        curl \
        git \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 10001 orchestrator \
    && useradd --uid 10001 --gid 10001 --create-home --shell /bin/bash orchestrator \
    && install -d --owner=orchestrator --group=orchestrator \
        /home/orchestrator/.codex \
        /home/orchestrator/.opensymphony \
        /orchestrator \
        /target \
        /workspaces \
    && test ! -e /opt/symphony-cpp-seed

COPY --from=builder-base /usr/local/cargo /opt/rust/cargo
COPY --from=builder-base /usr/local/rustup /opt/rust/rustup
COPY --from=runtime-tools /opt/node /opt/node
COPY --from=runtime-tools /opt/tools /opt/tools

ENV HOME=/home/orchestrator \
    CARGO_HOME=/opt/rust/cargo \
    RUSTUP_HOME=/opt/rust/rustup \
    PATH="/opt/node/bin:/opt/tools/bin:/opt/rust/cargo/bin:${PATH}"

RUN test "$(cargo --version | awk '{print $2}')" = "1.93.0" \
    && test "$(rustc --version | awk '{print $2}')" = "1.93.0" \
    && test "$(node --version)" = "v24.15.0" \
    && test "$(codex --version)" = "codex-cli ${CODEX_CLI_VERSION}" \
    && test "$(uv --version)" = "uv 0.7.22"

FROM orchestrator-runtime AS symphony-orchestrator-candidate

ARG OPENSYMPHONY_COMMIT=0cc21ddda5d1853a8fbd11add578b43b6ebd6fcb
ARG BUILD_INPUT_SHA256
ARG SOURCE_REVISION
COPY --from=candidate-builder /opt/opensymphony/bin/opensymphony /usr/local/bin/opensymphony
COPY --from=candidate-builder /opt/licenses/OpenSymphony-LICENSE /LICENSES/OpenSymphony-LICENSE
LABEL org.opencontainers.image.source="https://github.com/ray-manaloto/symphony-cpp" \
      org.opencontainers.image.description="Unvalidated local-only OpenSymphony acceptance candidate for symphony-cpp" \
      org.opencontainers.image.revision="${SOURCE_REVISION}" \
      org.opencontainers.image.version="v2.10.0" \
      dev.opensymphony.build-input.sha256="${BUILD_INPUT_SHA256}" \
      dev.opensymphony.source.commit="${OPENSYMPHONY_COMMIT}" \
      dev.opensymphony.upstream-tests="unverified-candidate" \
      dev.symphony.source.revision="${SOURCE_REVISION}"

USER orchestrator
WORKDIR /orchestrator
EXPOSE 2468
ENTRYPOINT ["opensymphony"]
CMD ["run", "--config", "/orchestrator/config.yaml", "--dry-run"]

FROM orchestrator-runtime AS symphony-orchestrator

ARG OPENSYMPHONY_COMMIT=0cc21ddda5d1853a8fbd11add578b43b6ebd6fcb
ARG BUILD_INPUT_SHA256
ARG SOURCE_REVISION
COPY --from=validated-builder /opt/opensymphony/bin/opensymphony /usr/local/bin/opensymphony
COPY --from=validated-builder /opt/licenses/OpenSymphony-LICENSE /LICENSES/OpenSymphony-LICENSE
LABEL org.opencontainers.image.source="https://github.com/ray-manaloto/symphony-cpp" \
      org.opencontainers.image.description="Validated local-only OpenSymphony development orchestrator for symphony-cpp" \
      org.opencontainers.image.revision="${SOURCE_REVISION}" \
      org.opencontainers.image.version="v2.10.0" \
      dev.opensymphony.build-input.sha256="${BUILD_INPUT_SHA256}" \
      dev.opensymphony.source.commit="${OPENSYMPHONY_COMMIT}" \
      dev.opensymphony.upstream-tests="passed" \
      dev.symphony.source.revision="${SOURCE_REVISION}"

USER orchestrator
WORKDIR /orchestrator
EXPOSE 2468
ENTRYPOINT ["opensymphony"]
CMD ["run", "--config", "/orchestrator/config.yaml", "--dry-run"]
