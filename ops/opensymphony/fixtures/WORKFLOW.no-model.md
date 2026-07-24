---
tracker:
  kind: linear
  endpoint: http://linear-fixture:8080/graphql
  project_slug: fixture-project
  active_states:
    - In Progress
  terminal_states:
    - Done

polling:
  interval_ms: 100

workspace:
  root: /workspaces

hooks:
  after_create: |
    printf '%s\n' after-create > .opensymphony-fixture-after-create
  before_run: |
    printf '%s\n' before-run > .opensymphony-fixture-before-run
  after_run: |
    printf '%s\n' after-run > .opensymphony-fixture-after-run
  before_remove: |
    printf '%s\n' before-remove >> .opensymphony-fixture-before-remove
  timeout_ms: 10000

agent:
  max_concurrent_agents: 1
  max_turns: 1
  max_retry_backoff_ms: 1000
  stall_timeout_ms: 1000

routing:
  harness: codex_app_server
  model: gpt-5.6-sol
  model_profile: codex-chatgpt-local-keychain
---

This disposable fixture proves OpenSymphony's no-model route against fake services.
It must never receive a live tracker endpoint or model credential.
