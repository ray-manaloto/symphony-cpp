# R1-CI-PRECOMMIT-RESOLVE-001 — fixture tool resolution

## Observable contract

The push-route fixture installs hooks with the repository-selected pre-commit 4.6.1 executable even
after its current directory changes to a disposable Git repository that has no mise configuration.

## Failure-first evidence

Source CI run `30228487196` failed in nine seconds at fixture initialization: the mise shim searched
the disposable repository, found no pre-commit version, and skipped the GCC job.

## Maintained mechanism and owned paths

Resolve the installed executable once with pinned `mise which pre-commit` from the owning repository
before entering fixtures. No copied binary, PATH mutation, global default, or new dependency.

- `scripts/test-push-route.mjs`
- `docs/dependency-decisions.md`
- `.codex/goals/standalone-cpp26-v2.md`
- `.codex/notepads/root.md`
- `.codex/notepads/r1-ci-precommit-resolve-001.md`

## Validation and stop

Run focused quick fixtures and complete quick preflight, then use one bounded review. Commit and
normal-push only if the failure is fixed without changing receipt behavior. Stop on any local
fixture regression, new workflow/tool installation, or review finding.

## Evidence

- Focused quick fixtures: PASS, 23.37 seconds.
- Complete quick preflight: PASS, 48.44 seconds, no Docker.
