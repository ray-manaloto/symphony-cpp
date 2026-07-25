# Standalone C++26 Symphony implementation goal

Updated: 2026-07-25

This is the durable, human-readable mirror of the native Codex `/goal`. It is a task checklist and
handoff record, not a lease, scheduler, or replacement for native goal state. Update it after each
coherent checkpoint, material evidence change, newly resolved ambiguity, or reordered priority.
Historical decisions and evidence remain in `docs/implementation-log.md`.

## Objective

Continue the standalone C++26 Symphony implementation using an evidence-first, self-improving
engineering system. Finish the contained OpenSymphony safety boundary, keep OpenSymphony
fail-closed until its complete admission gates pass, then implement the approved standalone
C++26 backlog in small independently testable slices.

## Definition of done

- [ ] Every implementation slice has one observable contract, authoritative inputs, one owner,
      non-overlapping file/resource scope, one failing fixture or exact reproduction, one expected
      artifact, one focused validation command, and explicit stop/split/completion conditions.
- [ ] Nontrivial work begins with current source/tests/specification, upstream evidence, and
      primary-source research; maintained third-party capabilities are evaluated before custom
      implementation.
- [ ] The deterministic controller uses no model. Planning, execution, normal review, adversarial
      review, triage, and monitoring roles have bounded inputs, outputs, authority, and model/effort
      policies.
- [ ] Only one writable implementation lane operates until atomic file/resource claims,
      isolated-worktree coordination, crash recovery, and serialized integration pass hostile
      fixtures. Parallel research, triage, monitoring, and review remain read-only.
- [ ] Every writable worker/controller maintains a sanitized durable task notepad containing
      objective, constraints, decisions/sources, command/result evidence, repository identity,
      file/resource ownership, task states, context telemetry, failure counters, blockers, and next
      action. A read-only specialist returns one sanitized provisional result; the controller
      verifies and persists accepted evidence without weakening the specialist's sandbox.
- [ ] Free-form notepads are replaced by a versioned schema-validated task record. A task record is
      recovery evidence, never authority or a write lease.
- [ ] Context policy is fixture-proven:
  - [ ] update and verify the durable notepad by 45% reported utilization;
  - [ ] target clean-context handoff at 50%;
  - [ ] add no scope after reaching 50%;
  - [ ] authorize no next model turn at or above 55%;
  - [ ] require fresh telemetry correlated to the exact thread and turn;
  - [ ] pause on missing, stale, malformed, cumulative-only, or non-positive telemetry;
  - [ ] end a session after compaction and restore through a new process/thread;
  - [ ] never reset task-wide retry, failure, time, token, or expensive-build budgets on rollover.
- The owner clarified that 50% is guidance and may be exceeded slightly. This checklist adopts 55%
  as the conservative hard no-next-turn boundary, a five-point allowance; that decision is active
  unless the owner explicitly supersedes it.
- [ ] The learning loop is executable:
  - [ ] normalize the failure family and retry disposition;
  - [ ] preserve the smallest reproduction;
  - [ ] test one falsifiable correction;
  - [ ] add a regression guard on first occurrence;
  - [ ] promote a deterministic guard with owner/deletion trigger on second occurrence in 30 days;
  - [ ] disable automatic retry and reconcile authoritative evidence on third occurrence;
  - [ ] reject summaries, timestamps, run IDs, tokens, and process success as objective progress.
- [ ] Model/effort adaptation uses measurable evidence:
  - [ ] baseline executor and normal reviewer use `gpt-5.6-sol` / `high`;
  - [ ] cross-subsystem planning, primary-source reconciliation, and high-risk adversarial review
        use `gpt-5.6-sol` / `xhigh`;
  - [ ] focused triage may use `gpt-5.6-terra` / `medium`, rising to `high` only for ambiguous
        causality;
  - [ ] the first eligible product/test/compiler no-progress outcome routes the next fresh session
        to Sol / `xhigh`;
  - [ ] one repeated eligible signature permits one bounded fresh Sol / `max` diagnostic;
  - [ ] another recurrence pauses rather than escalating;
  - [ ] credential, authority, telemetry, external-service, and resource failures never raise
        reasoning effort;
  - [ ] de-escalation requires changed objective progress and fresh green review.
- [ ] Normal and required adversarial reviews bind to the exact final SHA. Reviewed-path byte
      changes invalidate prior review; unresolved findings, stale evidence, co-author review, or
      missing reruns block publication.
