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
- Committed the completed slice as `ef9a5ce6a9f5370f0101c4240f5a746813646696`; commit-time fast
  preflight passed. Exact-commit reviews, redacted publication scan, ordinary push, and terminal
  Source CI evidence remain.
- An incorrectly expanded abbreviated SHA was rejected by the first exact reviewer and corrected
  from live Git evidence; no substitution was accepted. Exact normal/adversarial attestations now
  report no findings for `afb0996e…ef9a5ce6`, with all-12-path hash `68cba15e…` and
  implementation/document hash `e1467d75…`. Run the redacted exact-range scan next.
- Redacted publication scan passed for the exact reviewed range: 12 paths, 330 added lines, zero
  findings. Ordinary non-force push is next; post-commit goal/notepad bytes remain local.
- The complete pre-push hook passed after about 16 minutes, but SSH closed while it ran; the command
  exited nonzero after restoring the checkpoint files. Fresh remote evidence still shows
  `afb0996e…`, while local HEAD is exact reviewed `ef9a5ce6…`, ahead by one. Retry unchanged HEAD
  with only the already-passed `symphony-push-preflight` hook skipped.
- Exact retry skipped only the already-passed hook and pushed
  `ef9a5ce6a9f5370f0101c4240f5a746813646696` normally without force or rebase. Watch exact-HEAD
  Source CI to terminal state next.
- `gh-watch-run` followed exact Source CI run `30186945918` to success: preflight passed in 14
  seconds and GCC 16.1 source/reflection tests passed in 1 minute 39 seconds. Local/upstream/remote
  all resolve to `ef9a5ce6a9f5370f0101c4240f5a746813646696` with ahead/behind `0/0`; only this
  terminal checkpoint and the root notepad remain modified.
- `CONTROL-RECORDS-001` resume reconciliation matches that exact state; native `/goal` is active,
  no PR is open, and OpenSymphony #227 remains open/fail-closed. The native objective's embedded
  policy slice is historical; the canonical checklist advances to dependency-first schema/codec
  mapping. No schema source or test has changed.

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

`CONTROL-RECORDS-001` has a frozen dependency-first capsule. Glaze 7.9.0 owns strict typed JSON and
schema generation, pinned `check-jsonschema` 0.37.4 owns independent fixture validation, and
`std::expected` owns the public error boundary; no dependency is added. The write scope is limited
to the new control-record header/implementation/tests/schema generator/fixtures, their two scoped
CMake lists, the dependency ledger, and controller-owned goal/notepad. Add the failure-first tests
and generator next, then run the focused GCC 16.1 build/CTest command and record the expected
missing control-record header/library failure before implementation. OpenSymphony remains a
separate fail-closed monitor-only lane.

Failure-first evidence is now recorded: the reused devcontainer configured with
`/opt/gcc-16.1/bin/g++`, reused every pinned vcpkg package, and the focused two-target build exited
`1` because both test translation units could not find `symphony/control/records.hpp`. No
control-record implementation existed when this red result was observed. Implement only the
declared public aggregates, private Glaze adapter, and scoped target links next.

The implementation now passes the 11-test focused control-record gate and the complete 22-test GCC
16.1 Debug suite, including public-header verification. The independent advisory report exposed
and primary-source inspection confirmed missing record-kind constants, Draft 2020-12 schema IDs,
and metaschema validation; all three are corrected. Strict decode also rejects input larger than
one MiB before allocation. Dependency policy, analysis/toolchain contracts, JSON/diff checks, owned
LLVM 22.1.8 formatting, and quick preflight pass. The repository-wide formatter still finds only
the existing out-of-scope `tests/supervisor_policy_tests.cpp` baseline. Next, freeze exact current
bytes and run sequential bounded normal/adversarial reviews; any changed reviewed byte invalidates
them.

The first 17-path normal-review packet missed its time bound and did not respond to a direct
stop-and-return request, so it was interrupted. Treat it as no review evidence. Split replacement
reviews into code/test and controller-document packets and do not repeat the same shape.

The 15-path replacement normal review repeated the same missing-checkpoint and ignored-stop
signature. It was interrupted and supplies no evidence. The recurrence policy permits one fresh
Sol/max diagnostic narrowed to only the public header and private adapter. Another recurrence must
pause review rather than spend more attempts.

The final two-path Sol/max review also missed its checkpoint and ignored the return-now request, so
automatic independent review is paused with no accepted review evidence. Local audit found a
separate testable issue: encode accepted wrong versions, wrong kinds, and oversized output. The new
focused GCC 16.1 fixture failed exactly those three assertions while control-character escaping
already passed. Add only the symmetric encode identity/size checks, then rerun focused and prior
green gates.

Encode now symmetrically rejects wrong version, wrong kind, and output larger than one MiB; escaped
control characters round-trip. The 11 focused tests, full 22-test GCC 16.1 suite, dependency and
toolchain contracts, owned formatting, diff check, and quick preflight all pass after the byte
change. Do not commit or publish yet: required independent normal/adversarial attestations are
absent because three reviewer processes failed to checkpoint, including the final two-file Sol/max
attempt. Preserve these bytes and counters. In a fresh context, first verify whether reviewer
checkpoint delivery changed, then use one explicitly authorized independent mechanism against a
new exact manifest; do not repeat the same automatic agent loop.

Unblock mechanism research used the installed `codex-cli 0.145.0` help surfaces. The CLI supports
a fresh one-shot `codex exec review --uncommitted` process and top-level read-only sandbox,
never-approve, selected model/effort, ephemeral-session, JSONL, and final-message controls. The
recommended next action, after explicit owner authorization, is to recompute an exact dirty-path
manifest, freeze the worktree, materialize a temporary detached clone containing only the 15-path
code/test delta, run one bounded normal review in that independent read-only process, then one
separate adversarial review against the identical manifest. This prevents `--uncommitted` from
silently adding the controller goal/notepad packet. Prefer this to another inherited
collaboration-agent retry. A separate read-only Desktop task is the fallback if the CLI review
process also fails to checkpoint. No review process was launched at this checkpoint.

The prepared 15-path code/test/dependency manifest has aggregate Git blob identity
`e3b6ec1512612a2f24d8bc238282e332f0a83ccb`:

