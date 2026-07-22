# Elixir reference versus Rust OpenSymphony runtime comparison

**Accessed:** 2026-07-22
**Decision scope:** whether a fixture-only third-party runtime should run alongside `symphony-cpp` while the C++ implementation is built. This is comparative research; [`openai/symphony` `SPEC.md`](https://github.com/openai/symphony/blob/main/SPEC.md) remains the normative authority.

## Recommendation

Run **both, sequentially and fixture-only**, with different jobs:

1. Use the upstream **Elixir reference first** as the primary behavioral oracle for Symphony Draft v1 and the Codex app-server protocol.
2. Use **Rust OpenSymphony second** as a comparative implementation and a source of operational test scenarios, not as a conformance authority.

Do not point either runtime at a real tracker, production repository, personal credentials, or an agent permitted to mutate the target repository. Start with a fake tracker, disposable workspace root, fake Codex app-server, and recorded event/HTTP fixtures. Promote only tests whose expected behavior is independently traceable to `SPEC.md`.

This deliberately does **not** choose a single "most mature" project in every dimension. OpenSymphony is materially broader as operator software, but the Elixir program is the official implementation and directly exercises the required Codex app-server integration. For `symphony-cpp`, those are different kinds of evidence.

## Evidence snapshot

| Dimension | OpenAI Symphony Elixir | Rust OpenSymphony |
| --- | --- | --- |
| Upstream relationship | Official repository, whose root `SPEC.md` defines Draft v1; its README calls the Elixir code the experimental reference. | Independent MIT implementation that declares alignment with the upstream spec. |
| Snapshot examined | `1f3219bb1ea5f69a1305dc594e79b0db57c113c5` (current `main`). | `0cc21ddda5d1853a8fbd11add578b43b6ebd6fcb`, tagged `v2.10.0`. |
| Current activity | Repository API reported a push on 2026-07-22; CI runs `make all` on push/PR. | Repository API reported a push on 2026-07-22; CI runs Rust fmt, Clippy, tests, TypeScript build/typecheck, and Jest on push/PR. |
| Releases | `v0.0.1`, published 2026-07-18, includes self-contained macOS and Linux executables plus SHA-256 sidecars. | Git tag `v2.10.0` targets the examined commit; no GitHub Release endpoint was published at access time. |
| Runtime | Codex app-server subprocess and JSONL/JSON-RPC client. | OpenHands REST/WebSocket is the default; a local Codex app-server harness is also implemented. |
| Trackers | Linear plus GitHub Issues, Jira Cloud, Asana, and GitLab adapters with provider-native app-server tools. | Linear only for orchestration, through GraphQL; agent-side helper/query assets support writes. |
| Operator surface | Structured logs; optional Phoenix LiveView dashboard and JSON API. | Local control plane, FrankenTUI, alpha web/desktop shells, run detail, event stream, memory and code-graph extensions. |
| Test inventory (file count, not a coverage claim) | 42 files below `elixir/test`, including fake/unit tests and opt-in tracker/Codex live E2E paths. | 35 root integration-test files plus 215 files under internal module trees; fake-server contract, scheduler, workspace, Codex, OpenHands, control-plane, and UI suites. |
| Installation burden | Either `mise` plus Elixir/Erlang build, or a prebuilt Burrito executable. Still needs `codex`, `git`, and tracker auth for live use. | Rust stable, then either Codex CLI login or a pinned Python/`uv` OpenHands stack plus model credentials; desktop adds Node/Tauri paths. |

The repository facts come from the upstream [Elixir README](https://github.com/openai/symphony/blob/main/elixir/README.md), [release `v0.0.1`](https://github.com/openai/symphony/releases/tag/v0.0.1), OpenSymphony [README](https://github.com/kumanday/OpenSymphony/blob/main/README.md), [CI workflow](https://github.com/kumanday/OpenSymphony/blob/main/.github/workflows/ci.yml), and [tag `v2.10.0`](https://github.com/kumanday/OpenSymphony/tree/v2.10.0).

## Spec and feature comparison

### Verified in the Elixir reference

The Elixir implementation is a close learning target for the intended C++ runtime:

- It loads `WORKFLOW.md` YAML front matter plus prompt body, applies defaults and environment indirection, validates at startup, and retains the last valid workflow after an invalid live reload.
- It owns polling, claims, bounded concurrency, retries, reconciliation, terminal cleanup, deterministic workspaces, lifecycle hooks, and structured logging.
- It launches **Codex app-server** within each issue workspace, streams updates, and exposes blocking/operator-input state to its JSON/dashboard status surface.
- Its app-server integration exposes provider-native tools server-side and strips declared tracker-token environment variables from the Codex child.
- The current reference extends the Draft v1 Linear minimum with GitHub Issues, Jira, Asana, and GitLab. Those extensions are useful design evidence but are not required by the current normative draft.

These behaviors are documented in the [Elixir README](https://github.com/openai/symphony/blob/main/elixir/README.md) and implemented under [`elixir/lib`](https://github.com/openai/symphony/tree/main/elixir/lib). The release notes also identify recent hardening of orchestration/policy handling, workflow validation, input-blocked session visibility, workspace isolation, and live Linear/Codex E2E coverage.

**Important limitation:** upstream labels this program "prototype software intended for evaluation only" and advises hardened independent implementations based on the spec. Its blocked-entry map is explicitly in-memory and is cleared on restart. C++ must therefore treat behavior that exceeds `SPEC.md` as a recorded implementation choice, not silently as a normative rule.

### Verified in Rust OpenSymphony

OpenSymphony contains a substantially wider product surface:

- The documented core has workflow loading, a normalized domain model, retry/backoff, reconciliation, per-issue workspace manifests and hooks, Linear polling, and a control plane.
- Its default agent integration is a managed OpenHands agent-server, using REST plus WebSocket event streaming and a persisted per-issue conversation model. Its own alignment document explicitly calls this a substitution for the upstream app-server runner.
- It now also includes a documented Codex app-server harness and tests for it, but Codex is an optional harness rather than the default operational path.
- It adds hierarchy-aware selection, task/dependency graph views, desktop and TUI clients, local memory/knowledge graph, Tree-sitter code graph, planning features, deployment modes, and installer work. These are product extensions beyond Draft v1.
- Its testing guide describes deterministic fake OpenHands, Linear, and control-plane tests; opt-in live OpenHands/Linear tests; and concrete scheduler/workspace/runtime failure cases. This is a strong catalog for C++ test design.

The project’s own [spec-alignment document](https://github.com/kumanday/OpenSymphony/blob/main/docs/specs/symphony-spec-alignment.md) is unusually useful because it says which portions are preserved and identifies the OpenHands runner as the main deviation. That self-report is **not independently verified conformance**. In particular, its fixed continuation delay and implementation-specific conversation persistence must be checked against the pinned upstream `SPEC.md` before becoming C++ expectations.

## Maturity assessment

**Inference from the verified evidence:**

- **Conformance maturity:** Elixir is stronger. It is maintained in the same repository as the normative draft and uses the required Codex app-server mode directly. The draft nevertheless outranks its code whenever they differ.
- **Operational/UI maturity:** OpenSymphony is stronger in breadth. It has a `v2.10.0` package/tag, much more extensive operational documentation, a desktop/TUI control plane, durable local artifacts, and broader automated validation.
- **Least-risk oracle for the C++ core:** Elixir is stronger because it has less runtime substitution: C++ needs a Codex app-server adapter, while OpenSymphony’s default path is OpenHands. A broad product is not automatically a closer oracle.
- **Best source of adversarial scenarios:** OpenSymphony is stronger. Mine its fake tests and documented edge cases for scheduler, retry, reconnect, workspace containment, manifests, and status models, then restate the test in C++ terms and bind expected results to `SPEC.md` or an explicit C++ ADR.

Neither should be treated as production-ready evidence for activating real tracker writes. The official README warns that the Elixir implementation is evaluation software; OpenSymphony’s default local mode describes host filesystem access and process-level isolation on trusted machines.

## Fixture-only execution plan

1. **Pin source:** record the two commits above in a C++ fixture manifest. Do not follow moving `main` branches in deterministic tests.
2. **Elixir protocol lane:** run the Elixir runtime against a disposable `WORKFLOW.md`, in-memory/fake tracker, temporary workspace root, and fake Codex app-server. Capture redacted JSONL request/response sequences and status snapshots. Cover malformed events, normal completion, an unchanged-progress continuation, timeout, terminal-state cancellation, invalid reload retaining last-good config, and restart behavior.
3. **Rust scenario lane:** run only its fake/local test facilities at first. Extract scheduler, workspace, reconnection, manifest-recovery, and control-plane fixtures. When using its Codex harness, keep the same fake app-server transcript used in the Elixir lane so a difference is attributable to the orchestrator rather than the agent service.
4. **Create a C++ differential harness:** normalize each observation into `issue state`, `attempt number`, `workspace action`, `runtime action`, and `operator event`. Assert C++ equality only for requirements traceable to the official draft. Record all other differences as `extension`, `intentional C++ policy`, or `unresolved`.
5. **Keep active operations out of scope:** no live Linear, no GitHub/Jira/Asana/GitLab mutation, no real Codex login, no production repository checkout, no secrets in fixtures, and no agent with a writable non-temporary path.

## C++ implementation implications

- Build the `symphony_codex` JSONL/JSON-RPC adapter early and make the Elixir transcript suite its first compatibility target.
- Keep the C++ scheduler, tracker, workspace, clock, event store, and status output interfaces separate, so that OpenSymphony-derived fake cases can be run without accepting the OpenHands architecture.
- Adopt only the Draft v1 core first. Put OpenSymphony-only concepts such as a WebSocket-first runtime, OpenHands conversation persistence, code graph, memory graph, desktop/TUI, and hierarchical selection behind later, explicitly approved extensions.
- Preserve the requested anti-spin rule as a C++ policy test. It is a product strengthening beyond a simple normal-exit retry behavior, so it must not be inferred merely from either comparison runtime.

## Decision

Use **Elixir first, Rust second**. The Elixir runtime is the right reference implementation for conformance and Codex-protocol learning. OpenSymphony is worth running fixture-only as a high-value comparative implementation, especially for failure-mode and operator-experience research, but its OpenHands-default architecture means it must not define the C++ service contract.
