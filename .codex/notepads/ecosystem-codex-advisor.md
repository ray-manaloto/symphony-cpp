# Ecosystem and Codex capability advisor

Updated: 2026-07-25

## Assignment and boundary

Design a project-scoped research agent that:

- discovers maintained free/open-source technology before Symphony owns a custom mechanism;
- watches current Codex, ChatGPT desktop, and iOS capabilities that could improve this workflow;
- returns cited, decision-ready deltas to the controller so the canonical goal can be reordered;
- performs no installation, external mutation, pin movement, issue/PR mutation, or repository edit.

This is a read-only advisory lane. It is not the controller, task authority, dependency approver,
tracker operator, or implementation owner. The controller remains deterministic and the primary
agent remains the only goal editor. A read-only custom agent cannot update a repository notepad;
therefore its typed final result is the handoff, and the primary agent persists accepted evidence.
If direct per-agent notepad writes remain mandatory, use a separately authorized one-path writer
after the research turn rather than weakening the researcher's sandbox.

Repository identity at review: `ray-manaloto/symphony-cpp`, branch `codex/implementation`, HEAD
`bbd773da68610e513ef2caaf45f50ef59e28c7a5`. Existing dirty changes in the canonical goal and root
notepad belong to the primary agent and were not touched.

## Evidence reviewed

- Repository guidance, canonical goal, research source list, ecosystem catalog, model policy,
  upstream-watch ledger, and all three repository skills were read completely.
- Fresh official Codex manual:
  `/var/folders/z4/0p475gq56vvczc3y4qlt60f80000gn/T/openai-docs-cache/codex-manual.md`,
  modified `2026-07-25T11:05:46-0500`, SHA-256
  `9aa974cc5289fa8e54ddb3b62c0a09979ba7764dcb094c10499462573d73617e`.
- Installed user, plugin-cache, and repository skill trees contain no skill or plugin named or
  describing `last30days` / `last 30 days`. `.build/research/last30days` is an earlier report
  artifact, not a callable capability.

## Recommended operating design

Do not keep a model-backed watcher running continuously. Use a two-stage gate:

1. A deterministic collector records immutable identities and bounded metadata from approved
   primary sources. It emits `no_delta`, `relevant_delta`, or `collector_failure`.
2. Spawn `ecosystem_codex_advisor` only for `relevant_delta`, before a custom mechanism is
   authorized, or when the primary agent requests a decision comparison. The advisor verifies the
   sources, maps the delta to repository contracts, and returns a typed proposal. It never edits
   the goal itself.

This preserves the goal's no-model controller rule, avoids weekly token spend on unchanged data,
and prevents mutable discovery sources from silently changing pins or project authority.

### Triggers

- Before implementing or expanding a commodity mechanism covered by `dependency-first`.
- A new release, tag, relevant merged PR, security advisory, or configuration-schema change in an
  already tracked upstream.
- A Codex CLI/app release, official “What's new” entry, custom-agent/config-schema change, plugin or
  skill catalog change, or ChatGPT iOS release affecting task inspection or steering.
- A second occurrence of custom infrastructure duplication, documentation drift, stale workflow
  guidance, or missed available Codex capability.
- A bounded weekly watch may collect metadata, but model synthesis runs only when the collected
  identity changes.

### Freshness and source policy

- “Current” Codex/app advice: official docs and changelog accessed within 7 days; recheck within
  24 hours before changing configuration or relying on a preview/beta feature.
- Dependency/tool advice: owning repository release/commit, security policy, license, package
  availability, and compatibility evidence accessed within 30 days; recheck immediately before
  adoption.
- Standards/compiler claims: immutable WG21 paper or compiler source/release identity.
- GitHub state: immutable commit/tag/release identities plus access timestamp. Issue, PR, and
  discussion text is proposal evidence unless merged.
- Blogs, catalogs, Reddit, social feeds, talks, and search snippets discover candidates only.
  Consequential claims must resolve to an owning primary source.
- Missing, inaccessible, stale, or contradictory evidence yields `needs_research` or
  `human_review`; it never becomes an adoption recommendation.

### Bounded replacement for an absent `last30days` capability