```text
34977b4bb2a2dffd4be94a3c75fff669262a381f  docs/dependency-decisions.md
c3c1384eb0bdc56ce284312045590271f947ab84  include/symphony/control/records.hpp
078882b3f417c7f7817e36c4e81293d6bbceb73e  src/CMakeLists.txt
8ac5f8b592efe8eef94b2899c62b19013a32c20e  src/control/records.cpp
75aceddaa7604eb19f973f2fe57c03288ed46d3d  tests/CMakeLists.txt
7e0a5c2734f9188bde367ebaf60eece77e4a50aa  tests/control_record_schema_generator.cpp
14c4bc12449bb01a43e4a837743cc6527dbd7756  tests/control_records_tests.cpp
55e1196a9968410bd58b79f8fd12d019363871d1  tests/fixtures/control-records/review-attestation-v1.hostile.json
b197e42e93bfd6590e4cee46b0c770a5142ceb4d  tests/fixtures/control-records/review-attestation-v1.valid.json
b4ca6b3b744c8b2cf54dd9ecfb595a6f2d37ef3e  tests/fixtures/control-records/task-notepad-v1.hostile.json
166f180e533c3c74538795b2d7a81c6b8f5375e3  tests/fixtures/control-records/task-notepad-v1.valid.json
3c8d37290f6ae350510a2bc53bdf694e26b065e6  tests/fixtures/control-records/task-packet-v1.hostile.json
e0e570f6573d7648d2b6f2f04ce4a05d8f566835  tests/fixtures/control-records/task-packet-v1.valid.json
9e3b148fb0b75fde2758ceecbdb39c23ab02d0c6  tests/fixtures/control-records/task-result-v1.hostile.json
c01b5fff759993a6b9e85b4bf6e6ab3201c3a03b  tests/fixtures/control-records/task-result-v1.valid.json
```

Recompute the aggregate before and after each review; changed identity invalidates the result.
The host does not provide `shasum`, so use `git hash-object`. Do not use lowercase `path` as a zsh
loop variable because it overwrites the shell's executable-search array; use `manifest_file`.
These two preparation failures are resolved command-design evidence, not reviewer attempts.

Blocked audit reached the required third consecutive goal turn. The exact impasse is missing owner
authorization to launch the prepared fresh read-only normal and adversarial CLI review processes.
The retry policy forbids another automatic reviewer attempt, and no deterministic local check can
substitute for independent attestation. Mark the native goal blocked. On owner authorization,
resume as a fresh blocked audit, recompute manifest `e3b6ec1512612a2f24d8bc238282e332f0a83ccb`,
and reject the review if the recomputed identity differs.

The owner explicitly authorized the two prepared fresh read-only CLI review processes on
2026-07-26. Repository reconciliation remains exact at branch `codex/implementation`, HEAD and
upstream `ef9a5ce6a9f5370f0101c4240f5a746813646696`, ahead/behind `0/0`, no open PRs, and green
Source CI run `30186945918`. OpenSymphony #227 and upstream `main` are unchanged, so that lane
remains fail-closed. Historical reviewer failure counters remain three; this owner-authorized
alternative mechanism starts a fresh blocked audit rather than resetting them.

The authorized normal review completed in fresh ephemeral CLI thread
`019f9cd4-234d-7c51-b57e-72ea98da4d7a` with source and isolated-snapshot manifest unchanged at
`e3b6ec1512612a2f24d8bc238282e332f0a83ccb`. Two preceding parser-only invocations consumed no
model: global `-a` must precede `exec`, and `exec review --uncommitted` cannot accept the advertised
custom prompt. Generic `codex exec` with the global read-only sandbox and one-turn review prompt
succeeded. The reviewer reports five unresolved findings:

1. P1: `ReviewAttestationV1` accepts `passed=true` with findings, stale checks, or changed bytes.
2. P1: identity, digest, timestamp, repository, and path strings lack semantic/schema constraints.
3. P1: proposed V1 fields for checkpoint schema identity, independence facts, and rerun evidence
   are missing.
4. P2: redaction summary is caller-authored while raw command/evidence strings serialize verbatim.
5. P2: hostile-schema `WILL_FAIL` tests can pass on validator/tool failure and combine several
   defects, obscuring the rejected invariant.

The reviewer independently ran dependency policy and diff check successfully. Keep all five
findings unresolved until the separate adversarial pass completes against the unchanged manifest;
then reconcile them against the newer bounded goal contract before editing.

The authorized adversarial review completed in fresh ephemeral CLI thread
`019f9cdb-98cd-73e0-9219-4bcb3d089b17`; source and clone remained
`e3b6ec1512612a2f24d8bc238282e332f0a83ccb`. Its initial OpenSymphony memory probe was an
incorrect routing decision for this standalone slice, but the admission gate failed closed because
no qualified image exists, no container started, and the probe did not recur. The complete review
reports:

1. P1: contradictory `passed` review attestations are accepted.
2. P1: the one-MiB runtime boundary is absent from schema validation and encode rejects only after
   allocating the complete output.
3. P2: unconditional CTest `WILL_FAIL` can convert validator/tool failure into a passing hostile
   test.
4. P2: multi-defect hostile fixtures do not isolate unknown, missing, wrong-version, wrong-kind,
   nested-closure, duplicate-key, or semantic-contradiction regressions.

The adversary explicitly classified replay, expiry, digest recomputation, authentication,
authority/claims, persistence, tracker mutation, specialist admission, and current secret leakage
as deferred rather than defects. Reconcile this overlap with the normal findings before editing;
accepted corrections require new red fixtures and invalidate both uncommitted attestations.

Provider-backed dispositions:

- Accept runtime review-pass consistency, missing structural V1 fields, bounded Glaze span output,
  an exact-status CMake/check-jsonschema wrapper with byte gate, and single-mutation fixtures.
- Glaze 7.9.0's `buffer_traits<std::span>` is bounded and returns
  `error_code::buffer_overflow`; use it rather than custom serialization.
- Pinned check-jsonschema 0.37.4 returns JSON `status: ok`/`fail`; ordinary invalid input and an
  operationally missing file both exit 1, but only the expected validation failure has empty
  stderr, parseable JSON status `fail`, and nonempty errors. The CMake wrapper must check all of
  those facts.
- Glaze schema metadata lacks cross-field `if`/`then`; enforce review-pass consistency on both
  runtime directions and document schemas as structural. Do not hand-build a second schema engine.
- Defer identity/digest semantics, replay/expiry/authentication, claims/authority, persistence,
  tracker mutation, specialist admission, and redaction-owned sinks to existing later tasks.
- Do not add another parser for duplicate keys: Glaze exposes no such strict option, the frozen
  contract does not claim it, and a second parser violates dependency-first.

Expand scope only to `tests/cmake/CheckJsonSchemaFixture.cmake` and new single-mutation fixture JSON.
Add contradictory review tests and reproduce the missing-fixture `WILL_FAIL` false green before
fixing implementation or validation orchestration.

Failure-first review correction is red under GCC 16.1/CMake 4.4. The focused executable failed all
five new contradictory-attestation assertions: encode accepted stale checks, changed bytes, and an
unresolved finding while `passed=true`; decode accepted stale-check and changed-byte mutations.
The deliberately missing schema fixture simultaneously passed because current CTest
`WILL_FAIL` inverted its operational failure. CTest exited 8, and all pinned vcpkg packages were
reused. Replace that deliberate false-green with a wrapper self-test after implementing the exact
status/error contract.

