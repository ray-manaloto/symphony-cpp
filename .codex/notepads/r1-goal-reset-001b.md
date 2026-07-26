# R1-GOAL-RESET-001B — atomic goal reset and routing guard

## Observable contract

One commit atomically makes v2 the sole live canonical goal, preserves the pre-reset goal/root in
dated archives, updates every active orchestration reference, and installs a fail-closed guard
that proves required regular files and the forbidden v1 path independently in both the Git index
and live worktree. Git owns index/worktree discovery; repository code owns only path policy.

## Failure-first evidence

The two archived partial capsules preserve the red stale-reference fixture and five accepted
review findings: stale root identity, unchecked migration state, worktree-only required-path
checks, overbroad checker self-exclusion, and a non-self-consistent document-only commit. The new
hostile suite must reject:

- a required goal or archive missing only from the index;
- a required goal or archive missing only from the worktree;
- v1 present only in the index or only in the worktree;
- a stale v1 reference present only in staged content or an untracked file;
- a required worktree goal replaced by a symlink.

The first focused run failed before hostile cases completed: ShellCheck rejected a combined
`readonly` assignment, and a loop-scoped index entry was accidentally made globally immutable
after the first required path. Separate assignment/readonly and a reusable loop variable correct
both; the hostile suite is the regression guard.

The first final-byte normal review found that ignored untracked files were outside the worktree
scan and that `git grep` can report an object-read error with the same status 1 as a clean
no-match. Corrected bytes use `--no-exclude-standard`, require status 1 to have no diagnostic
output, and add ignored-file and missing-object fatal-path fixtures. These changes require a fresh
corrected normal/adversarial pair.

The next normal review of tree `8609e520371b196b1776709823028464304aab9f` reported a
tracked-worktree false accept and a `ls-files` diagnostic/no-match gap. A new modified-tracked
fixture proves the existing `--untracked` worktree scan rejects that state, so no production scan
change is needed for the first claim. The second finding is valid: the legacy index probe now uses
`ls-files --stage`, distinguishes empty success from inspection failure, and has a deterministic
fatal-path shim. The shim initially recursed through mise; resolving Git under `getconf PATH`
removes that nonportable test dependency.

The normal review of tree `f9ffff7965cf56135cfe7973f0b3e950e17edd1e` found two P2 fixture
defects. The staged-only case restored from the index rather than HEAD, and checker lookup used
`${PWD}`. It now restores the worktree explicitly from HEAD and resolves the checker through
`${BASH_SOURCE[0]}`. The focused suite passes from both the repository root and `/tmp`.

## Owned paths

- the 14 previously staged reset/reference paths;
- `.codex/notepads/archive/r1-reset-doc-001a-partial.md`;
- `.codex/notepads/r1-goal-reset-001b.md`;
- `docs/dependency-decisions.md`;
- `scripts/check-goal-routing.sh`;
- `scripts/test-goal-routing.sh`;
- `scripts/check-local-preflight.sh`.

## Validation and evidence

- Focused: `./scripts/test-goal-routing.sh && ./scripts/check-goal-routing.sh`.
- Required: `./scripts/check-local-preflight.sh quick`, `git diff --check`,
  `node scripts/check-dependency-policy.mjs`, stable archive hashes, and goal/notepad line ceilings.
- Evidence: immutable staged tree, exact raw change manifest, and patch hashes under `/tmp`.
- Pass: every hostile fixture fails closed, the real index/worktree passes, full quick preflight
  passes, fresh normal/adversarial reviews return PASS on identical bytes, and the exact tree
  commits without pushing.

Latest focused evidence: all 14 valid/hostile cases pass, including modified-tracked,
ignored-reference, missing-object diagnostic, and `ls-files` diagnostic rejection; Bash syntax,
ShellCheck, and the real repository guard pass. Complete quick preflight, dependency policy,
staged diff hygiene, archive hashes, executable modes, and goal/root line ceilings pass on exactly
19 staged paths with no unstaged drift. The latest fixture corrections invalidate that complete
evidence. Stage the corrected 19-path tree and regenerate complete-preflight, archive, mode,
line-ceiling, tree, manifest, patch, and fresh review evidence.

## Stop or split

Stop on archive drift, scope drift, any false accept/reject, nonportable Git/Shell behavior,
review-envelope exhaustion, or commit-tree mismatch. Do not split routing from its guard again.
