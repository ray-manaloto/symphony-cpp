# Symphony Draft v1 Section 18.1 matrix

Normative revision: `1f3219bb1ea5f69a1305dc594e79b0db57c113c5`.

| Requirement | Evidence | Status |
| --- | --- | --- |
| Runtime path and cwd default | `WorkflowLoader::resolve_path` tests | Implemented |
| YAML front matter and prompt split | workflow tests | Implemented |
| Typed defaults and `$` expansion | workflow tests | Implemented |
| Dynamic reload | `WorkflowWatcher` tests plus daemon reconfigure loop | Implemented; invalid changes retain last good config |
| Positional workflow CLI and process exits | CLI11 parser fixtures plus Boost.Process-backed executable tests | Implemented for cwd default, one positional path, `--workflow` compatibility, strict conflicts/extras, help success, parse failure, and startup-validation failure |
| Single-authority polling | deterministic scheduler tests | Implemented |
| Bounded concurrent workers | scheduler and execution-provider fixtures | Gap: scheduler state is single-authority, but `AgentRuntime::run` still blocks the poll authority; pinned stdexec compatibility gate precedes worker migration |
| Tracker state-list and ID refresh | `IssueTracker` plus `FakeTracker` | Implemented |
| Tracker normalization, pagination, profiles, and portable errors | tracker contract fixtures | Implemented for the provider-neutral fixture boundary; live Glaze HTTP adapters remain gated and disabled |
| Candidate completeness, routability, and dispatch ordering | scheduler fixture tests | Implemented for normalized core fields, adapter `dispatchable`, priority, creation time, and identifier tie-breaks |
| Safe per-issue workspaces | workspace traversal, symlink-swap, lifecycle, and hook fixtures | Implemented with canonical direct-child revalidation before hooks/removal and outside-sentinel preservation; exact GCC 16.1 Source CI run `29981194421` passed |
| Lifecycle hooks and 60s default | workflow, scheduler, and workspace tests | Implemented in fixture and contained POSIX executors |
| App-server framed subprocess | Codex transport and subprocess tests | Implemented; full §17.5 signal/telemetry matrix remains open |
| Codex default command | config default test | Implemented |
| Codex usage and rate-limit telemetry | protocol, conversation, and scheduler tests | Implemented for replacement of repeated cumulative updates within a conversation, saturating aggregation across completed runs, latest-turn usage, and sparse rate-limit-window merging against Codex CLI 0.145.0 generated schema |
| Codex interactive-request policy | protocol and conversation fixtures | Implemented fail-closed handling for approval and user-input requests plus structured rejection-and-continue behavior for unadvertised dynamic tools; GCC 16.1 Source CI run `29970037383` passed |
| Codex startup policy payloads | protocol, runtime, workflow reload, and schema fixtures | Implemented pass-through model, reasoning effort, approval, and thread-sandbox strings plus validated raw-JSON turn sandbox policy against the Codex CLI 0.145.0 v2 shapes; no local enum or model catalog duplicates Codex |
| Codex turn and stall deadlines | protocol, scheduler, workflow, and Boost.Process-backed runtime tests | Implemented with bounded read polling, independent total-turn and last-event clocks, disabled-stall semantics, distinct outcomes/events, and explicit EOF handling |
| Codex context telemetry | protocol, conversation, workflow, and scheduler fixtures | Implemented for model context-window preservation, legacy/current compaction-event counting, configured between-turn utilization rollover, strict threshold validation, operator events, and fresh-session rollover after observed compaction |
| Bounded in-worker turn loop | app-server conversation and scheduler fixtures | Implemented with one live app-server process/thread, tracker refresh after each successful turn, continuation-only prompts, dynamic `agent.max_turns`, compaction cutoff, and normal continuation retry |
| Adaptive worker policy | scheduler, workflow, and Codex fixtures | Implemented for configured baseline, one-failure/no-progress escalation, repeated-identical-failure ceiling, and progress-evidence recovery between bounded sessions; OpenSymphony v2.10.0 remains operator-adjusted |
| Concurrent worker execution | stdexec provider, scheduler overlap, completion-drain, and cancellation fixtures | Implemented with the pinned NVIDIA stdexec static thread pool, keyed cooperative cancellation, scheduler-thread-only state mutation, and deferred terminal cleanup; exact GCC 16.1 Source CI run `29976334674` passed |
| Child-process lifecycle | Boost.Process v2 fixtures and production Codex adapter | Implemented for the Draft v1 launch and stop contract: working directory, tracker-secret-free child environment, separate stdio handles, explicit EOF, graceful-exit request, termination, wait, reap, and concurrent bounded stderr-tail capture. Process-tree/group cancellation remains an owner-gated hardening extension. |
| Strict issue/attempt prompt | workflow renderer tests | Implemented |
| Exponential continuation retry | scheduler tests | Implemented |
| 5m retry cap | config/scheduler tests | Implemented |
| Retry queue metadata and slot-exhaustion requeue | scheduler tests | Implemented with one-based attempts, monotonic due times, timer handles, retained claims, and the normative capacity error |
| Terminal/non-active reconciliation | scheduler tests | Implemented |
| Terminal cleanup | scheduler/workspace tests | Implemented for startup sweep and active transition |
| Structured contextual logs | observability tests plus spdlog adapter | Implemented for redact-before-dispatch JSON, bounded status history, synchronous stderr delivery, and isolated/countable sink failures |
| Operator-visible observability | structured JSON events plus `symphonyctl status` | Implemented for the required structured-log surface. Live snapshot wiring remains an OPTIONAL extension under Draft v1 §§13.3–13.4. |

This matrix is intentionally fail-closed. `Partial` is not conformance. Official fixture parity and
the pinned compiler matrix must be green before the implementation may claim full conformance.

## Remaining validation and hardening gaps

The pinned Draft v1 core profile does not require a status snapshot or process-group cancellation:
§§13.3–13.4 make snapshots and human-readable status optional, while §§10.1, 17.5, and 18.1
require the app-server launch/stop behavior without prescribing descendant-process groups.

The following implementation-plan evidence is still required before this repository claims the
planned validation profile:

- a green exact-SHA compiler matrix covering GCC 16.1, sanitizers, and clang-p2996 differential
  reflection;
- explicit restart and reconciliation evidence from the covered deterministic fixtures.

Process-tree/group cancellation remains a separately tracked hardening extension. Boost.Process
1.91 v2 exposes no maintained process-group abstraction, so the repository will not add an
unreviewed POSIX-only lifecycle layer or mix in the deprecated v1 group API.