The accepted review corrections are focused-green in the existing GCC 16.1/CMake 4.4
devcontainer. Both requested targets compiled, and all 14 `^symphony_control_record` tests passed
in 7.07 seconds. This verifies the bounded Glaze writer, symmetric passed-attestation consistency,
reviewer-independence rejection, resolved-finding rerun evidence, strict single-mutation schemas,
one-MiB instance gate, and operational-failure wrapper self-test. Run the complete GCC Debug suite
and deterministic repository checks next. The two authorized uncommitted reviews no longer attest
the changed bytes; fresh model reviews require a new explicit owner authorization.

The deterministic correction gates are green: all 25 GCC Debug CTest tests pass, dependency policy
passes with six immutable overlay pins, both toolchain contract scripts pass, JSON syntax and diff
hygiene pass, and quick preflight passes. The four owned C++ files are clean under the Mac's
clang-format 22.1.8. Authoritative full-tree formatting remains blocked because the pinned
analysis devcontainer image has no published manifest and an unrelated existing violation remains
in `tests/supervisor_policy_tests.cpp`; preserve that path unless authority expands.

The final corrected 18-path snapshot currently hashes to aggregate manifest
`9b508e2e6268a5751cc460edc2b89c0425063e90`. Both authorized reviews cover the superseded
manifest, so the next model action requires explicit owner authorization for exactly two fresh
read-only correction reviews: normal Sol/high and adversarial Sol/xhigh. Do not stage, commit, or
publish before those reviews and the format gate pass.

Read-only continuation reconciliation remains exact at branch/HEAD/upstream
`codex/implementation` / `ef9a5ce6…`, ahead/behind `0/0`, with nothing staged and no open PR.
OpenSymphony #227 and upstream `main` are unchanged, so admission stays fail-closed.

The missing analysis image is expected debt tracked by GitHub issue #4: no
`symphony-analysis` GHCR package exists, and successful compiler-matrix run `30150376563` used
cache-only `push: false` analysis targets. Do not publish an unqualified mutable edge tag. The
full-tree formatter finding is a single mechanical layout difference in
`tests/supervisor_policy_tests.cpp` introduced at current HEAD. Recommended next authority is:
exactly two corrected-byte read-only reviews plus a narrow formatter-only scope expansion; retain
exact LLVM 22.1.8 cache-only CI as final provenance until issue #4 independently qualifies and
digest-pins the local analysis runtime.

Blocked audit reached the third consecutive resumed goal turn. Current state is unchanged:
`codex/implementation` at local/upstream `ef9a5ce6…`, ahead/behind `0/0`, nothing staged, no open
PR, corrected 18-path manifest `9b508e2e…`, and OpenSymphony #227 still open. All meaningful
read-only and deterministic work is exhausted. Mark the native goal blocked until the owner
explicitly authorizes exactly two corrected-byte read-only reviews and the one-path
`tests/supervisor_policy_tests.cpp` formatting-only scope expansion. This does not authorize an
analysis-image publication.

The owner resumed the blocked goal by authorizing exactly two corrected-byte CLI reviews
(normal Sol/high and adversarial Sol/xhigh) plus the single mechanical clang-format correction in
`tests/supervisor_policy_tests.cpp`. The native status remains blocked only because its API has no
resume transition; the exact authority impasse is resolved. Apply that one-path format patch,
rerun focused/full deterministic checks, freeze a new manifest, then run exactly the two authorized
read-only processes. No analysis-image publication is authorized.

The single authorized supervisor formatting correction is complete. Repository-wide clang-format
22.1.8 dry-run, the focused supervisor test, all 25 GCC 16.1 Debug tests, dependency policy,
toolchain contracts, quick preflight, JSON syntax, and diff hygiene pass. Freeze a new 19-path
manifest and create a fresh isolated clone before starting the first of the two authorized reviews.

The final 19-path source snapshot and fresh detached no-remote clone both hash to aggregate
manifest `c4122e97c39705f5fb50e0ce4918d148cd7e9fb8`; clone path is
`/tmp/symphony-control-records-correction-review.1WDPCh/repo`. Goal/notepad bytes are excluded.
Keep source quiescent and run the authorized normal Sol/high review, verify no drift, then run the
separate adversarial Sol/xhigh review.

The authorized normal Sol/high review completed in thread
`019f9cfd-b13e-76c3-b30a-9e96d34659c3` with source/clone unchanged at `c4122e97…`. It reports one
P1: Source CI's isolated GCC job does not install pinned `check-jsonschema`, while new test CMake
requires it during configuration; the separate metadata job cannot share its mise PATH. Final
message blob `a322f888…`. Preserve bytes and run the authorized adversarial review before
disposition or correction.

The authorized adversarial Sol/xhigh process used fresh ephemeral thread
`019f9d07-15d8-7892-a43a-41ef53721cdb` and independently confirmed the same Source CI
`check-jsonschema` provisioning P1. It found no second actionable issue before exceeding its
30-command limit and stalling, so the controller terminated it. No final attestation exists; treat
this as corroboration plus a reviewer-process failure, not a passing review. Both authorized model
processes are exhausted.

After termination, source and detached clone remain byte-identical at aggregate manifest
`c4122e97c39705f5fb50e0ce4918d148cd7e9fb8`. Normal final SHA-256 is
`ebe2ab055db13d6ecd92ff3093633561b3fe5f4ee5bbc35e7abfb8cc75eed30d`; adversarial final is absent.
Do not change the frozen code/test bytes or expand into `.github/workflows/source-ci.yml` until
primary-source research is recorded and the owner explicitly authorizes the workflow correction.

Research confirms jobs are fresh isolated runners; `needs` cannot share the metadata job's PATH.
Pinned mise-action supports locked targeted install arguments and scoped caching, but mise's
`pipx:` backend requires `uv` or `pipx`. Exact cached `gcc:16.1@sha256:4eb18b10…` is Debian 13 with
Python but neither provider. An ephemeral exact-image test installed Debian `pipx`, verified the
pinned mise 2026.7.12 binary SHA-256 `dad54e0b…`, installed locked
`pipx:check-jsonschema` 0.37.4, and returned the exact expected CLI version.

Recommended authority request: expand only
`scripts/test-toolchain-platform-contract.sh` (failure-first static contract) and
`.github/workflows/source-ci.yml` (add `pipx`, reuse exact pinned mise-action with targeted
`install_args`, distinct cache prefix, exact version assertion), then authorize exactly two fresh
reviews for the changed final manifest. Reject direct pipx duplication, optional schema validation,
and cross-job artifact transfer unless the owner chooses their documented tradeoffs.

