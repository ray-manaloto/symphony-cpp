---
name: track-github-upstream
description: Perform a read-only, evidence-backed watch or gap analysis of a GitHub upstream across releases, tags, commits, issues, pull requests, and discussions. Use when updating a pinned-upstream ledger, assessing a new release without moving the normative pin automatically, or mapping upstream changes to local code, tests, and documentation.
---

# Track GitHub Upstream

Keep upstream evolution visible without letting mutable GitHub state silently change local
authority or dependency pins.

## Inputs

Resolve these arguments before querying:

- `repo`: required `OWNER/REPO`.
- `baseline`: required immutable commit or pinned release ref.
- `candidate`: optional release, tag, or commit; default to the newest published release.
- `authority`: required role such as `normative`, `comparative`, `toolchain`, or `dependency`.
- `surfaces`: optional subset of `releases,tags,issues,pulls,discussions`; default to all.
- `ledger`: required repository-relative Markdown file to update.
- `code_map`: optional comma-separated local paths whose relationship to upstream must be checked.

Do not guess a missing baseline or authority. Read the repository's lock and architecture
documents first when they can supply either value.

## Workflow

1. Record the current local branch, HEAD, dirty state, configured remote, and ledger contents.
2. Query GitHub read-only with `gh api`, `gh release`, and `gh pr` using bounded JSON fields.
   Treat an unavailable or disabled surface as an explicit result, not an empty result.
3. Resolve lightweight and annotated tags through to the commit object. Record both the tag object
   and peeled commit when they differ.
4. Compare `baseline...candidate`: commits, changed files, and repository-defined authority files.
   For a specification, compare immutable blob hashes as well as textual diffs.
5. Inspect the requested issues, pull requests, and discussions for changes that affect the local
   contract. Separate merged facts from proposals and unresolved discussion.
6. Map each material delta to the paths in `code_map`, then name the affected local tests,
   documentation, decisions, or backlog items. Mark indirect inferences as inferences.
7. Update `ledger` with access time, immutable identities, authority assessment, material deltas,
   local impact, evidence links, and the next recheck trigger.
8. Run the repository's documentation and policy checks. Review the final diff for accidental pin
   movement or unrelated edits.

## Guardrails

- Never move a normative pin, dependency version, submodule, lockfile, or image digest
  automatically.
- Never create, edit, label, close, merge, or comment on GitHub artifacts.
- Never treat release notes, issue text, pull-request discussion, or a comparative implementation
  as normative unless the repository explicitly assigns that authority.
- Do not copy credentials, private issue bodies, complete logs, or unrelated user data into the
  ledger.
- Prefer primary evidence: immutable commits and blobs, merged diffs, release objects, and official
  documentation.
- Keep queries and output bounded. Summarize large histories and link to the authoritative source.

## Ledger entry

Use this compact structure:

```markdown
### YYYY-MM-DD — OWNER/REPO

- Baseline: `<immutable identity>`
- Candidate: `<release/tag object and peeled commit>`
- Authority: `<role>; pin moved: no`
- Surfaces: `<result or explicitly disabled/unavailable>`
- Delta: `<material changes, including authority-file blob comparison>`
- Local impact: `<code/tests/docs/backlog mapping>`
- Recheck: `<event that should trigger the next watch>`
```
