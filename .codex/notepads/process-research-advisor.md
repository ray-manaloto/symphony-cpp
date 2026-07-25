# Process research advisor

> Historical specialist evidence, not current policy. Its strict-50 recommendation was superseded
> by the owner's clarification that 50% is guidance and the canonical goal's 45/50/55 policy.
> Follow `.codex/goals/standalone-cpp26.md` for the active writable slice and next command.

## Objective

Produce a concise, evidence-backed, read-only proposal for self-improving
software-agent orchestration in `symphony-cpp`, with exact measurable gates for:

- planner/executor/reviewer separation;
- externally grounded reflection and feedback loops;
- eval-driven development;
- failure classification and recurrence;
- context and token management;
- checkpoint-before-handoff behavior;
- small task packets; and
- human escalation and explicit non-automation boundaries.

## Constraints

- Repository guidance and the pinned OpenAI Symphony Draft v1 are authoritative.
- GCC 16.1 defines executable semantics; OpenSymphony is an external contained
  development orchestrator, not a C++ runtime dependency or conformance authority.
- No source, tracker, goal, deployment, credential, publication, or production mutation.
- This notepad is the sole write exception.
- No agent may exceed 50% of its reported context window.
- Before reaching 50%, persist objective, constraints, decisions, evidence references,
  exact commands/results, file/resource ownership, blockers, and next bounded action,
  then hand off to a fresh context.
- Never estimate context utilization when required telemetry is absent or inconsistent.
- Distinguish Codex mechanisms from repository convention.

## Repository evidence

- `AGENTS.md`: fixture-first, dependency-first before subsystem expansion, failing test
  before observable behavior changes, redaction at the structured event boundary, and
  no real tracker/publication/credential mutation.
- `docs/upstream-lock.md`: OpenAI Symphony spec pin
  `1f3219bb1ea5f69a1305dc594e79b0db57c113c5`; OpenSymphony v2.10.0 is external only;
  Codex CLI 0.145.0 is the pinned worker input.
- `docs/dependency-decisions.md`: deterministic external supervisor, Sol/high baseline,
  typed failure routing, four accepted sessions/issue, 90-minute limit, telemetry
  fail-closed policy, and disarmed external process until checkpoint wiring passes.
- `docs/engineering-system.md`: one observable contract per lane, one failing fixture,
  one provider/seam, one focused validation; independent exact-fingerprint review;
  recurrence-driven deterministic guards.
- `docs/opensymphony-supervisor.md`: current 50/60/65 checkpoint/handoff/rollover policy,
  objective progress fingerprints, durable SQLite journal, and explicit non-automation
  boundaries. The new owner constraint supersedes the 60/65 continuation bands.
- `WORKFLOW.md`: one writable worker, four turns/session, two consecutive no-progress
  stop, independent review, and current disarmed external enforcement.
- Current implementation: `thread/tokenUsage/updated` decoding preserves distinct
  `last.inputTokens` plus positive `modelContextWindow`; the pure reducer applies policy
  only between completed turns and pauses on missing telemetry.

## Primary external sources

- OpenAI, Evaluation best practices:
  https://developers.openai.com/api/docs/guides/evaluation-best-practices
- OpenAI, Evaluate agent workflows:
  https://developers.openai.com/api/docs/guides/agent-evals
- OpenAI, Practical guide to building agents:
  https://openai.com/business/guides-and-resources/a-practical-guide-to-building-ai-agents/
- OpenAI, Codex app-server events:
  https://learn.chatgpt.com/docs/app-server#events
- Anthropic, Building effective agents:
  https://www.anthropic.com/engineering/building-effective-agents
- Anthropic, Effective harnesses for long-running agents:
  https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents
- Anthropic, Harness design for long-running application development:
  https://www.anthropic.com/engineering/harness-design-long-running-apps
- Anthropic, Demystifying evals for AI agents:
  https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents
- ReAct, ICLR 2023:
  https://arxiv.org/abs/2210.03629
- Reflexion:
  https://arxiv.org/abs/2303.11366
- Large Language Models Cannot Self-Correct Reasoning Yet:
  https://arxiv.org/abs/2310.01798
- SWE-agent:
  https://arxiv.org/abs/2405.15793
- Lost in the Middle:
  https://arxiv.org/abs/2307.03172
- METR task-completion time horizons:
  https://metr.org/time-horizons/

## Findings

- Keep the controller deterministic. Model-backed planning is advisory and bounded;
  it must not own leases, retries, budgets, policy, publication, or authority.
- Use planner, implementer, and independent reviewer as distinct roles with typed,
  schema-validated handoffs. Review must bind to the exact final SHA/fingerprint.
- Permit iterative repair only from external evidence: executable tests, compiler/tool
  results, structured environment state, or an independent review finding. Intrinsic
  self-critique without new evidence is not progress and can degrade accuracy.