Fresh continuation reconciled the stale native objective against current evidence. Do not rerun
POLICY-CONTEXT-001: canonical history and live Git prove it is published at `ef9a5ce6…`.
Repository/branch/local/upstream/remote are exact at `ray-manaloto/symphony-cpp`,
`codex/implementation`, `ef9a5ce6a9f5370f0101c4240f5a746813646696`, ahead/behind `0/0`;
nothing is staged, no PR is open, and exact-HEAD Source CI `30186945918` is successful. Native goal
is active.

The preserved control-record/format snapshot and controller checkpoints are the only worktree
changes. OpenSymphony #227 is still open and upstream main is still `0cc21ddda5d1…`, so admission
remains fail-closed. Dependency-first recheck confirms reuse of pinned mise/mise-action and
check-jsonschema with Debian pipx as the missing prerequisite. Current blocker remains owner
authority for the two-path Source CI correction and exactly two fresh post-correction reviews; do
not edit, stage, or publish before it.

Second resumed-turn failure-first evidence: a read-only proposed Source CI contract exited `8`
with five missing properties—GCC `pipx`, targeted locked check-jsonschema install, isolated schema
cache prefix, exact 0.37.4 assertion, and a second pinned mise-action occurrence. The current
`scripts/test-toolchain-platform-contract.sh` still exits `0`, proving the deterministic regression
guard is absent. The reviewed implementation snapshot remains exactly `c4122e97…`, and diff
hygiene passes. No authorized writable path changed. If the same authority condition persists on
the next consecutive goal turn, the strict three-turn blocked audit will be satisfied.

Third consecutive continuation confirms the exact same impasse. Final live evidence remains
`codex/implementation` / `ef9a5ce6…`, ahead/behind `0/0`, nothing staged, no PR, OpenSymphony #227
open with upstream main `0cc21ddda5d1…`, implementation manifest `c4122e97…`, and clean diff
hygiene. Safe research and deterministic checks are exhausted. Mark the native goal blocked until
the owner explicitly authorizes both the two-path CI correction and exactly two fresh
post-correction reviews. A generic automatic goal continuation authorizes neither.

Owner explicitly authorized both the two-path CI correction and exactly two fresh
post-correction reviews (normal Sol/high, adversarial Sol/xhigh). Resume as a fresh blocked audit;
the native API has no resume transition. Change only the deterministic contract first, record its
failure against unchanged Source CI, then correct the workflow. Preserve every other path.

Failure-first CI contract is red. Only `scripts/test-toolchain-platform-contract.sh` changed; it
now scopes exact pipx/mise/check-jsonschema pin, cache, and version requirements to the GCC job.
Against unchanged Source CI it exited `1`. This satisfies the required ordering; edit only
`.github/workflows/source-ci.yml` next.

Source CI correction is focused-green. The GCC job now installs pipx, uses the existing exact
mise-action/mise pins for targeted locked check-jsonschema installation with an isolated cache,
and verifies version 0.37.4 before configure. Toolchain contract, shell/ShellCheck, actionlint,
workflow schemas, zizmor, and diff hygiene pass. A duplicate readonly variable warning in the
first test edit was removed by renaming that test-local variable; the clean rerun emitted no
stderr. Full deterministic and GCC validation remains.

Full validation is green. Existing GCC 16.1/CMake 4.4 devcontainer passed all 25 GCC Debug tests
in 20.15 seconds with cached dependencies and no rebuild. Dependency policy, analysis/P2996/native
toolchain contracts, quick preflight, workflow/security checks, repository JSON parsing, and diff
hygiene pass. Freeze all implementation/configuration bytes except goal/notepad into one detached
no-remote review clone, then run the exactly two authorized reviews sequentially.

Final review snapshot contains 21 paths at aggregate manifest `0f1eaae21985aa10485f627565b99881bdc20140`.
Source and detached no-remote clone `/tmp/symphony-control-records-final-review.JS7sHS/repo` match;
goal/notepad are excluded. Keep source quiescent. Run normal Sol/high, reverify bytes, then the
single authorized adversarial Sol/xhigh review on the identical clone.

Normal Sol/high thread `019f9f4c-b222-7560-b780-83a7c7ebc5e0` returned FAIL with one P3 while
source/clone stayed `0f1eaae…` (final SHA-256 `17f79710…`): static CI guard runs from gcc16 to EOF
and does not prove a future sibling-job boundary or provisioning-before-exactly-four-workflows
ordering. Workflow itself is correctly ordered; no product/schema/dependency finding. Preserve
bytes and run the authorized adversarial review before correction.

Adversarial Sol/xhigh thread `019f9f51-5549-7423-ba9b-eb352a499856` completed on the unchanged
21-path clone (final SHA-256 `cecec0a8…`) and returned FAIL. P2: passed review attestations accept a
resolved finding with no rerun evidence; fix symmetrically in `src/control/records.cpp` and
`tests/control_records_tests.cpp`. P3: independently confirms the exact-job/ordering weakness in
the Source CI static guard. P3: add exact one-MiB and limit-plus-one encoded/input boundary tests,
including trailing whitespace/garbage. No P0/P1, authority, dependency, generated-fixture, or
publication regression. The two authorized review processes are consumed. Keep bytes unpublished;
request exact expansion authority for the two newly implicated C++/test paths and one fresh
normal Sol/high plus adversarial Sol/xhigh pair, then batch all accepted corrections into one
validation/review cycle.

Fresh continuation re-baseline: canonical goal supersedes the native objective's stale
`afb0996e…`/`POLICY-CONTEXT-001` starting text. Live state is branch/local/upstream
`codex/implementation` / `ef9a5ce6a9f5370f0101c4240f5a746813646696`, ahead/behind `0/0`, no
staged paths or open PR, and Source CI `30186945918` green for exact HEAD. Native goal is active;
repository controller state remains bootstrap-only. OpenSymphony #227 is still open and upstream
main is `0cc21dd…`, so admission stays fail-closed. Preserve all current bytes except the
still-authorized static CI contract correction. First prove its sibling-job/order false-green in
an isolated copy; do not alter the newly implicated C++/test paths or launch more reviews without
fresh explicit authority.

Static-guard red evidence: an in-memory workflow mutation removed `pipx` and validator setup from
the exact `gcc16` job and injected every expected marker into a later `sibling_probe` job. The
current line-41 `sed`/presence block still exited 0, while exact-job extraction proved
`install_args` absent from `gcc16`. No repository byte changed. Now consolidate the script onto
one exact-job extraction, require unique markers and exactly four workflows, and assert
provisioning plus version verification precede all four.

Static-guard correction is green. The script now bounds extraction to the exact `gcc16` job,
requires every provisioning/check/workflow marker exactly once, requires exactly four GCC
workflows, and proves provisioning/version verification precede Debug, Release, sanitizers, and
TSan. Real workflow exits 0; detached sibling-job and late-provisioning mutations each exit 1 with
empty output. Bash syntax, configured warning-level ShellCheck, platform contract, dependency
policy, quick preflight, and diff hygiene pass. Only this already-authorized P3 is resolved. Do
not touch `src/control/records.cpp` or `tests/control_records_tests.cpp` until exact scope expansion
is authorized; fresh final normal/adversarial review authority is also still required.

