# Standalone C++26 Symphony goal v2 — control-plane reset

Updated: 2026-07-26

This is the canonical active checklist and handoff. It is a control document, not an execution
transcript. Keep it below 250 lines. Replace the current checkpoint in place; put chronological
evidence in `docs/implementation-log.md`. The pre-reset ledger is archived at
`.codex/goals/archive/standalone-cpp26-2026-07-26-pre-reset.md` and is never a required reviewer
input.

## Objective

Deliver the standalone OpenAI Symphony Draft v1 service in C++26, but first restore the intended
development control plane:

1. a clean, immutable, GCC 16.1 local development container operated through Dev Container CLI;
2. admitted stock OpenSymphony running locally as the external Codex orchestrator;
3. bounded review, publication, context, and authority workflows that do not repeatedly pause the
   native goal;
4. C++ implementation slices executed through that admitted workflow.

No new standalone product subsystem may begin until the GCC devcontainer and OpenSymphony
admission phases below pass. Preserve already completed product work.

## Governing boundaries

- `AGENTS.md` and its named files/skills govern.
- OpenAI Symphony Draft v1 remains normative.
- Core product code is C++26. GCC 16.1 defines executable semantics; Bloomberg clang-p2996 at
  `7220baff` is differential-only.
- Use CMake 4.4, Ninja, CTest, ccache, pinned vcpkg, and NVIDIA stdexec at its selected seam.
- Run `dependency-first` before covered capability work; no custom commodity replacement without
  explicit owner authorization recorded in `docs/dependency-decisions.md`.
- OpenSymphony remains external, stock, local-only, and unmodified until an upstream-reviewed
  immutable correction is deliberately repinned.
- No deployment, force-push, rebase, production credential inspection, unapproved tracker
  mutation, mutable image admission, or unrelated repository work. The pre-reset canary is
  historically consumed; the owner-provided native reset objective separately authorizes exactly
  one post-reset fixture-only canary after admission and explicitly forbids a second post-reset
  canary.

## Goal and context operating policy

- Keep this file below 250 lines and `.codex/notepads/root.md` below 150 lines.
- Update only on a material state transition: new evidence, decision, red/green boundary, review,
  commit, push, CI terminal state, blocker, or reordered task.
- Replace `Current checkpoint`; do not append a turn-by-turn narrative.
- Store exact long logs and generated packets under ignored `.build/` or disposable `/tmp`; retain
  only hashes, commands, results, and paths here.
- Reviewers receive a preassembled bounded packet and the exact changed paths, not this archive,
  the full goal history, private memory, or broad repository access.
- Verify durable state by 45% reported context utilization, target clean handoff at 50%, add no
  scope after 50%, and authorize no next model turn at or above 55%.
- Never estimate missing utilization or compaction. After observed compaction, end the process and
  restore from this file plus the root notepad in a fresh thread/process.
- When utilization telemetry is unavailable, execute at most one atomic slice, 12 controller tool
  calls, or 30 minutes in the current turn, whichever ends first; checkpoint both durable files
  and start a fresh turn/process before taking another slice.
- Native `blocked` is reserved for the same true impasse after three consecutive goal turns.
  Ordinary review lifecycle, CI, and upstream waits remain explicit task states while other
  meaningful work exists.

## Agent and review policy

- One writable integration lane. Read-only research/review may run concurrently only on immutable
  snapshots; until `AGENT-GOV-005/006` pass, run at most one specialist beside the controller.
- Reset architecture and high-risk adversarial review: `gpt-5.6-sol` / `xhigh`.
- Normal implementation and review: `gpt-5.6-sol` / `high`.
- Focused read-heavy triage may use `gpt-5.6-terra` / `medium`.
- Do not raise effort for missing authority, credentials, external service state, oversized
  packets, schema launch errors, or absent telemetry.

Standing read-only review envelope for each independently testable slice:

- one normal review and one risk-triggered adversarial review;
- one fresh corrected-byte pair after accepted findings change reviewed bytes;
- at most four successful-inference reviewer processes: the initial pair and one corrected pair;
- at most two schema/transport launch retries before inference, counted separately;
- immutable no-remote snapshot, no network, no delegation, no edits, no memory lookup;
- at most three tool commands and 15 minutes per inferred reviewer;
- target at most 150,000 cumulative input tokens per process and 400,000 per slice; if post-run
  telemetry exceeds a target, redesign the next packet rather than retry or raise effort;
- at most twelve inferred-review commands and 60 inferred-review minutes per slice;
- stop fail-closed with a partial result when any measurable hard limit is exhausted.

