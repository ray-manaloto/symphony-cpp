# syntax=docker/dockerfile:1.10@sha256:865e5dd094beca432e8c0a1d5e1c465db5f998dca4e439981029b3b81fb39ed5

ARG RUST_IMAGE=rust:1.97.1-bookworm@sha256:389c1ae98c20fbcadca68a685482749267cec3c90893ae4671c5a37cc894c416

FROM ${RUST_IMAGE} AS opensymphony-source

WORKDIR /src/opensymphony
ADD --checksum=sha256:6376662ac21d930f0b4b488a7d13e5b8e7fbf94a02d67ab552d7e341ae257a1c \
  https://codeload.github.com/kumanday/OpenSymphony/tar.gz/refs/tags/v2.11.3 \
  /tmp/opensymphony-v2.11.3.tar.gz
ADD --checksum=sha256:62c7a1e35f56406896d7aa7ca52d0cc0d272ac022b5d2796e7d6905db8a3636a \
  https://raw.githubusercontent.com/rust-lang/rust/1.97.1/LICENSE-APACHE \
  /tmp/Rust-LICENSE-APACHE
ADD --checksum=sha256:b71bd43a069ca0641a9ecfe585ca7b3c53b5cc1608f8b68321168698e28b5ea1 \
  https://raw.githubusercontent.com/rust-lang/rust/1.97.1/LICENSE-MIT \
  /tmp/Rust-LICENSE-MIT
RUN tar --extract --gzip --file /tmp/opensymphony-v2.11.3.tar.gz \
      --strip-components=1 --directory /src/opensymphony \
    && printf '%s  %s\n' \
      6376662ac21d930f0b4b488a7d13e5b8e7fbf94a02d67ab552d7e341ae257a1c \
      /tmp/opensymphony-v2.11.3.tar.gz | sha256sum --check --strict \
    && printf '%s  %s\n' \
      99f92f0a22a89c42a33474bf7b34f4433ef877371f0da10ff532c47b20b74301 \
      /src/opensymphony/Cargo.lock | sha256sum --check --strict \
    && printf '%s  %s\n' \
      d22aeaebdf4cf94f10801bddcfb204b296581a94023ab92350b18b24c631199f \
      /src/opensymphony/LICENSE | sha256sum --check --strict \
    && printf '%s  %s\n' \
      62c7a1e35f56406896d7aa7ca52d0cc0d272ac022b5d2796e7d6905db8a3636a \
      /tmp/Rust-LICENSE-APACHE | sha256sum --check --strict \
    && printf '%s  %s\n' \
      b71bd43a069ca0641a9ecfe585ca7b3c53b5cc1608f8b68321168698e28b5ea1 \
      /tmp/Rust-LICENSE-MIT | sha256sum --check --strict

FROM opensymphony-source AS upstream-tests

RUN cargo fmt --check \
    && groupadd --gid 10001 opensymphony-build \
    && useradd --uid 10001 --gid 10001 --create-home --shell /bin/bash \
      opensymphony-build \
    && install -d --owner=10001 --group=10001 \
      /home/opensymphony-build/.cargo \
      /opt/opensymphony \
    && chown -R 10001:10001 /src/opensymphony
ENV CARGO_HOME=/home/opensymphony-build/.cargo
ENV HOME=/home/opensymphony-build
USER opensymphony-build
RUN --mount=type=cache,id=opensymphony-v2113-amd64-cargo-registry,target=/home/opensymphony-build/.cargo/registry,sharing=locked,uid=10001,gid=10001 \
    --mount=type=cache,id=opensymphony-v2113-amd64-cargo-git,target=/home/opensymphony-build/.cargo/git,sharing=locked,uid=10001,gid=10001 \
    --mount=type=cache,id=opensymphony-v2113-amd64-target,target=/src/opensymphony/target,sharing=locked,uid=10001,gid=10001 \
    cargo clippy --locked --workspace --all-targets -- -D warnings
RUN --mount=type=cache,id=opensymphony-v2113-amd64-cargo-registry,target=/home/opensymphony-build/.cargo/registry,sharing=locked,uid=10001,gid=10001 \
    --mount=type=cache,id=opensymphony-v2113-amd64-cargo-git,target=/home/opensymphony-build/.cargo/git,sharing=locked,uid=10001,gid=10001 \
    --mount=type=cache,id=opensymphony-v2113-amd64-target,target=/src/opensymphony/target,sharing=locked,uid=10001,gid=10001 \
    cargo test --locked --workspace -- --test-threads=1
