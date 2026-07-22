# symphony-cpp

A standalone C++26 implementation of [OpenAI Symphony Draft v1](https://github.com/openai/symphony).

The current vertical slice provides typed domain state, deterministic scheduling and retry,
progress/context tracking, the anti-spin transition, workflow discovery and parsing, contained
fixture workspaces, a JSONL app-server transport boundary, redacted event history, daemon and CLI
entry points, and conformance tests. Live provider mutation remains disabled.

## Build

```sh
docker buildx build --platform linux/amd64 --target symphony-dev -f containers/Containerfile .
cmake --preset gcc-debug
cmake --build --preset gcc-debug
ctest --preset gcc-debug
```

The compiler images are deliberately expensive source builds. Their source hashes, signatures, base
image digest, and fork commit are pinned in [docs/upstream-lock.md](docs/upstream-lock.md).

Generate an inspectable C++ model/client surface from the pinned official OpenAI OpenAPI 3.1 schema
with `./scripts/generate-openai-api.sh`. Output is disposable under
`.build/generated/openai-api`; GitHub Actions also publishes it as a short-lived build artifact.
This describes the OpenAI REST API and does not replace Symphony's Codex app-server transport.

## Commands

```sh
symphonyctl validate ./WORKFLOW.md
symphonyctl conformance
symphonyd --workflow ./WORKFLOW.md --once
```

CI publishes only tested compiler images to this repository's GHCR namespace. It does not publish a
service deployment, install privileged VM components, mutate a live tracker, or use production
credentials.