This envelope never authorizes source-scope expansion, publication, credentials, tracker mutation,
image promotion, merge, or a live canary.

Before starting any unchecked phase item, create or refresh its bounded slice capsule under
`.codex/notepads/`. The capsule must name one observable contract, failing fixture, owned paths,
exact validation command, expected evidence artifact/hash, pass condition, and stop/split
condition. A phase item cannot be checked from prose or reviewer opinion alone.

## Publication policy

- Exact-byte review binds to a manifest and is invalidated by reviewed-path changes.
- Change-route validation:
  - ordinary C++ source: formatting, dependency/static checks, focused and full GCC devcontainer
    tests;
  - workflow/container inputs: only affected Docker/Bake contracts;
  - compiler/runtime recipes: complete toolchain graph.
- The supported local ceremony is one normal push of the current checked-out existing branch.
  Before transport, `scripts/check-push-route.mjs prepare` classifies the exact fast-forward range,
  runs routed validation, and writes the existing redacted exact-base/head publication result as a
  15-minute receipt. The pre-push hook only revalidates the actual range, allowed checkpoint drift,
  and that strict zero-finding receipt.
- Documentation/control and hook-self preparation runs quick preflight plus the publication scan
  without Docker and must finish within 60 seconds; hook verification must finish within 5 seconds.
  Other routes fail closed until their phase admits exact validation.
- Do not expand this narrow receipt into a general publisher/ref/storage protocol without measured
  evidence and a new dependency-first decision.
- Run `scripts/check-adaptive-orchestration.mjs` on the exact reviewed range before public push.
- Require exact-HEAD Source CI after every push.

## Reset phase order

### R0 — Preserve the completed domain checkpoint

- [x] `CONTROL-EVIDENCE-DOMAIN-001` implementation is committed as
      `b0b9d8b8f832f0c55688cd571688172dfdde8b51`.
- [x] Focused/full GCC 16.1 tests, deterministic checks, exact-byte normal/adversarial reviews,
      commit-tree manifest `04743d935781a0d8d0aff46f43e18bc9c0e59c10`, and redacted
      publication scan pass.
- [x] Full pre-push gate passed on the exact commit; SSH transport expired afterward.
- [x] After this reset is activated, perform one explicitly bounded legacy transport retry:
      reverify local HEAD `b0b9d8b8…`, remote `179d0dbe…`, commit-tree manifest `04743d93…`,
      no staged paths, no implementation/configuration drift, and only reset documents dirty;
      then push normally while skipping exactly the already-passed `symphony-push-preflight`
      hook. Remote now equals `b0b9d8b8…`. This exception is consumed and cannot be reused.
- [x] Obtain exact-HEAD Source CI: run `30222627774` passed in 4m46s.
- [x] Freeze `CONTROL-EVIDENCE-VERIFY/WIRE`; do not start either during control-plane reset.

### R1 — Make orchestration mechanically efficient

- [x] Update `docs/agent-orchestration.md` and deterministic link checks from the archived v1 goal
      path to this canonical v2 path.
- [ ] Add failure-first fixtures for change-routed pre-push selection and strict exact-HEAD receipt
      verification.
- [ ] Prove documentation/control/self receipt preparation rejects wrong refs, routes,
      stale/malformed/forged receipts, and non-checkpoint drift; executes no Docker within 60
      seconds; then prove the normal push hook verifies within 5 seconds.
- [ ] Publish the reviewed reset plus routed-hook commits and obtain exact-HEAD Source CI.
- [ ] Generate a single preassembled review-evidence packet and measure token/latency reduction
      against the recorded 272,331-token and 109,495-token reviews.
- [ ] Add representative specialist admission fixtures before raising read-only concurrency above
      one.

### R2 — Admit the daily GCC 16.1 devcontainer

- [ ] Treat the running `symphony-dev:edge` container as prohibited migration evidence; it is not
      an authoritative development environment.
- [ ] Execute GitHub issue #4: qualify a clean runnable generic GCC runtime from pinned
      Codex Universal plus the exact qualified GCC child, with no Symphony source, vcpkg installed
      tree, build tree, OpenSymphony, or credentials.
- [ ] Obtain separate image-publication authority before pushing the candidate/runtime index.
- [ ] Pin `.devcontainer/devcontainer.json` to the reviewed immutable multi-platform digest and
      make `scripts/devcontainer-build.sh` reject mutable tags and report the resolved digest.
- [ ] Recreate through Dev Container CLI 0.88.0 and prove current lifecycle, mise/pre-commit
      mounts, architecture-scoped ccache/vcpkg archives, GCC 16.1, CMake 4.4, C++26 reflection,
      focused tests, and full CTest.
