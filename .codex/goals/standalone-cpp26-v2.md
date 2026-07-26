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
- at most two retries for schema/transport failures that occur before inference;
- immutable no-remote snapshot, no network, no delegation, no edits, no memory lookup;
- at most three tool commands and 15 minutes per reviewer;
- target at most 150,000 cumulative input tokens per process and 400,000 per slice; if post-run
  telemetry exceeds a target, redesign the next packet rather than retry or raise effort;
- retries are cumulative within the slice: at most three total attempts, nine total reviewer
  commands, 45 total reviewer minutes, and the 400,000-token slice target;
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
- Do not keep an SSH push connection idle during a 12–16 minute gate. Run the required exact-HEAD
  gate first, write a receipt bound to HEAD and relevant-input manifest, then perform one immediate
  ordinary push that skips only that proven hook. Add hostile fixtures before adopting this path.
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

- [ ] Update `docs/agent-orchestration.md` and deterministic link checks from the archived v1 goal
      path to this canonical v2 path.
- [ ] Add failure-first fixtures for change-routed pre-push selection.
- [ ] Add an exact-HEAD validation receipt and immediate transport-only publisher with stale
      HEAD/worktree/relevant-input rejection.
- [ ] Prove ordinary C++ changes do not execute unrelated compiler/OpenSymphony graph checks.
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

`R1-GOAL-RESET-001B` is the active atomic slice. Two partial attempts are archived with all review
findings and counters. Candidate scope recombines v1 deletion, v2 routing, archives, live
references, dependency evidence, an exact Git index/worktree guard, and hostile fixtures. The
first final-byte normal review found two P1 false accepts: ignored untracked references and Git
object-read diagnostics returned with status 1. Corrected bytes now inspect ignored files and
treat nonempty no-match diagnostics as failure; all 12 valid/hostile cases, Bash syntax,
ShellCheck, the real repository guard, and complete quick preflight pass on exactly 19 staged
paths. Archive hashes, executable modes, dependency policy, diff hygiene, and line ceilings pass.
A fresh normal review of tree `8609e520…` then found a missing modified-tracked fixture and a real
`ls-files` diagnostic/no-match gap. The new fixture proves the existing worktree scan rejects
modified tracked references; the production guard now also rejects `ls-files` failures, and all 14
valid/hostile cases pass. Complete quick preflight, dependency policy, archive hashes, executable
modes, diff hygiene, and line ceilings pass on exactly 19 staged paths with no unstaged drift.
A final normal review of tree `f9ffff79…` found two P2 fixture defects: the index-only case restored
from the index, and the test resolved its checker from the caller's directory. Corrected focused
tests now prove true index-only rejection and pass both repository-root and `/tmp` invocation.
These changes invalidate the complete-preflight and snapshot evidence. Next, stage and rerun the
complete preflight, freeze one new immutable snapshot, and obtain a fresh corrected-byte
normal/adversarial pair before committing without pushing. Do not begin publisher/product work
first.