- [ ] Canonical policy documentation, scoped `AGENTS.md` links, workflow diagrams, sequence
      diagrams, and executable drift checks stay synchronized.
- [ ] All focused tests, dependency policy, preflight/static analysis, documented container matrix,
      exact-final reviews, and exact-range redacted publication checks pass before public push.

## Architectural and authority constraints

- OpenAI Symphony Draft v1 is normative.
- Core code is C++26. GCC 16.1 defines executable semantics; Bloomberg clang-p2996 at `7220baff`
  is differential-only.
- Use CMake 4.4, Ninja, CTest, ccache, pinned vcpkg manifests/overlays, and documented
  devcontainers.
- Use maintained third-party capabilities when they satisfy the contract. Owner authorization and
  a recorded dependency decision are required for custom replacements.
- OpenSymphony v2.10.0 remains external, local-only, and unmodified.
- Do not publish an OpenSymphony image or install it in the development container.
- No force-push, rebase, deployment, privileged installation, production credentials, credential
  inspection, unauthorized tracker mutation, unrelated repository changes, or generated reflection
  fixture edits.

## Current evidence

- [x] Repository remote is `ray-manaloto/symphony-cpp`; active implementation branch is
      `codex/implementation`.
- [x] Qualified GCC 16.1 AMD64 and ARM64 compiler artifacts exist independently of project source.
- [x] Project source, vcpkg checkout/installed tree, and binary archives are excluded from reusable
      compiler runtime images; dependency archives are validation caches only.
- [x] Clean local OpenSymphony composition proves GCC 16.1, CMake 4.4, C++26 reflection, exact
      `/opt` runtime linkage, and merged-rootfs contamination guards.
- [x] Current diagnostic OpenSymphony candidate is local-only and marked unverified.
- [x] The unchanged v2.10.0 suite passed all 848 library tests.
- [ ] OpenSymphony admission is blocked by upstream issue #227: its memory integration suite passed
      45 tests and failed the single missing-`gh` diagnostic assertion.
- [ ] No `upstream-tests=passed` local image exists; contained memory, doctor, and no-model dry-run
      remain correctly unavailable.
- [x] The sole authorized fixture canary was already consumed historically; no second canary is
      authorized.
- [x] Research advisor, policy planner, and adversarial reviewer completed fresh-context
      `gpt-5.6-sol` / `xhigh` passes and wrote separate task notepads.
- [ ] Native `/goal` remains blocked and must be resumed/replaced before this checklist can be
      mirrored into native goal state.

## Immediate task order

1. [x] **OPS-SAFETY-001:** Finish the current contained OpenSymphony image/launcher safety slice without mixing
       supervisor-policy implementation into its commit.
   - [x] Reproduce the unchanged pinned upstream #227 failure.
   - [x] Rebuild the current local diagnostic candidate with exact relevant-input identity.
   - [x] Run focused launcher, Bake graph, preflight, dependency-policy, syntax, and diff checks.
   - [x] Run independent final-diff normal and adversarial reviews.
   - [x] Apply first-pass findings: operational admission now ignores ambient GCC artifact
         overrides, and the Bake test binds the same explicit context into its input digest.
   - [x] Repeat reviews after byte changes.
   - [x] Run the exact-range redacted publication gate.
   - [x] Commit and push the exact branch without force-push or rebase.
2. [ ] **POLICY-CONTEXT-001:** Implement the context-policy slice with failure-first boundary, stale/missing telemetry,
       compaction, and fresh-session fixtures for the 45/50/55 policy.
3. [ ] **CONTROL-RECORDS-001:** Introduce versioned `TaskPacketV1`, `TaskResultV1`, `ReviewAttestationV1`, and
       `TaskNotepadV1` schemas using the pinned schema validator and existing C++ codec seams.
4. [ ] **CONTROL-PROGRESS-001:** Remove model-authored narrative fields from objective progress fingerprints.
5. [ ] **CONTROL-FAILURE-001:** Normalize volatile failure signatures and enforce the third-recurrence stop.
6. [ ] **AGENT-ROLES-001:** Add durable planner, executor, reviewer, adversarial-review, triage, and monitor profiles.
7. [ ] **DOC-GUARD-001:** Link scoped `AGENTS.md` files to one canonical engineering policy without duplicating it.
8. [ ] **DOC-DIAGRAM-001:** Add and validate architecture, workflow, state, and sequence diagrams.
9. [ ] **OPENSYMPHONY-ADMIT-001:** Resolve or consume an upstream OpenSymphony release containing the #227 fix, rerun the
       unchanged admission suite, then run contained doctor and no-model dry-run gates.