- Evaluate outcomes and traces. Final repository/test state is ground truth; model
  claims, process success, summaries, tokens, and timestamps are not.
- A task packet should own one observable behavior/invariant, one reproduction, one
  seam/provider, one focused command, one file/resource claim, and one checkpoint.
- Use repeated stochastic trials for model/harness evaluation, but exhaustive
  deterministic fixtures for state-machine and authority boundaries.
- Context resets with a structured handoff are better aligned with the owner constraint
  than continuing after compaction. Compaction is a rollover signal, never progress.
- Codex app-server mechanically emits `thread/tokenUsage/updated`, `turn/completed`,
  `contextCompaction`, `turn/interrupt`, and thread start/resume/fork events. The local
  pinned adapter additionally verifies correlated `last.inputTokens` and a positive
  context window.
- The current supervisor observes utilization after/during model activity and makes its
  pure decision after a completed turn; it does not have a documented pre-invocation
  reservation that proves the next invocation will remain under 50%. Therefore a strict
  50% ceiling cannot be claimed from prompt convention or post-hoc telemetry alone.
- Until a fixture-proven pre-invocation bound exists, percentage-based autonomous
  continuation must remain disarmed or use a conservative earlier stop plus bounded
  inputs; missing/stale/inconsistent telemetry must pause.

## Recommended measurable gates

### Role and authority gates

- Keep the controller model-free. It alone admits task capsules, owns counters/deadlines,
  validates claims, and selects terminal transitions.
- Planner output is a closed-schema task capsule. Admission requires exactly one
  observable contract, one reproduction, one provider/seam, one focused command, an
  allowed/denied path set, resource claims, stop/split rules, and next bounded action.
- Executor receives only an admitted capsule and one isolated writable claim. Any
  attempted out-of-allowlist path or shared-resource access stops the lane.
- Reviewer is read-only, did not plan/author/correct the slice, and reviews the exact
  final SHA/fingerprint. Any byte change makes the review stale. Risk-triggered work
  requires a second adversarial review.
- Promotion gate: 100% pass for schema rejection, path alias/symlink overlap, stale SHA,
  contributor-as-reviewer, missing finding disposition, crash/claim recovery, and
  malformed/hostile envelope fixtures.

### Evidence-grounded feedback gates

- A repair loop may start only from a failing executable check, compiler/tool result,
  structured environment state, or independent review finding.
- A reflection record is evidence metadata, not authority: evidence ID/digest, normalized
  family/signature, one falsifiable hypothesis, one changed bounded action, and expected
  verification. Free-form intrinsic self-critique is not progress.
- No new attempt when both the progress fingerprint and normalized failure signature are
  unchanged. Two consecutive same-signature/no-progress issue attempts pause.
- Across the 30-day learning ledger: first occurrence adds a regression fixture; second
  strengthens a deterministic guard with owner and deletion trigger; third disables
  automatic retry for that family pending bounded source reconciliation.

### Failure and retry gates

- Preserve the repository's ten failure families and add orthogonal disposition:
  deterministic/permanent, transient/idempotent, external, resource, telemetry,
  authority-blocked, or unknown.
- Normalize signatures from family, operation/command identity, exit/status class,
  toolchain/environment identity, and relevant artifact digest; exclude secrets, prompts,
  issue bodies, and unbounded logs.
- Only typed transient and idempotent failures receive one automatic retry, at one
  controller layer, with bounded exponential backoff and jitter. Invalid input, permanent
  provider/toolchain incompatibility, credential/authority, missing telemetry, resource
  exhaustion, and unknown failures do not receive model-effort retries.
- Existing hard budgets remain ceilings: four accepted sessions/issue, 90 minutes, and
  no fifth launch. A new context never resets issue-wide counters or deadlines.

### Context and durable handoff gates

- The 50% rule is a strict ceiling: `2 * last_input_tokens < model_context_window`.
  Equality or greater is a violation and cannot authorize work.
- Before every model invocation, admission must prove the invocation's complete input
  remains strictly below half the positive reported window and leaves enough bounded
  room to persist the handoff. Missing, stale, inconsistent, cumulative-only, or
  uncorrelated telemetry pauses; never infer or estimate.
- Before the ceiling, atomically persist and read back a versioned per-task notepad with
  objective, constraints/authority, decisions and source/evidence references, exact
  commands/results, file/resource ownership, blockers/risks, progress and failure
  fingerprints, and next bounded action. Code-bearing state also requires an exact clean
  checkpoint commit.
- Then stop/reap the old worker and start a new process/thread from the verified
  checkpoint and notepad. A fork or compaction is recovery evidence only, never the
  continuation context. Any observed compaction forces the same fresh-context path.
