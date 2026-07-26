# Orchestration policy planner notepad

> Historical specialist evidence, not current policy. Its strict-50 recommendation was superseded
> by the owner's clarification that 50% is guidance and the canonical goal's 45/50/55 policy.
> Follow `.codex/goals/standalone-cpp26-v2.md` for the active writable slice and next command.

## Objective

Design a durable, unit-testable, small-slice orchestration contract for planner, executor, normal
reviewer, and adversarial reviewer roles. Preserve the OpenSymphony fail-closed boundary and define
the exact repository artifacts and tests that should eventually implement the contract.

## Constraints

- This subtask is read-only except for this notepad.
- Do not mutate trackers, credentials, branches, commits, or the existing dirty worktree.
- GCC 16.1 defines executable semantics; clang-p2996 remains differential-only.
- OpenSymphony v2.10.0 stays a pinned external scheduler; the local C++ supervisor is a guard, not a
  replacement controller or deployed-service component.
- No writable concurrency above one until atomic file/resource claims, canonicalization,
  cancellation drain, recovery, and integration fixtures pass.
- Every agent must make a verified durable handoff and roll over before 50% reported context use.
- Missing, stale, inconsistent, or cumulative-only context telemetry pauses; never estimate.
- Do not log prompts, issue content, secrets, credentials, or hidden reasoning.

## Inspected files and evidence

- `AGENTS.md`
- `CONTEXT.md`
- `WORKFLOW.md`
- `.codex/goals/active.json`
- `docs/upstream-lock.md`
- `docs/architecture.md`
- `docs/engineering-system.md`
- `docs/opensymphony-supervisor.md`
- `docs/research/agent-model-policy.md`
- `docs/dependency-decisions.md`
- `docs/implementation-log.md`
- `docs/opensymphony-feature-matrix.md`
- `docs/conformance.md`
- `docs/cross-project-coordination.md`
- `docs/tracker-adapters.md`
- `ops/opensymphony/README.md`
- `include/symphony/domain/domain.hpp`
- `include/symphony/supervisor/policy.hpp`
- `src/supervisor/policy.cpp`
- `src/scheduler/scheduler.cpp`
- `include/symphony/persistence/event_store.hpp`
- `src/persistence/event_store.cpp`
- `tests/supervisor_policy_tests.cpp`
- `tests/scheduler_tests.cpp`
- `tests/persistence_tests.cpp`
- `tests/CMakeLists.txt`
- `src/CMakeLists.txt`
- `scripts/check-adaptive-orchestration.mjs`
- Current `git status`, diff names/stat, all modified-file diffs, and all three untracked files.

Contained OpenSymphony memory status was unavailable because no qualified local image is present.
Private memory therefore supplied no planning facts; current source, tests, and tracked docs remain
the evidence authority.

The dirty worktree is an orthogonal OpenSymphony image/launcher hardening slice. It modifies
`WORKFLOW.md`, container composition, OpenSymphony launch/acceptance scripts, dependency and
implementation ledgers, and related docs; it does not modify the supervisor policy source/tests.

## Proposed task packet and evidence schemas

Use a controller-issued, immutable `TaskPacketV1` plus separate result/checkpoint/review records.
Authority must never be inferred from prose.

`TaskPacketV1`:

- identity: schema version, packet ID, issue ID/identifier, repository URL, base SHA, plan/spec
  digests, created-at, expiry;
- role: planner, executor, reviewer, or adversarial reviewer;
- objective: one observable contract, acceptance boundary, one atomic action, split/stop conditions;
- authority: read-only flag, allowed/denied canonical paths, serialized shared paths, tracker and
  publication permissions fixed false unless separately authorized;
- claims: repository/worktree/branch identities and exclusive file/resource keys;
- dependency gate: decision status, selected provider/seam, decision-record reference;
- failure-first evidence: fixture/reproduction ID, exact focused command, expected initial outcome;
- acceptance requirements: command, cwd, expected exit, artifact path/digest rules, toolchain and
  commit binding;
- risk/review policy: risk triggers, required review kinds, independence requirements;
- execution budget: turn/session/deadline/no-progress/repeated-failure limits;
- model route: preapproved model/effort and deterministic reason;
- checkpoint policy: notepad path/schema, context telemetry source, pre-50 thresholds, next owner.

