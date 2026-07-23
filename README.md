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

Run the GCC 16.1 AddressSanitizer and UndefinedBehaviorSanitizer gate in the same devcontainer:

```sh
./scripts/devcontainer-build.sh gcc-sanitizers
```

Run the differential reflection suite in the separate Bloomberg clang-p2996 devcontainer:

```sh
./scripts/devcontainer-build.sh clang-p2996
```

The official Dev Container CLI starts or reuses the container, applies its lifecycle setup, and
runs configure, build, and CTest inside it. The bind-mounted repository retains `build/` and
`.build/vcpkg`; named Docker volumes retain compiler-specific ccache data and shared vcpkg binary
archives. Do not configure or compile this project directly on the macOS host.

The compiler images are deliberately expensive source builds. Their source hashes, signatures, base
image digest, fork commit, and vcpkg registry baseline are pinned in source. GitHub builds and
validates both devcontainer images; publication to GHCR is an explicit workflow input. Each image
preseeds the vcpkg binary archive, while lifecycle setup bootstraps the same repository-local pinned
vcpkg checkout in the mounted workspace. See [docs/upstream-lock.md](docs/upstream-lock.md).

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

When explicitly requested, CI publishes only tested devcontainer images to this repository's GHCR
namespace. It does not publish a service deployment, install privileged VM components, mutate a live
tracker, or use production credentials.

The pinned external OpenSymphony development orchestrator is documented under
[`ops/opensymphony`](ops/opensymphony/README.md). It runs behind a container boundary and remains
separate from the C++ service and its normative conformance path.
