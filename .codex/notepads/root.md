# Root orchestration notepad

## Objective

Make the native goal and repository engineering system use explicit, independently verifiable
task slices, evidence-driven self-improvement, specialized planning/review roles, adaptive
model/effort selection, and clean-context rollover targeted at 50% reported context with a small,
explicitly bounded overrun allowance.

Canonical durable goal checklist:
`.codex/goals/standalone-cpp26.md`.

## Authority and constraints

- OpenAI Symphony Draft v1 and current repository source/tests remain authoritative.
- GCC 16.1 defines executable semantics; clang-p2996 is differential-only.
- OpenSymphony v2.10.0 remains fail-closed and cannot become the controller until its unchanged
  mandatory suite produces an admitted image and contained doctor/dry-run gates pass.
- Never estimate context utilization when positive, fresh telemetry is unavailable.
- The owner clarified that 50% is guidance rather than an instantaneous hard ceiling. The active
  conservative policy is checkpoint/notepad at 45%, target handoff at 50%, and no next model turn
  at or above 55%; the owner may explicitly supersede that five-point allowance.
- Self-learning means reviewed external artifacts, regression guards, skills, and checklists; it
  does not mean hidden prompt mutation, model-weight updates, or expanded authority.
- No secret values, issue contents, prompts, or hidden reasoning belong in this notepad.

## Current evidence

- Native goal status is `blocked`; the goal API rejected replacement because the existing goal is
  unfinished. User-controlled resume is required before its objective can be replaced.
- Contained `memory-status` failed closed because no qualified OpenSymphony image is present.
- The current OpenSymphony diagnostic candidate is local-only and unqualified.
- The unchanged v2.10.0 suite passed 848 library tests and reproduced upstream issue #227 in the
  memory integration suite, so no `upstream-tests=passed` image exists.
- `docs/engineering-system.md`, `docs/research/agent-model-policy.md`, and
  `docs/opensymphony-supervisor.md` currently specify 50% checkpoint, 60% handoff, and 65% rollover;
  source and documentation still need reconciliation to the active canonical 45/50/55 policy.
- Official Codex guidance supports bounded specialized subagents, small high-signal context,
  durable `AGENTS.md` guidance after repeated mistakes, explicit model/effort per custom agent,
  and independent review. It does not document a parent-visible universal context meter for every
  subagent.
- Independent planner and adversarial review agree that post-turn telemetry can enforce a
  between-call admission ceiling. The canonical goal defines the five-point allowance beyond the
  50% target; source and documentation have not implemented it yet.
- The adversarial review found that narrative `summary`/`current_step` values currently influence
  progress fingerprints and volatile raw error text can evade recurrence grouping. These require
  separate failure-first implementation slices before broader autonomy.
- The dependency-first candidate for interim notepad validation is the already pinned
  `check-jsonschema` tool plus a versioned structured record. Free-form Markdown is only a
  temporary recovery aid and never an authority record or write lease.
- The first exact-diff normal-review packet covered both runtime and documentation paths and did
  not produce the requested bounded checkpoint after repeated waits. The integration owner
  interrupted it and narrowed the restarted review to runtime code/tests; evidence documentation
  remains a separate specialist lane. Future review packets must split runtime and narrative
  surfaces before dispatch rather than relying on higher effort to absorb both.
- The narrowed restart still failed to checkpoint, as did the parallel adversarial and evidence
  packets. All three were stopped. Replacement packets are limited respectively to four
  build/Bake files, three launcher/test files and five named attack classes, and four evidence
  documents with six fixed facts. This is an orchestration packet-sizing defect, not evidence that
  more model effort is warranted.
- Fresh bounded review produced two actionable findings. The launcher inherited
  `GCC16_ARTIFACT_CONTEXT` into its expected admission digest; it now removes that variable and a
  hostile fixture proves an alternate valid digest cannot be selected. The Bake graph test now
  passes its explicit GCC context into the digest helper. Both affected focused tests, shell
  syntax, and `git diff --check` pass.
- The dirty-build provenance concern does not require a whole-worktree cleanliness gate. The
  image-specific context plus the build-input allowlist covers every local input used by this
  selected graph, and `docs/implementation-log.md` explicitly calls the Git revision label
  informational. The exact input digest is the admission identity; coupling local-only image work
  to unrelated dirty files would weaken containment.
- Fresh exact-current launcher, Bake, and evidence reviews report no findings after the fixes.
  The full quick preflight, dependency policy, launcher and Bake tests, shell syntax, and
  `git diff --check` all pass on the reviewed bytes. No `.codex/**` artifact is part of the
  safety-slice review or intended commit.
- The exact 19-path reviewed slice was committed as
  `0713d1662c29bb003e443924843265f3ba2f06e8`; the publication scan against parent
  `4f61da38afcf32fd89e3ee01a8f1dc13a85d904d` passed with 828 added lines and zero redacted
  findings. Only `.codex/**` goal/notepad recovery artifacts remain untracked.
- The full Docker-enabled pre-push suite passed. The push then skipped only the duplicate hook
  invocation and succeeded normally without force or rebase. Local HEAD, upstream, and
  `origin/codex/implementation` are identical at
  `0713d1662c29bb003e443924843265f3ba2f06e8` with ahead/behind `0/0`.
- GitHub Source CI run `30170305498` completed successfully for the exact pushed SHA.

## Active task list

- [x] Reconcile research advisor, policy planner, and adversarial findings.
- [ ] Define one versioned notepad/task-packet schema with required fields and redaction rules.
- [ ] Define fail-closed behavior for missing, stale, or non-positive context telemetry.
- [ ] Replace the 50/60/65 continuation policy with an exact 50% target and bounded hard rollover.
- [x] Define objective model/effort escalation and de-escalation triggers.
- [x] Define failure-to-guard promotion criteria; executable fixtures remain open.
- [x] Define read-only parallel roles and serialized write/integration ownership.
- [ ] Add scoped `AGENTS.md` links to one canonical policy page without duplicating it.
- [ ] Add drift checks for required policy, diagrams, and task-packet fields.
- [ ] Run focused checks, independent review, adversarial review, and repository preflight.
- [ ] Resume and update the native goal when its controller permits objective replacement.

## File and resource ownership

- Root integration agent owns the current dirty OpenSymphony safety slice and any eventual policy
  integration.
- Research advisor, policy planner, and adversary are read-only except for their distinct
  `.codex/notepads/<agent>.md` files.
- No agent may modify another agent's notepad or the current OpenSymphony implementation files.

## Next bounded action

Keep the dirty OpenSymphony image/launcher hardening work as the only current implementation slice.
Review and version this goal plus redacted recovery notepads as a durability-only commit. Then add
failing 44/45/49/50/54/55 default-boundary cases to `tests/supervisor_policy_tests.cpp`, with
initial write scope limited to that test plus `include/symphony/supervisor/policy.hpp` and
`src/supervisor/policy.cpp`. First prove the existing 50/60/65 defaults fail the new expectation
using `ctest --preset gcc-debug -R '^symphony_supervisor_policy_tests$' --output-on-failure`.
