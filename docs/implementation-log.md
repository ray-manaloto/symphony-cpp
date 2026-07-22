# Implementation goal log

Append-only record for the standalone implementation.

| Date | Observation | Decision |
| --- | --- | --- |
| 2026-07-22 | A new repository avoids coupling the C++ service to the honeymoon Node controller. Both research lanes already have current artifacts. | Bootstrap a fixture-only C++ vertical slice; mark primary and Last30Days research `reused`; prohibit live mutations and publication. |
| 2026-07-22 | The initial portable Linux C++26 suite passed, then dependency-enabled Docker commands detached after the tool window and overlapping invocations corrupted Ninja's log. | Treat long compiler/build jobs as named containers and poll one owner; never start a duplicate for an unchanged running build. This is `promoted` into `scripts/container-job.sh`. |
| 2026-07-22 | Repository creation already triggered the compiler matrix; a manual dispatch queued the same revision behind it. | Cancel the duplicate immediately. Before dispatch, list runs for the exact workflow and commit; dispatch only when no queued or running equivalent exists. |
| 2026-07-22 | GCC 16.1 surfaced a deprecation warning inside nlohmann/json under the project's `-Werror` policy. | Mark fetched third-party dependencies as CMake `SYSTEM`; retain strict warnings for project source. |
| 2026-07-22 | The owner wants to choose the C++ infrastructure libraries before the scaffold expands. | Freeze the library decision boundary; continue only architecture-neutral protocol, conformance, source-lock, and CI work until those choices are agreed. |
| 2026-07-22 | The workspace-level commit hook evaluates this standalone repository against an expired controller lease in the separate honeymoon worktree. | Do not bypass the hook or mutate the other worktree. Preserve the staged changes and treat repository-local commit authorization as unresolved infrastructure. |
