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
  stall_timeout_ms: 300000

codex:
  model: gpt-5.6-sol
  reasoning_effort: high
  escalation_model: gpt-5.6-sol
  escalation_reasoning_effort: xhigh
  repeated_failure_reasoning_effort: max

routing:
  harness: codex_app_server
  model: gpt-5.6-sol
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
result. If two consecutive attempts make no material progress, stop and report a
stalled/no-progress outcome instead of repeating the same approach.
