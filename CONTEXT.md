# Symphony C++ context

`symphony-cpp` is a standalone, fixture-first C++26 implementation of OpenAI Symphony Draft v1.
The daemon polls a tracker, assigns eligible issues to isolated workspaces, drives Codex app-server,
reconciles tracker state, and exposes redacted operational state.

The trust boundary is a single operator-controlled Linux host. Tracker, workspace, agent runtime,
clock, event store, and status output are explicit interfaces. The default development profile uses
only deterministic fakes and never mutates a real tracker or repository.

The anti-spin invariant is strict: after the first unchanged progress fingerprint, Symphony permits
one corrective continuation; a second unchanged result terminates the attempt as
`stalled_no_progress`.

OpenSymphony v2.10.0 is a pinned, local-only development orchestrator around this repository; it is
not part of the C++ service or a conformance authority. Its image is built locally, never published,
and kept outside the interactive devcontainer. Full feature evaluation uses internal Docker
networks, disposable state, and fake Linear/GitHub/model services. The completed `GUI-5` run is the
sole live canary.

OpenSymphony does not enforce the approved run, effort, progress, failure, or context policy. The
external C++26 supervisor therefore fails closed after four model-backed runs, 90 minutes, two
unchanged/repeated-failure results, missing telemetry, or failed checkpoint reconciliation. It
checkpoints at 50%, finishes only an atomic handoff slice at 60%, and authorizes no continuation at
65% of last-turn input tokens over the reported positive context window. Compaction immediately
requires a durable fresh-session rollover.

Stable compiler bases are built on native GitHub AMD64 and ARM64 runners and published only through
the guarded image ceremony. Apple Silicon daily development uses the ARM64 child of a reviewed
multi-platform GCC 16.1 index; AMD64 remains an explicit executable-semantics parity profile.
Caches and configured build trees never cross compiler or architecture boundaries.
