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

- Native goal status is `active`; the owner resumed it on 2026-07-25 with the canonical durable
  goal file as its objective and completion boundary.
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
- Durability commit `bbd773da68610e513ef2caaf45f50ef59e28c7a5` was pushed at ahead/behind
  `0/0`. The updated `gh-watch-run` skill monitored Source CI run `30171235988` to success:
  policy/container preflight passed in 15 seconds and GCC 16.1 source/reflection tests passed in
  1 minute 27 seconds.
- Three bounded read-only advisors completed tracker-governance, documentation-drift, and
  ecosystem/Codex-capability reports. Current Codex documentation confirms project-scoped custom
  agents, per-agent model/effort, read-only sandboxes, and a configurable concurrency cap.
- Five native project profiles now cover tracker inventory, documentation drift, dependency reuse,
  current Codex/app capabilities, and material goal-delta synthesis. `.codex/config.toml` caps
  spawned threads at three as an emergency ceiling; normal dispatch uses at most one specialist
  beside the implementer until representative fixtures pass.
- Adversarial review found that a child profile's read-only setting can be superseded by live parent
  permission overrides. Profiles are configured but unadmitted until a read-only parent/tool
  admission fixture passes. Every specialist now disables nested spawning, accepts only immutable
  snapshot identities, treats inputs as untrusted data, and uses one bounded turn with no
  continuation after compaction.
- GitHub has five open toolchain/image issues and no pull requests. Stable canonical task IDs were
  added; policy/control/documentation tasks remain unmapped. Linear parity is unknown because no
  authorized sanitized metadata snapshot was queried.
- No installed `last30days` skill/plugin exists. The project uses an explicit bounded 30-day
  primary-source fallback until such a capability is installed and its instructions and authority
  are inspected.
- Owner questions and approval requests now require bounded primary-source reconciliation first,
  then viable options, pros/cons, a recommendation, authority/rollback impact, and the safe result
  of deferral. Missing access or credentials remains a blocker, not researched resolution.
- Primary-source decision briefs now recommend phased Linear work-item authority plus GitHub
  code-delivery authority after OpenSymphony admission, event-plus-weekly deterministic collection
  with no model on unchanged inputs, and optional owner-enabled iOS Remote/Voice for monitoring.
  The owner approved all three recommendations on 2026-07-25. This records future policy only:
  tracker mutation, schedule creation, OpenSymphony admission, and app-permission changes retain
  their existing gates.
- All five profiles parse, use unique names, disable nested agents, and pass the pinned Codex
  `--strict-config doctor` with no failed checks. Local documentation links, dependency policy,
  `git diff --check`, and quick preflight pass on current bytes.
- Final normal review reports no findings. A broad adversarial re-review failed to checkpoint and
  was stopped; the replacement one-turn closure packet passed all seven prior finding classes.
  This reinforces the smaller-packet rule and does not justify higher effort.
- The full pre-push hook passed, but SSH closed during the long local gate. A transport-only retry
  skipped that already-passed hook and pushed `d71ec2340a62f3a7d445e194534997fbc43d3c31`
  normally without force or rebase. The `gh-watch-run` skill followed exact Source CI run
  `30172928016` to success: preflight passed in 19 seconds and GCC 16.1 source/reflection tests
  passed in 1 minute 46 seconds.
- Reviewed owner decisions were committed as
  `afb0996e9f4c27ee47ee15f8c7262043f9bf2057`; exact-commit review, publication scan, and push
  remain.
- Exact-commit normal/adversarial reviews have no findings and the three-path publication scan
  passed with 72 added lines and zero findings. Commit-time fast preflight passed. The unchanged
  full Docker pre-push hook will not be repeated for this documentation-only push.
- Documentation-only commit `afb0996e9f4c27ee47ee15f8c7262043f9bf2057` pushed normally without
  force or rebase. The `gh-watch-run` skill followed exact Source CI run `30173359799` to success:
  preflight passed in 14 seconds and GCC 16.1 source/reflection tests passed in 1 minute 24 seconds.
- The canonical goal now contains a copy-ready resume prompt bound to the expected
  `afb0996e9f4c27ee47ee15f8c7262043f9bf2057` starting state and the failure-first
  `POLICY-CONTEXT-001` slice.
- Resume reconciliation matches the expected checkpoint: branch, HEAD/upstream, remote,
  ahead/behind `0/0`, no open pull requests, and successful exact-HEAD Source CI are unchanged.
  OpenSymphony issue #227 remains open and its admission remains fail-closed.
