# Tracker governance advisor notepad

## Objective

Design a project-scoped custom Codex agent that reconciles the canonical goal, repository task
references, GitHub issues and pull requests, and a sanitized Linear metadata projection. The agent
is an evidence-producing auditor: it never changes a tracker, pull request, branch, goal, plan, or
notepad. The root integration/goal owner decides how findings alter
`.codex/goals/standalone-cpp26-v2.md`.

## Authority and constraints

- This design task is read-only except for this notepad.
- Do not create, edit, close, reopen, assign, label, comment on, merge, approve, or otherwise mutate
  a GitHub or Linear object.
- Do not query, copy, summarize, hash, or persist Linear descriptions, comments, attachments, or
  other issue-body content. Accept only a controller-provided sanitized metadata projection or a
  read-only metadata query that excludes those fields.
- Do not read, print, validate, enumerate, or pass through tracker credential values. Secret
  environment names may be documented; their values are out of scope.
- Do not treat a Markdown goal/notepad, GitHub issue, Linear issue, pull request, model report, or
  exit status as authority to execute or publish work.
- Preserve the single-writer rule. The advisor returns findings to the root integration owner and
  has no repository write scope.
- OpenSymphony remains fail-closed. Tracker reconciliation cannot arm a worker, consume a canary,
  admit an image, archive tracker work, or authorize publication.
- Current source, tests, exact Git state, provider metadata, and terminal CI/review evidence outrank
  narrative status. Conflicts are surfaced rather than silently resolved.

## Sources inspected

- `AGENTS.md`
- `.codex/goals/standalone-cpp26-v2.md`
- `.codex/goals/active.json`
- `WORKFLOW.md`
- `docs/tracker-adapters.md`
- `docs/engineering-system.md`
- `.github/PULL_REQUEST_TEMPLATE.md`
- `include/symphony/tracker/tracker.hpp`
- `src/tracker/tracker.cpp`
- `tests/tracker_tests.cpp`
- Current branch, HEAD, upstream divergence, remote, and worktree state
- Read-only GitHub issue and pull-request metadata for `ray-manaloto/symphony-cpp`
- Current official Codex manual sections for subagents and custom-agent configuration

The current official Codex manual defines project agents as standalone TOML files under
`.codex/agents/`. Required fields are `name`, `description`, and `developer_instructions`; supported
session configuration keys such as `model`, `model_reasoning_effort`, and `sandbox_mode` may also
be set. Read-heavy parallel reconciliation is an intended subagent use, and the manual recommends
narrow custom agents with a matching tool surface. It also warns that subagents add token cost.

## Current reconciliation snapshot

Snapshot time: 2026-07-25, America/Chicago.

- Repository: `git@github.com:ray-manaloto/symphony-cpp.git`
- Branch: `codex/implementation`
- HEAD/upstream: `bbd773da68610e513ef2caaf45f50ef59e28c7a5`, ahead/behind `0/0`
- Existing root-owned local changes at inspection: the canonical goal and root notepad only
- GitHub pull requests: none, open or closed
- GitHub issues: five open issues, identifiers `#1` through `#5`
- Repository references establish:
  - `#1`: finalized generic toolchain-image supply-chain documentation and agent guardrails
  - `#2`: dependency-validation cache durability and pressure-aware behavior
  - `#3`: read-only compiler-artifact resolution versus opt-in publication authority
  - `#4`: generic runtime qualification and immutable devcontainer wiring
  - `#5`: compiler payload identity versus qualification identity
- The canonical goal's immediate tasks 2 through 8 do not currently have an explicit GitHub issue
  mapping in the inspected task surfaces. This is a coverage gap to report, not permission to
  create issues.
- Linear parity is unknown by design. No Linear issue body or live Linear object was queried in
  this task. `WORKFLOW.md` names one project and active-state vocabulary, but that is configuration,
  not evidence that an issue exists or is synchronized.
- The product GitHub and Linear adapters are non-networking stubs and mutation is disabled. A
  custom Codex advisor must not be confused with, or used to bypass, that product boundary.

## Recommended role

Name the role `tracker_inventory_auditor`, not “manager.” The name makes its non-mutating authority
clear.

Responsibilities:

