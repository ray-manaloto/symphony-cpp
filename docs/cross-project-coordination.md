# Cross-project coordination

The two repositories are separate ChatGPT/Codex project contexts:

- [`ray-manaloto/honeymoon-period`](https://github.com/ray-manaloto/honeymoon-period) owns product
  requirements and any decision to consume or integrate the standalone service.
- [`ray-manaloto/symphony-cpp`](https://github.com/ray-manaloto/symphony-cpp) owns the C++26
  implementation, conformance, toolchains, containers, and development orchestration.

Neither repository may edit the other's worktree or borrow its goal, lease,
credential, publication, or archival state. Cross-project changes travel through
committed contracts and explicit handoffs. A handoff records repository URL,
exact commit, affected contract or artifact, verification evidence, and the next
owner; it links source material instead of copying conversation history.

The initial integration boundary is intentionally informational. No runtime
dependency from `honeymoon-period` to `symphony-cpp` exists until both projects
approve a versioned provider-neutral API contract.
