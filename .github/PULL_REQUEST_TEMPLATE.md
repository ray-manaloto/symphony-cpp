## Dependency-first evidence

- [ ] I reused an existing selected dependency, tool, generator, or permitted service.
- [ ] Any new capability has a decision-ledger entry backed by current primary-source research.
- [ ] Any custom implementation includes explicit, capability-specific owner authorization.
- [ ] Dependencies use the pinned vcpkg registry or a pinned, hashed overlay with an exit criterion.
- [ ] I did not add FetchContent, CPM, ExternalProject, vendored dependencies, or floating refs.
- [ ] `node scripts/check-dependency-policy.mjs` passes.

## Verification

Describe the focused tests and CI evidence.
