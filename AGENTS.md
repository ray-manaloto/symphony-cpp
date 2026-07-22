# Repository guidance

This repository implements OpenAI Symphony Draft v1 as a standalone C++26 service.

- `docs/upstream-lock.md` pins the normative specification and experimental toolchains.
- GCC 16.1 defines executable semantics. Bloomberg clang-p2996 is differential-only.
- Core code is C++26. Do not introduce Rust, Node.js, or a dependency on another repository.
- Work fixture-first. Real tracker mutation, production credentials, deployment, image publication,
  privileged installation, and force-push are outside current authorization.
- Add a failing test before changing observable behavior. Run `ctest --preset gcc-debug` for focused
  development and the documented container matrix before declaring conformance.
- Keep secrets and issue content out of logs. Redact at the structured event boundary.
- Never hand-edit generated reflection fixtures under `fixtures/generated/`.
- The repository-local `.codex/goals/active.json` marks only the controller bootstrap as complete.
  Ongoing work is tracked through the native Codex goal until this standalone project deliberately
  adopts its own controller; never borrow goal state or leases from another repository.