`TaskResultV1`:

- packet ID and immutable packet digest;
- role/actor/session IDs and role-history digest;
- base/head SHA, changed-path digest, progress fingerprint;
- exact command results with exit status, toolchain/environment identity, bounded redacted log
  digest, and output artifact digests;
- failure signature/family/recurrence, correction and guard reference;
- files/resources touched, unresolved risks/blockers, next bounded action and owner;
- checkpoint/notepad digest and terminal reason.

`ReviewAttestationV1`:

- review kind, reviewer identity/session, independence facts, reviewed exact SHA and diff digest;
- finding IDs, severity, file/line evidence, dispositions, rerun evidence IDs;
- pass only with zero unresolved findings and fresh required checks;
- any reviewed-path byte change invalidates the attestation.

`TaskNotepadV1`:

- schema version, task/packet ID, objective, constraints;
- decisions with evidence references;
- exact commands and redacted results;
- canonical file/resource ownership;
- progress fingerprint, failure family/signature/count;
- blockers and unresolved risks;
- current role/model/effort/turn/session plus last-input/window telemetry and compaction count;
- task-list items with state;
- next bounded action and next owner;
- base/head SHA, created-at, updated-at, and content digest.

## Proposed policy gates

- Planner: verify normative inputs and current repository state; create one-contract packet; split
  cross-subsystem work; select dependency seam; define a failing fixture, exact acceptance evidence,
  claims, risk triggers, and stop conditions. No implementation authority.
- Executor: validate packet/digest/base/claims; add the failing fixture first; implement one slice;
  run focused then required integrated checks; produce a commit-bound result and updated notepad.
- Reviewer: independent read-only review of the complete exact-SHA diff for spec/plan,
  dependency-first, correctness, tests, redaction, and evidence freshness. Return findings only.
- Adversarial reviewer: separate read-only attestation for hostile, malformed, race, crash, replay,
  stale-evidence, and authority-boundary cases selected by risk trigger. Return findings only.
- Corrections invalidate prior attestations; normal review repeats after any reviewed-path byte
  change, and required adversarial review also rebinds to the corrected SHA.
- First failure records the smallest fixture and guard. Second same-family occurrence within 30
  days promotes a deterministic guard with owner and deletion trigger. A third matching occurrence
  stops automatic retries and enters bounded source/plan/spec/upstream reconciliation; Human Review
  occurs only for remaining material ambiguity or missing authority.
- Operational two-consecutive no-progress/repeated-signature limits remain stricter than the
  30-day learning count: execution pauses before a third blind attempt.
- Writable lanes remain one. Read-only planner/reviewer/triage lanes may overlap only with immutable
  inputs and no resource ownership. Canonical path or shared-resource overlap pauses/repartitions.
- Expired/crashed claims are quarantined, never stolen; integration conflicts abort and repartition;
  cancellation drains before release; final checks run on the integrated SHA.

## Pre-50 context policy and reconciliation

The current reducer decides only after a completed turn. Merely changing `65` to `45` would not
prove the hard owner ceiling: a turn can begin below 45% and report at or above 50% when it ends.
The executable admission rule must therefore include bounded headroom for the next invocation.

Proposed tiers for every model-backed role:

- below 35%: normal bounded work;
- at 35%: persist and verify `TaskNotepadV1` after the current coherent action; add no scope;
- at 40%: finish only the current atomic action, commit when code-bearing, persist the handoff, and
  authorize no further substantive action;
- deny the next turn whenever `last_input_tokens + proven_next_turn_reservation` is greater than or
  equal to 50% of the positive reported window; only a reservation derived from bounded serialized
  input, tool-result, and output limits is admissible;
- a provisional 45% observed rollover target may be used only after fixtures prove the remaining
  5% headroom bounds every admitted turn; until then percentage-based continuation stays disarmed;
- any compaction: same hard rollover after the completed turn;
- absent, stale, inconsistent, cumulative-only, or non-positive-window telemetry: pause immediately;
  do not continue, estimate, or mint a handoff as verified.

The hard ceiling is exclusive: a decision that cannot prove the next turn remains below 50% is a
rollover/pause decision. This replaces every current 50/60/65 operational default. Historical
implementation-log entries mentioning 70% or 50/60/70 remain append-only history and should receive
a new superseding entry, not edits.

