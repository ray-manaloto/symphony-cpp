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

## Library decisions

The owner selected Glaze, `ut`, and vcpkg on 2026-07-22. The current `yaml-cpp`,
`nlohmann/json`, pinned FetchContent declarations, and minimal test harness are bootstrap mechanisms
to remove in bounded, always-green migrations. They must not spread into new boundaries.

| Capability | Preferred candidate | Alternatives under discussion | Required property |
| --- | --- | --- | --- |
| Async execution | local sender/receiver boundary; evaluate NVIDIA `stdexec` | Glaze's ASIO substrate behind an adapter | one scheduler authority, cancellation, fake time |
| HTTP client/server | bounded Glaze HTTP prototype | another ASIO adapter if the prototype gate fails | cancellation, TLS, bounded bodies, graceful shutdown |
| JSON | Glaze behind `symphony_codec` | none concurrently | strict JSON-RPC, explicit DTO names, limits and redaction |
| YAML | Glaze fixture gate, then remove `yaml-cpp` if conformant | retain isolated `yaml-cpp` loader | Symphony frontmatter, unknown-key and expansion semantics |
| Child processes | Boost.Process v2 | contained POSIX implementation | separate stderr, process groups, timeouts |
| Persistence | proposed SQLite C API + thin RAII repository | bounded `sqlgen` deletion-test spike | restart-safe atomic retries, events and migrations |
| Tests | `openalgz/ut` plus libFuzzer/property fixtures | none concurrently | deterministic state-machine properties and compile-time tests |
| CLI/logging | CLI11 and spdlog | owner-selected alternatives | typed errors and structured redaction |
| Formatting | `{fmt}` | standard formatting when supported equivalently | type safety and redact-before-format discipline |
| Dependencies | vcpkg manifest mode at a Git baseline | minimal pinned overlay ports | immutable, reproducible, auditable inputs |

Whichever libraries are selected, domain types depend only on the standard library and the thin
`symphony_meta` reflection adapter. Tracker, workspace, runtime, clock, event-store, and status
boundaries remain abstract. Generated OpenAI OpenAPI C++ is a disposable REST reference artifact;
the Codex app-server JSON-RPC protocol remains the Symphony agent transport.

Glaze REPE is not the Codex transport: it is a distinct, currently unstable protocol whose registry
leaves synchronization to the caller. The Glaze HTTP adapter is accepted only after fixture tests
cover cancellation, malformed input, body/header limits, TLS verification, overload and graceful
shutdown. Intel's bare-metal libraries remain references, not hosted-Linux runtime dependencies.
