# OpenSymphony external supervisor

OpenSymphony v2.10.0 remains a pinned, stock development orchestrator. A separate
local-only C++26 `opensymphony-supervisor` process supplies the execution budgets,
progress decisions, context checkpoints, and merge evidence that the pinned
release does not implement. It is a guard around OpenSymphony, not a replacement
Symphony controller and not part of the deployed standalone service.

The supervisor is the direct parent of `opensymphony run` inside the contained
worker-host image. It receives no Docker socket. OpenSymphony and its Codex child
receive no GitHub merge credential. A separate publisher verifies the
supervisor's digest-bound evidence before it performs repository actions.

## Implementation and validation order

The pinned stock OpenSymphony release is validated before any feature is
disabled or replaced. The complete feature matrix must record executable
evidence for supported behavior and explicit evidence for unsupported,
misleading, or incomplete upstream behavior. A feature is not skipped merely
because the initial Codex route does not need it.

Upstream behavior is handled upstream-first: reproduce the smallest case
against the pinned release, search existing upstream reports, and file or update
an upstream issue with bounded redacted evidence before designing a local
containment. The external supervisor may enforce repository-owned safety and
evidence policy that upstream does not provide, but it does not patch, fork, or
silently redefine OpenSymphony. Complete the supervisor guards and their linked
upstream issues before widening autonomous worker or merge authority.

## Accepted operating policy

| Policy | Initial value |
| --- | --- |
| Active issues | One |
| Worker-run budget | Four accepted model-backed `turn/start` events |
| Wall-clock budget | 90 minutes from the first model-backed run |
| No-progress budget | Two consecutive post-baseline runs |
| Repeated-failure budget | Two matching redacted signatures without changed diff/check evidence |
| Context checkpoint | At 50% of the last-turn input tokens over the reported positive model context window |
| Context handoff | At 60%, finish only the active atomic slice and prepare durable handoff |
| Context rollover | At 65%, authorize no continuation and resume from durable state in a fresh session |
| Missing or inconsistent telemetry | Pause; never estimate |
| Fork/compact failure | Pause and preserve the original thread |
| Pause tracker state | `Backlog`, which is outside the configured active-state set |
| Operational concurrency | One until the complete isolated-concurrency fixture passes |

Cached input is not added to the last-turn input count again. Cumulative token
totals are cost evidence, not context utilization. Every accepted model-backed
turn consumes one worker-run budget even when the run is later cancelled for a
checkpoint. Restarts, compaction, forks, and process failure never reset a
counter or deadline.

## State machine

```mermaid
stateDiagram-v2
  [*] --> Disarmed
  Disarmed --> Preflight: operator arms one governed issue
  Preflight --> Launching: policy and persisted state agree
  Preflight --> Quarantined: missing or contradictory evidence
  Launching --> ObservingRun: child and gateway identities agree
  ObservingRun --> Cancelling: context reaches 65 percent
  ObservingRun --> Evaluating: run completes
  ObservingRun --> Exhausted: four runs or 90 minutes
  ObservingRun --> Quarantined: event gap or identity conflict
  Cancelling --> Checkpointing: child stops within grace period
  Cancelling --> Quarantined: cancellation or reap fails
  Checkpointing --> Evaluating: fork checkpoint and canonical compaction succeed
  Checkpointing --> PausedNeedsReview: checkpoint fails
  Evaluating --> ContinueAuthorized: objective evidence changed
  Evaluating --> PausedNeedsReview: second no-progress or repeated failure
  ContinueAuthorized --> Launching
  Evaluating --> EvidenceGating: issue work is complete
  EvidenceGating --> MergeReady: every digest-bound gate passes
  EvidenceGating --> PausedNeedsReview: gate fails or scope is ambiguous
  Exhausted --> PausedNeedsReview
  Quarantined --> PausedNeedsReview
  MergeReady --> [*]
```

`PausedNeedsReview` is a fail-closed machine state, not an automatic request for
human approval. The controller first dispatches the bounded research and
reconciliation allowed by the issue manifest; it asks a person only when that
work leaves a material ambiguity, contradiction, or missing authority.

The supervisor persists the issue identity, absolute deadline, run counters,
context observations, failure signatures, progress fingerprints, child
identifiers, gateway cursor, checkpoints, and every policy transition in its
own SQLite journal before it launches or resumes work. Gateway history is
bounded and in-memory, so restart reconciliation fails closed when the durable
journal and current gateway/manifests cannot be proven consistent.

## Objective progress

A run makes objective progress only when at least one approved artifact changes:

- repository HEAD or an allowed-path content fingerprint;
- a required command produces a new exit status and artifact digest;
- an approved plan item advances with attributable evidence;
- an allowed PR or tracker state advances.

Tokens, summaries, timestamps, run identifiers, repeated commands, process
success, and unsupported claims of completion are not progress.

OpenSymphony's validation endpoint is advisory because it does not carry the
required command/evidence records. The supervisor reads actual repository,
test-artifact, and CI evidence instead.

## Context checkpoint

At 50% the supervisor checkpoints after the next coherent change and accepts no
new scope. At 60% it finishes only the active atomic slice and prepares durable
handoff. At the 65% boundary it:

1. persists the observation and requests cancellation;
2. stops and reaps OpenSymphony within a bounded grace period;
3. starts a short-lived contained Codex app-server against the same isolated
   authentication and issue workspace;
4. forks through the last completed turn as a recovery checkpoint;
5. compacts the original canonical thread;
6. records both thread identities and resumes only after reconciliation.

The fork is recovery state; the compacted original remains canonical. Missing
`modelContextWindow`, an event gap, a failed fork/compact, or disagreement about
the last completed turn pauses the issue.

