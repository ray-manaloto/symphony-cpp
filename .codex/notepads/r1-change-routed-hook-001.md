# R1-CHANGE-ROUTED-HOOK-001 — narrow exact-HEAD receipt routing

## Observable contract

Before one normal push of the current checked-out existing branch, `prepare` classifies the exact
fast-forward range, runs quick preflight plus the redacted publication scan without Docker, and
writes that existing strict exact-base/head result as a 15-minute receipt. The pre-commit hook only
checks the actual proposed range, allowed checkpoint drift, and receipt. Source, devcontainer,
container-recipe, unknown, new-branch, tag, detached, zero-OID, and non-fast-forward cases fail
closed until their later routes are admitted.

The hook accepts durable checkpoint drift only under the canonical goal and `.codex/notepads/`;
other staged, tracked-worktree, or nonignored-untracked drift fails. It is a local latency and
mistake-prevention gate, not authenticated remote enforcement. Exact-HEAD Source CI remains
authoritative.

## Failure-first evidence

Disposable Git repositories and a local bare remote cover:

- missing/zero/moved base or head and missing remote metadata;
- missing, malformed, stale, future, forged-base/head, nonzero-finding, or nonredacted receipts;
- non-branch local or remote refs and non-current HEAD;
- source, devcontainer, container-recipe, and unknown route rejection;
- documentation deletion and type-change acceptance;
- rename across the documentation boundary rejection using both old and new paths;
- disallowed worktree drift rejection and checkpoint-notepad drift acceptance;
- direct push without preparation rejection and a prepared normal existing-branch local push;
- exact-base/head zero-finding publication output.

The installed pre-commit adapter exposes one proposed-update namespace, so this slice deliberately
supports only the repository's single-current-branch ceremony. It does not claim to enforce direct
multi-ref Git client usage. A general receipt/publisher was rejected after review because it grew
past 1,000 lines, duplicated Git/pre-commit behavior, conflicted with durable checkpoint updates,
and blocked R2. The selected receipt reuses the existing publication artifact and adds no remote
protocol, custom storage location, branch-creation mode, or transport wrapper.

## Maintained mechanism

- Git owns exact commit IDs, ancestry, symbolic refs, rename detection, and normal transport.
- Pinned pre-commit 4.6.1 owns hook installation and `PRE_COMMIT_*` push metadata.
- Pinned Node.js standard process/file APIs own NUL-safe routing and strict bounded receipt reads.
- Existing quick preflight and redacted publication scan own validation and receipt generation.

Sources:

- <https://git-scm.com/docs/githooks#_pre_push>
- <https://pre-commit.com/#pre-push>

## Owned paths

- `.codex/goals/standalone-cpp26-v2.md`
- `.codex/notepads/root.md`
- `.codex/notepads/r1-goal-reset-001b.md`
- `.codex/notepads/r1-change-routed-hook-001.md`
- `.pre-commit-config.yaml`
- `scripts/check-push-route.mjs`
- `scripts/test-push-route.mjs`
- `scripts/check-local-preflight.sh`
- `scripts/check-adaptive-orchestration.mjs`
- `scripts/test-toolchain-platform-contract.sh`
- `docs/agent-orchestration.md`
- `docs/dependency-decisions.md`
- `docs/toolchain-and-devcontainer-workflow.md`

Do not edit C++, workflow, compiler, devcontainer, OpenSymphony, tracker, or credential surfaces.

## Validation and pass condition

- Fast preparation gate: `node scripts/test-push-route.mjs --quick`.
- Complete focused integration: `node scripts/test-push-route.mjs`.
- Required: `./scripts/check-local-preflight.sh quick`, dependency policy, diff hygiene, executable
  modes, exact immutable snapshot, normal/high review, and adversarial/xhigh review.
- Commit the hook slice, permit only goal/notepad checkpoint drift, prepare the exact receipt
  before transport, then push the exact current branch normally and measure both durations.
- Pass only if the local bare-remote fixture and real documentation/self push use no Docker,
  preparation finishes in at most 60 seconds, hook verification finishes in at most 5 seconds, the
  live remote equals local HEAD, and exact-HEAD Source CI passes.

## Stop or split

Stop on false route/receipt acceptance, incomplete rename/deletion/type coverage, pre-commit
metadata ambiguity for the supported update, non-checkpoint drift, preparation over 60 seconds,
hook verification over 5 seconds, or reviewed/committed tree mismatch. Do not restore the
abandoned general receipt/publisher protocol by default.

## Review outcome

This slice consumed its four-inference review envelope and is closed without commit or push.

1. Normal review of tree `1828ba99…` found concurrent ref movement could escape detection.
2. Normal review of tree `e0eed7e2…` found multiple push destinations could partially publish.
3. Final normal review of tree `4ca0115a…` passed.
4. Final adversarial review of the same tree found path-reopen TOCTOU and missing receipt
   revalidation after the final context check.

Both findings are routed to independent slice `R1-RECEIPT-ATOMIC-READ-001`.
