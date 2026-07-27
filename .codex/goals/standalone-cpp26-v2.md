# Standalone C++26 Symphony — active goal

This is the canonical evolving checklist and handoff record. Update it only when identity, evidence,
task order, authority, or blockers change. Put chronological detail in `docs/implementation-log.md`
and one capsule under `.codex/notepads/` per atomic slice.

## Objective

Implement OpenAI Symphony Draft v1 as a standalone C++26 service, using an admitted local GCC 16.1
devcontainer and a fully qualified stock OpenSymphony workflow for development orchestration.
OpenSymphony is an external controller, never a product dependency or conformance authority.

## Non-negotiable boundaries

- GCC 16.1 defines executable semantics; Bloomberg clang-p2996 `7220baff…` is differential-only.
- Core/product code is C++26. Use the project `dependency-first` skill before capability work.
- All third-party C++ code is pinned through vcpkg manifest/overlays; no FetchContent or vendoring.
- Generic runtime images contain no Symphony source, project/vcpkg state, OpenSymphony, or secrets.
- Devcontainers are built locally with Dev Container CLI 0.88.0 from immutable generic images.
- Builds run locally inside admitted devcontainers; CI validates exact source and publishes only
  separately authorized generic runtime artifacts. Never publish a configured devcontainer or
  OpenSymphony image.
- Fixture-first; no production credentials, deployment, force-push, rebase, privileged install,
  unapproved tracker mutation, or unqualified image.
- Keep OpenSymphony fail-closed until every admission row passes. Never weaken upstream tests.

## Operating protocol

- One atomic slice: observable contract, failing fixture, owned paths, focused command, pass
  condition, and stop/split condition in a capsule under `.codex/notepads/`.
- One writable integration lane and at most one read-only specialist beside the controller until
  `AGENT-GOV-005` admits higher concurrency. Additional useful lanes remain queued.
- Review only immutable milestone-final bytes. Normal review uses Sol/high; security, concurrency,
  publication, and architecture adversaries use Sol/xhigh. Controller/planner uses Sol/xhigh.
  Inventory/log watching uses Terra/medium. Increase effort only after two matching reasoning
  defects with changed evidence, never for external waits or missing authority.
- Standing review authority is read-only against an immutable packet: no edits, staging, commits,
  pushes, network, containers, project memory, or delegation. Each reviewer gets at most three
  commands or 15 minutes; each slice gets at most four successful review inferences, 12 reviewer
  commands, or 60 minutes cumulatively. Exhaustion closes the slice fail-closed.
- A review finding closes or remediates its finite slice; it does not pause the whole goal.
  Mark the goal blocked only for a genuine external/authority impasse after three repeated audits.
- Checkpoint durable state at 45% context; at 50% add no scope and prepare handoff; at 55% continue
  only in a fresh task/session. Compaction requires a fresh-task handoff. If telemetry is absent,
  use 12 controller tool calls or 30 minutes as a normal rollover boundary, not a blocker.
- Keep this file under 150 lines, root notepad under 150, slice capsules under 80, and reviewer
  packets near 15k–25k tokens. Never fork a long context; start fresh from durable files.
- Research maintained mechanisms first. Human questions follow research and include evidence plus
  pros/cons only when material ambiguity or new authority remains.

## Gates

### G0 — Preserve and publish recovered control state

- [x] Domain checkpoint `b0b9d8b8…` passed exact review and Source CI `30222627774`.
- [x] Goal reset `8cdf0802…` and exact-HEAD routed receipt `3b177518…` published normally.
- [x] Atomic receipt fixes use one-open/no-follow descriptor reads and final revalidation.
- [x] CI portability fix `105d77c7…` published; Source CI `30228797505` passed in 2m14s.
- [x] Freeze R1. Packet-efficiency measurement and specialist-admission fixtures are backlog items,
  not prerequisites for runtime or devcontainer work.

### G1 — Qualify the generic GCC 16.1 runtime

- [ ] Execute GitHub issue #4 without rebuilding qualified compiler children.
- [ ] Assemble native AMD64/ARM64 Codex Universal descendants from exact qualified GCC children.
- [ ] Prove GCC 16.1, CMake 4.4, C++26 reflection, `/opt` runtime linkage, rootfs cleanliness, and
  absence of repository/vcpkg/build/cache/OpenSymphony/credential state.
