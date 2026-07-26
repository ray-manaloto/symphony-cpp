# R1-RESET-DOC-001 — archived partial mixed slice

## Observable contract

Every live orchestration surface routes the controller and specialists to
`.codex/goals/standalone-cpp26-v2.md`. The former v1 goal and root notepad exist only as immutable
dated archive evidence. A deterministic fast-preflight check rejects a missing v2 goal, a live v1
goal, or any v1 path reference outside `.codex/goals/archive/` and `.codex/notepads/archive/`.

## Failure-first fixture

Before implementation, an exact fixed-string scan returned live v1 references in
`docs/agent-orchestration.md`, one `.codex/agents/*.toml` profile, and five active advisor
notepads. The fixture is red while any such reference remains:

```bash
legacy_goal_dir=.codex/goals
if grep -RFn \
  --exclude-dir=archive \
  --exclude=standalone-cpp26-v2.md \
  "${legacy_goal_dir}/standalone-cpp26.md" \
  docs/agent-orchestration.md .codex/agents .codex/notepads; then
  exit 1
fi
```

The first wrapper used zsh's read-only `status` parameter after the scan. It was discarded as a
preparation error and rerun under Bash with `fixture_rc`; the corrected red result identified one
specialist profile and five advisor notepads plus the orchestration page.

## Owned paths

- former active v1 goal path (deleted)
- `.codex/goals/standalone-cpp26-v2.md`
- `.codex/goals/archive/standalone-cpp26-2026-07-26-pre-reset.md`
- `.codex/notepads/root.md`
- `.codex/notepads/r1-reset-doc-001.md`
- `.codex/notepads/archive/root-2026-07-26-pre-reset.md`
- `.codex/agents/tracker-inventory-auditor.toml`
- `.codex/notepads/{documentation-drift-advisor,orchestration-adversary,orchestration-policy-planner,process-research-advisor,tracker-governance-advisor}.md`
- `docs/agent-orchestration.md`
- `docs/dependency-decisions.md`
- `scripts/check-local-preflight.sh`

## Validation and evidence

- Focused command: archive/live-goal existence checks plus `git grep --cached` and
  `git grep --untracked` fixed-string scans across the complete repository, excluding only the two
  dated archive trees and the checker's own legacy-path constant.
- Full command: `./scripts/check-local-preflight.sh quick`.
- Required repository checks: `git diff --check` and `node scripts/check-dependency-policy.mjs`.
- Evidence artifact: path-ordered Git-blob manifest and aggregate under ignored
  `.build/review/r1-reset-doc-001/`.
- Pass: focused and full commands exit zero; old path exists only inside the two archive trees;
  archive goal/notepad hashes remain stable; one bounded final-byte review returns no actionable
  finding; exactly the owned paths are committed.

Current final-byte validation:

- focused contract: pass;
- quick preflight: pass;
- archived goal SHA-256:
  `80d0d83e87f45a62bde23fdc9f61a4b09aa7e4785c0ffe16038bb1bb3f4ad695`;
- archived root notepad SHA-256:
  `59e80b48dcce0e8bb242f233e73fe371a79c8ed5bb2594656b0923038e0b3bd2`.

The first bounded final-byte review found three accepted issues: the reference scan was narrower
than its repository-wide contract, the root identity block retained the pre-push remote/divergence
state, and the completed migration item remained unchecked. The corrected candidate widens both
index and live-worktree scans, records `b0b9d8b8…` at divergence zero, and closes the migration
item. These byte changes require the standing corrected-byte review pair.

The fresh corrected normal review found two additional accepted issues: required v2/archive and
forbidden v1 path presence were proven only in the worktree rather than independently in the index
and worktree, and excluding the complete checker from the legacy scan could hide a second stale
reference. The remaining adversarial attempt is not run on known-bad bytes. Split the unchanged
reset/reference document subset for exact-byte adversarial closure, and continue the checker as
`R1-GOAL-GUARD-001` with independent index/worktree hostile fixtures. The two normal attempts,
commands, time, and token evidence remain cumulative and are not reset by this split.

## Stop or split

Stop on any non-owned dirty path, archive-byte drift, checker dependency expansion, required
behavior change outside canonical-goal routing, review-envelope exhaustion, or failed validation.
Do not push this slice; R1 publication mechanics remain the next fresh slice.

Final disposition: split after the second normal review. This mixed slice is not commit authority
for the checker. Its accepted findings and consumed attempts transfer as historical evidence;
`R1-RESET-DOC-001A` owns the unchanged durable documents, and `R1-GOAL-GUARD-001` owns the
checker/dependency-ledger correction.
