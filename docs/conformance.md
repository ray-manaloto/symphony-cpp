# Symphony Draft v1 Section 18.1 matrix

Normative revision: `1f3219bb1ea5f69a1305dc594e79b0db57c113c5`.

| Requirement | Evidence | Status |
| --- | --- | --- |
| Runtime path and cwd default | `WorkflowLoader::resolve_path` tests | Implemented |
| YAML front matter and prompt split | workflow tests | Implemented |
| Typed defaults and `$` expansion | workflow tests | Implemented |
| Dynamic reload | `WorkflowWatcher` tests plus daemon reconfigure loop | Implemented; invalid changes retain last good config |
| Single-authority polling | deterministic scheduler tests | Implemented |
| Tracker state-list and ID refresh | `IssueTracker` plus `FakeTracker` | Implemented |
| Tracker normalization, pagination, profiles, and portable errors | tracker contract fixtures | Implemented for the provider-neutral fixture boundary; live Glaze HTTP adapters remain gated and disabled |
| Candidate completeness, routability, and dispatch ordering | scheduler fixture tests | Implemented for normalized core fields, adapter `dispatchable`, priority, creation time, and identifier tie-breaks |
| Safe per-issue workspaces | workspace tests | Implemented |
| Lifecycle hooks and 60s default | workflow, scheduler, and workspace tests | Implemented in fixture and contained POSIX executors |
| App-server framed subprocess | Codex transport and subprocess tests | Implemented; full §17.5 signal/telemetry matrix remains open |
| Codex default command | config default test | Implemented |
| Codex usage and rate-limit telemetry | protocol, conversation, and scheduler tests | Implemented for cumulative token usage, latest-turn usage, and sparse rate-limit-window merging against Codex CLI 0.145.0 generated schema |
| Codex interactive-request policy | protocol and conversation fixtures | Implemented fail-closed handling for approval and user-input requests plus structured rejection-and-continue behavior for unadvertised dynamic tools; GCC 16.1 Source CI run `29970037383` passed |
| Codex startup policy payloads | protocol, runtime, workflow reload, and schema fixtures | Implemented pass-through model, reasoning effort, approval, and thread-sandbox strings plus validated raw-JSON turn sandbox policy against the Codex CLI 0.145.0 v2 shapes; no local enum or model catalog duplicates Codex |
| Codex turn and stall deadlines | protocol, scheduler, workflow, and Boost.Process-backed runtime tests | Implemented with bounded read polling, independent total-turn and last-event clocks, disabled-stall semantics, distinct outcomes/events, and explicit EOF handling |
| Codex context telemetry | protocol, conversation, and scheduler fixtures | Implemented for model context-window preservation, legacy/current compaction-event counting, and fresh-session rollover after observed compaction; proactive threshold evidence remains open |
| Bounded in-worker turn loop | app-server conversation and scheduler fixtures | Implemented with one live app-server process/thread, tracker refresh after each successful turn, continuation-only prompts, dynamic `agent.max_turns`, compaction cutoff, and normal continuation retry |
| Adaptive worker policy | scheduler, workflow, and Codex fixtures | Implemented for configured baseline, one-failure/no-progress escalation, repeated-identical-failure ceiling, and progress-evidence recovery between bounded sessions; OpenSymphony v2.10.0 remains operator-adjusted |
| Child-process lifecycle | Boost.Process v2 fixtures and production Codex adapter | Implemented for launch, working directory, separate stdio handles, explicit EOF, graceful-exit request, termination, wait, and reap; GCC 16.1 Source CI run `29969683664` passed |
| Strict issue/attempt prompt | workflow renderer tests | Implemented |
| Exponential continuation retry | scheduler tests | Implemented |
| 5m retry cap | config/scheduler tests | Implemented |
| Retry queue metadata and slot-exhaustion requeue | scheduler tests | Implemented with one-based attempts, monotonic due times, timer handles, retained claims, and the normative capacity error |
| Terminal/non-active reconciliation | scheduler tests | Implemented |
| Terminal cleanup | scheduler/workspace tests | Implemented for startup sweep and active transition |
| Structured contextual logs | observability tests | Implemented |
| Operator-visible observability | `symphonyctl status`, JSON events | Partial: CLI surface exists; live snapshot wiring pending |

This matrix is intentionally fail-closed. `Partial` is not conformance. Official fixture parity and
the pinned compiler matrix must be green before the implementation may claim full conformance.

## Section 17 deterministic-profile gaps

The following required evidence is not yet complete and prevents a conformance claim:

- bounded Codex stderr diagnostics, process-tree/group cancellation, and proactive compaction
  thresholds;
- logging-sink failure isolation and repeated telemetry aggregation;
- positional workflow CLI behavior and process lifecycle exit tests;
- compiler-matrix, sanitizer, restart, reconciliation, traversal, symlink, and differential
  reflection evidence required by the implementation plan.
