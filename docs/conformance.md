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
| Safe per-issue workspaces | workspace tests | Implemented |
| Lifecycle hooks and 60s default | workflow, scheduler, and workspace tests | Implemented in fixture and contained POSIX executors |
| App-server framed subprocess | Codex transport and subprocess tests | Implemented; full §17.5 signal/telemetry matrix remains open |
| Codex default command | config default test | Implemented |
| Strict issue/attempt prompt | workflow renderer tests | Implemented |
| Exponential continuation retry | scheduler tests | Implemented |
| 5m retry cap | config/scheduler tests | Implemented |
| Terminal/non-active reconciliation | scheduler tests | Implemented |
| Terminal cleanup | scheduler/workspace tests | Implemented for startup sweep and active transition |
| Structured contextual logs | observability tests | Implemented |
| Operator-visible observability | `symphonyctl status`, JSON events | Partial: CLI surface exists; live snapshot wiring pending |

This matrix is intentionally fail-closed. `Partial` is not conformance. Official fixture parity and
the pinned compiler matrix must be green before the implementation may claim full conformance.

## Section 17 deterministic-profile gaps

The following required evidence is not yet complete and prevents a conformance claim:

- tracker normalization, pagination, malformed-record behavior, compact adapter profiles, and
  portable error mapping;
- priority/creation-time dispatch ordering, explicit `dispatchable`, retry-entry metadata, slot
  exhaustion, and stalled-session termination;
- Codex turn timeout, stderr separation, approval/user-input policy, unsupported tool calls, usage,
  and rate-limit telemetry;
- logging-sink failure isolation and repeated telemetry aggregation;
- positional workflow CLI behavior and process lifecycle exit tests;
- compiler-matrix, sanitizer, restart, reconciliation, traversal, symlink, and differential
  reflection evidence required by the implementation plan.