- [ ] Keep validation capability-absent. Obtain explicit GHCR publication authority, then publish
  exact child digests and a reviewed multi-platform index; no mutable accepted tag.

### G2 — Admit and use the daily local GCC devcontainer

- [ ] Pin only the GCC profile to the reviewed immutable multi-platform runtime digest.
- [ ] Remove the unconditional AMD64 override for native Apple Silicon and reject mutable refs.
- [ ] Recreate through Dev Container CLI 0.88.0; print and verify the resolved digest.
- [ ] Prove lifecycle setup, mise/pre-commit, architecture-scoped ccache/vcpkg archive reuse,
  GCC 16.1, CMake 4.4, reflection, focused tests, and full CTest inside the container.
- [ ] Qualify analysis and clang-p2996 devcontainers independently after the GCC daily loop.

### G3 — Resolve and admit stock OpenSymphony

- [ ] Assess candidate tag `v2.10.1` (`d72bb0a…`) against pinned `v2.10.0` (`0cc21ddd…`);
  no GitHub release object exists, `main` remains at v2.10.0, and issue #227 remains open.
- [ ] Because v2.10.1 does not touch #227, reproduce the minimal upstream-first correction in a
  disposable clone and run focused, memory-integration, locked-workspace, and full upstream suites.
- [ ] Request separate authority before publishing any upstream fork/branch/PR.
- [ ] Repin only to an upstream-reviewed immutable correction whose unchanged suite passes.
- [ ] Build the local-only admitted image with exact labels and `upstream-tests=passed`.

### G4 — Prove every required OpenSymphony feature

- [ ] Run contained login only if needed, then memory init/status/context, preflight, doctor, and
  no-model dry run in documented order.
- [ ] Give each feature-matrix row one bounded fixture and status: working, unsupported by pinned
  upstream, or failed. Required failed rows block activation; no silent disabling.
- [ ] Cover recovery, lifecycle, workspace isolation, retries, reconciliation, task graph,
  code/knowledge memory, dashboard/TUI/API, Codex, model/effort observability, and OpenHands.
- [ ] Keep OpenHands a separate local service; it is an alternate harness, not part of the C++
  devcontainer.
- [x] Reconcile canary documentation to the owner-authorized single post-reset fixture-only canary.

### G5 — Activate one fixture canary, then resume C++

- [ ] After all G4 admission rows pass, activate exactly one fixture-only Linear canary at
  concurrency one; native goal is admission monitor/handoff authority only.
- [ ] Prove zero unauthorized tracker mutation, workspace/hook/recovery/review/context evidence,
  and deterministic cleanup. No second canary.
- [ ] Resume `CONTROL-EVIDENCE-VERIFY-001`, then `CONTROL-EVIDENCE-WIRE-001`, as small
  OpenSymphony-managed work inside the admitted GCC devcontainer.
- [ ] Continue the remaining standalone C++26 backlog under the same dependency, review, and
  conformance gates.

## Parallel work and current checkpoint

- Writable lane: `G1-RUNTIME-GRAPH-001` — qualify the generic GCC runtime without compiler rebuild.
- Read-only queue A: complete the v2.10.1/#227 upstream gap packet and proposed test plan.
- Read-only queue B: verify the GCC devcontainer digest/native-platform contract before G1
  publication. Activate it only after queue A finishes.
- Do not run concurrent local Docker builds. While GitHub runtime CI runs, continue the one active
  read-only lane and documentation reconciliation.

Current branch/local/live remote is `codex/implementation` at `105d77c70acf2d71a7f7b498aafb24be57e03d6a`.
Working-tree checkpoint edits are this goal, root/capsule evidence, upstream watch evidence, and
reset documentation only. OpenSymphony remains fail-closed; the current devcontainer still points
to prohibited mutable `symphony-dev:edge`. Real unresolved authority: generic GHCR runtime
publication and any upstream OpenSymphony branch/PR. The goal is active, not paused or blocked.