10. [ ] **PRODUCT-BACKLOG-001:** Continue the approved standalone C++26 product backlog in independently testable slices.

## Parallel read-only governance lane

This lane may run without displacing `POLICY-CONTEXT-001`. It performs no implementation, tracker
mutation, publication, controller activation, or goal writes outside the primary controller.

- [x] **AGENT-GOV-001:** Reconcile current official Codex custom-agent/configuration behavior,
      repository policy, and independent tracker/documentation/ecosystem advisor reports.
- [x] **AGENT-GOV-002:** Add project-scoped read-only profiles for tracker reconciliation,
      documentation drift, dependency reuse, Codex capability watching, and material goal-delta
      synthesis.
- [x] **AGENT-GOV-003:** Cap spawned specialist threads at three while normal dispatch uses at most
      one beside the implementer until representative fixtures pass; treat three as an emergency
      ceiling and disable nested spawning in every specialist profile.
- [x] **AGENT-GOV-004:** Document event triggers, typed result boundaries, controller-only goal
      synthesis, 30-day primary-source fallback, model/effort selection, and no-mutation authority.
- [x] **AGENT-GOV-004A:** Require bounded primary-source reconciliation before every material owner
      question or approval request, followed by viable options, pros/cons, recommendation,
      authority/rollback impact, and the safe consequence of deferral.
- [ ] **AGENT-GOV-005:** Add deterministic representative fixtures for agent configuration and
      typed report contracts; measure latency, token use, false positives, and defect recall before
      increasing routine concurrency.
- [ ] **AGENT-GOV-006:** Prove specialist admission from a read-only parent with mutation-capable
      app/MCP tools absent, immutable input manifests, one-turn termination, prompt-injection
      fixtures, and invalidation on changed bytes. Profiles remain configured but unadmitted until
      this passes.
- [ ] **TRACKER-MAP-001:** Reconcile every stable goal task ID with GitHub issue/PR identifiers and
      an authorized sanitized Linear metadata projection. Current GitHub issues `#1` through `#5`
      cover toolchain/image work; tasks `POLICY-CONTEXT-001` through `DOC-DIAGRAM-001` are currently
      unmapped. Linear parity remains unknown because no authorized metadata snapshot was read.
- [ ] **DOC-DRIFT-001:** Keep the reported 45/50/55 documentation drift, ADR architecture
      ambiguity, and missing diagram/link gates visible until their independently scoped fixes
      land. Navigation is resolved in this governance slice; policy and ADR semantics remain
      intentionally untouched.

## Open questions

- [ ] **DEC-TRACKER-001:** Approve or revise the researched phased Linear-work/GitHub-code
      authority recommendation and the future provider-native mutation allowlist.
- [ ] **DEC-WATCH-001:** Choose event-plus-weekly, event-only, weekly-only, or explicit-request-only
      deterministic ecosystem/Codex collection.
- [ ] **DEC-REMOTE-001:** Decide whether to enable iOS Remote/Voice as a monitoring and steering
      convenience without changing repository authority.
- [ ] **DEC-CONTROLLER-001:** Identify the future trusted controller and transactional storage
      boundary for authoritative task packets and atomic claims.
- [ ] **DEC-REVIEW-MODEL-001:** Decide whether high-risk review requires a heterogeneous model
      family once comparative defect-recall evidence exists.
- [ ] **DEC-BUDGET-001:** Set explicit task-wide token/cost and expensive-matrix budgets after
      trustworthy telemetry and price-policy evidence are available.

## Current checkpoint

