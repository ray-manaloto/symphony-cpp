---
name: opensymphony-memory
description: Consult contained OpenSymphony project memory before planning nontrivial issue work, during review rework, and before documentation updates.
---

# OpenSymphony Memory

Use this skill when working on an OpenSymphony-managed issue after the contained
memory volume has been initialized. Memory is learned context from completed
fixture work. Current source, tests, specifications, and user instructions
remain authoritative.

## When to consult memory

- At kickoff for a nontrivial issue, after reading its body and before planning.
- After identifying likely files, directories, or subsystem areas.
- During review rework that resembles a prior failure mode.
- Before changing documentation or behavior covered by existing topic docs.

## Contained commands

Use the repository launcher so neither credentials nor the host home directory
are exposed:

```bash
./scripts/opensymphony-container.sh memory-status
./scripts/opensymphony-container.sh memory-context GUI-5
```

Run the smallest command that answers the question. Do not invoke a host
`opensymphony` binary or inspect the Docker volume directly.

## Rules

- Do not create or update issue capsules during ordinary implementation.
  Capture belongs to the OpenSymphony run loop.
- Never archive a Linear issue unless the user explicitly authorizes that exact
  mutation. Automatic archival remains disabled.
- Do not rewrite public docs from private memory by hand.
- Do not copy complete prompts, transcripts, credentials, or issue content into
  memory or documentation.
- Treat stale, missing, or warning-heavy memory as a pointer to stronger
  evidence, not as proof.

## Interpretation

Prefer source references such as issue IDs, pull requests, and commit SHAs when
making audit claims. Verify them against current source and tests before acting.
