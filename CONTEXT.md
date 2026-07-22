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

