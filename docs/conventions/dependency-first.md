# Dependency-first engineering

The project owner requires symphony-cpp to use an existing maintained library, tool, generator, or
permitted service whenever one satisfies the required capability. Codex may not decide to build a
replacement from scratch. A custom implementation requires the owner's explicit, capability-specific
authorization recorded in [`docs/dependency-decisions.md`](../dependency-decisions.md).

This policy applies to new work and to custom bootstrap code encountered during refactoring. It does
not mean blindly adding dependencies: candidates must pass license, security, maintenance,
determinism, supported-toolchain, isolation, and deletion-value gates. When no candidate passes,
implementation pauses for the owner's decision.

Required workflow:

1. Define the capability and constraints.
2. Reuse current research or perform a bounded primary-source search.
3. Check the pinned vcpkg registry before creating an overlay.
4. Record the selected provider and rejected alternatives.
5. Generate schemas/protocol clients when maintained generation exists.
6. Implement only the thinnest project-specific adapter and Symphony behavior.
7. Add a regression test and a dependency removal/re-evaluation trigger.

The project-local `dependency-first` skill is mandatory for this workflow. The automated policy
check rejects known dependency bypasses and missing governance files; semantic enforcement remains
part of design review because no textual scan can reliably distinguish product behavior from a
reimplementation.
