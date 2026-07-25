# Repository guidance

This repository implements OpenAI Symphony Draft v1 as a standalone C++26 service.

- `docs/upstream-lock.md` pins the normative specification and experimental toolchains.
- GCC 16.1 defines executable semantics. Bloomberg clang-p2996 is differential-only.
- Core code is C++26. Do not introduce Rust, Node.js, or a dependency on another repository.
- Run the project-local `dependency-first` skill before implementing or expanding any subsystem,
  protocol, parser, serializer, database layer, concurrency primitive, network layer, CLI, build
  tool, test utility, generator, or service integration. Use maintained third-party capabilities
  whenever they meet the contract. Codex may not authorize custom replacements; record explicit
  owner exceptions in `docs/dependency-decisions.md` before implementation.
- For nontrivial OpenSymphony-managed issue work, consult the project-local
  `opensymphony-memory` skill before planning. Memory is private, non-authoritative context;
  verify it against current source and tests, and never archive tracker work without explicit
  authorization.
- All third-party C++ dependencies use the pinned vcpkg manifest/overlays. FetchContent, CPM,
  ExternalProject source builds, vendored dependency trees, and floating refs are prohibited.
- Work fixture-first. Real tracker mutation, production credentials, deployment, image publication,
  privileged installation, and force-push are outside current authorization.
- Add a failing test before changing observable behavior. Run `ctest --preset gcc-debug` for focused
  development and the documented container matrix before declaring conformance.
- Keep secrets and issue content out of logs. Redact at the structured event boundary.
- Never hand-edit generated reflection fixtures under `fixtures/generated/`.
- Run `node scripts/check-dependency-policy.mjs` with source/config changes.
- The repository-local `.codex/goals/active.json` marks only the controller bootstrap as complete.
  Ongoing work is tracked through the native Codex goal until this standalone project deliberately
  adopts its own controller; never borrow goal state or leases from another repository.
- Public pushes use `scripts/check-adaptive-orchestration.mjs` only as an exact-range redacted
  publication gate. It is not part of the C++ service, daemon runtime, or orchestration controller.
- Native specialist-agent roles follow `docs/agent-orchestration.md`. Dispatch only bounded,
  event-triggered read-only roles in parallel; the primary controller alone updates the canonical
  goal and integration worktree. No tracker or pull-request mutation agent is currently authorized.
- Before requesting owner approval or asking a material question, complete bounded primary-source
  research and present viable options, pros, cons, a recommendation, and the consequence of
  deferring. Missing credentials, access, or evidence is not research resolution.