Read-only design for the remaining correction is frozen. Tests first: require passed resolved
findings with empty rerun evidence to fail symmetrically on encode/decode; derive exact one-MiB
payloads from an encoded empty-field baseline so exact-size encode/decode succeeds and plus-one
encode fails; exercise exact-limit trailing whitespace success, trailing garbage `invalid_json`,
and plus-one input `record_too_large`. Preserve resolved-with-evidence success and do not constrain
`not_applicable` or failed attestations. Minimal source change is one passed-attestation predicate
for `resolved && rerun_evidence_ids.empty()`. No new dependency/provider is needed. Await exact
scope authority, then edit tests only and record red before touching the adapter.

Pinned Glaze 7.9.0 headers validate the design: span capacity accepts `required <= capacity`,
overflow occurs only above capacity, fixed-span finalize adds no terminator, and strict read
accepts RFC 8259 trailing whitespace but emits syntax error for a remaining non-whitespace byte.
Thus exact-limit success, plus-one overflow, exact-limit whitespace success, and exact-size garbage
failure are provider-backed cases. No repository implementation/test byte changed. This is the
second consecutive active-goal turn awaiting the same two authorities; one further unchanged
impasse with no useful read-only work will satisfy the native blocked audit.

Third-turn blocked audit is satisfied. Live state remains `codex/implementation` at
`ef9a5ce6a9f5370f0101c4240f5a746813646696`, ahead/behind `0/0`, no staged paths/open PR, Source CI
`30186945918` green, OpenSymphony #227 open, and upstream main `0cc21dd…`; diff hygiene passes.
Read-only provider/test/workflow work is exhausted. Block only on explicit authority for
failure-first edits to `tests/control_records_tests.cpp` plus `src/control/records.cpp`, and exactly
two fresh post-validation reviews (normal Sol/high, adversarial Sol/xhigh). Resume as a fresh audit
only after both are explicit.

Owner authorized both exact gates: test-first changes to
`tests/control_records_tests.cpp`/`src/control/records.cpp`, and exactly two fresh final reviews
(normal Sol/high, then adversarial Sol/xhigh). Native goal is active again; historical counters
remain. Live Git/GitHub/OpenSymphony evidence is unchanged at `ef9a5ce6…`, ahead/behind `0/0`,
Source CI `30186945918` green, no staged paths/open PR, and #227 still open. Glaze/std::expected
remains the dependency-first provider. Edit tests only, then capture the focused GCC 16.1 red
before touching source.

Failure-first red captured in the GCC 16.1/CMake 4.4 devcontainer. Test-only build succeeded;
14 focused CTests exited 8 with 13 passing. The executable passed 79/83 assertions and failed
exactly four: missing-rerun passed attestations are accepted on encode and decode, and the fixed
writer rejects derived 1,048,576- and 1,048,575-byte outputs. Adapter remains untouched. Inspect
Glaze's actual padding/chunk path before implementing; preserve the inclusive one-MiB contract and
avoid guessed overhead.

Provider proof: Glaze's direct string writer reserves `ix + 10 + 2*n`, explaining the false
overflow. A disposable GCC 16.1/C++26 probe using maintained
`glz::basic_ostream_buffer<std::ospanstream>` over a one-MiB standard span accepted exactly
1,048,576 bytes and rejected 1,048,577 via stream failure while the destination stayed capped.
Use this Glaze/standard-library slow path, retain the inline span fast path, and add only the
missing passed-attestation predicate before rerunning the red suite.

Focused correction is green. Shared pass-state validation now rejects resolved findings with no
rerun evidence. The 4-KiB direct-span fast path remains; the slow path streams Glaze through
standard `std::ospanstream` into an exactly one-MiB span and maps stream overflow to
`record_too_large`. GCC 16.1/CMake 4.4 rebuilt the affected targets and all 14 focused CTests
passed in 6.69s, including exact/plus-one size and trailing-input cases. Run the full suite and
deterministic gates before freezing bytes for the two authorized reviews.

Full validation is green: GCC 16.1/CMake 4.4 built current bytes and all 25 CTests passed in
19.59s. Dependency policy, analysis/P2996/native contracts, quick preflight, JSON parsing, exact
clang-format 22.1.8 for touched paths, and diff hygiene pass. Freeze all implementation/config
paths except goal/notepad into a fresh detached no-remote clone. Keep source quiescent; run exactly
normal Sol/high, reverify manifests, then adversarial Sol/xhigh on the identical bytes.

Frozen final review input: 21 paths in detached no-remote clone
`/tmp/symphony-control-records-final-correction.VHzXnd/repo`; goal/notepad excluded. Source/clone
per-path Git blobs match, with canonical manifest aggregate `63b552e76d1241bf4897582a56d1e3bc2513ee3d`.
Keep bytes quiescent. Run the authorized normal Sol/high review, reverify manifests, then the one
authorized adversarial Sol/xhigh review on identical bytes.

Final normal review passed with no P0–P3 findings in ephemeral read-only Sol/high thread
`019f9fcc-27f4-7892-aa36-fd0fa54cdee7`. It independently matched HEAD, 21 paths, and aggregate
`63b552e7…`; final artifact SHA-256 is `2502c845cfc90081e648e20c2bb2b053a0a07fbc11b18ac4d3b1cf276bbd9198`.
Post-review source/clone/stored manifests remain identical. Keep implementation/config bytes
quiescent and run only the remaining authorized adversarial Sol/xhigh review on the same clone.

Final adversarial review passed with no P0–P3 findings in ephemeral read-only Sol/xhigh thread
`019f9fd0-d911-7c11-9cb5-ac1db01cc89f`. It independently matched all 21 paths and aggregate
`63b552e7…`; final artifact SHA-256 is `4dc5915b74c610d87e35d9542db9e1d09214be10ba269bc3efdb33b1f3f4d8d8`.
Post-review source/clone/stored manifests still match exactly. Both reviews are consumed and
green. Preserve reviewed bytes and run the guarded staging/publication/commit/non-force-push
ceremony next.

Exactly 21 reviewed paths are staged and every index blob matches the frozen manifest. Goal and
root notepad are the only unstaged paths. Commit with hooks enabled, verify the commit carries
those exact blobs, then run the exact-range redacted publication scan.

Fast preflight passed and commit `bbf0ad17099ad9c29a185155969b5a617dca2a63` was created over
`ef9a5ce6…`. Its 21 tree blobs exactly reproduce frozen aggregate `63b552e7…`. The exact-range
redacted scan passed: 21 paths, 2,013 added lines, zero findings. Only goal/notepad remain dirty.
Push normally with the full pre-push hook, then monitor exact-HEAD Source CI.

