# Orchestration adversary notepad

> Historical specialist evidence, not current policy. Its strict-50 recommendation was superseded
> by the owner's clarification that 50% is guidance and the canonical goal's 45/50/55 policy.
> Follow `.codex/goals/standalone-cpp26.md` for the active writable slice and next command.

## Objective

Evaluate whether adaptive agent routing, durable learning, context rollover, and multi-agent work can
be enforced without context loss, self-referential drift, runaway cost, unsafe authority expansion,
write collisions, correlated review, secret leakage, or unverifiable process claims.

## Constraints

- Read-only review except for this notepad.
- No tracker mutation, network mutation, production credentials, publication, or repository cleanup.
- No agent may exceed the owner's 50% context ceiling.
- Every clean reset must restore from durable task state, not from a continued or compacted thread.
- Current writable concurrency remains one; parallel specialists are read-only.
- Current source and executable evidence are authoritative. Descriptive policy is not implementation.

## Risks and failure cases

- The current pure supervisor action at 50% is `checkpoint_then_continue`; it does not enforce a
  hard 50% stop.
- Last-turn token telemetry is observed after a turn. Without a before-model-call admission hook and
  a bounded next-call delta, an external supervisor cannot guarantee that a turn never crosses 50%.
- Missing, stale, malformed, uncorrelated, or non-positive-window telemetry must deny continuation.
- Model-authored progress summaries and current-step text currently affect the progress fingerprint;
  narrative churn can reset no-progress and repeated-failure evidence without artifact progress.
- Raw error-text hashing is unstable across timestamps, paths, IDs, and nondeterministic formatting;
  it can evade recurrence limits or conflate generic failures.
- Repeated identical failures currently escalate to maximum effort but are still requeued without an
  implemented third-failure stop or issue-wide session, token, cost, or deadline ceiling.
- A free-form shared notepad can be stale, truncated, corrupted, poisoned by another task, committed
  accidentally, or used to smuggle issue content, prompts, credentials, or authority expansion.
- Shared-worktree notepads permit lost updates and collisions. A task note is not an atomic claim or
  permission manifest.
- Same-model reviewers with shared assumptions or author context can produce correlated errors even
  when their role labels differ.
- A review, checkpoint, fresh-session, or learning claim is unverifiable unless bound to exact task,
  repository, policy, session, commit, artifact, and evidence identities.
- The current worktree has unrelated uncommitted and untracked orchestration/container changes, so
  this review cannot be reused as exact-commit merge evidence.

## Proposed objective tests and stop conditions

- Boundary tests immediately below and at 50%; at 50% the next action must be mandatory rollover,
  not continuation.
- Cross-threshold test: a turn admitted below 50% reports above 50%; prove no next turn launches and
  separately expose that post-turn telemetry cannot prove the strict instantaneous ceiling.
- Before-model-call admission fixture, or fail the strict-ceiling capability gate when no such hook
  exists.
- Missing, stale, duplicate, out-of-order, wrong-thread, wrong-turn, negative, overflowed, and
  malformed telemetry all pause without estimating.
- Crash tests at every checkpoint boundary: before/after task-state commit, Git checkpoint, fsync,
  old-process reap, session-count compare-and-swap, and fresh-session launch.
- Corrupt/truncated/unknown-schema/foreign-task/foreign-repository/stale-SHA task state quarantines
  the task; it is never reconstructed from model prose.
- Concurrent compare-and-swap update test admits one writer and rejects the loser; canonical path,
  symlink, branch, worktree, and shared-resource overlap tests reject conflicting claims.
- Secret fixtures are rejected or redacted before serialization; raw database, WAL, handoff, logs,
  backups, and generated snapshots contain no secret bytes.
- Progress tests prove that narrative-only changes, timestamps, run IDs, repeated commands, and
  process success do not change the progress fingerprint or reset failure counters.
- Failure-family tests normalize volatile text, distinguish materially different failures, promote
  a deterministic guard on the second recurrence, and stop automatic retries on the third.
