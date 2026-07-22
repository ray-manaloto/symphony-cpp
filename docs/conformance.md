# Symphony Draft v1 Section 18.1 matrix

Normative revision: `1f3219bb1ea5f69a1305dc594e79b0db57c113c5`.

| Requirement | Evidence | Status |
| --- | --- | --- |
| Runtime path and cwd default | `WorkflowLoader::resolve_path` tests | Implemented |
| YAML front matter and prompt split | workflow tests | Implemented |
| Typed defaults and `$` expansion | workflow tests | Implemented |
| Dynamic reload | `WorkflowWatcher` fingerprint tests | Partial: change detection implemented; daemon re-apply loop pending |
| Single-authority polling | deterministic scheduler tests | Implemented |
| Tracker state-list and ID refresh | `IssueTracker` plus `FakeTracker` | Implemented |
| Safe per-issue workspaces | workspace tests | Implemented |
| Lifecycle hooks and 60s default | workflow/workspace interfaces | Partial: fixture execution only |
| App-server framed subprocess | Codex transport tests | Partial: strict codec/fake runtime; subprocess lifecycle pending |
| Codex default command | config default test | Implemented |
| Strict issue/attempt prompt | workflow renderer tests | Implemented |
| Exponential continuation retry | scheduler tests | Implemented |
| 5m retry cap | config/scheduler tests | Implemented |
| Terminal/non-active reconciliation | scheduler tests | Implemented |
| Terminal cleanup | scheduler/workspace tests | Partial: active transition implemented; startup sweep pending |
| Structured contextual logs | observability tests | Implemented |
| Operator-visible observability | `symphonyctl status`, JSON events | Partial: CLI surface exists; live snapshot wiring pending |

This matrix is intentionally fail-closed. `Partial` is not conformance. Official fixture parity and
the pinned compiler matrix must be green before the implementation may claim full conformance.