USER root
RUN install -d /opt/opensymphony/evidence \
    && printf '%s\n' \
      'cargo fmt --check: passed' \
      'cargo clippy --locked --workspace --all-targets -- -D warnings: passed' \
      'cargo test --locked --workspace -- --test-threads=1: passed' \
      'patches: none' \
      'task-added xfails: none' \
      'task-added skips: none' \
      > /opt/opensymphony/evidence/upstream-tests-v1.txt
USER opensymphony-build

FROM upstream-tests AS opensymphony-builder

RUN --mount=type=cache,id=opensymphony-v2113-amd64-cargo-registry,target=/home/opensymphony-build/.cargo/registry,sharing=locked,uid=10001,gid=10001 \
    --mount=type=cache,id=opensymphony-v2113-amd64-cargo-git,target=/home/opensymphony-build/.cargo/git,sharing=locked,uid=10001,gid=10001 \
    --mount=type=cache,id=opensymphony-v2113-amd64-target,target=/src/opensymphony/target,sharing=locked,uid=10001,gid=10001 \
    cargo build --locked --release \
    && install --mode=0755 target/release/opensymphony /opt/opensymphony/opensymphony

FROM ${RUST_IMAGE} AS codex-input

ADD --checksum=sha256:5ba3b9405543953081f661d0854d266f76e2abbe51d41349355a36de7673776a \
  https://github.com/openai/codex/releases/download/rust-v0.146.0/codex-x86_64-unknown-linux-musl.tar.gz \
  /tmp/codex-x86_64-unknown-linux-musl.tar.gz
ADD --checksum=sha256:d17f227e4df5da1600391338865ce0f3055211760a36688f816941d58232d8dc \
  https://raw.githubusercontent.com/openai/codex/e363b08c9175ac1cbe5893615dd2cb9ddf95043b/LICENSE \
  /tmp/Codex-LICENSE
RUN install -d /tmp/codex /opt/codex/bin \
    && tar --extract --gzip --file /tmp/codex-x86_64-unknown-linux-musl.tar.gz \
      --directory /tmp/codex \
    && codex_binary="$(find /tmp/codex -type f \
      -name codex-x86_64-unknown-linux-musl -print -quit)" \
    && test -n "${codex_binary}" \
    && printf '%s  %s\n' \
      2e863156ed35ecc5253b1e2f907a9143077b9f7cb51942070c61996471ff6e04 \
      "${codex_binary}" | sha256sum --check --strict \
    && install --mode=0755 "${codex_binary}" /opt/codex/bin/codex \
    && test "$(/opt/codex/bin/codex --version)" = 'codex-cli 0.146.0'

FROM codex-input AS codex-schema

ENV CODEX_HOME=/tmp/codex-home
RUN install -d --mode=0700 /tmp/codex-home \
    && install -d /opt/codex/app-server-schema \
    && /opt/codex/bin/codex app-server generate-json-schema \
      --out /opt/codex/app-server-schema \
    && test -n "$(find /opt/codex/app-server-schema -type f -print -quit)" \
    && find /opt/codex/app-server-schema -type f -print0 | sort -z | \
      xargs -0 sha256sum > /opt/codex/codex-app-server-schema.sha256

FROM ${RUST_IMAGE} AS evaluation-image

ARG BUILD_INPUT_SHA256

RUN printf '%s' "${BUILD_INPUT_SHA256}" | grep -Eq '^[0-9a-f]{64}$' \
    && groupadd --gid 10001 orchestrator \
    && useradd --uid 10001 --gid 10001 --create-home --shell /bin/bash orchestrator \
    && install -d \
      /LICENSES \
      /opt/opensymphony/evidence/source \
      /opt/opensymphony/evidence/codex-app-server-schema
COPY --from=opensymphony-builder --chmod=0755 \
  /opt/opensymphony/opensymphony /usr/local/bin/opensymphony
COPY --from=codex-input --chmod=0755 /opt/codex/bin/codex /usr/local/bin/codex
COPY --from=opensymphony-source --chmod=0444 \
  /src/opensymphony/LICENSE /LICENSES/OpenSymphony-LICENSE
COPY --from=codex-input --chmod=0444 /tmp/Codex-LICENSE /LICENSES/Codex-LICENSE
COPY --from=opensymphony-source --chmod=0444 \
  /tmp/Rust-LICENSE-APACHE /LICENSES/Rust-LICENSE-APACHE
