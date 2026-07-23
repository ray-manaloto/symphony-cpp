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

The owner selected Glaze, `ut`, and vcpkg on 2026-07-22. Glaze now owns JSON codecs and schema
generation, and `ut` owns the test framework. The remaining `yaml-cpp` workflow loader is a
bootstrap mechanism to remove only through a bounded, always-green migration.

| Capability | Preferred candidate | Alternatives under discussion | Required property |
| --- | --- | --- | --- |
| Async execution | pinned NVIDIA stdexec behind a local sender/receiver boundary | Glaze's ASIO substrate behind an adapter | one scheduler authority, cancellation, fake time |
| HTTP client/server | bounded Glaze HTTP prototype | another ASIO adapter if the prototype gate fails | cancellation, TLS, bounded bodies, graceful shutdown |
| JSON | Glaze behind `symphony_meta` and the Codex protocol adapter | none concurrently | strict JSON-RPC, explicit DTO names, limits and redaction |
| YAML | Glaze fixture gate, then remove `yaml-cpp` if conformant | retain isolated `yaml-cpp` loader | Symphony frontmatter, unknown-key and expansion semantics |
| Child processes | Boost.Process v2 behind the Codex protocol channel | none concurrently | separate bounded stderr, process-tree cancellation, timeouts, deterministic reap |
| Persistence | `klemens-morgenstern/sqlite` behind a serialized executor and repository interface | bounded `sqlgen` deletion-test spike | restart-safe atomic retries, events and migrations |
| Tests | `openalgz/ut` plus libFuzzer/property fixtures | none concurrently | deterministic state-machine properties and compile-time tests |
| CLI | CLI11 2.6.2 behind executable option structs | none concurrently | positional workflow path, strict options, standard help and exit codes |
| Logging | spdlog 1.17.0 behind `EventStore` | none concurrently | synchronous JSON sinks, sink-failure isolation, structured redaction, and bounded status history |
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
The selected SQLite wrapper is synchronous, so it never runs on the scheduler's I/O thread. A
repository-owned executor serializes access and supplies cancellation at the queued-operation seam;
domain types and durable schema do not depend on Boost.Describe/PFR metadata.

The Codex protocol channel uses Boost.Process v2 and Boost.Asio pipes for launch, working directory,
stdin/stdout/stderr transport, EOF, exit requests, termination, wait, and reap. JSONL framing,
protocol sequencing, deadline policy, and the diagnostic retention limit remain product-specific.
Stderr is drained concurrently so it cannot block the child; only its final 4 KiB plus total-byte
and truncation metadata survive the process boundary. The scheduler emits that tail through the
structured event-store redaction boundary. Process-tree cancellation remains an explicit
conformance gap rather than a reason to reintroduce direct POSIX lifecycle ownership.

The current unattended Codex interaction posture is fail-closed: approval requests and user-input
requests end the run immediately, so neither can wait indefinitely for an absent operator. Because
the runtime advertises no dynamic tools, every `item/tool/call` request receives a structured
failure result and the turn continues. Workflow-configured approval and thread-sandbox values pass
through as strings; turn sandbox policy passes through as a Glaze-validated raw JSON object so this
repository does not duplicate Codex's evolving enums.

The worker model and reasoning effort are workflow pass-through strings owned by the targeted Codex
schema. The contained 0.145.0 catalog verified `gpt-5.6-sol` with `high` effort before both were
pinned. The model is present on thread and turn startup; effort uses Codex's turn-level `effort`
field. Between fresh worker sessions, the scheduler may select configured escalation values after
one abnormal failure or an unchanged progress fingerprint, and a configured ceiling after the same
failure repeats. A changed progress fingerprint clears that evidence. Neither the standalone
service nor external OpenSymphony maintains a copied model catalog.

Codex remains responsible for the compaction mechanism. Symphony preserves the reported model
context-window size, recognizes both the legacy `thread/compacted` notification and the current
`contextCompaction` completed item, counts them, and emits an operator event. Once compaction is
observed, the current worker session exits normally at the next completed turn without requesting a
continuation; a retry starts from the durable workspace in a fresh process and thread. When Codex
reports both cumulative tokens and a positive context-window size, the configured
`codex.context_rollover_percent` stops continuation at or above that utilization between completed
turns. Missing telemetry is never estimated. This reduces compaction pressure but cannot interrupt
an internal compaction that Codex performs during a single turn.

One worker invocation owns one app-server process and coding-agent thread. After each successful
turn, a scheduler callback refreshes the issue and routability state. Eligible work receives a
continuation-only prompt on the same thread until the current workflow snapshot's positive
`agent.max_turns` cap is reached. The repository workflow uses four turns per worker session to
bound copied context and failure scope. The worker then exits normally and retains the normative
short continuation retry so a still-active issue can begin a new bounded session.