- Mechanical gap: current Codex app-server supplies usage, compaction, interrupt, and
  thread lifecycle events, while the pinned adapter correlates last-turn usage. It does
  not document a pre-invocation input reservation/hard percentage cap, and the current
  reducer decides after completed turns. Therefore strict enforcement stays disarmed
  until an exact preflight/hard-cap mechanism and threshold-crossing/race fixtures pass.
  Prompt instructions or an arbitrary early percentage are convention, not proof.

### Eval-driven promotion gates

- Start with 40 isolated fixture tasks: four for each of the repository's ten failure
  families, balanced with at least two act/repair and two stop/escalate cases per family.
  Every task has an unambiguous reference outcome and a known passing reference solution.
- Run three independent clean trials per task for every model, prompt, tool, or harness
  change. Use pass@1 for task success and pass^3 for reliability; never report best-of-k
  as autonomous reliability.
- Hard invariants require 120/120 trials: no scope/authority/secret/real-service violation,
  no stale review acceptance, no unverified checkpoint resume, no continuation without
  telemetry, and no reported context at or above 50%.
- The regression subset requires 3/3 success per task. For capability tasks, promotion
  requires a paired one-sided 95% non-inferiority bound above -5 percentage points versus
  the pinned baseline; claim improvement only when the paired 95% lower bound is above
  zero. Do not invent an accuracy target before measuring the baseline.
- Prefer deterministic outcome graders (tests, exit status, repository state, exact
  policy transitions). Model graders are advisory until calibrated on at least 40
  balanced expert-labeled examples with Cohen's kappa at least 0.80, 100% recall for
  critical authority/safety findings, and false-positive rate at most 10%.
- Manually inspect every failed trace plus a stratified 10% of passing traces (minimum
  ten traces) for each promotion candidate. Add each fair new failure as a regression
  task; repair grader bugs rather than optimizing the agent against them.

### Small-task gate

- One packet equals one observable behavior/invariant, one failing fixture, one
  provider/seam, one focused command, one writable claim, and one checkpoint. Split when
  it crosses more than one subsystem, needs multiple expensive matrices, mixes unresolved
  provider selection with integration, has shared-file contention, or cannot express
  success as one changed progress fingerprint.
- Keep writable concurrency at one until atomic canonical path/resource claims,
  cancellation drain, crash/expiry recovery, and deterministic merge serialization pass
  every hostile fixture. Read-only research/triage/review may be separate only with typed
  bounded handoffs.

### Human escalation and non-automation

- Human decision is mandatory for unresolved spec/plan/source conflicts; scope or command
  expansion; missing/contradictory telemetry or evidence; dependency exceptions; security,
  credential, deployment, publication, workflow-permission, merge-policy, or destructive
  actions without explicit manifest authority; and providers that cannot meet the
  recorded contract.
- Never automate policy expansion, owner exceptions, real tracker mutation, credential
  acquisition/use expansion, deployment, image/package publication, force push, generated
  fixture edits, secret/issue-content memory, self-approval, reviewer finding dismissal,
  or autonomous merge while its publisher gates remain disarmed.
- Escalation must state one exact question, the evidence conflict or missing authority,
  cited options with tradeoffs, and a recommendation; it must not mutate disputed scope.

## Open questions

- Exact local stochastic eval corpus size and baseline are not yet established.
- The correct early handoff guard band below 50% must be measured from the maximum
  observed per-invocation context increase; it must not be guessed.
- A future mechanical ceiling needs either Codex preflight utilization/reservation or a
  proven upper bound over serialized next-call input, tool results, and output growth.

## Commands and results

- Read `AGENTS.md`, `docs/upstream-lock.md`, `.codex/goals/active.json`,
  `docs/dependency-decisions.md`, `docs/engineering-system.md`,
  `docs/opensymphony-supervisor.md`, `docs/opensymphony-feature-matrix.md`,
  `docs/research/agent-model-policy.md`, `WORKFLOW.md`, supervisor policy source/header,
  and related tests. No test or mutating command was run.
- The OpenAI Docs skill helper path was unavailable (`MODULE_NOT_FOUND`); used official
  OpenAI documentation MCP search/fetch as the skill-directed fallback.

## File and resource ownership

- Sole owned write: `.codex/notepads/process-research-advisor.md`.
- All repository source, tests, docs, tracker, goal, credentials, containers, and
  publication resources remain read-only/unowned.

## Status and task list

- [x] Read governing repository documents and current policy/implementation.
- [x] Gather primary sources for all requested orchestration techniques.
- [x] Reconcile the new hard 50% owner constraint with current 50/60/65 policy.
- [x] Finalize exact measurable promotion, runtime, and escalation gates.
- [x] Persist the complete redacted handoff state in this notepad.
- [x] Prepare the concise proposal and source links for the parent handoff.

## Next bounded action

Parent integration: reconcile this recommendation with sibling research, preserving the
strict 50% enforcement gap and the currently disarmed external-supervisor boundary.