## Autonomous merge contract

Autonomous merge is permitted only when a tracked plan-policy manifest already
authorizes it. The manifest contains:

- issue and repository identities;
- normative specification and approved-plan digests;
- allowed paths;
- exact required commands, presets, compiler/container matrix, and review gates;
- expected publication target and merge strategy;
- explicit autonomous-merge authorization;
- excluded change classes.

The global supervisor policy is tracked in this repository. A per-issue manifest
may be derived without human intervention when it is a strict subset of the
approved standalone implementation plan and governing specification. Changing
the global policy or expanding an issue beyond those sources requires human
review.

The normative specification and fully researched approved plan are the primary
decision inputs. A plan-conformant change with complete, fresh evidence proceeds
through the guarded autonomous path without routine human approval. Research is
a prerequisite to escalation, not itself a reason to escalate: first reconcile
the current specification, approved plan, source, tests, upstream reports, and
primary documentation. Pause for a person only when material ambiguity or a
contradiction remains after that reconciliation.

The supervisor emits a commit-bound evidence envelope. A separate publisher
checks the envelope signature/digest, base and head SHAs, branch freshness,
required CI, unresolved reviews, publication scan, and branch rules before
enabling auto-merge. It never force-pushes, rebases, bypasses a rule, or merges a
stale head.

Human intervention is required only after research when:

- governing specifications, approved plans, or cited primary sources conflict;
- the requested diff exceeds its allowed paths or acceptance commands;
- required telemetry/evidence is missing or contradictory;
- a security, credential, deployment, publication, workflow-permission, or
  dependency exception is not explicitly covered by the approved manifest;
- a required provider/toolchain cannot satisfy the recorded contract.

That handoff must identify the exact unresolved question, explain the
contradiction or missing authority, cite the governing and primary sources, and
present viable proposals with their advantages, disadvantages, and a
recommended next decision. It must not mutate the disputed scope while awaiting
the decision.

The existing overlay-updater policy explicitly prohibits auto-merge.
Dependency-pin updater PRs therefore remain human-reviewed until that governing
decision is deliberately revised. Ordinary dependency use inside an already
approved immutable graph is not excluded.

The tracked global policy and schema will live under
`.github/autonomy/policy-v1.json` and `.github/autonomy/policy.schema.json`.
Derived issue policies live at
`.symphony/plans/<issue-identifier>.merge-policy.json`. The publisher reads the
global policy from the protected base commit and accepts a head policy only
after proving that allowed paths shrink, denied/excluded sets and required
evidence only grow, expiry and size caps only tighten, and immutable repository,
source, plan, merge-method, and publisher-app identities are unchanged. Unknown
fields and ambiguous glob containment pause.

The required-check rollout is deliberately staged:

1. land an unconditional `CI / required` aggregate on `pull_request` and
   `merge_group`, plus policy/schema/verifier fixtures;
2. install a repository-selected GitHub App whose only write capability is the
   app-owned `autonomy-policy / merge-ready` check and merge authority;
3. seed both exact check contexts, then create a disabled no-bypass `main`
   ruleset and compare its fetched representation with the tracked policy;
4. activate pull-request, squash-only, resolved-thread, deletion,
   non-fast-forward, strict-CI, and app-check rules and prove blocking/allowed
   fixture cases;
5. add a one-PR merge queue only after both Actions and the publisher revalidate
   the synthetic `merge_group` head.

The worker and supervisor never receive the GitHub App key or installation
token. The Mac-local publisher mints a repository-scoped installation token for
one decision, recomputes base/head/check/review/ruleset facts, posts a
commit-bound evidence digest through the Checks API, and enables auto-merge
against the expected head OID. It never uses admin bypass, direct merge, rebase,
force-push, branch update, Actions write, workflow write, packages, deployment,
secrets, or repository-administration permission.

Merge authorization does not imply deployment, package publication, image
publication, or broader tracker mutation. Each remains a separate explicit
authority boundary.

## Model and effort

The supervisor itself is deterministic and uses no model.

- Normal implementation: `gpt-5.6-sol` / `high`.
- Cross-subsystem or first repeated/no-progress recovery: Sol / `xhigh`.
- Second matching failure: one short Sol / `max` diagnostic session.
- Another matching failure or missing evidence: pause.
- Focused deterministic reproduction may use Terra / `medium`, promoted to
  `high` only when causality remains ambiguous.

Effort is selected through preapproved, read-only Codex configuration overlays
between worker runs. OpenSymphony's ignored `codex:` map is not treated as an
effective control.

## Required fixture coverage

- transition-table boundaries and virtual-clock deadlines;
- four-run and 90-minute persistence across crashes/restarts;
- duplicate, missing, and out-of-order events;
- context values immediately below/at 65%, null windows, and compaction events;
- fork/compact and cancellation failures;
- automatic-continuation races;
- objective-progress discrimination and repeated failure normalization;
- malformed or hostile manifests and structured-event redaction;
- merge-envelope replay, tampering, stale heads, and disallowed paths;
- fake Linear pause transitions and conflicts;
- fake GitHub CI/review/auto-merge behavior;
- disposable-container end-to-end operation with fake Linear, Codex, and
  GitHub services.

Upstream gaps are tracked in
[OpenSymphony #222](https://github.com/kumanday/OpenSymphony/issues/222),
[#223](https://github.com/kumanday/OpenSymphony/issues/223), and
[#224](https://github.com/kumanday/OpenSymphony/issues/224). The fixed gateway
timeout is recorded in
[#225](https://github.com/kumanday/OpenSymphony/issues/225), and the
missing-`gh` memory-test diagnostic gap is tracked in
[#226](https://github.com/kumanday/OpenSymphony/issues/226).
