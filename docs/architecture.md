# Architecture

Dependencies point inward: executables depend on services, services depend on abstract boundaries,
and the domain has no I/O dependency.

```text
symphonyd / symphonyctl
  -> scheduler + workflow + observability
  -> tracker | workspace | codex runtime interfaces
  -> domain + meta
```

The single scheduler object owns mutable run and retry state. Adapters return values and events; they
do not mutate scheduler state. All clocks are injected. Workspace paths are derived beneath one
canonical root and revalidated before hooks or cleanup.

Reflection is isolated in `symphony_meta`. GCC 16.1 supplies the release semantics. The
clang-p2996 job compiles the same reflected fixtures and records differences; it never creates a
release artifact. Conventional headers avoid the fork's documented serialization limitations.

## Library decision boundary

The current `yaml-cpp`, `nlohmann/json`, POSIX subprocess, in-memory event store, and minimal test
harness are bootstrap mechanisms, not accepted architecture. Do not expand them across boundaries
until the following choices are agreed with the project owner:

| Capability | Preferred candidate | Alternatives under discussion | Required property |
| --- | --- | --- | --- |
| Async execution | Boost.Asio coroutines | sender/receiver or a smaller event loop | one scheduler authority, cancellation, fake time |
| HTTP client/server | Boost.Beast | libcurl plus a small server; another cohesive stack | async cancellation, TLS, bounded bodies |
| JSON | nlohmann/json behind a codec | Boost.JSON, Glaze, simdjson | strict JSON-RPC plus reflection adapters |
| YAML | yaml-cpp behind the workflow loader | another YAML 1.2 implementation | preserve provider-owned configuration |
| Child processes | Boost.Process v2 | contained POSIX implementation | separate stderr, process groups, timeouts |
| Persistence | SQLite | append-only filesystem store | restart-safe retries and events |
| Tests | Catch2 plus RapidCheck | GoogleTest plus a property framework | deterministic state-machine properties |
| CLI/logging | CLI11 and spdlog | owner-selected alternatives | typed errors and structured redaction |
| Dependencies | pinned FetchContent | Conan or vcpkg lockfiles | immutable, reproducible, auditable inputs |

Whichever libraries are selected, domain types depend only on the standard library and the thin
`symphony_meta` reflection adapter. Tracker, workspace, runtime, clock, event-store, and status
boundaries remain abstract. Generated OpenAI OpenAPI C++ is a disposable REST reference artifact;
the Codex app-server JSON-RPC protocol remains the Symphony agent transport.