COPY --from=opensymphony-source --chmod=0444 \
  /tmp/Rust-LICENSE-MIT /LICENSES/Rust-LICENSE-MIT
COPY --from=upstream-tests --chmod=0444 \
  /opt/opensymphony/evidence/upstream-tests-v1.txt \
  /opt/opensymphony/evidence/upstream-tests-v1.txt
COPY --from=opensymphony-source --chmod=0444 \
  /tmp/opensymphony-v2.11.3.tar.gz \
  /opt/opensymphony/evidence/source/opensymphony-v2.11.3.tar.gz
COPY --from=opensymphony-source --chmod=0444 \
  /src/opensymphony/Cargo.lock \
  /opt/opensymphony/evidence/source/Cargo.lock
COPY --from=codex-schema --chmod=0444 \
  /opt/codex/app-server-schema/ \
  /opt/opensymphony/evidence/codex-app-server-schema/
COPY --from=codex-schema --chmod=0444 \
  /opt/codex/codex-app-server-schema.sha256 \
  /opt/opensymphony/evidence/codex-app-server-schema.sha256
COPY --chmod=0444 \
  ops/opensymphony/evaluation/v2.11.3/input-manifest-v1.json \
  /opt/opensymphony/evidence/input-manifest-v1.json
RUN test "$(rustc --version)" = 'rustc 1.97.1 (3dea8f2f2 2026-06-16)' \
    && test "$(cargo --version | awk '{print $1, $2}')" = 'cargo 1.97.1' \
    && test "$(opensymphony --version)" = 'opensymphony 2.11.3' \
    && test "$(codex --version)" = 'codex-cli 0.146.0' \
    && printf '%s  %s\n' \
      d22aeaebdf4cf94f10801bddcfb204b296581a94023ab92350b18b24c631199f \
      /LICENSES/OpenSymphony-LICENSE \
      d17f227e4df5da1600391338865ce0f3055211760a36688f816941d58232d8dc \
      /LICENSES/Codex-LICENSE \
      62c7a1e35f56406896d7aa7ca52d0cc0d272ac022b5d2796e7d6905db8a3636a \
      /LICENSES/Rust-LICENSE-APACHE \
      b71bd43a069ca0641a9ecfe585ca7b3c53b5cc1608f8b68321168698e28b5ea1 \
      /LICENSES/Rust-LICENSE-MIT | sha256sum --check --strict \
    && sha256sum \
      /usr/local/bin/opensymphony \
      /usr/local/bin/codex \
      > /opt/opensymphony/evidence/binaries.sha256 \
    && sha256sum \
      /opt/opensymphony/evidence/source/opensymphony-v2.11.3.tar.gz \
      /opt/opensymphony/evidence/source/Cargo.lock \
      /opt/opensymphony/evidence/input-manifest-v1.json \
      > /opt/opensymphony/evidence/source-inputs.sha256 \
    && cd / \
    && sha256sum --check /opt/opensymphony/evidence/codex-app-server-schema.sha256

LABEL dev.opensymphony.eval.program=opensymphony-v2.11.3-three-arm \
      dev.opensymphony.eval.controller=019fc0ca-dde9-7132-91a5-8530d7d76592 \
      dev.opensymphony.eval.ticket=47 \
      dev.opensymphony.eval.ownership=temporary \
      dev.opensymphony.eval.source.tag-object=ed265b58f1b17c0184775635444e1e2be383177f \
      dev.opensymphony.eval.source.commit=af6a65459385104fcef4e249980701bf8e7964d4 \
      dev.opensymphony.eval.source.tree=ddde2287e4bd975dc721b131f039cec6b32f437b \
      dev.opensymphony.eval.source.archive-sha256=6376662ac21d930f0b4b488a7d13e5b8e7fbf94a02d67ab552d7e341ae257a1c \
      dev.opensymphony.eval.codex.tag-object=be449751a978f02e5bbba886999662956c7f38f5 \
      dev.opensymphony.eval.codex.commit=e363b08c9175ac1cbe5893615dd2cb9ddf95043b \
      dev.opensymphony.eval.build-input-sha256=${BUILD_INPUT_SHA256} \
      dev.opensymphony.eval.upstream-tests=passed-stock-unchanged

ENV HOME=/home/orchestrator
USER orchestrator
WORKDIR /opt/opensymphony
CMD ["opensymphony", "--help"]