1. Resolve exact repository, branch, HEAD, upstream divergence, dirty paths, canonical goal path,
   and the goal's current ordered checklist.
2. Read repository-owned issue/PR references and the current GitHub metadata needed to identify
   state, links, updated revision, CI/review/merge state, and duplicates.
3. Accept only sanitized Linear metadata: opaque ID, identifier, state, URL, priority, labels,
   assignee ID, blocker identifiers/states, and updated timestamp. Exclude descriptions, comments,
   attachments, and secret-bearing diagnostics.
4. Build a many-to-many mapping between goal item IDs, repository evidence paths, GitHub issue/PR
   IDs, and sanitized Linear identifiers.
5. Classify discrepancies without resolving them:
   - `untracked_goal_item`
   - `orphan_tracker_item`
   - `state_mismatch`
   - `duplicate_scope`
   - `missing_acceptance_evidence`
   - `stale_evidence`
   - `blocked_dependency`
   - `pr_without_goal_mapping`
   - `terminal_tracker_with_open_goal`
   - `open_tracker_with_completed_goal`
   - `authority_or_identity_conflict`
6. Return a compact, schema-shaped reconciliation report with evidence references, confidence,
   unresolved ambiguity, and proposed goal-order changes. It does not edit the goal.
7. Notify the root owner immediately for authority conflicts, unexpected tracker mutation,
   terminal-state mismatch, PR/HEAD mismatch, secret exposure, or evidence that OpenSymphony was
   armed while an admission gate remained closed.

Non-responsibilities:

- writing task lists, issues, PRs, comments, labels, assignments, reviews, merge settings, or goal
  files;
- deciding that work is complete from tracker state alone;
- archiving, closing, merging, publishing, deploying, or arming orchestration;
- reading issue bodies or retaining issue content;
- selecting implementation design, dismissing review findings, or assigning file/resource claims;
- polling continuously in a model thread.

## Trigger conditions and scheduling

Run the advisor at bounded reconciliation points:

- at fresh-session/bootstrap reconciliation;
- after a coherent checkpoint changes canonical goal status or ordering;
- after a commit, push, PR open/update/close/merge, or terminal CI/review result;
- when a GitHub or sanitized Linear metadata event changes state, blockers, or updated revision;
- before selecting the next atomic implementation slice;
- before guarded publication or autonomous merge admission;
- at context rollover before the root handoff is finalized;
- on an explicit owner request for task/tracker status.

Do not keep a model agent resident or use it as a poller. A deterministic event source or scheduled
automation should collect provider metadata and invoke one bounded reconciliation. Debounce multiple
events for the same repository revision; identical input fingerprints produce no new report.

## Inputs

Required:

- canonical repository URL, worktree, branch, base/head SHA, upstream SHA, and dirty-path digest;
- canonical goal path and digest plus stable goal-item IDs;
- repository-owned mappings or references to issues/PRs;
- GitHub repository identity and read-only issue/PR/check metadata snapshot;
- sanitized Linear metadata snapshot or explicit `unavailable/not_authorized/not_configured` status;
- prior reconciliation report digest;
- authority policy, terminal/active state sets, and current time;
- current task packet/checkpoint/review evidence IDs when those schemas exist.

Rejected:

- issue descriptions, comments, prompts, transcripts, environment values, credentials, hidden
  reasoning, unbounded logs, mutable “latest” references, or provider data without repository and
  retrieval identity.

## Output schema

Use a future `TrackerReconciliationReportV1` record:

```text
schema_version
report_id
generated_at
agent_role
model
effort
repository_url
worktree
branch
base_sha
head_sha
upstream_sha
ahead_count
behind_count
dirty_path_digest
goal_path
goal_digest
goal_updated_at
input_fingerprint
previous_report_digest
provider_snapshots[] {
  provider
  repository_or_project_id
  retrieval_status
  retrieved_at
  snapshot_revision
  item_count
  redaction_policy_id
}
items[] {
  canonical_task_id
  parent_task_id
  goal_state
  acceptance_evidence_ids[]
  github_issue_numbers[]
  github_pr_numbers[]
  linear_identifiers[]
  provider_states[]
  blocker_identifiers[]
  last_provider_update_at
  mapping_source_paths[]
  mapping_confidence
}
discrepancies[] {
  discrepancy_id
  kind
  severity
  affected_task_ids[]
  affected_provider_refs[]
  evidence_refs[]
  observed
  expected
  proposed_root_action
  requires_human_decision
}
proposed_goal_changes[] {
  operation
  target_task_id
  proposed_state_or_position
  justification
  evidence_refs[]
}
authority_alerts[]
unresolved_ambiguities[]
next_reconciliation_trigger
terminal_result
```