Historical completed safety-slice checkpoint: the active writable slice was the contained
OpenSymphony image/launcher safety work. Policy implementation was deliberately sequenced afterward
to avoid mixing independent changes. Launcher
tests, exact Bake topology, quick preflight, dependency policy, shell syntax, and diff checks pass
on the current worktree. Three initial exact-current-diff review packets failed to produce bounded
checkpoints, so they were stopped and recorded as a packet-sizing failure rather than allowed to
consume more context. Reviews are now split into three independently bounded surfaces: build/Bake
mechanics, launcher attack surface, and evidence documentation. The bounded reviews found that
ambient `GCC16_ARTIFACT_CONTEXT` could redefine the operationally accepted input label and that the
Bake graph test did not bind its explicit GCC context into the digest invocation. Both are fixed;
the hostile launcher fixture, launcher suite, Bake graph contract, shell syntax, and diff check
pass. A proposed whole-worktree cleanliness gate was rejected because the image-specific context
and exact relevant-input digest already bind every local input used by this graph, while the
repository-revision label is explicitly informational. Fresh launcher adversarial, Bake mechanics,
and evidence reviews report no findings. The launcher and Bake suites, quick preflight, dependency
policy, shell syntax, and diff checks all pass on the final reviewed bytes. The exact 19-path slice
was committed as `0713d1662c29bb003e443924843265f3ba2f06e8`. The redacted publication scan over
`4f61da38afcf32fd89e3ee01a8f1dc13a85d904d..0713d1662c29bb003e443924843265f3ba2f06e8`
passed with 828 added lines and zero findings. The next atomic action is a non-force push of the
exact `codex/implementation` branch. That push succeeded; local HEAD, upstream, and
`origin/codex/implementation` now all resolve to
`0713d1662c29bb003e443924843265f3ba2f06e8` with ahead/behind `0/0`. The full Docker-enabled
pre-push suite passed manually; the publication command skipped only the duplicate hook rerun.
GitHub Source CI run `30170305498` completed successfully for that exact SHA. The next independent
slice is the failure-first 45/50/55 context-policy work. This canonical goal and its four redacted
notepads were independently reviewed, all findings were resolved, and they are versioned together
in the durability-only current HEAD; a fresh session must resolve that exact SHA from Git rather
than rely on a self-referential hash inside this file.

Post-publication reconciliation: durability commit
`bbd773da68610e513ef2caaf45f50ef59e28c7a5` is pushed with local/upstream ahead/behind `0/0`.
Source CI run `30171235988` completed successfully: policy/container preflight passed in 15 seconds
and GCC 16.1 source/reflection tests passed in 1 minute 27 seconds. This checkpoint update is the
only expected local modification at context rollover and belongs with the next policy slice.

Parallel governance checkpoint: three independent read-only advisors completed bounded tracker,
documentation, and ecosystem/Codex reports. Current official Codex documentation confirms
project-scoped `.codex/agents/*.toml`, per-role model/effort, read-only sandboxes, and bounded
concurrency; it warns that subagents add token cost and recommends read-heavy parallelism first.
Five native read-only profiles and `.codex/config.toml` are now present with the primary controller
meaning the top-level native Codex integration task, as the sole goal writer. The profiles are
configured but unadmitted until read-only parent/tool isolation and hostile input fixtures pass.
No `last30days` skill/plugin is installed, so the documented bounded
30-day primary-source fallback remains active. GitHub currently has five open issues and no pull
requests; Linear parity was not queried and remains unknown. This governance checkpoint does not
change the next writable action: first prove the existing 50/60/65 policy fails the new
44/45/49/50/54/55 default-boundary expectations.

Governance validation checkpoint: all five TOML profiles parse, expose unique names, disable nested
agents, and pass the pinned Codex CLI `--strict-config doctor` with no failed checks. Local
documentation links, dependency policy, `git diff --check`, and quick preflight pass. The final
normal review reports no findings. The broad adversarial re-review repeated the earlier
no-checkpoint packet failure and was stopped; a replacement one-turn closure packet verified all
seven prior authority, recursion, TOCTOU, prompt-injection, context, schema, and controller-state
findings as closed. The configured profiles remain unadmitted because `AGENT-GOV-005` and
`AGENT-GOV-006` require executable hostile fixtures, not because of an unresolved review finding.

The first independently executable action in that slice is to add failing default-boundary cases
to `tests/supervisor_policy_tests.cpp` for 44/45/49/50/54/55 percent, scoped initially to that test,
`include/symphony/supervisor/policy.hpp`, and `src/supervisor/policy.cpp`. The expected initial
failure is that defaults still implement 50/60/65. Validate with
`ctest --preset gcc-debug -R '^symphony_supervisor_policy_tests$' --output-on-failure`; do not edit
policy or documentation until the failure is observed and recorded.
