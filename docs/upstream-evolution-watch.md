# Upstream evolution watch

This ledger tracks upstream changes that may affect Symphony conformance, orchestration behavior,
or the development environment. It does not move immutable pins automatically. Every adoption still
requires an exact revision, a scoped gap analysis, and the repository's normal tests and publication
gate.

## OpenAI Symphony

The normative implementation input remains OpenAI Symphony Draft v1 at
`1f3219bb1ea5f69a1305dc594e79b0db57c113c5`.

### v0.0.2 assessment

Accessed 2026-07-24.

- Release: [`v0.0.2`](https://github.com/openai/symphony/releases/tag/v0.0.2), published
  2026-07-24 at 15:01:31 UTC.
- Annotated tag object: `c1b2c519e9300bc93b78527bebdaddef5163d702`.
- Release commit: `653f8b3cc476db03420479ba6f95b2ed7281c401`.
- The release commit is one commit ahead of the normative pin. The only changed file is
  `elixir/mix.exs` with one addition and one deletion for the version bump.
- `SPEC.md` is unchanged: both revisions resolve to blob
  `a6b44e162383e7241a76bce85afb7a8e8d704c45` (91,923 bytes).
- Result: no Draft v1 requirement or current C++ conformance fixture changes are required for this
  release. The release notes still provide comparative evidence for generic trackers, terminal
  cleanup, retry freshness, workspace setup recovery, and tool-input safety; those implementation
  areas remain subject to ordinary requirement-to-test review.
- GitHub Issues are disabled for `openai/symphony`. Pull requests and Discussions are enabled, so
  the watch must record the disabled issue surface rather than silently returning an empty list.

### Recurring release gate

- [ ] Resolve every new release/tag to its annotated tag object, commit, and tree.
- [ ] Compare the new commit with the current normative pin and record every changed path.
- [ ] Hash and compare `SPEC.md`; map each changed clause to C++ source, tests, ADRs, and diagrams.
- [ ] Review release notes and merged PRs for behavioral oracle changes even when the spec is stable.
- [ ] Snapshot open PRs and recent Discussions; record whether Issues remain disabled.
- [ ] Classify each delta as normative, reference-implementation-only, tooling, documentation, or
      irrelevant to this standalone C++ service.
- [ ] Update an immutable pin only after focused GCC 16.1 tests and the complete required matrix pass.

## OpenSymphony

OpenSymphony remains a comparative, local-only development orchestrator. It is not the normative
Symphony specification or a C++ runtime dependency.

### 2026-07-24 — kumanday/OpenSymphony

- Baseline: pinned unsigned annotated tag `v2.10.0`, tag object
  `26750bbd9aa648297a083db24fb48681a523713b`, peeled commit
  [`0cc21ddda5d1853a8fbd11add578b43b6ebd6fcb`](https://github.com/kumanday/OpenSymphony/commit/0cc21ddda5d1853a8fbd11add578b43b6ebd6fcb).
- Candidate: unsigned annotated tag `v2.10.1`, tag object
  `530fa8fee49ec0338d4eae733876ae394b20d95c`, peeled commit
  [`d72bb0a409c006e20f2b0d766a0def218f94cd41`](https://github.com/kumanday/OpenSymphony/commit/d72bb0a409c006e20f2b0d766a0def218f94cd41).
- Authority: comparative orchestrator; pin moved: no.
- Surfaces: the repository has tags but no GitHub Release objects. Discussions are disabled.
  [Issue #227](https://github.com/kumanday/OpenSymphony/issues/227) remains open and unchanged
  since the exact Rust 1.93 reproduction; no pull request is linked to either candidate commit or
  the issue.
- Delta: the candidate is two commits ahead of the baseline. One commit makes legacy DuckDB
  code-graph catalogs tolerate absent snapshot tables; the other changes code-graph rendering and
  bumps release metadata. Neither commit changes the missing-`gh` process classification or its
  failing memory integration test. The repository's `main` ref still resolves to the baseline
  commit, while `develop` contains the candidate. The only reported check on the candidate commit
  is a changelog-sync dispatch rather than the locked Rust/Linux suite, so its commit-message test
  claims are not regression evidence for issue #227.
- Local impact: do not update `docs/upstream-lock.md`, rebuild the local image, or classify
  OpenSymphony as healthy from `v2.10.1`. The complete pinned upstream suite remains blocked by
  issue #227, and the current local image remains diagnostic-only. The code-graph fixes are
  relevant to later full-feature acceptance but do not unblock doctor, the documented contained
  dry run, or operational promotion.
- Recheck: a new immutable tag, a change to issue #227, or an upstream commit that changes the
  missing-command fixture or the two `gh` process launches.

## Environment and toolchain alignment backlog

- [ ] Compare the pinned
      [`openai/codex-universal`](https://github.com/openai/codex-universal) revision and image digests
      with its current Dockerfile, setup script, verification workflow, AMD64/ARM64 behavior, and
      `CODEX_ENV_*` contract.
- [ ] Map the repository devcontainers to the official
      [local](https://learn.chatgpt.com/docs/environments/local-environment) and
      [cloud](https://learn.chatgpt.com/docs/environments/cloud-environment) environment contracts.
      Preserve one source-derived toolchain contract while allowing local lifecycle configuration
      to differ from Codex cloud setup.
- [ ] Review the existing
      [`ray-manaloto/dotfiles` compiler CI](https://github.com/ray-manaloto/dotfiles/blob/main/.github/workflows/ci.yml)
      and its
      [devcontainer guidance](https://github.com/ray-manaloto/dotfiles/blob/main/.devcontainer/AGENTS.md)
      as comparative evidence. Do not copy cross-project state or floating image tags.
- [ ] Review
      [`bloomberg/clang-p2996` Actions](https://github.com/bloomberg/clang-p2996/actions) and pinned
      workflow source for its compiler/runtime build flags, caches, tests, artifacts, and license
      handling.

## mise and hook migration backlog

The repository already uses locked mise for its lint-tool environment and installs pre-commit and
pre-push hooks. The next step is measured consolidation, not a second uncontrolled hook stack.

- [ ] Evaluate [`jdx/hk`](https://github.com/jdx/hk) against the current pre-commit configuration,
      hook stages, staged-file semantics, parallelism, caching, failure output, and CI parity.
- [ ] Produce a deletion ledger showing which pre-commit wrappers hk would replace. Do not run both
      owners for the same check indefinitely.
- [ ] Pin mise, hk, plugins, and transitive acquisition metadata; keep global mise configuration
      isolated from repository setup.
- [ ] Review
      [`brentmitchell25/mise-plugin`](https://github.com/brentmitchell25/mise-plugin) as behavioral
      input only. Evaluate the official
      [`openai/openai-developers-for-claude`](https://github.com/openai/openai-developers-for-claude),
      [`yibie/plugin-claude-2-codex`](https://github.com/yibie/plugin-claude-2-codex), and
      [`tokenRollAI/acplugin`](https://github.com/tokenRollAI/acplugin) conversion paths before
      porting; never execute third-party migration code without review.

## Reusable tracking capability

- [ ] Forward-test the parameterized upstream-watch skill with OpenAI Symphony and codex-universal.
- [ ] Package it as a personal plugin only after the skill's report schema and read-only GitHub
      boundary stabilize. A plugin may contain the skill and use existing GitHub capabilities; it
      must not embed credentials or a repository-specific token.
- [ ] Decide explicitly whether a later marketplace entry is personal or repository/team scoped
      before generating it.
- [ ] Add automation only after its frequency, notification behavior, retained evidence, and
      no-mutation boundary are reviewed.