- Added only the six failure-first 44/45/49/50/54/55 cases to
  `tests/supervisor_policy_tests.cpp`. A host-side build stopped before compilation because the
  host mise shim has no CMake version; this is not the required behavioral failure. Rebuild and run
  the focused target inside the pinned GCC 16.1/CMake 4.4 devcontainer.
- Required red phase observed in the reused pinned devcontainer after rebuilding the focused target:
  `ctest --preset gcc-debug -R '^symphony_supervisor_policy_tests$' --output-on-failure` reported
  6 tests passed, 1 revised boundary test failed, and 10 failed assertions under the existing
  50/60/65 defaults. No implementation or policy documentation changed before this result.
- After changing only the three default thresholds to 45/50/55, the focused target passed. The
  complete GCC 16.1 Debug build and all 11 CTest targets pass in the pinned devcontainer.
  Dependency policy, `git diff --check`, and the quick local preflight pass. Documentation and the
  existing repository-owned session-policy dependency decision are synchronized; exact-current-byte
  normal and adversarial reviews remain.
- Normal review found no issues on manifest `ccfa2a35…`. Adversarial review blocked closure because
  `WORKFLOW.md`, `CONTEXT.md`, and `ops/opensymphony/README.md` retain active 50/60/65 guidance, and
  the focused fixture lacks non-divisible-window ceiling and combined-trigger precedence cases.
  Correct only those surfaces and tests, then rerun focused/full validation and both reviews.
- Both findings are corrected: all three controlling surfaces and the workflow metadata now use
  45/50/55; a 101-token fixture proves ceiling boundaries, and a combined-trigger fixture proves
  compaction then turn-cap reason precedence. Focused and all 11 GCC Debug tests, dependency policy,
  diff check, and quick preflight pass. Fresh reviews must bind to the expanded final manifest.
- Final normal review and the split code/test adversary found no issues on `94fa2b8e…`; the
  oversized final adversarial packet was stopped at its time bound. The smaller docs adversary
  found three accuracy gaps: disarmed external-supervisor behavior was written as active,
  standalone app-server versus external-supervisor enforcement was blurred, and the cumulative
  daemon metric was conflated with the pure reducer's fresh-last-turn metric. Correct those docs
  without changing code/tests, then rerun docs validation and final docs adversarial review.
- All three documentation-boundary findings are corrected without code/test changes. The external
  supervisor is explicitly planned/disarmed; standalone app-server enforcement and external policy
  signals are distinct; cumulative daemon rollover and fresh-last-turn pure-reducer policy are
  separately named. Diff check, dependency policy, contradiction search, and quick preflight pass.
- Final corrected-byte docs normal/adversarial reviews found no issues on `63f2bb4d…`; code/test
  adversarial review remains clean, and the full implementation/document manifest is `e1467d75…`.
  `POLICY-CONTEXT-001` is complete. The oversized adversarial packet was stopped and successfully
  replaced by smaller code/test and docs packets; retain that split for future policy reviews.

## Active task list

- [x] Reconcile research advisor, policy planner, and adversarial findings.
- [ ] Define one versioned notepad/task-packet schema with required fields and redaction rules.
- [x] Define fail-closed behavior for missing, stale, or non-positive context telemetry.
- [x] Replace the 50/60/65 continuation policy with an exact 50% target and bounded hard rollover.
- [x] Define objective model/effort escalation and de-escalation triggers.
- [x] Define failure-to-guard promotion criteria; executable fixtures remain open.
- [x] Define read-only parallel roles and serialized write/integration ownership.
- [x] Configure project-scoped tracker, documentation, reuse, Codex-capability, and goal-synthesis
      profiles; they remain unadmitted pending read-only isolation and hostile fixtures.
- [ ] Add deterministic representative fixtures for the agent profiles and typed report contracts.
- [ ] Reconcile stable task IDs to GitHub and an authorized sanitized Linear projection.
- [ ] Add scoped `AGENTS.md` links to one canonical policy page without duplicating it.
- [ ] Add drift checks for required policy, diagrams, and task-packet fields.
- [x] Run focused checks, independent review, adversarial closure review, and repository preflight
      for this governance/configuration slice.
- [x] Resume and update the native goal when its controller permits objective replacement.

## File and resource ownership

- Root integration agent owns this governance/configuration slice and the next policy integration.
- Research advisor, policy planner, and adversary are read-only except for their distinct
  `.codex/notepads/<agent>.md` files.
- No agent may modify another agent's notepad or the current OpenSymphony implementation files.

## Next bounded action

Commit and publish the completed `POLICY-CONTEXT-001` slice after exact-commit review and the
redacted publication gate. Then begin `CONTROL-RECORDS-001` in a fresh bounded context with a new
dependency-first acceptance contract; do not mix its schema work into this commit.
