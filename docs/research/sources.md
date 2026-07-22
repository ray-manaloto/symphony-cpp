# Research sources and ingestion checklist

Primary sources define behavior; comparisons only identify possible gaps. Accessed 2026-07-22.

- [x] [OpenAI Symphony repository and Draft v1 specification](https://github.com/openai/symphony), pinned at `1f3219b`
- [x] [GCC 16.1 release sources](https://ftp.gnu.org/gnu/gcc/gcc-16.1.0/)
- [x] [Bloomberg clang-p2996](https://github.com/bloomberg/clang-p2996), pinned at `7220baff`
- [x] [OpenAI codex-universal](https://github.com/openai/codex-universal), image digest pinned separately
- [x] [OpenSymphony](https://opensymphony.dev/), comparative only
- [x] [Verdent Symphony architecture deep dive](https://www.verdent.ai/guides/openai-symphony-architecture-deep-dive), comparative only
- [x] [OpenAI Tart](https://github.com/openai/tart), deferred Apple-Silicon executor
- [x] [Tart Guest Agent](https://github.com/openai/tart-guest-agent), deferred guest operations
- [x] [OpenAI Softnet](https://github.com/openai/softnet), deferred privileged network isolation
- [x] [OpenAI Orchard](https://github.com/openai/orchard), deferred multi-host scheduling
- [x] [OpenAI OpenAPI](https://github.com/openai/openai-openapi), pinned REST API schema and generated C++ reference surface
- [x] [OpenAPI Generator](https://github.com/OpenAPITools/openapi-generator), pinned C++ Boost.Beast reference generator
- [x] [Glaze](https://github.com/stephenberry/glaze) and its [HTTP/REST](https://stephenberry.github.io/glaze/networking/http-rest-support/), [REPE RPC](https://stephenberry.github.io/glaze/rpc/repe-rpc/), and [P2996](https://stephenberry.github.io/glaze/p2996-reflection/) documentation
- [x] [`openalgz/ut`](https://github.com/openalgz/ut), selected unit and compile-time test library
- [x] [vcpkg manifest mode and versioning](https://learn.microsoft.com/en-us/vcpkg/concepts/manifest-mode), selected dependency manager
- [x] [`reflect-cpp`](https://github.com/getml/reflect-cpp) and [`sqlgen`](https://github.com/getml/sqlgen), persistence/reflection comparisons
- [x] [`klemens-morgenstern/sqlite`](https://github.com/klemens-morgenstern/sqlite), selected synchronous SQLite adapter behind the persistence executor
- [x] [`fmt`](https://github.com/fmtlib/fmt), [`scnlib`](https://github.com/eliaskosunen/scnlib), and [Boost.Decimal](https://github.com/boostorg/decimal)
- [x] [Intel bare-metal concurrency](https://github.com/intel/cpp-baremetal-concurrency), [senders/receivers](https://github.com/intel/cpp-baremetal-senders-and-receivers), [compile-time init/build](https://github.com/intel/compile-time-init-build), and [standard extensions](https://github.com/intel/cpp-std-extensions)
- [x] [`mirror_bridge`](https://github.com/FranciscoThiesen/mirror_bridge), [`imrefl`](https://github.com/fullptr/imrefl), and [`splice`](https://github.com/FloofyPlasma/splice), reflection references only
- [x] [NVIDIA `stdexec`](https://github.com/NVIDIA/stdexec), current reference implementation for C++26 `std::execution`
- [x] [LLVM clang-tidy](https://clang.llvm.org/extra/clang-tidy/) and [Include-What-You-Use](https://include-what-you-use.org/)
- [x] [r/cpp](https://www.reddit.com/r/cpp/), practitioner discovery only; consequential claims require primary-source verification
- [ ] [Cpplang Slack](https://cpplang.slack.com/), monitoring deferred until the owner explicitly authorizes plugin installation and workspace access

Research preflight: both lanes were refreshed on 2026-07-22. The primary-source evaluation is in
[`cpp-library-evaluation.md`](cpp-library-evaluation.md). The recent-practitioner raw report is under
`.build/research/last30days`; it was noisy and thin, so it did not override primary documentation.
Consequential implementation claims were rechecked against owning repositories.

The generated OpenAI REST client is an inspectable reference artifact, not Symphony's agent
transport. Symphony Draft v1 requires the Codex app-server JSONL/JSON-RPC protocol. OpenAI does not
publish an official C++ SDK, and the selected generator does not fully support OpenAPI 3.1 unions,
polymorphism, or authorization, so generated output must not silently become production runtime code.