## Exact future repository artifacts and tests

- Extend `include/symphony/supervisor/policy.hpp` and `src/supervisor/policy.cpp` with pure role,
  packet-admission, evidence-gating, failure recurrence, model-route, and checkpoint decisions.
- Add `include/symphony/supervisor/task_packet.hpp` and `src/supervisor/task_packet.cpp` for durable
  versioned DTO validation and Glaze JSON codec/schema. Keep transport and tracker mutation out.
- Add `include/symphony/supervisor/journal.hpp` and `src/supervisor/journal.cpp` only after the
  existing SQLite/event-store seam is evaluated for exact atomic checkpoint/claim needs; persist
  packets, results, claims, reviews, notepad digests, and transitions transactionally.
- Add `ops/opensymphony/supervisor/policy-v1.json` as the one canonical operational policy and
  `ops/opensymphony/supervisor/schemas/{task-packet-v1,task-result-v1,review-attestation-v1,task-notepad-v1}.schema.json`.
  Future machine-validated runtime notepads live at `.codex/notepads/<task-id>.json`; current
  role-specific Markdown notepads are transitional handoff records and never grant authority.
- Add `tests/supervisor_task_packet_tests.cpp`,
  `tests/supervisor_evidence_tests.cpp`, `tests/supervisor_claim_tests.cpp`,
  `tests/supervisor_notepad_tests.cpp`, and extend `tests/supervisor_policy_tests.cpp`.
- Do not add another Node build tool. Reuse pinned `check-jsonschema` for JSON-schema fixture
  validation and add a focused C++ policy-contract test that loads the canonical policy,
  `WORKFLOW.md`, notepad fixtures, and supervisor defaults through the selected Glaze seams.
  Documentation should link the canonical policy ID rather than duplicate operational numbers.
- Register focused CTest targets in `tests/CMakeLists.txt` and sources in `src/CMakeLists.txt`.
- Update `docs/engineering-system.md`, `docs/opensymphony-supervisor.md`,
  `docs/research/agent-model-policy.md`, `CONTEXT.md`, `WORKFLOW.md`,
  `ops/opensymphony/README.md`, `docs/dependency-decisions.md`, and append a superseding
  `docs/implementation-log.md` entry in the same reviewed policy slice.

Required hostile fixtures include unknown schema fields/versions, missing required fields,
untrusted absolute or symlink-aliased paths, claim intersections, shared-resource collisions,
expired/crashed claims, stale packet/base/review/notepad digests, dirty or out-of-scope checkpoints,
reviewer role-history conflicts, unresolved findings, missing/rerun evidence, malformed telemetry,
34/35/39/40/44/45/49/50% boundaries, threshold-crossing turns, insufficient next-turn headroom,
reservation overflow, compaction, restart counter persistence, and any policy-surface drift.

## Open questions

- The exact tracked location for per-task notepads must balance durability with avoiding issue
  content in Git. The proposed schema plus task-local runtime JSON is safe only if runtime notepads
  remain redacted and are not treated as authority.
- A dependency-first review is still required before adding a new schema-validation/drift script;
  Glaze, pinned `check-jsonschema`, and the existing SQLite/stdexec seams should remain the
  preferred providers.
- The external supervisor process remains disarmed until packet, notepad, telemetry, persistence,
  cancellation/reap, and hostile restart fixtures all pass.

## Status and task list

- [x] Read repository guidance, upstream lock, orchestration/engineering docs, source, tests, and
  current git state/diff.
- [x] Consult project-local OpenSymphony memory status and record its unavailable state.
- [x] Identify current pure-policy coverage and the disarmed external-process boundary.
- [x] Design role checklist, task/evidence schemas, failure loop, claims, model routing, and context
  checkpoints.
- [x] Reconcile the new hard-before-50 owner constraint with current 50/60/65 and historical
  50/60/70 text.
- [x] Deliver the evidence-backed read-only design to the parent agent.

## Next bounded action

Parent integration should reconcile this proposal with the independent research and adversarial
notepads, then introduce the smallest failing policy fixture before changing canonical policy.
Make no other repository changes from this lane.
