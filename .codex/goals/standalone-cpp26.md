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
- [ ] Every agent maintains a sanitized durable task notepad containing objective, constraints,
      decisions/sources, command/result evidence, repository identity, file/resource ownership,
      task states, context telemetry, failure counters, blockers, and next action.
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

1. [x] Finish the current contained OpenSymphony image/launcher safety slice without mixing
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
2. [ ] Implement the context-policy slice with failure-first boundary, stale/missing telemetry,
       compaction, and fresh-session fixtures for the 45/50/55 policy.
3. [ ] Introduce versioned `TaskPacketV1`, `TaskResultV1`, `ReviewAttestationV1`, and
       `TaskNotepadV1` schemas using the pinned schema validator and existing C++ codec seams.
4. [ ] Remove model-authored narrative fields from objective progress fingerprints.
5. [ ] Normalize volatile failure signatures and enforce the third-recurrence stop.
6. [ ] Add durable planner, executor, reviewer, adversarial-review, triage, and monitor profiles.
7. [ ] Link scoped `AGENTS.md` files to one canonical engineering policy without duplicating it.
8. [ ] Add and validate architecture, workflow, state, and sequence diagrams.
9. [ ] Resolve or consume an upstream OpenSymphony release containing the #227 fix, rerun the
       unchanged admission suite, then run contained doctor and no-model dry-run gates.
10. [ ] Continue the approved standalone C++26 product backlog in independently testable slices.

## Open questions

- [ ] Identify the future trusted controller and transactional storage boundary for authoritative
      task packets and atomic claims.
- [ ] Decide whether high-risk review requires a heterogeneous model family once comparative
      defect-recall evidence exists.
- [ ] Set explicit task-wide token/cost and expensive-matrix budgets after trustworthy telemetry
      and price-policy evidence are available.

## Current checkpoint

The active writable slice remains the contained OpenSymphony image/launcher safety work. Policy
implementation is deliberately sequenced afterward to avoid mixing independent changes. Launcher
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

The first independently executable action in that slice is to add failing default-boundary cases
to `tests/supervisor_policy_tests.cpp` for 44/45/49/50/54/55 percent, scoped initially to that test,
`include/symphony/supervisor/policy.hpp`, and `src/supervisor/policy.cpp`. The expected initial
failure is that defaults still implement 50/60/65. Validate with
`ctest --preset gcc-debug -R '^symphony_supervisor_policy_tests$' --output-on-failure`; do not edit
policy or documentation until the failure is observed and recorded.
