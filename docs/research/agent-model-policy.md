# Agent model and effort policy

Accessed 2026-07-22. This is an operational recommendation, not part of OpenAI Symphony Draft v1.

## Current state

OpenSymphony is a deterministic Rust scheduler around a coding-agent harness. It should not spend
model tokens deciding polling, routing, retry, reconciliation, or workspace lifecycle. The pinned
v2.10.0 Codex harness accepts one selected model for a worker and otherwise delegates selection to
Codex CLI. The contained configuration now selects `gpt-5.6-sol` and overlays the non-secret Codex
setting `model_reasoning_effort = "high"`; it still defines no role-specific agent pool. Upstream
`.agents/skills` specialize instructions, not model instances.

Native Codex work now has project-scoped profiles under `.codex/agents/` for tracker inventory,
documentation drift, dependency reuse, current Codex/app capabilities, and material goal-delta
synthesis. They are configured but unadmitted until read-only parent/tool isolation and hostile
fixtures pass. They do not change OpenSymphony configuration or add writable workers.
`.codex/config.toml` caps spawned threads at three as an emergency ceiling. Until representative
agent fixtures pass, normal dispatch uses at most one specialist beside the implementer. See
[`../agent-orchestration.md`](../agent-orchestration.md).

The contained image pins Codex CLI 0.145.0. Its authenticated, read-only `model/list` result on
2026-07-22 advertised Sol as the default with `low` effort and supported `low`, `medium`, `high`,
`xhigh`, `max`, and `ultra`. Terra advertised the same range; Luna advertised through `max`. This
probe started no model-backed turn and accessed no Linear state. Keep the image-pinned catalog and
the prior CLI-default behavior available as rollback evidence.

## Recommended role matrix

| Role | Recommended model | Default effort | Escalate when | Scope |
| --- | --- | --- | --- | --- |
| Orchestration controller | No model | N/A | Never | Deterministic scheduling, leases, retries, routing, and limits |
| Primary issue implementer | `gpt-5.6-sol` | `high` | `xhigh` for cross-subsystem design or repeated failed evidence | One isolated issue workspace |
| Architecture/research specialist | `gpt-5.6-sol` | `xhigh` | `max` only for bounded, high-impact decisions | Read-only primary-source synthesis and decision records |
| Independent reviewer/verification specialist | `gpt-5.6-sol` | `high` | `xhigh` for security, concurrency, persistence, or release gates | Review a completed diff; do not co-author it |
| Focused test/triage specialist | `gpt-5.6-terra` | `medium` | `high` when failure causality remains ambiguous | Reproduction, logs, focused fixtures, compiler diagnostics |
| Mechanical search/documentation specialist | `gpt-5.6-luna` | `low` | `medium` for synthesis across several sources | Bounded inventory, formatting, or documentation updates |
| Tracker inventory specialist | `gpt-5.6-sol` | `high` | `xhigh` only for a verified cross-provider identity conflict | Read-only goal/GitHub/sanitized-Linear reconciliation |
| Documentation drift specialist | `gpt-5.6-sol` | `high` | `xhigh` only for a cross-subsystem authority conflict | Read-only exact-SHA/diff claim verification |
| Dependency reuse specialist | `gpt-5.6-sol` | `xhigh` | `max` only for one bounded high-impact provider decision | Read-only dependency-first primary-source synthesis |
| Codex capability specialist | `gpt-5.6-sol` | `high` | `xhigh` only for a material configuration/authority conflict | Read-only official-source delta synthesis |
| Goal synthesis specialist | `gpt-5.6-sol` | `xhigh` | Pause after a repeated unresolved conflict | Read-only exact goal-delta proposal; controller applies |

Use aliases only while evaluating quality. Once representative fixtures pass, prefer dated model
snapshots where the selected access path supports them. Do not use `max` as a routine default: it
adds latency and token cost, and official migration guidance recommends testing the same effort and
one level lower because GPT-5.6 can maintain quality with less reasoning.

## Specialization boundary

Specialized agents are justified only when their inputs, outputs, and authority are distinct:

- research is read-only and returns sourced evidence;
- implementation owns one bounded issue workspace;
- review is independent and returns findings, not silent edits;
- test triage owns reproduction and diagnostics;
- mechanical work cannot make architecture decisions.

