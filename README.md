# symphony-cpp

A standalone C++26 implementation of [OpenAI Symphony Draft v1](https://github.com/openai/symphony).

The current vertical slice provides typed domain state, deterministic scheduling and retry,
progress/context tracking, the anti-spin transition, workflow discovery and parsing, contained
fixture workspaces, a JSONL app-server transport boundary, redacted event history, daemon and CLI
entry points, and conformance tests. Live provider mutation remains disabled.

This project is dependency-first: use a maintained library, tool, generator, or permitted service
instead of building commodity capability from scratch. Read the
[dependency-first convention](docs/conventions/dependency-first.md) and
[decision ledger](docs/dependency-decisions.md) before adding infrastructure.

## Build

Day-to-day development runs inside the pinned GCC 16.1 devcontainer:

```sh
./scripts/devcontainer-build.sh gcc
```

Run the optimized GCC 16.1 build and test path:

```sh
./scripts/devcontainer-build.sh gcc-release
```

Run the GCC 16.1 AddressSanitizer and UndefinedBehaviorSanitizer gate in the same devcontainer:

```sh
./scripts/devcontainer-build.sh gcc-sanitizers
```

Run the differential reflection suite in the separate Bloomberg clang-p2996 devcontainer:

```sh
./scripts/devcontainer-build.sh clang-p2996
```

Run the exact LLVM 22.1.8 formatting gate and the initial reflection-disabled static-analysis
report in the dedicated analysis devcontainer:

```sh
./scripts/devcontainer-build.sh analysis
```

The official Dev Container CLI starts or reuses the container, applies its lifecycle setup, and
runs configure, build, and CTest inside it. The bind-mounted repository retains `build/` and
`.build/vcpkg`; named Docker volumes retain compiler-specific ccache data and shared vcpkg binary
archives. Do not configure or compile this project directly on the macOS host.

The compiler images are deliberately expensive source builds. Their source hashes, signatures, base
image digest, fork commit, and vcpkg registry baseline are pinned in source. GitHub builds and
validates three reusable toolchain base images; publication to GHCR is an explicit workflow input.
After publication, a separate reviewed change pins the immutable manifest digests used by thin local
development-container Dockerfiles. Local lifecycle setup bootstraps the repository's pinned vcpkg
graph in the mounted workspace. See
[docs/toolchain-and-devcontainer-workflow.md](docs/toolchain-and-devcontainer-workflow.md) and
[docs/upstream-lock.md](docs/upstream-lock.md).

Verify that every overlay port uses an immutable commit, SHA-512, synchronized manifest version,
and matching upstream lock row:

```sh
node scripts/update-overlay-dependencies.mjs --check
```

The weekly/manual overlay updater resolves only the repositories and branches allowlisted in
`config/overlay-dependencies.json`. It stops when a port appears in the pinned curated registry,
validates a changed graph through the full GCC 16.1 Source CI workflows, and may create one draft
pull request using an ordinary non-force push. Manual workflow runs default to validation-only.

Generate an inspectable C++ model/client surface from the pinned official OpenAI OpenAPI 3.1 schema
with `./scripts/generate-openai-api.sh`. Output is disposable under
`.build/generated/openai-api`; GitHub Actions also publishes it as a short-lived build artifact.
This describes the OpenAI REST API and does not replace Symphony's Codex app-server transport.

## Commands

```sh
symphonyctl validate ./WORKFLOW.md
symphonyctl conformance
symphonyd ./WORKFLOW.md --once
```

`symphonyd` defaults to `WORKFLOW.md` in the current directory. The older
`--workflow ./WORKFLOW.md` spelling remains a compatibility alias; supplying both forms is an
error.

When explicitly requested from the approved branch, CI publishes only directly verified toolchain
base images to this repository's GHCR namespace. Full development containers are built locally with
the pinned reference CLI; CI does not publish them. It also does not publish a service deployment,
install privileged VM components, mutate a live tracker, or use production credentials.

The pinned external OpenSymphony development orchestrator is documented under
[`ops/opensymphony`](ops/opensymphony/README.md). It runs behind a container boundary and remains
separate from the C++ service and its normative conformance path.