The report must not contain issue titles/bodies or credential-derived text in durable logs. It may
show opaque provider identifiers, URLs, states, labels, timestamps, and repository evidence paths.
The root owner should render any human-facing title transiently from an authorized provider view
rather than persist it in the agent notepad.

Terminal results:

- `in_sync`: no discrepancy and the input fingerprint changed or was independently refreshed;
- `no_change`: exact input fingerprint matches the previous report;
- `findings`: one or more non-authority discrepancies;
- `blocked`: required evidence is absent, malformed, stale, or identity-inconsistent;
- `authority_alert`: mutation or authority-boundary evidence requires immediate root/human review.

## Conflict and escalation rules

- Git commit/test/review evidence conflicts with a tracker state: do not choose either silently;
  report the exact mismatch. Code is not complete without required evidence, and a terminal tracker
  state does not override that gate.
- Goal and provider scope differ: propose a mapping or split, but do not modify either surface.
- GitHub and Linear appear to describe the same task without an authoritative mapping: mark
  `duplicate_scope` with `mapping_confidence=unconfirmed`; require root reconciliation.
- A provider item is terminal while required goal work is open: block completion and request root
  review. Never reopen it.
- Goal work is complete while provider metadata is open: propose a mutation packet for later
  approval; never close it.
- PR head/base/SHA or review evidence is stale: block merge admission and report exact identifiers.
- Provider access is missing: return `blocked` for that provider; do not infer parity from the other
  provider.
- Issue content or credentials appear in input/output: stop, redact the durable report, and raise an
  authority alert.
- Any proposed task creation, state change, comment, assignment, label, review, merge, or closure
  is handed off as a separate mutation proposal with the complete intended operation and evidence.

## Model and effort

Use `gpt-5.6-sol` / `high`.

Reason: the role is read-heavy, but reconciliation crosses goal hierarchy, two provider state
models, Git/PR/review evidence, duplicate detection, and authority boundaries. It needs more than a
fast metadata scan. Use Terra/medium only for a deterministic single-provider inventory refresh
whose mappings already exist; use Sol/xhigh only after an actual cross-provider identity conflict
or ambiguous state transition survives one high-effort pass. Credential, permission, availability,
or missing-evidence failures pause and never raise effort.

The role follows the canonical 45/50/55 policy, preserves issue-wide budgets across rollover, and
returns `blocked` rather than estimating missing context telemetry.

## Proposed project custom-agent TOML

Supported Codex custom-agent fields only:

```toml
name = "tracker_inventory_auditor"
description = "Read-only project task and tracker reconciler. Use at checkpoints, provider state changes, before selecting work, and before publication or merge admission."
model = "gpt-5.6-sol"
model_reasoning_effort = "high"
sandbox_mode = "read-only"
developer_instructions = """
Reconcile the canonical standalone C++26 goal with exact Git state, repository evidence, GitHub
issue/PR/check metadata, and only a sanitized Linear metadata projection.

Read AGENTS.md, .codex/goals/standalone-cpp26-v2.md, WORKFLOW.md,
docs/tracker-adapters.md, and docs/engineering-system.md before reporting. Treat the goal as the
root owner's evolving checklist, never as a write lease. Resolve repository, branch, HEAD, upstream
divergence, dirty-path digest, goal digest, and provider snapshot identities.

Operate read-only. Never create, edit, close, reopen, assign, label, comment, approve, merge, arm,
publish, or otherwise mutate a tracker, pull request, repository, goal, plan, or notepad. Never
read or retain Linear descriptions, comments, attachments, secrets, prompts, transcripts, hidden
reasoning, or unbounded logs. Never inspect credential values.

Map stable goal item IDs to repository evidence and opaque GitHub/Linear identifiers. Classify
untracked work, orphan items, state mismatches, duplicate scope, missing or stale evidence,
blockers, PR/goal mapping gaps, and authority conflicts. Return one compact
TrackerReconciliationReportV1-shaped result with evidence paths, confidence, proposed root-owner
actions, unresolved ambiguity, and the next trigger. Do not apply proposed changes.

Tracker state alone never proves implementation completion. Exact commit-bound tests and required
independent reviews remain mandatory. Missing provider access or stale/malformed identity blocks
that portion of reconciliation; never infer parity. Unexpected mutation, credential exposure,
terminal-state conflicts, stale merge evidence, or OpenSymphony activation while admission is
closed is an immediate authority alert.

Follow the project 45/50/55 context policy. Do not add scope at 50 percent; authorize no next turn
at or above 55 percent; pause on missing or stale telemetry; after compaction return a durable
handoff for a fresh session. Do not poll continuously. Identical input fingerprints return
no_change.
"""
```