The full pre-push hook passed after about 15 minutes, including Buildx target/Bake static checks
without compiler rebuilds. The idle SSH channel had already closed, so Git returned nonzero.
Remote remains `ef9a5ce6…`; local is `bbf0ad17…`, with only goal/notepad dirty. Retry once with
only the already-green `symphony-push-preflight` hook skipped.

The transport-only retry pushed `bbf0ad17099ad9c29a185155969b5a617dca2a63` successfully without
force/rebase. Local, tracking upstream, and remote match at ahead/behind `0/0`. Source CI run
`30216952035` is in progress for exact HEAD; monitor it once with `gh-watch-run`.

`CONTROL-RECORDS-001` is complete. Source CI `30216952035` passed exact
`bbf0ad17099ad9c29a185155969b5a617dca2a63` in 3m52s: preflight 16s and GCC 16.1
source/reflection 3m32s, including Debug, Release, ASan/UBSan, and TSan. Local/upstream/remote are
equal at ahead/behind `0/0`; only goal/notepad remain modified. Keep published bytes quiescent.
Next fresh slice is `CONTROL-PROGRESS-001`: map objective-progress fingerprint inputs/consumers,
run dependency-first research, freeze a narrow contract/scope, and add a failing narrative-field
fixture before implementation.

Fresh `CONTROL-PROGRESS-001` reconciliation matches that exact state: no staged/untracked paths,
no PR, Source CI `30216952035` green, and native `/goal` active despite its historical embedded
policy routing. OpenSymphony #227 is still open and upstream `main` is still `0cc21dd…`, so its
admission lane remains fail-closed. Dependency-first is active. Read and map progress-fingerprint
inputs, tests, and consumers before freezing any writable implementation scope.

`CONTROL-PROGRESS-001` contract is frozen. Current local 64-bit FNV-like fingerprint consumes
model-authored summary/current-step strings, aliases path/check namespaces, and counts duplicates;
the scheduler uses it to reset no-progress/failure evidence. Reuse pinned PicoSHA2 1.0.1 with
sorted unique objective entries and versioned typed length framing. Write scope is exactly
`tests/domain_tests.cpp`, `src/domain/domain.cpp`, `src/CMakeLists.txt`,
`docs/dependency-decisions.md`, goal, and root notepad. Tests first must prove narrative/order/
duplicate invariance, path/check separation, real-objective sensitivity, and 64 lowercase hex,
then capture the focused GCC 16.1 red before source/CMake edits.

Failure-first red is captured with GCC 16.1/CMake 4.4. `symphony_tests` exited 8 with exactly four
new failed assertions: narrative churn, duplicate churn, path/check aliasing, and 16-character
output. Real objective-entry sensitivity passed. Domain implementation/CMake were untouched before
red. Implement only the PicoSHA2 typed-frame replacement and private include wiring.

The PicoSHA2 implementation made all new assertions green. Focused CTest remained red only because
an old fixture called summary-only `"one"` to `"two"` “new progress” and expected counter reset.
Update that fixture to add a real changed path; keep adapter bytes unchanged and rerun focused.

Focused green: the obsolete fixture now adds a real changed path; GCC 16.1 rebuilt the test and
`^symphony_tests$` passed in 9.97s. Run the full GCC Debug suite and deterministic gates next.

Full green for `CONTROL-PROGRESS-001`: full GCC Debug build plus all 25 CTests passed (19.28s);
dependency policy passed with six immutable overlays; analysis/toolchain platform contracts and
quick local preflight passed; clang-format 22.1.8 dry-run, 104 JSON parses, and `git diff --check`
passed. Modified scope remains exactly the four implementation/decision paths plus durable
goal/notepad, with no staged or untracked files. Owner explicitly authorized both fresh read-only
Codex CLI reviews. Freeze the four implementation/decision paths in a detached no-remote clone,
prove byte identity, and run normal then adversarial review against unchanged bytes.

Review snapshot frozen at `/tmp/symphony-control-progress-review.kJnuiV/repo`: detached base HEAD
`bbf0ad17099ad9c29a185155969b5a617dca2a63`, zero remotes, four source/snapshot Git blobs equal,
aggregate `b5265a22179a3ace3ac21a2e2ffde9f0fdd90da1`. Goal/notepad excluded. Keep reviewed paths
quiescent; run authorized normal Sol/high, recheck byte identity, then authorized adversarial
Sol/xhigh on the same clone.

Normal Sol/high thread `019f9ffb-b901-7500-a647-9970bade3d03` returned FAIL with one P2: tests
do not lock the portable v1 framing. Add a known-answer assertion for `{"a.cpp"}`/`{"unit"}` with
digest `89fd5e5fe8adee4352abbb949116b76a51b705c55c598b189682701bd8c77043`.
Artifact SHA-256 `71e60113b9367c710663079b01b096c8ae4f88e8b588c14c0c13cd8a2c31128d`.
Source/snapshot manifests remain `b5265a22…`. Keep bytes frozen and run the already-authorized
adversarial Sol/xhigh review before correction.

Adversarial Sol/xhigh thread `019fa002-4711-7422-853d-d29cbe69bd6f` independently reproduced the
81-byte mixed-vector digest and inspected the code/scheduler/policy surfaces, but repeatedly
brute-forced unrelated SHA-256 manifest formats despite the supplied Git-blob recipe. Controller
terminated it; no final artifact or additional attested finding exists. This process is consumed
and is not a pass. Source/snapshot remain `b5265a22…`. Apply the accepted known-answer test only,
validate focused/full, then obtain fresh corrected-byte review authority.

Known-answer correction changed only `tests/domain_tests.cpp`. Focused `symphony_tests` passed
(10.00s); full GCC 16.1 CTest passed 25/25 (20.11s). Dependency policy, analysis and platform
contracts, quick preflight, clang-format 22.1.8, 21 tracked JSON parses, and diff hygiene pass.
Corrected detached no-remote snapshot:
`/tmp/symphony-control-progress-corrected-review.IoskLq/repo`; same four paths, aggregate
`4fe868606b71ce1badc2ef41ccdb18ef7c8ef83d`. Prior reviews are stale/consumed. Need owner
authorization for exactly two fresh corrected-byte reviews: normal Sol/high, then adversarial
Sol/xhigh. Give reviewers the literal manifest construction recipe to avoid repeating the
attestation-format failure.

Fresh continuation: local/upstream/remote remain `bbf0ad17…`, ahead/behind `0/0`, exactly six
expected modified paths, nothing staged/untracked, no PR, exact-HEAD Source CI `30216952035`
green. OpenSymphony #227/upstream main unchanged, so fail-closed. Corrected source/clone/stored
manifests still equal `4fe86860…`; clone has zero remotes and diff hygiene passes. No fresh review
authority arrived and no model was launched; first repeated authority turn. Next review packet:
one literal path-ordered `<blob>  <path>\n` command piped to `git hash-object --stdin`, no
alternative-format guessing, maximum 20 commands, and immediate `FAIL` on identity mismatch.

