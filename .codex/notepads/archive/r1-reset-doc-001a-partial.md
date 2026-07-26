# R1-RESET-DOC-001A — archived partial document slice

## Observable contract

The v2 goal is the only live canonical controller handoff. The pre-reset goal and root notepad are
retained under dated archive paths, every active orchestration document/profile/handoff points to
v2, and the root repository identity matches published commit `b0b9d8b8…` at divergence zero.
This document-only slice does not claim the deterministic guard is complete.

## Failure-first evidence

The archived mixed slice records the red fixed-string scan, stale root identity, unchecked task,
and two checker-specific findings. This split carries those counters and findings forward rather
than retrying the mixed packet. The document subset is independently reviewable because it excludes
`scripts/check-local-preflight.sh` and `docs/dependency-decisions.md`.

## Owned paths

- `.codex/agents/tracker-inventory-auditor.toml`
- former active v1 goal path (deleted)
- `.codex/goals/standalone-cpp26-v2.md`
- `.codex/goals/archive/standalone-cpp26-2026-07-26-pre-reset.md`
- `.codex/notepads/root.md`
- `.codex/notepads/r1-reset-doc-001a.md`
- `.codex/notepads/archive/root-2026-07-26-pre-reset.md`
- `.codex/notepads/archive/r1-reset-doc-001-partial.md`
- `.codex/notepads/{documentation-drift-advisor,orchestration-adversary,orchestration-policy-planner,process-research-advisor,tracker-governance-advisor}.md`
- `docs/agent-orchestration.md`

## Validation and evidence

- Focused command: require v2 and both dated archives, require no live v1 goal, and scan the
  explicitly owned live orchestration surfaces for the archived v1 path.
- Required checks: `git diff --cached --check`, archive SHA-256 equality, and goal/notepad line
  ceilings.
- Evidence artifact: immutable staged tree plus path-ordered raw manifest and patch hashes.
- Pass: focused checks pass; archive hashes remain `80d0d83e…` and `59e80b48…`; one fresh normal
  and one fresh adversarial review of identical document bytes return PASS; exactly these paths
  commit without pushing.

The first document-only normal review found the canary authority epochs were ambiguous: the
archive says the historical pre-reset canary was consumed, while v2 authorized a canary without
recording that the active owner-provided native reset objective separately granted exactly one
post-reset fixture-only run and forbade a second. Corrected bytes make that provenance and limit
explicit. They require a fresh corrected normal/adversarial pair on identical bytes.

## Stop or split

Stop on an owned-byte change after review, archive drift, non-document finding, path-scope drift,
review-envelope exhaustion, or failed commit hook. Leave the checker and dependency-ledger changes
unstaged for `R1-GOAL-GUARD-001`.

Final disposition: partial, do not commit. Corrected normal review returned PASS. Adversarial
review found the proposed document-only commit was not self-consistent because v1 deletion and v2
routing must land atomically with the exact-tree guard and its hostile fixtures. Recombine all
bytes as `R1-GOAL-RESET-001B`; the two review attempts and finding remain durable evidence.
