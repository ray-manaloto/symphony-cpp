# Fixture guidance

The repository-root `AGENTS.md` applies here.

- `p2996_reflection_probe.cpp` is a byte-pinned input to the published GCC 16.1 and clang-p2996
  compiler artifact identities. Do not edit or mechanically format it without an explicitly
  reviewed artifact-identity migration or recipe/package rotation.
- See
  [`docs/toolchain-and-devcontainer-workflow.md`](../../docs/toolchain-and-devcontainer-workflow.md#byte-stable-compiler-recipe-probe)
  for the rationale and removal condition.
- All other C++ fixtures remain subject to exact LLVM 22.1.8 formatting and the normal compiler
  matrix.
- After fixture or source-enumeration changes, run `./scripts/test-analysis-toolchain-contract.sh`,
  `./scripts/test-toolchain-platform-contract.sh`, and `./scripts/check-local-preflight.sh quick`.
