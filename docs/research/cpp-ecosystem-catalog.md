# C++ ecosystem and engineering source catalog

This page is the durable inbox for sources that may influence Symphony's C++26 architecture,
dependencies, build system, documentation, and engineering practices. It is not an approval list.
Normative project inputs remain in [`sources.md`](sources.md), and adopted mechanisms remain in
[`../dependency-decisions.md`](../dependency-decisions.md).

**Last reviewed:** 2026-07-23.

## How to maintain this catalog

Every consequential decision must be rechecked against a primary source owned by the relevant
standards body, compiler, library, or tool project. Catalogs, blogs, conference talks, social media,
and community discussions are discovery inputs only.

| Status | Meaning |
| --- | --- |
| Active | Used as recurring evidence; review when its pinned input changes |
| Evaluate | A bounded comparison or fixture gate is warranted |
| Monitor | Useful signal source; no adoption work is currently justified |
| Reference | Educational or comparative only |
| Rejected | Evaluated and incompatible with a documented boundary |

When adding an entry, record its status, intended use, authority tier, and a re-evaluation trigger.
Remove stale discovery sources when two reviews produce no actionable primary-source leads.

## Standards, compiler, and language authority

| Source | Tier | Status | Intended use |
| --- | --- | --- | --- |
| [WG21 papers](https://wg21.link/) and the [current working draft](https://eel.is/c++draft/) | Primary | Active | Verify C++26 language/library contracts, feature-test macros, and proposal wording |
| [WG21 Wiki MCP](https://github.com/cppalliance/wg21-wiki-mcp) | Tool over primary data | Evaluate | Search and cross-reference WG21 papers; pin the server and verify every result against the paper |
| [GCC C++ status](https://gcc.gnu.org/projects/cxx-status.html) and [GCC 16.1 sources](https://ftp.gnu.org/gnu/gcc/gcc-16.1.0/) | Primary | Active | Define executable semantics and supported C++26 switches |
| [Bloomberg clang-p2996](https://github.com/bloomberg/clang-p2996) | Primary implementation | Active | Differential reflection evidence only, pinned at the repository lock |
| [cppreference](https://en.cppreference.com/w/cpp/26.html) | Curated secondary | Active | Fast index into C++26 facilities; confirm consequential claims in WG21/compiler sources |
| [Compiler Explorer](https://github.com/compiler-explorer/compiler-explorer) | Tool | Active | Small compiler and code-generation experiments; preserve reproducible compiler/options links |
| [C++ Core Guidelines](https://github.com/isocpp/CppCoreGuidelines) | Primary guidance | Evaluate | Select enforceable safety/interface rules rather than adopting every style rule |

### Compile-time and C++26 opportunity filter

Prefer compile-time enforcement when it deletes runtime states without moving I/O, allocation, or
policy into templates. Evaluate each opportunity in this order:

1. concepts and constrained overloads at subsystem boundaries;
2. `constexpr`/`consteval` validation for fixed schemas, transition tables, field maps, and
   configuration constants;
3. compile-time `ut` fixtures and `static_assert` for invariants and feature probes;
4. standard reflection isolated behind `symphony_meta` for DTO/schema/code generation;
5. generated adapters where measured handwritten mapping is repetitive.

Do not make runtime tracker data, workflow files, database migrations, secrets, or operator policy
compile-time inputs. Compile-time work must retain readable diagnostics and be covered by the exact
GCC 16.1 gate; clang-p2996 remains differential-only.

## Library discovery and evaluation

| Source | Tier | Status | Intended use |
| --- | --- | --- | --- |
| [`fffaraz/awesome-cpp`](https://github.com/fffaraz/awesome-cpp) | Community catalog | Monitor | Candidate discovery; never sufficient adoption evidence |
| [`uhub/awesome-cpp`](https://github.com/uhub/awesome-cpp) | Community catalog | Monitor | Independent candidate discovery and category cross-check |
| [Microsoft vcpkg registry](https://github.com/microsoft/vcpkg/tree/master/ports) | Package authority | Active | Confirm curated availability before considering an overlay |
| [NVIDIA `stdexec`](https://github.com/NVIDIA/stdexec) | Primary | Active | Selected C++26 senders/receivers reference implementation behind the execution seam |
| [Glaze](https://github.com/stephenberry/glaze) | Primary | Active | Selected JSON/YAML/schema provider and bounded HTTP candidate |
| [`openalgz/ut`](https://github.com/openalgz/ut) | Primary | Active | Selected runtime and compile-time test framework |
| [`klemens-morgenstern/sqlite`](https://github.com/klemens-morgenstern/sqlite) | Primary | Active | Selected typed SQLite adapter behind the persistence seam |
| [`fmt`](https://github.com/fmtlib/fmt), [`scnlib`](https://github.com/eliaskosunen/scnlib), and [Boost libraries](https://www.boost.org/doc/libs/) | Primary | Active/monitor | Formatting is active; scanning and new Boost components remain need-driven |

NVIDIA `stdexec` currently passes the pinned curated-port GCC 16.1 gates. Do not create an overlay
merely to configure it differently. Add the smallest same-source overlay only after an exact,
reproducible packaging/options failure and record its removal criterion.

## Reflection, code generation, and foreign-language boundaries

Core code, the service runtime, and executable semantics remain entirely C++26. A Python, Rust, or
other foreign implementation may be evaluated only behind an explicit process, stable C ABI, RPC,
or generated-binding boundary. It must not become the domain model, scheduler authority, build
orchestrator, or required language runtime.

| Source | Tier | Status | Intended use |
| --- | --- | --- | --- |
| [`mirror_bridge`](https://github.com/FranciscoThiesen/mirror_bridge) | Primary experimental | Reference | Study C++26 reflection-driven foreign binding generation and compiler differences |
| [`imrefl`](https://github.com/fullptr/imrefl) and [`splice`](https://github.com/FloofyPlasma/splice) | Primary experimental | Reference | Compare reflection techniques without adding runtime dependencies |
| [pybind11](https://github.com/pybind/pybind11) | Primary | Evaluate only on demand | In-process Python extension boundary; unsuitable for importing a Python service runtime |
| [nanobind](https://github.com/wjakob/nanobind) | Primary | Evaluate only on demand | Smaller modern Python binding comparison |
| [SWIG](https://github.com/swig/swig) | Primary | Reference | Mature generated multi-language C/C++ binding comparison |
| [CXX](https://github.com/dtolnay/cxx) and [Corrosion](https://github.com/corrosion-rs/corrosion) | Primary | Reference | Rust/C++ bridge and CMake integration comparisons; incompatible with an entirely C++ core unless an owner-approved optional boundary appears |
| [Protocol Buffers](https://github.com/protocolbuffers/protobuf) and [Cap'n Proto](https://github.com/capnproto/capnproto) | Primary | Evaluate only on demand | Process/RPC schemas if a real cross-language service boundary appears |
| [gRPC C++](https://grpc.io/docs/languages/cpp/) | Primary | Evaluate only on demand | Generated cross-process RPC when deadlines, cancellation, and a service boundary are actual requirements |
| [FlatBuffers](https://github.com/google/flatbuffers) | Primary | Reference | Generated interchange format only if measured zero-copy requirements justify a second wire format |
| [ZeroMQ](https://github.com/zeromq/libzmq) and [`cppzmq`](https://github.com/zeromq/cppzmq) | Primary | Reference | Transport comparison; supplies no schema or product protocol by itself |
| [`yalantinglibs/coro_rpc`](https://alibaba.github.io/yalantinglibs/en/coro_rpc/coro_rpc_introduction.html) | Primary | Rejected | Duplicates the selected Asio/stdexec/Glaze reflection and execution mechanisms and does not supply the required cross-language contract |

An interop candidate must pass an ABI/lifetime/error/cancellation/ownership fixture, document its
toolchain and runtime footprint, and show that it deletes more boundary code than it introduces.

## Blogs, newsletters, and educational sources

These sources generate leads. Link the owning proposal, code, compiler documentation, or measured
fixture before changing the project.

| Source | Status | Notes |
| --- | --- | --- |
| [LinkedIn C++ newsletter supplied by the owner](https://www.linkedin.com/newsletters/7306756121757708288/) | Monitor | May require authenticated access; catalog titles and follow primary links |
| [HFT University](https://hftuniversity.com/) | Monitor | Performance/low-latency techniques; validate applicability with project benchmarks |
| [Microsoft C++ Team Blog](https://devblogs.microsoft.com/cppblog/) | Monitor | Compiler, library, CMake, and tooling announcements |
| [The Old New Thing](https://devblogs.microsoft.com/oldnewthing/) | Reference | Language/runtime and Windows engineering explanations |
| [Barry Revzin](https://brevzin.github.io/) | Monitor | Standards and modern C++ analysis; follow cited WG21 papers |
| [Sandor Dargo](https://www.sandordargo.com/) | Monitor | Modern C++ practice and language articles |
| [JetBrains CLion Blog](https://blog.jetbrains.com/clion/) | Monitor | IDE, debugger, CMake, and analysis-tool announcements |
| [ISO C++ news](https://isocpp.org/blog) | Monitor | Standards/community index |
| [C++ Stories](https://www.cppstories.com/) | Monitor | Modern C++ examples; reproduce before adoption |
| [Modernes C++](https://www.modernescpp.com/) | Monitor | Concurrency and language education |
| [C++ Alliance news and documentation](https://cppalliance.org/news/) | Monitor | MrDocs, Boost ecosystem, and tooling developments |
| [LLVM Blog](https://blog.llvm.org/) | Monitor | Compiler/toolchain implementation developments |
| [Compiler Explorer blog](https://blog.compiler-explorer.com/) | Monitor | Compiler behavior and reproducible tooling experiments |

## Community and discussion

| Source | Status | Notes |
| --- | --- | --- |
| [`r/cpp`](https://www.reddit.com/r/cpp/) | Monitor | Practitioner/news discovery only |
| [`r/cpponline`](https://www.reddit.com/r/cpponline/) | Monitor | Online conference and community discovery |
| [Cpplang Slack](https://cpplang.slack.com/) | Deferred | Requires explicit workspace/plugin authorization |

## Conferences and video

Prefer published slides, code, papers, and current tool documentation over a talk recording when
making a decision.

| Source | Status |
| --- | --- |
| [CppNow](http://www.youtube.com/@CppNow) | Monitor |
| [CppCon](http://www.youtube.com/@CppCon) | Monitor |
| [C++ Online](https://www.youtube.com/@CppOnline) | Monitor |
| [Meeting C++](https://www.youtube.com/@MeetingCPP) | Monitor |
| [Owner-supplied livestream](https://www.youtube.com/live/6t2mNymWFJ4) | Review |
| [ACCU Conference](https://www.youtube.com/@ACCUConf) | Monitor |
| [code::dive](http://www.youtube.com/@codediveconference) | Monitor |
| [C++ Weekly](https://www.youtube.com/@cppweekly) | Monitor |

## Social signals

Social feeds are never implementation authority. Use them to discover a linked paper, release, bug,
benchmark, or talk.

| Source | Status |
| --- | --- |
| [`@cppnow`](https://x.com/cppnow) | Monitor |
| [`@mattgodbolt`](https://x.com/mattgodbolt) | Monitor |
| [`@krisjusiak`](https://x.com/krisjusiak) | Monitor |
| [`@cpponlineconf`](https://x.com/cpponlineconf) | Monitor |
| [`@meetingcpp`](https://x.com/meetingcpp) | Monitor |

## Engineering, CI, and documentation tools

| Source | Tier | Status | Intended use |
| --- | --- | --- | --- |
| [`cppalliance/tools-public`](https://github.com/cppalliance/tools-public) | Primary | Evaluate | Inspect reusable C++ Alliance tooling; adopt components only through the dependency policy |
| [`cppalliance/local-ci-test-system`](https://github.com/cppalliance/local-ci-test-system) | Primary | Evaluate | Compare local GitHub Actions reproduction with the selected devcontainer lifecycle |
| [CMake](https://cmake.org/cmake/help/latest/), [Ninja](https://ninja-build.org/manual.html), and [ccache](https://ccache.dev/manual/latest.html) | Primary | Active | Pinned build frontend, executor, and compiler-result cache |
| [Dev Container specification](https://containers.dev/implementors/spec/) and [reference CLI](https://github.com/devcontainers/cli) | Primary | Active | Local and CI development-container lifecycle |
| [Docker Build cache](https://docs.docker.com/build/cache/) | Primary | Active | Diagnose and improve compiler image cache behavior |
| [GitHub CLI](https://cli.github.com/manual/) and [Actions schedules](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#schedule) | Primary | Active | Guard, publish, and open reviewable dependency-update branches without force-push |
| [LLVM `clang-format`](https://clang.llvm.org/docs/ClangFormat.html) | Primary | Evaluate | Commit a versioned style and enforce a non-mutating format check |
| [LLVM `clang-tidy`](https://clang.llvm.org/extra/clang-tidy/) and [Clang Static Analyzer](https://clang-analyzer.llvm.org/) | Primary | Evaluate | Pinned analysis image, compile-database-driven bug, concurrency, portability, and guideline checks |
| [Include What You Use](https://include-what-you-use.org/) | Primary | Evaluate | Scheduled non-mutating include hygiene with a compiler-compatible build |
| [MrDocs](https://cppalliance.org/mrdocs/) | Primary | Evaluate | Clang-AST API reference generation from the existing compilation database |
| [Doxygen](https://www.doxygen.nl/manual/) | Primary | Reference | Mature API-doc and Graphviz comparison |
| [Graphviz](https://graphviz.org/documentation/) | Primary | Evaluate | Generated dependency, state, and API relationship diagrams |
| [Mermaid](https://mermaid.js.org/intro/) | Primary | Evaluate | Reviewable workflow/architecture diagram source embedded in Markdown |
| [PlantUML](https://plantuml.com/) | Primary | Reference | Sequence/C4 comparison when Mermaid is insufficient |
| [MkDocs](https://www.mkdocs.org/) and [Material for MkDocs](https://squidfunk.github.io/mkdocs-material/) | Primary | Evaluate | Static documentation portal over repository Markdown and generated API output |
| [GitHub Pages](https://docs.github.com/pages) | Primary | Evaluate | Repository-native static hosting; publication requires a separate owner-approved workflow |
| [Read the Docs](https://docs.readthedocs.com/platform/stable/) | Primary | Reference | Hosted preview/versioning alternative; introduces an external service integration |
| [Sphinx](https://www.sphinx-doc.org/) and [Breathe](https://breathe.readthedocs.io/) | Primary | Reference | Doxygen/XML documentation-site comparison |

## Local Codex capability survey

The installed repository-specific capabilities are `dependency-first` and the reusable
`gh-watch-run` skill. The available GitHub plugin covers repository/PR/CI triage, but no installed
specialized C++, CMake, vcpkg, Docker, or Dev Container skill was found on 2026-07-23. Generic
coding agents and shell tooling remain the implementation path; create a repository skill only
after a repeated, stable workflow is evidenced. Unrelated available business and Apple-platform
plugins do not help this project and should not be installed.
