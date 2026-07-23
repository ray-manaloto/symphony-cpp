# OpenSymphony v2.10.0 Codex-mode feature matrix

OpenSymphony is a contained external development orchestrator. It is not the
standalone C++26 service or a conformance authority. This matrix defines the
features that are useful inside the repository's current authorization boundary
and the evidence required before they are called working.

| Feature | Decision | Required evidence |
| --- | --- | --- |
| Immutable v2.10.0 build | Adopt | Exact commit checkout, locked full Rust workspace tests, release build, image smoke tests, immutable GHCR digest |
| Target repository `init` | Adopt through disposable fixture | Non-interactive fixture bootstrap produces `WORKFLOW.md`, config, memory policy, and memory skill without touching this checkout |
| Template `update` / self-update | Do not run in the canonical checkout | The immutable image is rebuilt from the reviewed pin instead; mutable template refreshes are diffed in a disposable fixture before selective adoption |
| `doctor` | Adopt | Green static doctor in the image acceptance suite plus authenticated local preflight |
| Codex app-server harness | Adopt | Strict config, login status, generated app-server schemas containing `thread/start` and `turn/start`, prior fixture canary |
| Model and effort | Adopt one bounded worker profile | `routing.model` and local-keychain profile resolve to `gpt-5.6-sol`; the read-only Codex overlay selects `high`; OpenSymphony remains operator-adjusted because v2.10.0 has no effort route |
| Read-only dry run | Adopt | Zero-worker, zero-token route preview using the contained credential injection; repeat after every image or Codex pin |
| Live scheduler canary | Adopt exactly once | The completed `GUI-5` fixture remains the sole authorized canary; no second issue is activated for regression testing |
| Project memory capture/index | Adopt privately | Deterministic fixture import creates a capsule and DuckDB index with zero warnings in an isolated volume |
| Memory documentation sync | Adopt as private staging | Fixture sync writes only under `.opensymphony/memory/generated-docs`; tracked docs require separate review and repository gates |
| Read-only memory MCP server | Adopt | `/health` and MCP `initialize` pass against the isolated captured-memory volume |
| Control plane and TUI | Adopt | Demo control plane `/healthz` and a bounded TUI attachment pass in image acceptance |
| Codex `debug` | Retain for operator recovery | The CLI path is exposed; a future recovery check must use an already persisted fixture thread and must not start another model turn |
| `rehydrate` | Reject for this route | v2.10.0 implements it for OpenHands conversation manifests, not Codex threads |
| Code graph / AST context | Defer for C++ | The pinned query packs cover JavaScript, Python, Rust, and TypeScript, not C++; do not claim C++ indexing or add an unreviewed parser |
| Hierarchy/dependency scheduling | Retain, fixture-gated | The scheduler supports it, but multi-issue Linear mutation is outside the one-canary boundary; add a deterministic GraphQL fixture before raising concurrency |
| Concurrent workers | Keep at one | Raise only after isolated write lanes, resource leases, and multi-issue fixture evidence exist |
| Branch push, PR landing, and AI PR review | Keep outside the worker | GitHub credentials and the host SSH agent are intentionally not mounted; publication stays in the guarded operator ceremony |
| OpenHands runtime | Not applicable | Codex-only routing skips `uv` and managed OpenHands tooling |
| Desktop/web planning clients | Not required for contained CLI operation | Re-evaluate only if their operator features replace a documented repository tool rather than duplicating it |

The image acceptance test is
`scripts/test-opensymphony-acceptance.sh`. Credential-bearing dry runs remain a
separate local ceremony and never run in public CI.