Do not add tracker MCP credentials or mutation-capable tool configuration to this agent file.
Omitting MCP configuration lets the parent/controller supply an explicitly authorized read-only
snapshot. A sandbox setting does not constrain remote connector mutations by itself, so the
instruction and tool-routing layer must both deny mutating calls.

## Mutation-agent recommendation

Keep all tracker and PR mutation in a separate approval-gated agent or deterministic publisher.
Do not add mutation authority to `tracker_inventory_auditor`.

Recommended future flow:

```text
read-only snapshot
  -> tracker_inventory_auditor report
  -> root owner disposition
  -> exact TrackerMutationProposalV1
  -> human approval or pre-authorized deterministic policy gate
  -> least-privilege mutation executor
  -> read-after-write verification
  -> fresh read-only reconciliation
```

The mutation proposal should include provider/repository identity, exact object ID and expected
revision, one operation, complete intended payload, justification/evidence IDs, required approval,
idempotency key, expiry, rollback/recovery plan, and postcondition query. The executor should
receive no broader credential or action scope than that one operation. Autonomous merging remains
a separate publisher path because its app credential, review/SHA gates, and blast radius differ
from issue-state updates.

## Suggested adjacent roles and orchestration tweaks

- `goal_synthesis_planner` (read-only, Sol/high): consumes bounded specialist reports and proposes
  goal ordering; only the root owner edits the goal.
- `documentation_drift_auditor` (read-only, Sol/high): maps code/config/tests to canonical docs and
  reports exact stale claims.
- `dependency_reuse_researcher` (read-only, Sol/xhigh for cross-subsystem selection): runs the
  dependency-first process and compares maintained libraries/tools/services/plugins before custom
  work.
- `codex_capability_watch` (read-only, Terra/medium for routine scans, Sol/high for synthesis):
  checks the current official Codex manual/changelog and installed capabilities without changing
  settings.
- Keep CI watching deterministic and single-run through the existing `gh-watch-run` skill rather
  than a standing model agent.
- Limit recurring advisors to event-driven bounded reports. Let one root synthesis pass consume
  their schema-shaped outputs; avoid agents recursively editing the plan or one another's reports.
- Add stable goal item IDs before automated reconciliation. Ordered Markdown numbers are not stable
  identity when priorities change.
- Validate future reports against a versioned schema before using them for planning. The report is
  recovery/reconciliation evidence, never controller authority.

## Status

- [x] Read all assigned governing and repository files.
- [x] Verified the supported current custom-agent TOML surface from the official Codex manual.
- [x] Reconciled current Git/remote state and read-only GitHub issue/PR metadata.
- [x] Preserved Linear body/content and credential boundaries; no Linear query was performed.
- [x] Defined responsibilities, triggers, inputs, outputs, schema fields, model/effort, conflict
      rules, and root-owner synthesis.
- [x] Recommended a separate approval-gated mutation/publisher lane.
- [x] Wrote only this notepad.

## Next bounded action

The root integration owner should synthesize this proposal with the documentation, dependency, and
Codex-capability advisor reports. If accepted, first add stable goal item IDs and a
schema-validated read-only reconciliation fixture; only then add
`.codex/agents/tracker-inventory-auditor.toml` in its own reviewed policy slice.