Skills remain the first specialization mechanism. A separate agent/model is warranted when work can
run independently, benefits from an independent context or reviewer, and has a bounded handoff.
Avoid a permanent swarm: it duplicates context, increases token use, and weakens the single
scheduler authority. Start with one implementer and at most one independently justified specialist,
then expand only after measured throughput and defect-recall evidence.

## Context and effort controls

- Pin model and effort in each supported worker launch/session path after its compatibility probe;
  both the external OpenSymphony and standalone C++ paths now use Sol/high.
- Preserve Codex-reported context-window and compaction telemetry.
- Let Codex own automatic compaction. End the bounded worker session after any observed compaction,
  then resume from durable workspace and tracker state in a fresh process and thread. The adapter
  distinctly decodes optional `tokenUsage.last.inputTokens`, and the pure reducer's 45/50/55%
  fixtures pass and pause on a missing value or non-positive window. Keep the external supervisor
  process disarmed until its telemetry/checkpoint wiring passes; never estimate missing
  utilization. The standalone C++ app-server path already stops its own continuation after an
  observed compaction or configured per-session turn cap; those signals are not yet enforced around
  stock OpenSymphony.
- Enforce a turn budget independently of context size. The repository workflow uses four turns per
  session. A compaction is not progress and does not reset retry/no-progress policy.
- Select Sol/high at baseline. Use Sol/xhigh in the next fresh session for cross-subsystem design or
  a typed product/test/compiler no-progress result, and Sol/max only after that same eligible
  signature repeats. Credential, authority, missing-telemetry, external-service, and resource
  failures pause or use deterministic handling rather than spending more model effort. Return to
  baseline only after the progress fingerprint changes and fresh review evidence is green; a clean
  process exit alone is insufficient. Escalation takes effect only in a fresh session restored from
  a durable checkpoint, never by continuing a bloated or compacted thread.
- Keep normal independent review on Sol/high. Use Sol/xhigh for adversarial review of security,
  concurrency, persistence, credentials, workspace deletion/containment, release, publication, or
  autonomous-merge boundaries; review agents report findings and do not co-author corrections.
- OpenSymphony v2.10.0 cannot apply an equivalent per-session effort route. Monitor its terminal
  reasons and repeated outcomes, but change its read-only overlay only through an explicit operator
  update until upstream exposes bounded routing.
- Record model, effort, context window, input/output/cached tokens, compactions, and terminal reason
  without logging prompts, issue content, credentials, or hidden reasoning.

Use the repository-wide checkpoint and recurrence policy in
[`../engineering-system.md`](../engineering-system.md). The pure policy checkpoints at 45% decoded
last-turn input use, prepares a fresh-session handoff at 50%, and makes 55% rollover mandatory; the
external process may enforce those transitions only after its wiring gate passes. Missing
last-turn telemetry pauses rather than interpreting cumulative totals as context pressure. A second
occurrence of one normalized failure family must promote a deterministic guard; a third stops
automatic retries and triggers bounded reconciliation against the approved plan, normative
specification, current evidence, upstream reports, and primary sources. Human Review is required
only if material ambiguity or contradiction remains, with cited options, tradeoffs, and a
recommendation. Forking and compaction never reset those counters.

## Primary evidence

- [OpenAI model guidance](https://developers.openai.com/api/docs/guides/latest-model) recommends
  GPT-5.6 Sol for complex work, Terra for balanced cost, and Luna for high-volume efficient work;
  it also recommends testing one effort level lower during migration.
- [OpenAI model catalog](https://developers.openai.com/api/docs/models) documents the GPT-5.6
  family, supported effort levels, and context windows.
- [Codex configuration schema](https://github.com/openai/codex/blob/main/codex-rs/core/config.schema.json)
  defines `model`, `model_reasoning_effort`, context-window, and auto-compaction controls.
- [Pinned OpenSymphony Codex harness documentation](https://github.com/kumanday/OpenSymphony/blob/0cc21ddda5d1853a8fbd11add578b43b6ebd6fcb/docs/codex-app-server-harness.md)
  states that `routing.model` is passed to Codex and omission delegates to the CLI default.
