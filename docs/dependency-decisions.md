# Dependency decision ledger

Record a row before implementing or materially expanding a capability. `Custom` is permitted only
with a link or quote identifying explicit owner authorization.

| Capability | Selected provider | Why this owns the mechanism | Status / re-evaluation trigger |
| --- | --- | --- | --- |
| JSON, reflected codecs, schema helpers | Glaze | One C++23/26 codec/reflection stack covers JSON and related formats; P2996 backend is differential-tested. | Selected; remove nlohmann/json after fixture parity. |
| Operator HTTP API | Glaze HTTP | Existing ASIO HTTP/REST implementation avoids a local server/router. | Prototype gate: cancellation, TLS, size limits, overload, shutdown. |
| Codex JSON-RPC payloads | Glaze JSON/JSON-RPC facilities plus newline framing adapter | Existing codec/protocol facilities own JSON-RPC semantics; local code owns only Codex-specific DTOs and JSONL process framing. | Validate exact app-server fixtures before deleting bootstrap codec. |
| Workflow YAML | Glaze YAML | Avoid a second parser if Symphony fixtures and unknown-key behavior pass. | Remove yaml-cpp after full workflow parity. |
| Unit tests | `openalgz/ut` | Existing C++23 runtime/compile-time test framework replaces the local registry/macros. | Active through the pinned vcpkg overlay; GCC 16.1 CI is the release gate. |
| Dependency management | vcpkg manifest mode | Pinned registry, version graph, binary caching, and overlay mechanism. | Active; FetchContent/CPM/vendoring prohibited. |
| Formatting | `{fmt}` | Maintained type-safe formatting; compatible with future standard formatting. | Selected; use only after redaction. |
| Async execution | NVIDIA `stdexec` behind a project execution seam | Reference implementation of C++26 `std::execution` for hosted systems. | Compatibility spike required; replace with standard library when complete. |
| SQLite access | `klemens-morgenstern/sqlite` | Typed queries, prepared statements, non-throwing APIs, RAII transactions/savepoints, hooks and backup. | Selected pinned overlay; synchronous calls stay on serialized DB executor. |
| Durable schema / repository | SQLite migrations plus repository-owned SQL | Durable domain schema is product-specific; wrapper owns mechanism, repository owns Symphony mapping. | `sqlgen` deletion-test spike before authoring repetitive mappers. |
| Child process lifecycle | Boost.Process v2 | Existing async process groups, pipes and exit handling should replace POSIX bootstrap code. | Fixture gate before expanding subprocess implementation. |
| CLI parsing | Glaze CLI facilities first | Reuse selected stack before adding another CLI library. | Evaluate against `symphonyctl` command/help/completion contract. |
| Exact decimal arithmetic | Boost.Decimal | Existing IEEE decimal types. | Add only when an upstream contract requires exact decimals. |
| Symphony domain transitions and scheduler policy | OpenAI Symphony Draft v1 implemented locally | Normative product behavior has no reusable conforming C++ implementation in the recorded search; the owner explicitly approved the standalone C++ plan. | Keep pure and fixture-driven; commodity mechanisms still require dependencies. |

Comparative evidence and access dates live in [`docs/research/sources.md`](research/sources.md) and
[`docs/research/cpp-library-evaluation.md`](research/cpp-library-evaluation.md).
