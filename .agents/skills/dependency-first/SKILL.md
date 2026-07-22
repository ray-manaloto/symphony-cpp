---
name: dependency-first
description: Enforce third-party-first architecture for symphony-cpp. Use before implementing or expanding any subsystem, protocol, parser, serializer, database layer, concurrency primitive, networking layer, CLI, build tool, test utility, code generator, or service integration; also use when replacing or reviewing custom infrastructure.
---

# Dependency First

Prefer deleting ownership. Do not build a capability from scratch when a maintained library, tool,
generator, or permitted service already supplies it. Only the project owner may authorize an
exception.

## Gate

1. State the capability and acceptance constraints before writing implementation code.
2. Search current primary sources, the pinned vcpkg registry, and existing repository research.
3. Compare credible maintained candidates on API fit, C++26/GCC 16 and clang-p2996 compatibility,
   license, security, maintenance, async/cancellation behavior, deterministic tests, and removal of
   repository-owned code.
4. Choose the smallest maintained capability that satisfies the contract. Prefer generation over
   handwritten protocol/schema code and a thin adapter over a local reimplementation.
5. Record the choice in `docs/dependency-decisions.md` before implementation.
6. If no candidate passes, stop and ask the owner to authorize a named custom implementation. Record
   the exact authorization and deletion/re-evaluation trigger. Silence is not authorization.

Product-specific Symphony state transitions may be authored locally only when the normative spec
defines behavior rather than a reusable implementation. Commodity mechanisms beneath them still
pass this gate.

## Constraints

- Use vcpkg manifest mode and the pinned registry. A missing port requires a minimal, pinned overlay
  with source hashes and an exit criterion.
- Do not add FetchContent, CPM, vendored source trees, floating Git refs, or ad hoc installers.
- Do not introduce a second library for a capability already owned by the selected stack unless a
  recorded deletion test proves the first cannot meet the contract.
- Do not let a service choice expand authority for credentials, paid usage, deployment, live tracker
  mutation, or private data.
- Keep third-party types behind repository interfaces where domain portability or durable schemas
  require it; adapters must remain thinner than a reimplementation.

## Learning loop

When work duplicates an available dependency, a candidate is discovered late, or a selected tool
fails its gate:

1. Record the observed failure, evidence, correction, and regression guard in
   `docs/implementation-log.md`.
2. Update `docs/dependency-decisions.md` and the relevant architecture/source entry.
3. Strengthen this skill or `scripts/check-dependency-policy.mjs` when the failure pattern can recur.
4. Re-run the policy check and affected build/test gate.

Do not create a follow-up note in place of the correction.
