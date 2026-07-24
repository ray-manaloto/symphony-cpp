# OpenSymphony v2.10.0 full-feature matrix

OpenSymphony is a contained external development orchestrator. It is not the
standalone C++26 service or a conformance authority. This matrix defines the
complete feature surface of the pinned release and the evidence required before
any feature is called working or deliberately disabled. A feature is not omitted
merely because the initial Codex route does not need it.

| Feature | Decision | Required evidence |
| --- | --- | --- |
| Immutable v2.10.0 build | Adopt locally | Exact commit checkout, locked full Rust workspace tests, release build, image smoke tests, and an immutable local image ID; OpenSymphony is not published by this repository |
| Target repository `init` | Adopt through disposable fixture | Non-interactive fixture bootstrap fetches the immutable template pin, produces `WORKFLOW.md`, config, memory policy, and memory skill, and asserts the selected project, branch, review provider, memory policy, and OpenHands tool path without touching this checkout |
| Template `update` / self-update | Prove in a disposable fixture, keep immutable runtime policy | Exercise installation, template/skill/memory changes, review-provider changes, and no-op/idempotence against a disposable home and Git repository; production-like containers remain rebuilt from reviewed pins |
| `doctor` | Adopt with isolated mutation boundary | Prove static, managed-OpenHands, `--live-openhands`, and `--rehydrate` paths using disposable home, tool, workspace, and conversation volumes; static doctor creates directories and may install tooling |
| Codex app-server harness | Adopt | Strict config, login status, generated app-server schemas containing `thread/start` and `turn/start`, prior fixture canary |
| Model and effort | Native model routing plus external policy required | Prove `routing.model` and `routing.model_profile`; verify the mounted Codex configuration selects the intended effort. OpenSymphony does not consume the repository's `codex:` effort/escalation fields and does not adapt effort |
| No-model dry run | Adopt only in a disposable fixture | Assert zero model workers and zero tokens while separately proving workspace creation/recovery, run-manifest writes, and lifecycle hooks. `run --dry-run` is not generally read-only |
| Live scheduler canary | Adopt exactly once | The completed `GUI-5` fixture remains the sole authorized canary; no second issue is activated for regression testing |
| Project memory capture/index | Adopt privately | Deterministic fixture import creates a capsule and DuckDB index with zero warnings in an isolated volume |
| Memory documentation sync | Adopt as private staging | Fixture sync writes only under `.opensymphony/memory/generated-docs`; tracked docs require separate review and repository gates |
| Memory CLI and MCP server | Prove the complete read and admin surface | Exercise read tools against a read-only state copy and every mutating/admin operation against a disposable copy, including OKF and code-intelligence operations; verify bearer-token separation and state fingerprints |
| Real run gateway and TUI | Adopt on loopback | Prove snapshots, capabilities, model status, journal/WebSocket, run detail, files/diffs/validation/approvals/timeline/logs/terminal, memory, task graph, cancel, and a bounded TUI attachment. Distinguish wired behavior from advertised capability flags |
| Demo `daemon` | Prove and label as demo-only | Exercise loopback snapshots and sampling independently; never treat it as the real scheduler gateway |
| Codex `debug` | Retain for operator recovery | The CLI path is exposed; a future recovery check must use an already persisted fixture thread and must not start another model turn |
| OpenHands `debug` / `rehydrate` | Prove in disposable conversations | Exercise normal, `--app`, summarized, and no-summary recovery paths without touching retained Codex or live OpenHands state |
| Code graph / AST context | Prove every supported language; record the C++ gap | Exercise the pinned JavaScript/JSX, TypeScript/TSX, Python, and Rust query packs plus lightweight JSON/YAML/TOML/Markdown parsing. C++ is unsupported; do not claim C++ indexing or add an unreviewed parser |
| Hierarchy/dependency scheduling | Retain, fixture-gated | The scheduler supports it, but multi-issue Linear mutation is outside the one-canary boundary; add a deterministic GraphQL fixture before raising concurrency |
| Concurrent workers | Prove with isolated fixture workers | Exercise configured concurrency, scheduling, cancellation, stalls, retries, and workspace isolation with deterministic fake workers before selecting the operational default |
| Branch push, PR creation, AI PR review, and merge | Adopt through a separate guarded publisher | Prove the template workflow in a disposable Git/GitHub fixture first. Live adoption requires deterministic issue branches, no-bypass base-branch rules, a short-lived single-repository GitHub App token held only by the publisher, a digest-bound approved plan-policy manifest, fresh required evidence, and stable required checks. Ordinary plan-conformant changes may merge autonomously; ambiguity, researched plan/spec contradictions, dependency/toolchain-pin policy changes, or incomplete/stale evidence require human resolution with cited options and tradeoffs |
| OpenHands managed-local runtime | Prove | Install the pinned runtime in isolated volumes; prove API-key and subscription-style configuration, lifecycle, conversation, event, file, action, and recovery behavior |
| OpenHands external agent server | Prove as a separate local service | Prove authenticated REST/WebSocket operation, shared per-issue workspace identity, interruption/recovery, and failure behavior without a Docker socket |
| Desktop and web operator clients | Prove the shipped surface | Exercise installer/update/dry-run/no-update behavior in an isolated home, launch the desktop/web shells, and distinguish real run views from fixture-only or under-construction planning views |
| Linear archive and task-graph mutation | Prove against a fixture API only | Exercise selectors, ranges, memory/state sources, GitHub suppression, dry-run, capture guards, milestones, issues, sub-issues, relations, and evidence comments without another live Linear mutation |