For a requested 30-day watch, compute an explicit UTC interval `[now-30d, now]`, then query only:

1. [OpenAI What's new](https://learn.chatgpt.com/docs/whats-new),
   [Codex changelog](https://learn.chatgpt.com/docs/changelog), and the relevant official feature
   pages;
2. [openai/codex releases and commits](https://github.com/openai/codex),
   [openai/skills](https://github.com/openai/skills), and the
   [Codex configuration schema](https://github.com/openai/codex/blob/main/codex-rs/core/config.schema.json);
3. owning repositories' releases, tags, merged PRs, security advisories, and documentation for
   candidates already in the catalog;
4. the installed universal plugin directory and local skill metadata as an inventory, not as proof
   of feature behavior.

Use live web search only for discovery and record query, interval, access time, source URL, immutable
identity when available, and whether the source is primary. Cap each watch at 20 changed primary
artifacts and summarize overflow by repository. Do not scrape authenticated social feeds. If a
future `last30days` skill is installed, inspect its `SKILL.md`, authority, date filter, source
quality, and mutation boundary before substituting it for this fallback.

## Output contract and decision gates

Return one compact `EcosystemAdviceV1` result:

- repository HEAD and collection interval;
- trigger and capability/problem statement;
- current repository owner of the capability;
- candidates with source URL, immutable version/commit, license, maintenance signal, vcpkg or
  tool-install path, GCC 16.1/C++26 compatibility evidence, security and operational footprint;
- Codex capability delta with official documentation/changelog URL, maturity, surface, required
  setting/environment variable, and rollback;
- deletion ledger: custom code/tooling/process removed versus introduced;
- recommendation: `no_change`, `evaluate_fixture`, `adopt_existing`, `defer`, or `human_review`;
- affected goal checklist IDs, tests/fixtures, docs/diagrams, pins, authority requirements, and
  next recheck trigger;
- ambiguity list and confidence.

An `adopt_existing` result is only a proposal. Adoption remains blocked until:

1. the exact capability and acceptance contract are defined;
2. a maintained candidate passes license, security, C++26/GCC 16.1, packaging, deterministic-test,
   and deletion-ledger checks;
3. the pinned vcpkg registry is checked first for C++ dependencies;
4. an overlay is used only for an exact missing-port/options failure, with immutable source/hash and
   removal criterion;
5. owner authority is obtained for new services, credentials, paid use, external mutation, custom
   replacement, or pin movement;
6. a failing fixture and focused validation exist before integration;
7. the primary agent updates dependency decisions, the canonical goal, diagrams/docs, and drift
   checks in one independently reviewed slice.

No tracker item should be created merely because a candidate exists. The task/issue steward should
deduplicate against the canonical goal and existing GitHub/Linear records, then propose one
authority-preserving change. GitHub and Linear must not become competing task authorities or be
silently dual-written.

## Proposed project custom agent

Suggested `.codex/agents/ecosystem-codex-advisor.toml` fields (proposal only):

```toml
name = "ecosystem_codex_advisor"
description = "Read-only primary-source advisor for OSS reuse and current Codex/ChatGPT capability deltas; use only after a deterministic delta or before authorizing custom infrastructure."
model = "gpt-5.6-sol"
model_reasoning_effort = "xhigh"
sandbox_mode = "read-only"
approval_policy = "never"
web_search = "live"
developer_instructions = """
Read the repository AGENTS.md, canonical goal, dependency-first skill, research catalog, dependency decisions, model policy, and upstream ledger before analysis.
Perform no repository or external mutation, installation, login, credential inspection, issue/PR action, pin movement, or code change.
Use current primary sources. Treat catalogs, blogs, social media, talks, and search snippets only as discovery.
For recency requests, use an explicit UTC interval and the bounded primary-source fallback; never claim a last30days capability unless its installed SKILL.md was inspected.
Prefer a maintained free/open-source library, tool, generator, plugin, skill, or self-hostable service only when it satisfies the documented contract and deletes project ownership.
Check the pinned vcpkg registry before proposing a C++ overlay. Never propose FetchContent, CPM, vendoring, floating refs, or ad hoc installers.
Return EcosystemAdviceV1 with immutable evidence, license/maintenance/compatibility, deletion ledger, maturity and rollback, affected goal items, fixture gate, authority needs, ambiguity, and recheck trigger.
Do not edit the canonical goal. The primary controller decides whether and how to synthesize accepted evidence.
"""

[mcp_servers.openaiDeveloperDocs]
url = "https://developers.openai.com/mcp"
```

`gpt-5.6-sol/xhigh` follows the repository's architecture/research policy. Routine unchanged-state
collection should be deterministic and use no model; do not downshift a consequential synthesis to
Terra merely to make a permanent watcher cheaper. The custom-agent file's sandbox is not an
absolute boundary when a parent turn supplies live permission overrides: official docs say parent
runtime overrides are reapplied to spawned children. Spawn this role only from a read-only parent
turn when hard enforcement matters, and keep the no-mutation developer instruction as defense in
depth. Do not set `CODEX_HOME`, `CODEX_SQLITE_HOME`, authentication variables, or `RUST_LOG` in this
agent. Codex says durable settings belong in `config.toml`; environment variables are for scoped
locations, secrets, installers, or diagnostics.

## Codex and ChatGPT capabilities worth evaluating

- Project custom agents are now first-class under `.codex/agents/`; the required fields are
  `name`, `description`, and `developer_instructions`, with model, effort, sandbox, MCP, and skill
  configuration available as ordinary config layers.
- Multi-agent tools are enabled by default and support a concurrency cap. Keep the cap measured and
  use bounded read-heavy agents; official guidance warns that subagents consume more tokens and
  write-heavy parallelism increases conflicts.
- Use the official OpenAI Developer Docs MCP for API/config verification. Use the existing
  `track-github-upstream` skill for immutable GitHub gap analysis. Do not create a second generic
  upstream watcher until its report contract demonstrably fails.
- Skills use progressive disclosure and the initial skill list has a 2%/8,000-character budget.
  Prefer a focused skill after a workflow repeats; package a plugin only for distribution or a
  connector bundle. Avoid installing unrelated plugins.
- Lifecycle hooks are stable, additive across layers, and trust-gated. Evaluate them only for
  deterministic local checks with bounded timeouts; never place model judgment, tracker writes,
  credential handling, or goal authority in a hook.
- Scheduled tasks can use skills/plugins and isolated worktrees, but local runs require the Mac and
  desktop app to stay running and run unattended with default permissions. Pilot only a read-only
  deterministic collector after its prompt and no-change behavior pass manually; do not schedule
  repository writers yet.
- Desktop settings useful now: **Prevent sleep while running**, follow-up behavior defaulting to
  **Queue** for independent follow-ups, completion/question notifications, the diff panel and inline
  review comments, integrated terminal, and project local-environment actions for documented
  preflight/test commands.
- Goal mode and separate side chats support status checks without contaminating the active goal;
  parallel writable chats still require isolated worktrees and non-overlapping claims.
- July 2026 official updates add multi-folder local projects, Voice-based task steering, and iOS
  inline Codex visualizations. Use iOS/Voice for monitoring and steering only; they do not replace
  durable repository evidence, exact-SHA review, or task authority.
- Live web search is appropriate for the bounded recency lane. Cached search is safer and remains
  appropriate for non-current discovery. Treat all web results as untrusted.

Primary Codex sources:

- [Subagents and custom agents](https://learn.chatgpt.com/docs/agent-configuration/subagents)
- [Configuration](https://learn.chatgpt.com/docs/config-file/config-basic)
- [Environment variables](https://learn.chatgpt.com/docs/config-file/environment-variables)
- [Skills](https://learn.chatgpt.com/docs/build-skills)
- [Plugins](https://learn.chatgpt.com/docs/plugins)
- [Hooks](https://learn.chatgpt.com/docs/hooks)
- [Scheduled tasks](https://learn.chatgpt.com/docs/automations)
- [Desktop settings](https://learn.chatgpt.com/docs/reference/settings)
- [Long-running work and Goal mode](https://learn.chatgpt.com/docs/long-running-work)
- [Remote connections / iOS](https://learn.chatgpt.com/docs/remote-connections)
- [What's new](https://learn.chatgpt.com/docs/whats-new)
- [Codex changelog](https://learn.chatgpt.com/docs/changelog)

## Maintained reuse candidates

Evaluate these only when their named gate is reached; this list does not adopt them:

| Capability | Candidate | Why it may delete ownership | Gate / caution |
| --- | --- | --- | --- |
| Pinned dependency update proposals | [Renovate](https://docs.renovatebot.com/) | Self-hostable updater with Docker, GitHub release/tag datasources, package rules, minimum release age, and custom regex/JSONata managers for otherwise unsupported pins | Compare with existing reviewed overlay-update workflow; proposals only, immutable pins, no autonomous merge until hostile fixtures and branch rules pass |
| Documentation link drift | [lychee](https://github.com/lycheeverse/lychee) | Maintained CLI/action for Markdown/HTML links | Pin exact binary/action; fixture authenticated, rate-limited, social, anchor, redirect, and offline behavior before making required |
| Prose/style drift | [Vale](https://vale.sh/docs) | Offline, versionable documentation rules rather than an LLM style checker | Start with small project vocabulary and factual anti-drift rules; avoid noisy subjective defaults |
| C++ API/reference synchronization | [MrDocs](https://mrdocs.com/docs/mrdocs/) | Clang-based corpus from the compilation database; understands templates, concepts, coroutines, and deduced types | Differential documentation tool only because GCC 16.1 remains executable authority; pin toolchain and verify reflection branch behavior |
| Documentation site | [MkDocs](https://www.mkdocs.org/) + [Material](https://squidfunk.github.io/mkdocs-material/) | Static site over canonical Markdown without inventing a portal | Build locally first; GitHub Pages publication is separately authorized external mutation |
| Architecture/workflow diagrams | [Mermaid](https://mermaid.js.org/) and [Graphviz](https://graphviz.org/documentation/) | Text sources can be reviewed and drift-checked | Generate from authoritative schemas/graphs where possible; hand-authored diagrams need executable link/mapping checks |
| Vulnerability and supply-chain evidence | [OSV-Scanner](https://google.github.io/osv-scanner/) and [OpenSSF Scorecard](https://scorecard.dev/) | Existing scanners can supplement pinned vcpkg/SBOM evidence | Evaluate coverage for C++/vcpkg and false-positive policy; neither replaces lock review, compiler tests, or human dependency decisions |

The immediate highest-value evaluations are not new orchestration services: first use the existing
upstream-watch skill and official docs MCP, then fixture `lychee`/Vale/MrDocs as documentation drift
checks, and compare Renovate against the already documented overlay-update mechanism. This avoids
building another watcher while the core context-policy and typed-record slices remain ahead in the
canonical goal.

## Synthesis recommendation

Add this advisor as an on-demand custom role, not a permanent autonomous swarm member. Its accepted
result should flow:

`deterministic delta -> read-only advisor -> primary-agent evidence check -> task/issue steward
deduplication -> canonical goal reorder -> owner gate if authority expands -> fixture-first slice`.

Suggested companion roles, without increasing concurrent write lanes:

1. `task_issue_steward`: read-only reconciliation of goal, GitHub, Linear, and PR state; proposes
   deduplicated mutations to a separately authorized operator.
2. `docs_drift_verifier`: exact-SHA code/docs/diagram mapping and generated-artifact verification;
   findings only.
3. `ecosystem_codex_advisor`: this role; primary-source reuse and capability deltas.

The primary agent should synthesize all three. A separate permanent “plan synthesizer” would
duplicate controller authority; use a bounded Sol/xhigh planner only when findings materially
contradict or reorder the approved goal. With four total concurrency slots, run at most two
read-only advisors alongside the primary and preserve one slot for exact-diff review/triage. Stop
or defer advisors when the implementation lane reaches a publication/review gate.

Unresolved owner decisions:

- Which tracker is authoritative if a goal item exists in both GitHub and Linear, and which exact
  mutations may the future tracker operator perform autonomously?
- Should scheduled read-only ecosystem collection run weekly, release-triggered only, or both?
- Is iOS/Voice monitoring desirable given that repository evidence, not mobile state, remains
  authoritative?
