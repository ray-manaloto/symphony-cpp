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
| Codex turn and stall deadlines | protocol, scheduler, and workflow tests | Implemented with bounded read polling, independent total-turn and last-event clocks, disabled-stall semantics, and distinct outcomes/events; deterministic child-lifecycle coverage remains with the Boost.Process v2 migration |
| Child-process dependency gate | Boost.Process v2 fixtures | GCC 16.1-verified for separate stdout/stderr, EOF, start directory, terminal cancellation, and reap; Codex runtime migration pending |
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

- Codex stderr separation, approval/user-input policy, and unsupported tool calls;
- logging-sink failure isolation and repeated telemetry aggregation;
- positional workflow CLI behavior and process lifecycle exit tests;
- compiler-matrix, sanitizer, restart, reconciliation, traversal, symlink, and differential
  reflection evidence required by the implementation plan.