- [ ] Qualify analysis and clang-p2996 devcontainers independently; they do not block the admitted
      GCC daily loop.

### R3 — Resolve OpenSymphony upstream admission

- [ ] Run read-only upstream discovery concurrently with the R2 writable lane after R1 publication;
      do not wait for the devcontainer to finish before collecting immutable upstream evidence.
- [ ] Keep `symphony-opensymphony:candidate` non-operational.
- [ ] Recheck upstream issue #227, linked PRs, releases, and `main` by immutable identity.
- [ ] If no upstream correction exists, reproduce the proposed PATH/exit-127 fix and its focused,
      memory-integration, and locked-workspace tests in a disposable upstream clone.
- [ ] Present the exact upstream patch and request separate authorization before fork/branch/PR
      publication; do not carry an unreviewed local patch in the admitted image.
- [ ] Repin only after an upstream-reviewed immutable correction passes the unchanged suite.

### R4 — Prove every required OpenSymphony feature

- [ ] Build the admitted local image with exact source/build-input identities and
      `upstream-tests=passed`.
- [ ] Run contained login only if required, then memory initialization/status/context, preflight,
      doctor, and no-model dry run in documented order.
- [ ] Execute every disposable feature-matrix gate, including recovery and the OpenHands
      acceptance lane; OpenHands remains a separate local service, not a devcontainer dependency.
- [ ] Classify each feature as proven working, proven unsupported, or blocked with exact evidence.
      Do not silently disable features.

### R5 — Migrate real work to OpenSymphony

- [ ] Consume exactly one owner-authorized post-reset fixture-only canary after every R4 gate
      passes; the historical pre-reset canary remains consumed and no second post-reset canary is
      authorized.
- [ ] Run that bounded OpenSymphony-managed issue with concurrency one and the native goal acting
      only as admission monitor/handoff authority.
- [ ] Prove workspace isolation, lifecycle hooks, review evidence, context rollover, recovery,
      task-state projection, and no unauthorized tracker mutation.
- [ ] Resume `CONTROL-EVIDENCE-VERIFY-001` and the remaining standalone C++ backlog only after the
      canary is healthy.

## Completion criteria

- [ ] R0–R5 are complete with exact evidence.
- [ ] The admitted daily GCC devcontainer is immutable, current, and used for all local builds.
- [ ] Stock/repinned-upstream OpenSymphony passes full admission and successfully orchestrates one
      authorized fixture issue.
- [ ] Review, publication, goal, context, and authority fixtures prevent the recurring pause and
      latency signatures.
- [ ] The remaining standalone C++26 product backlog is completed and verified under the admitted
      workflow.

## Current checkpoint

R0 is complete at local/tracking/live remote `b0b9d8b8…`; Source CI `30222627774` passed and the
one-time legacy hook exception is consumed. OpenSymphony remains fail-closed without a qualified
image; the stale mutable devcontainer remains prohibited.

`R1-GOAL-RESET-001B` completed as commit `8cdf0802f04e5b40ee08137e95b99605d037e7e2`.
Its exact reviewed tree is `0edc4edbf48cc71655f21ed9830d1c067e00b9d3`; normal/high and
adversarial/xhigh reviews passed the identical snapshot, and the commit tree equals it.

`R1-CHANGE-ROUTED-HOOK-001` stopped fail-closed after exhausting its four-inference review budget.
Successive reviews found and fixtures corrected concurrent ref movement and multiple push
destinations; final normal review passed. Final adversarial review of immutable tree
`4ca0115a…` found two valid P2s: receipt verification reopened a path after `lstat`, and the hook
did not reverify the receipt after its final context check. The prior slice is closed without a
commit or push; its exact review history is in
`.codex/notepads/r1-change-routed-hook-001.md`.

`R1-RECEIPT-ATOMIC-READ-001` is the active independent remediation slice. Replace path-based
receipt reads with one-open, no-follow, same-descriptor bounded verification; verify descriptor
metadata stability; and verify the receipt again after the final hook context check. Add
deterministic path-replacement and between-check mutation fixtures. Failure-first evidence rejected
the reopened replacement as malformed. After implementation, focused fixtures pass in 23.15
seconds, full integration in 40.77 seconds, and complete quick preflight in 52.97 seconds without
Docker. Freeze these staged bytes for a new immutable review packet. Detailed contract and stop
conditions are in `.codex/notepads/r1-receipt-atomic-read-001.md`. Do not commit or push until the
new normal and adversarial review pair passes identical bytes.
