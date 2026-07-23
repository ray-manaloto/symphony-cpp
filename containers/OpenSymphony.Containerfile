ARG RUST_IMAGE=rust:1.93.0-bookworm@sha256:d0a4aa3ca2e1088ac0c81690914a0d810f2eee188197034edf366ed010a2b382

FROM ${RUST_IMAGE} AS builder

ARG OPENSYMPHONY_REPOSITORY=https://github.com/kumanday/OpenSymphony.git
ARG OPENSYMPHONY_COMMIT=0cc21ddda5d1853a8fbd11add578b43b6ebd6fcb

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
RUN cargo test --locked --workspace \
    && cargo build --locked --release \
    && install -D --mode=0755 target/release/opensymphony /opt/opensymphony/bin/opensymphony \
    && install -D --mode=0644 LICENSE /opt/licenses/OpenSymphony-LICENSE

FROM ${RUST_IMAGE} AS symphony-orchestrator

ARG CODEX_CLI_VERSION=0.145.0
ARG OPENSYMPHONY_COMMIT=0cc21ddda5d1853a8fbd11add578b43b6ebd6fcb

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
        ca-certificates \
        curl \
        git \
        nodejs \
        npm \
        openssh-client \
    && npm install --global --omit=dev "@openai/codex@${CODEX_CLI_VERSION}" \
    && npm cache clean --force \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 10001 orchestrator \
    && useradd --uid 10001 --gid 10001 --create-home --shell /bin/bash orchestrator \
    && install -d --owner=orchestrator --group=orchestrator \
        /home/orchestrator/.codex \
        /orchestrator \
        /target \
        /workspaces

COPY --from=builder /opt/opensymphony/bin/opensymphony /usr/local/bin/opensymphony
COPY --from=builder /opt/licenses/OpenSymphony-LICENSE /LICENSES/OpenSymphony-LICENSE

LABEL org.opencontainers.image.source="https://github.com/ray-manaloto/symphony-cpp" \
      org.opencontainers.image.description="Contained OpenSymphony development orchestrator for symphony-cpp" \
      dev.opensymphony.source.commit="${OPENSYMPHONY_COMMIT}"

USER orchestrator
WORKDIR /orchestrator
EXPOSE 2468
ENTRYPOINT ["opensymphony"]
CMD ["run", "--config", "/orchestrator/config.yaml", "--dry-run"]
