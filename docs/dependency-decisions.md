# Dependency decision ledger

Record a row before implementing or materially expanding a capability. `Custom` is permitted only
with a link or quote identifying explicit owner authorization.

| Capability | Selected provider | Why this owns the mechanism | Status / re-evaluation trigger |
| --- | --- | --- | --- |
| JSON, reflected codecs, schema helpers | Glaze | One C++23/26 codec/reflection stack covers JSON and related formats; P2996 backend is differential-tested. | Active; nlohmann/json removed after fixture parity. |
| Operator HTTP API | Glaze HTTP | Existing ASIO HTTP/REST implementation avoids a local server/router. | Prototype gate: cancellation, TLS, size limits, overload, shutdown. |
| Codex JSON-RPC payloads | Glaze JSON facilities plus newline framing adapter | Existing codec facilities own JSON parsing and serialization; local code owns only Codex-specific DTOs, state sequencing, and JSONL process framing. | Active; additive-field and malformed-ID fixtures guard compatibility. |
| Workflow YAML | Glaze YAML | Avoid a second parser if Symphony fixtures and unknown-key behavior pass. | Remove yaml-cpp after full workflow parity. |
| Unit tests | `openalgz/ut` | Existing C++23 runtime/compile-time test framework replaces the local registry/macros. | Active through the pinned vcpkg overlay; GCC 16.1 CI is the release gate. |
| Dependency management | vcpkg manifest mode | Pinned registry, version graph, binary caching, and overlay mechanism. | Active; FetchContent/CPM/vendoring prohibited. |
| Formatting | `{fmt}` | Maintained type-safe formatting; compatible with future standard formatting. | Selected; use only after redaction. |
| Async execution | NVIDIA `stdexec` behind a project execution seam | Reference implementation of C++26 `std::execution` for hosted systems. | Compatibility spike required; replace with standard library when complete. |
| SQLite access | `klemens-morgenstern/sqlite` | Typed queries, prepared statements, non-throwing APIs, RAII transactions/savepoints, hooks and backup. | Selected pinned overlay; synchronous calls stay on serialized DB executor. |
| Durable schema / repository | SQLite migrations plus repository-owned SQL | Durable domain schema is product-specific; wrapper owns mechanism, repository owns Symphony mapping. | `sqlgen` deletion-test spike before authoring repetitive mappers. |
| Child process lifecycle | Boost.Process v2 1.91.0 | Its Asio-native process, stdio, EOF, working-directory, wait, and cancellation facilities replace repository-owned fork/exec/pipe/wait mechanics. The pinned GCC 16.1 gate passed separate stdout/stderr, explicit EOF, start-directory, termination, and reap fixtures. | Adopted; migrate the Codex runtime through a thin adapter before expanding subprocess behavior. Keep Boost filesystem/path types behind that boundary and replace direct POSIX lifecycle calls. |
| CLI parsing | Glaze CLI facilities first | Reuse selected stack before adding another CLI library. | Evaluate against `symphonyctl` command/help/completion contract. |
| Exact decimal arithmetic | Boost.Decimal | Existing IEEE decimal types. | Add only when an upstream contract requires exact decimals. |
| Symphony domain transitions and scheduler policy | OpenAI Symphony Draft v1 implemented locally | Normative product behavior has no reusable conforming C++ implementation in the recorded search; the owner explicitly approved the standalone C++ plan. | Keep pure and fixture-driven; commodity mechanisms still require dependencies. |
| Tracker adapter contract and normalization | C++26 `std::expected` plus Glaze DTO facilities behind the provider-neutral tracker seam | The Draft v1 issue model, adapter profiles, pagination safety, and error taxonomy are Symphony integration policy; standard vocabulary types carry failures without a custom result framework, while the selected codec will own future provider payload decoding. | Fixture-only contract active. Live HTTP remains disabled until the recorded Glaze HTTP client gate passes; do not add a second JSON or transport stack. |
| Development-work orchestrator | OpenSymphony `v2.10.0` as an external tool | It supplies Linear-driven scheduling, isolated issue workspaces, retries, recovery, Codex harnessing, and operator surfaces while leaving the standalone C++ product implementation independent. | Owner-approved bounded adoption. Run only in a containment boundary with the Codex harness; never link or vendor Rust into `symphony-cpp`. The dedicated Linear project is selected; worker activation remains gated on one-command secret injection, contained Codex login, healthy dry run, and one explicitly activated fixture-only canary. |

Comparative evidence and access dates live in [`docs/research/sources.md`](research/sources.md) and
[`docs/research/cpp-library-evaluation.md`](research/cpp-library-evaluation.md).