Owner now explicitly authorized both fresh corrected-byte processes: one normal Sol/high and one
adversarial Sol/xhigh, read-only and restricted to the frozen four-path snapshot. Reverify
aggregate `4fe868606b71ce1badc2ef41ccdb18ef7c8ef83d`, then launch both against identical bytes using
the bounded literal-manifest packet. No publication or tracker mutation is authorized by this
checkpoint.

Source/clone/stored manifests reverified at `4fe86860…`. The first parallel launch failed before
inference: temporary output-schema enum/const fields lacked explicit string types, producing API
`invalid_json_schema` for normal session `019fa010-0c52-7792-b138-206ac3b6f78f` and adversarial
session `019fa010-0c69-7703-b8ff-233359b98a8b`. No code review occurred and no review result was
consumed. Correct the temporary schema and retry the same authorized processes.

Corrected-schema retry completed on exact base/manifest. Normal Sol/high
`019fa010-d737-7772-b4d5-59a5c9c63f18` returned one P1 (artifact SHA-256 `aefa1284…`):
same path/check identities with changed content/status/artifact evidence still fingerprint as
unchanged and can falsely trigger the anti-spin stop. Adversarial Sol/xhigh
`019fa010-d737-73f0-84f1-ba43af749c36` passed with zero P0-P3 (artifact SHA-256 `9d422a20…`).
Keep bytes frozen and publication blocked while reconciling the P1 with the explicitly interim
identity-only slice and `docs/opensymphony-supervisor.md`'s stronger content/command-evidence
contract. Accepted correction must start with a failing same-identity/new-evidence fixture and
requires fresh reviews after any byte change.

Controller reconciliation rejects the P1 as out of the frozen slice, not as an invalid
system-level risk. Production decoding currently never supplies `ProgressSnapshot`; this capsule
explicitly splits authenticated content and command/artifact evidence into later typed wiring.
Doing it here would cross domain, Codex protocol, scheduler, persistence/authentication, and test
boundaries. Added durable `CONTROL-EVIDENCE-001` immediately after this slice and before failure
normalization; production progress decoding must not drive anti-spin until it passes. Reviewed
bytes remain unchanged and all manifests remain `4fe86860…`; adversarial PASS remains exact.
Normal review is still FAIL, so obtain owner authorization for one replacement normal Sol/high
review whose packet states the frozen pure-domain boundary and follow-up gate.

Reviewer telemetry: normal reported 97,066 tokens; adversarial reported 97,266. Neither supplied
window/utilization/compaction telemetry, so no percentage is inferred and neither terminal
one-turn process is continued. Replacement packet must eliminate the unnecessary OpenSymphony
memory attempt and broad scans: one identity command, bounded governing ranges, exact diff/context,
maximum 10 commands, no continuation. Keep Sol/high; higher effort is not indicated.

Post-review continuation live check: branch/local/upstream/remote remain
`codex/implementation` / `bbf0ad17099ad9c29a185155969b5a617dca2a63`, ahead/behind `0/0`,
with exactly the six expected unstaged paths and no staged/untracked paths. No PR is open;
exact-HEAD Source CI `30216952035` remains green. Native goal is active. OpenSymphony #227 and
upstream main remain open/unchanged, so admission stays fail-closed. No replacement normal-review
authority arrived; prepare but do not launch its bounded packet.

Prepared and dry-validated the replacement normal packet without a model:
`/tmp/symphony-control-progress-corrected-review.IoskLq/replacement-normal.prompt`, 3,608 bytes,
SHA-256 `acbe53d8…`; corrected schema 1,477 bytes, SHA-256 `86f466b6…`. Its seven fixed commands
all pass against exact detached base/manifest `bbf0ad17…` / `4fe86860…`; dependency policy,
schema parse, and diff hygiene pass. It forbids network/build/delegation/OpenSymphony memory/broad
scans and ends after one synthesis. No launch occurred. This is the second consecutive turn
awaiting authorization for that one replacement Sol/high process; native blocked threshold is not
yet met.

Third-turn audit: the same one-process authority condition remains unresolved. Live branch, HEAD,
upstream, remote, six-path dirty set, no-stage/no-untracked state, no-PR state, exact-HEAD green
Source CI, OpenSymphony #227, upstream main, manifest, and diff hygiene are unchanged. All safe
packet preparation and scope reconciliation are exhausted. Mark the native goal blocked solely on
explicit authorization to run the prepared one-turn normal Sol/high packet SHA-256 `acbe53d8…`
against manifest `4fe86860…`. No source edit, model launch, staging, publication, or external
mutation occurred.

Owner explicitly authorized the prepared one-turn normal Sol/high review. Reverified source/clone
manifest `4fe86860…`, prompt SHA-256 `acbe53d8…`, schema SHA-256 `86f466b6…`, exact
branch/HEAD/upstream, dirty paths, and diff hygiene. Launch only that ephemeral read-only process;
no other reviewer or mutation is authorized.

Replacement normal Sol/high thread `019fa030-30ed-7713-8660-1f644aecfc7f` passed exact
base/manifest with zero P0-P3; result SHA-256 `9c8ac26f…`. It used the seven-command packet and
reported 52,157 tokens, versus 97,066 previously; missing context-window/compaction telemetry is
not inferred. Prior adversarial PASS remains exact. Source/clone/stored manifests still equal
`4fe86860…`; both reviews are green. Stage only the four reviewed implementation/decision paths,
leave goal/notepad unstaged, prove index identity, then commit and run the exact-range scan.

Exactly four reviewed paths are staged; index aggregate is `4fe86860…`. Goal/notepad are the only
unstaged paths, nothing is untracked, and staged diff hygiene passes. Commit with hooks, verify
commit-tree blob identity, then run the redacted exact-range scan.

Fast preflight passed and commit `179d0dbe38bdce33860cea8d679faa289920ed26` was created over
`bbf0ad17…`. It is single-parent and its four tree blobs reproduce `4fe86860…`. Exact-range
redacted scan passed: four paths, 89 additions, zero findings. Only goal/notepad remain dirty.
Push normally with the full pre-push hook, then monitor exact-HEAD Source CI.

Full pre-push hook passed in about 12.5 minutes, but GitHub had closed the idle SSH transport.
Local remains reviewed `179d0dbe…`, remote/tracking remain `bbf0ad17…`, ahead/behind `1/0`;
only goal/notepad are dirty and diff hygiene passes. Retry once skipping only the already-green
`symphony-push-preflight` hook.

