# Research sources and ingestion checklist

Primary sources define behavior; comparisons only identify possible gaps. Accessed 2026-07-22
through 2026-07-24.

The agent model and effort recommendation additionally uses the current
[OpenAI model guidance](https://developers.openai.com/api/docs/guides/latest-model),
[model catalog](https://developers.openai.com/api/docs/models), and
[Codex configuration schema](https://github.com/openai/codex/blob/main/codex-rs/core/config.schema.json).

- [x] [OpenAI Symphony repository and Draft v1 specification](https://github.com/openai/symphony), pinned at `1f3219b`
- [x] [GCC 16.1 release sources](https://ftp.gnu.org/gnu/gcc/gcc-16.1.0/)
- [x] [Bloomberg clang-p2996](https://github.com/bloomberg/clang-p2996), pinned at `7220baff`
- [x] [OpenAI codex-universal](https://github.com/openai/codex-universal), image digest pinned separately
- [x] [OpenSymphony](https://github.com/kumanday/OpenSymphony), comparative only, pinned at `0cc21ddd` (`v2.10.0`)
- [x] [Verdent Symphony architecture deep dive](https://www.verdent.ai/guides/openai-symphony-architecture-deep-dive), comparative only
- [x] [OpenAI Tart](https://github.com/openai/tart), deferred Apple-Silicon executor
- [x] [Tart Guest Agent](https://github.com/openai/tart-guest-agent), deferred guest operations
- [x] [OpenAI Softnet](https://github.com/openai/softnet), deferred privileged network isolation
- [x] [OpenAI Orchard](https://github.com/openai/orchard), deferred multi-host scheduling
- [x] [OpenAI OpenAPI](https://github.com/openai/openai-openapi), pinned REST API schema and generated C++ reference surface
- [x] [OpenAPI Generator](https://github.com/OpenAPITools/openapi-generator), pinned C++ Boost.Beast reference generator
- [x] [Glaze](https://github.com/stephenberry/glaze) and its [HTTP/REST](https://stephenberry.github.io/glaze/networking/http-rest-support/), [REPE RPC](https://stephenberry.github.io/glaze/rpc/repe-rpc/), and [P2996](https://stephenberry.github.io/glaze/p2996-reflection/) documentation
- [x] [PicoSHA2](https://github.com/okdshin/PicoSHA2) `v1.0.1` for the Draft v1 stable workspace-key hash suffix
- [x] [`openalgz/ut`](https://github.com/openalgz/ut), selected unit and compile-time test library
- [x] [vcpkg manifest mode and versioning](https://learn.microsoft.com/en-us/vcpkg/concepts/manifest-mode), selected dependency manager
- [x] [vcpkg `vcpkg_from_github`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_from_github), immutable overlay `REF` and SHA-512 authority
- [x] [GitHub Actions workflows](https://docs.github.com/en/actions/concepts/workflows-and-actions/workflows), [`GITHUB_TOKEN`](https://docs.github.com/en/actions/concepts/security/github_token), and the [GitHub CLI](https://cli.github.com/manual/), scheduled reviewed overlay-update mechanism
- [x] GitHub autonomous-merge controls: [repository rulesets](https://docs.github.com/en/rest/repos/rules), [required-check rules and app binding](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets), [required-check troubleshooting](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks), [merge queues](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/merging-a-pull-request-with-a-merge-queue), [Checks API](https://docs.github.com/en/rest/checks/runs), [GitHub App least privilege](https://docs.github.com/en/apps/creating-github-apps/about-creating-github-apps/best-practices-for-creating-a-github-app), and [`gh pr merge --match-head-commit`](https://cli.github.com/manual/gh_pr_merge)
- [x] [`reflect-cpp`](https://github.com/getml/reflect-cpp) and [`sqlgen`](https://github.com/getml/sqlgen), persistence/reflection comparisons
- [x] [`klemens-morgenstern/sqlite`](https://github.com/klemens-morgenstern/sqlite), selected synchronous SQLite adapter behind the persistence executor
- [x] [`fmt`](https://github.com/fmtlib/fmt), [`scnlib`](https://github.com/eliaskosunen/scnlib), and [Boost.Decimal](https://github.com/boostorg/decimal)
- [x] [Intel bare-metal concurrency](https://github.com/intel/cpp-baremetal-concurrency), [senders/receivers](https://github.com/intel/cpp-baremetal-senders-and-receivers), [compile-time init/build](https://github.com/intel/compile-time-init-build), and [standard extensions](https://github.com/intel/cpp-std-extensions)
- [x] [Intel Safe Arithmetic](https://github.com/intel/safe-arithmetic) and [generic register operation optimizer](https://github.com/intel/generic-register-operation-optimizer), plus curated [Boost.MP11](https://www.boost.org/libs/mp11), [Frozen](https://github.com/serge-sans-paille/frozen), [Tesla fixed-containers](https://github.com/teslamotors/fixed-containers), and [magic_enum](https://github.com/Neargye/magic_enum) compile-time comparisons
- [x] [`mirror_bridge`](https://github.com/FranciscoThiesen/mirror_bridge), [`imrefl`](https://github.com/fullptr/imrefl), and [`splice`](https://github.com/FloofyPlasma/splice), reflection references only
- [x] [NVIDIA `stdexec`](https://github.com/NVIDIA/stdexec), current reference implementation for C++26 `std::execution`
- [x] [Development Containers specification](https://github.com/devcontainers/spec), [reference CLI](https://github.com/devcontainers/cli), and [CI action](https://github.com/devcontainers/ci)
- [x] Native multi-architecture toolchains: [GCC configure](https://gcc.gnu.org/install/configure.html), [AArch64 target notes](https://gcc.gnu.org/install/specific.html), [GCC 16 changes](https://gcc.gnu.org/gcc-16/changes.html), [LLVM host/target build guidance](https://llvm.org/docs/GettingStarted.html), [LLVM 22.1.8 release assets and attestations](https://github.com/llvm/llvm-project/releases/tag/llvmorg-22.1.8), [GitHub-hosted ARM64 runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners), and Docker's [native multi-platform CI architecture](https://docs.docker.com/build/ci/github-actions/github-builder/architecture/) and [multi-platform build guidance](https://docs.docker.com/build/building/multi-platform/)
- [x] Architecture-scoped caches: Docker [GitHub Actions cache backend](https://docs.docker.com/build/cache/backends/gha/) and the [ccache manual](https://ccache.dev/manual/4.13.6.html)
- [x] [LLVM clang-tidy](https://clang.llvm.org/extra/clang-tidy/) and [Include-What-You-Use](https://include-what-you-use.org/)
- [x] [r/cpp](https://www.reddit.com/r/cpp/), practitioner discovery only; consequential claims require primary-source verification
- [ ] [Cpplang Slack](https://cpplang.slack.com/), monitoring deferred until the owner explicitly authorizes plugin installation and workspace access

Research preflight: both lanes were refreshed on 2026-07-22. The primary-source evaluation is in
[`cpp-library-evaluation.md`](cpp-library-evaluation.md). The recent-practitioner raw report is under
`.build/research/last30days`; it was noisy and thin, so it did not override primary documentation.
Consequential implementation claims were rechecked against owning repositories.

The broader, maintainable discovery and engineering-tool inbox is
[`cpp-ecosystem-catalog.md`](cpp-ecosystem-catalog.md). Entries there are not adopted dependencies;
they carry authority and status labels so catalogs, blogs, talks, and social feeds cannot silently
override primary evidence.

The focused deletion ledger for compile-time and Intel candidates is
[`compile-time-library-review.md`](compile-time-library-review.md). It lists every reviewed
candidate, the selected providers, and explicit re-evaluation triggers.

The runtime comparison is in
[`elixir-vs-rust-runtime-comparison.md`](elixir-vs-rust-runtime-comparison.md). Run the official
Elixir implementation first as the pinned Draft v1 and Codex app-server behavioral oracle. Use
Rust OpenSymphony second, fixture-only, for differential scenarios and feature mining; its
OpenHands-default runtime and product extensions are not conformance authority.

The generated OpenAI REST client is an inspectable reference artifact, not Symphony's agent
transport. Symphony Draft v1 requires the Codex app-server JSONL/JSON-RPC protocol. OpenAI does not
publish an official C++ SDK, and the selected generator does not fully support OpenAPI 3.1 unions,
polymorphism, or authorization, so generated output must not silently become production runtime code.
