---
tracker:
  kind: linear
  project_slug: symphony-cpp-bf04553735be
  active_states:
    - Todo
    - In Progress
    - Human Review
    - Merging
    - Rework
  terminal_states:
    - Done
    - Closed
    - Cancelled
    - Canceled
    - Duplicate

polling:
  interval_ms: 30000

workspace:
  root: /workspaces

hooks:
  after_create: |
    git clone --depth 1 --branch codex/implementation https://github.com/ray-manaloto/symphony-cpp.git .
  before_run: |
    git status --short --branch
  after_run: |
    git status --short --branch
  before_remove: |
    git status --short --branch
  timeout_ms: 60000

agent:
  max_concurrent_agents: 1
  max_turns: 4
  max_retry_backoff_ms: 300000
  # OpenSymphony v2.10 extension; Draft v1 uses codex.stall_timeout_ms below.
  stall_timeout_ms: 300000

codex:
  model: gpt-5.6-sol
  reasoning_effort: high
  escalation_model: gpt-5.6-sol
  escalation_reasoning_effort: xhigh
  repeated_failure_reasoning_effort: max
  context_rollover_percent: 65
  stall_timeout_ms: 300000

routing:
  harness: codex_app_server
  model: gpt-5.6-sol
  model_profile: codex-chatgpt-local-keychain
---

You are implementing Linear issue `{{ issue.identifier }}` in the standalone
`symphony-cpp` repository.

Issue context:

- Title: {{ issue.title }}
- State: {{ issue.state }}
- URL: {{ issue.url }}

{% if issue.description %}
Description:

{{ issue.description }}
{% endif %}

Work only inside the provided isolated workspace. Read `AGENTS.md`, `CONTEXT.md`,
the relevant ADRs, and the dependency-first guidance before editing. The official
OpenAI Symphony Draft v1 specification is normative; OpenSymphony is an external
development orchestrator and comparative implementation, not the product runtime
or conformance authority.

Do not use production credentials, deploy, publish images, force-push, mutate
another worktree, or expand the issue scope. Do not implement a custom subsystem
when a maintained dependency satisfies its contract unless the repository owner
has recorded an explicit exception.

Start with a deterministic reproduction or failing test, implement the smallest
complete C++26 slice, run the affected checks, and leave a concise evidence-backed
result. Before writing, state a task capsule in the first progress report with
the one acceptance contract, allowed/denied files, shared resources, dependency
decision, focused command, checkpoint target, stop/split conditions, and next
atomic action. The controller records that capsule in the native task plan, which
is the interim authority; the progress report is only its projection. Do not
overlap another lane's file or resource claim. This is not an atomic lease;
writable concurrency remains one until the claim schema and fixtures pass.

Every code-bearing or policy/control-document result requires an independent
normal review against its exact fingerprint. Security, concurrency, persistence,
credential, workspace cleanup, release, publication, autonomous-merge, and
policy/control-document changes also require a separate adversarial review;
unresolved or stale findings block completion. After the distinct last-turn
context telemetry gate passes, at 60% finish only the active atomic slice and
prepare the durable handoff; at 65% authorize no continuation. Until that gate
passes, cumulative-only or missing telemetry pauses percentage-based supervisor
continuation. Any observed compaction or four completed turns in this session
also authorizes no continuation and resumes only from a verified checkpoint in a
fresh session. An issue may use at most four accepted model-backed sessions; that
issue-wide counter never resets. Never continue a compacted session. If two
consecutive attempts make no material progress, stop and report a
stalled/no-progress outcome instead of repeating the same approach.