## Native limitations that acceptance must not hide

- The top-level `codex:` map in `WORKFLOW.md` is accepted as opaque data but is
  not resolved or executed by OpenSymphony v2.10.0.
- `agent.max_turns` is stored in runtime snapshots but is not enforced by the
  scheduler or Codex backend.
- There is no maximum issue-lifetime retry count or adaptive escalation.
  Successful workers continue again after one second while the issue remains
  active; retryable failures back off from ten seconds to
  `agent.max_retry_backoff_ms`.
- Most generic gateway actions are journal/validation stubs; cancel is the
  action consumed by the running scheduler. Linear task-graph endpoints perform
  real writes.
- The gateway advertises API-key and planning/action capabilities more broadly
  than the pinned runtime wires them. It is a trusted loopback service, not an
  authenticated production boundary.
- `rust_native` and hosted worker pools are future/advertised modes, not working
  v2.10.0 backends.
- The planning workspace is fixture-backed and under construction.

These are upstream capability gaps, not locally disabled features. Their
acceptance result must be recorded as unsupported, misleading, or externally
contained rather than marked green.

The initial contained image acceptance test is
`scripts/test-opensymphony-acceptance.sh`. It proves the Codex-route smoke,
private memory/read-only MCP boundary, demo daemon/TUI, immutable `init`, and a
no-model routing slice on an internal Docker network against a fake Linear
server that rejects every mutation and every non-allowlisted query. The
no-model slice proves workspace creation, a successful run manifest, and the
`after_create`, `before_run`, and `after_run` hook markers with zero model
conversations, turns, threads, or tokens. Its second phase restarts the scheduler against the
same disposable volumes after replacing the read-only fake tracker with the
same issue in `Done`; it requires startup recovery to retain the original
manifest and bootstrap artifacts, run `before_remove` exactly once for that
observed transition, and still create no conversation, thread, turn, token
usage, or tracker mutation. The added recovery phase requires a fresh complete
acceptance run before its evidence is recorded as passed. It does not prove
in-flight Codex/OpenHands recovery, conversation resume, terminal workspace
deletion, or periodic cleanup idempotence, and it does not close the other
feature-specific disposable gates above. Credential-bearing live-project dry
runs remain a separate suffix-scoped local ceremony and never run in public CI.