- Hard monotonic budgets cover accepted sessions, completed turns, wall clock, input/output/cached
  tokens, priced cost when trustworthy, tool invocations, and expensive matrix runs. Reset/fork/
  compaction/restart must not reset issue-wide budgets.
- Reviewer tests reject author/coauthor identity, stale reviewed commit, shared session/thread,
  unresolved findings, byte changes after review, and missing required adversarial review.

Stop immediately on any of: telemetry unavailable or inconsistent; observed compaction; 50% reached
under the owner's ceiling; durable task-state or checkpoint verification failure; dirty or
out-of-scope checkpoint state; claim conflict; secret-policy rejection; two consecutive
artifact-identical no-progress attempts; third normalized failure recurrence; four accepted
sessions; 90-minute deadline; exhausted token/cost/matrix budget; stale or unresolved review;
authority, specification, or policy ambiguity that remains after bounded source reconciliation.

## Safe durable task-state schema

Use a controller-owned versioned record outside writable worktrees, updated transactionally with an
expected revision. The per-session agent receives only a read-only sanitized projection.

Required identity and integrity fields:

- `schema_version`, `record_revision`, `checkpoint_id`, `parent_checkpoint_id`, `content_digest`
- `task_id`, `lane_id`, `repository_id`, `policy_digest`
- `base_sha`, `checkpoint_sha`, `branch_id`, `worktree_id`, `claim_digest`
- `agent_role`, `model`, `effort`, `session_id`, `thread_id`, `turn_number`

Required scope and work fields:

- one bounded acceptance contract digest
- canonical allowed/denied path claims and shared-resource claims
- ordered task items with stable IDs and enum status
- next atomic action, stop/split condition, next owner
- evidence references containing exact command ID, exit status, artifact digest, and reviewed SHA

Required budget and recovery fields:

- model context window, fresh last-input tokens, utilization numerator/denominator, compactions
- issue-wide accepted sessions and completed turns
- cumulative input/output/cached tokens, cost-policy version, wall-clock deadline
- normalized failure family/signature/count and objective progress fingerprint
- old-process reap state, fresh-session reconciliation state, review state

Do not permit free-form prompts, transcripts, issue descriptions, environment values, credentials,
hidden reasoning, raw command output, or unbounded diagnostics. Redact and validate before the first
serialization boundary. Unknown schema or authority fields fail closed. Task state is a recovery
record, not an authority source; protected policy and atomic claims remain independently verified.

## Open questions

- Does “no agent above 50%” mean an instantaneous in-turn ceiling, or only “never authorize another
  model call/turn once fresh correlated telemetry is at or above 50%”? The former is not enforceable
  with current post-turn telemetry.
- Which trusted controller owns the durable task-state transaction and integrity key?
- What token/cost ceiling and price-policy snapshot apply per task?
- Is heterogeneous-model review required for high-risk work, or is fresh-session prompt and
  evidence separation plus deterministic tooling considered sufficient?
- Where will the versioned claim schema live, and when may writable concurrency exceed one?

## Status and task list

- [x] Read repository instructions and upstream lock.
- [x] Attempt contained project-memory status; qualified image is unavailable.
- [x] Read orchestration, engineering-system, model policy, feature matrix, workflow, source, tests,
      current diff, and git status.
- [x] Identify implementation/policy mismatches and adversarial risks.
- [x] Incorporate the 50% hard ceiling and durable task-state requirement.
- [x] Deliver prioritized findings, enforcement gates, tests, human boundaries, small-task rules,
      and fresh-session rules to the integration owner.

## Next action

Integration owner should resolve the meaning of the 50% ceiling, then sequence failure-first slices:
strict context admission capability, durable task-state schema/journal, objective artifact progress,
failure recurrence ceiling, and only afterward atomic claims and wider concurrency. Broader adaptive
autonomy remains blocked until those gates and exact-fingerprint reviews are executable.