Transport-only retry pushed `179d0dbe38bdce33860cea8d679faa289920ed26` successfully without
force/rebase. Local/upstream/remote match at ahead/behind `0/0`; only goal/notepad are dirty.
Exact-HEAD Source CI `30220397931` is in progress; monitor it once with `gh-watch-run`.

`CONTROL-PROGRESS-001` is complete. Source CI `30220397931` passed exact
`179d0dbe38bdce33860cea8d679faa289920ed26` in 2m43s: preflight 22s, GCC 16.1
source/reflection 2m17s through Debug/Release/ASan/UBSan/TSan. Local/upstream/remote match at
ahead/behind `0/0`; only goal/notepad remain dirty. Keep published bytes quiescent. Next slice is
`CONTROL-EVIDENCE-001`: dependency-first map authenticated content and command/artifact evidence,
prove production decoding remains disconnected, freeze a typed contract/scope, and add a failing
fixture first.

`CONTROL-EVIDENCE-001` dependency-first mapping: Draft v1 has no objective-progress record and
production Codex currently never populates `ProgressSnapshot`; only fixtures do. Preserve that
fail-closed state. Split the full task into domain typing/framing, content/artifact verification,
and verified `TaskResultV1` scheduler wiring; all remain required. First sub-slice introduces
typed repository path/content-digest and command/cwd/toolchain/exit/artifact-digest claims with a
portable v2 PicoSHA2 frame. Reuse existing PicoSHA2 plus standard C++26; do not couple domain to
control DTOs or Glaze JSON. Frozen first scope is domain header/source/test, scheduler fixture only
if mechanically required, dependency ledger, goal, and notepad. Add a typed same-identity/new-
evidence test first and capture the expected compile red before header/source edits.

Failure-first red captured in the GCC 16.1 devcontainer: only `tests/domain_tests.cpp` changed;
focused build exited `1` because both proposed evidence types and the replacement
`ProgressSnapshot` members are absent. Header/source were untouched before red. Implement only
the typed aggregates, v2 framing, and mechanical domain tests; keep verifier/wiring denied.

Focused green: domain owns typed repository content and command execution claims; v2 framing
normalizes evidence and hashes path/content plus command/cwd/toolchain/exit/artifacts in separate
namespaces. Independent 271-byte Node construction matches golden `49d4f71f…`. GCC 16.1 focused
test passed in 10.86s. Production progress remains absent and verifier/wiring untouched. Run
format/full GCC/deterministic gates.

Deterministic green: clang-format 22.1.8 apply/dry-run passed on the three changed C++ paths; the
complete GCC 16.1 Debug suite passed all 25 tests. Dependency policy, analysis/platform toolchain
contracts, quick preflight, and diff hygiene pass. Freeze domain/decision bytes and prepare
bounded exact-byte normal/adversarial review packets.

Goal-state audit: the prior blocked episode was the required third-turn audit for one missing
replacement-review authorization, with automatic continuations counted as consecutive turns.
Owner authorization resolved it; live native state is now active. Recommended prevention is a
bounded standing read-only review authorization per slice, including pre-inference schema/transport
retries and one invalidation rerun after accepted findings, capped by process/token budgets and
fail-closed on exhaustion. External mutation, publication, and scope expansion remain separate.

Review snapshot: live branch/local/upstream/remote are `codex/implementation` / `179d0dbe…`,
ahead/behind `0/0`; exact-HEAD Source CI `30220397931` is green, no PR is open, and native goal is
active. OpenSymphony #227/upstream main remain unchanged and fail-closed. The four domain/decision
paths are frozen in detached no-remote clone
`/tmp/symphony-control-evidence-domain-review.586wg1/repo`; source/clone aggregate is
`04743d935781a0d8d0aff46f43e18bc9c0e59c10`. Normal prompt SHA-256 `42d01910…`, adversarial
prompt `c3060cd9…`, schema `eb23f4cf…`; all dry checks pass. Keep bytes quiescent and run normal
Sol/high then adversarial Sol/xhigh sequentially on the identical snapshot.

Normal Sol/high thread `019fa052-7c61-7fa1-8764-cf8ad5c7c440` passed with zero findings; result
SHA-256 `cd85c8ce…`, exact base/aggregate attested, manifests unchanged. It reported 272,331
cumulative input tokens (224,512 cached) across seven fixed commands and no utilization/compaction
telemetry. Adapt the adversarial packet to exactly three commands to reduce repeated context replay;
new prompt SHA-256 `5ffc6fc2…`. Snapshot/model/effort/schema/authority are unchanged. Run one
Sol/xhigh adversary and compare usage.

Adversarial Sol/xhigh thread `019fa054-7815-7b53-a449-87e0550189d1` passed with zero findings;
result SHA-256 `d00c7585…`, identities exact, manifests unchanged. Three commands used 109,495
cumulative input tokens (75,008 cached), 59.8% below the seven-command normal review. Missing
utilization/compaction telemetry is not inferred. Both reviews are green. Retain the three-command
cap and evaluate one preassembled evidence payload later. Stage exactly the four reviewed paths,
prove index aggregate, commit with hooks, then run exact-range publication scan.

Guarded staging: exactly the four reviewed paths are staged; index manifest matches
`04743d935781a0d8d0aff46f43e18bc9c0e59c10`. Goal/notepad are the only unstaged paths, nothing
is untracked, and staged diff hygiene passes. Commit exact index bytes with hooks, verify the
single-parent tree manifest, then run the redacted exact-range scan.

Commit `b0b9d8b8f832f0c55688cd571688172dfdde8b51`
(`feat: add typed objective evidence`) is single-parent over `179d0dbe…`; fast preflight passed and
its four tree blobs reproduce `04743d935781a0d8d0aff46f43e18bc9c0e59c10`. Exact-range
redacted scan passed: four paths, 131 additions, zero findings. Only goal/notepad remain dirty;
local is ahead one. Push normally with the full pre-push hook, then monitor exact-HEAD Source CI.

Reset checkpoint: full pre-push passed after about 15 minutes, but GitHub closed idle SSH around
6.5 minutes; remote stays `179d0dbe…`, local reviewed `b0b9d8b8…` is ahead one. Owner stopped the
transport retry and requested an xhigh goal/workflow reset review. Do not push or start verifier.
Key evidence: canonical goal >1,800 lines with stale native objective; five terminal blocked audits
from granular authority exhaustion; four SSH timeouts behind 12–16 minute global pre-push gates;
the running Dev Container CLI environment uses prohibited historical `symphony-dev:edge`
`d4ee55fe…` with stale metadata, and checked-in GCC devcontainer still names that tag; qualified
OpenSymphony image is absent and memory-status fails closed while upstream #227/main are unchanged.
Run sequential xhigh advisors, archive this ledger, and replace it with a concise phase-gated goal.
Use native `/goal edit` or `/goal clear` rather than false complete/blocked state.
