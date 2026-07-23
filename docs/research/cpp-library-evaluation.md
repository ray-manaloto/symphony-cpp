# C++26 library-stack evaluation

**Question.** Which proposed libraries fit a standalone, fixture-first C++26
implementation of Symphony Draft v1, whose release semantics are GCC 16.1 and
whose clang-p2996 job is differential evidence rather than a release target?

**Accessed:** 2026-07-22.  This is a primary-source lane: project repositories,
their official documentation, the official vcpkg documentation/registry, and
LLVM documentation only.  “Maintenance risk” and recommendations are labelled
as inference; activity counts are deliberately not used as proof of quality.

## Decision summary

| Boundary | Recommendation | Reason / constraint |
| --- | --- | --- |
| JSON, JSONL, configuration codecs | **Adopt Glaze behind `symphony_codec` after a pinned-source fixture gate.** | It supports GCC 16 and clang-p2996 reflection, `std::expected`-style APIs, and a vcpkg port. Keep explicit DTO field names and a local codec seam; do not make Glaze metadata the domain model. |
| Status HTTP API | **Prototype Glaze HTTP; retain a thin transport interface until its fixture, cancellation, TLS, malformed-request, bounded-body, and shutdown suite passes.** | Its documentation says HTTP networking is under active development and API-changing. This makes it a promising adapter, not an accepted foundational dependency yet. |
| Codex app-server transport | **Hand-written JSONL/JSON-RPC adapter using Glaze JSON only; do not use REPE.** | Symphony speaks JSON-RPC/JSONL, whereas REPE is a different protocol. The REPE server/client/registry are expressly unstable and leave registry synchronization to callers. |
| Unit tests | **Adopt `ut` for small C++23/26 unit and compile-time tests; add a property/fuzz layer separately.** | `ut` is a single-header C++23 test library with compile-time tests, but it is small and has no evidence here of property testing, death tests, test discovery integration, or broad tooling support. |
| Dependencies | **Use vcpkg manifest mode with a committed Git `builtin-baseline`, version constraints/overrides, and a committed `vcpkg-configuration.json`.** | Manifest mode gives project-local installs and is required for versioning/registries. Use an overlay port only when a required library is absent from the curated registry, then pin its source hash and add an exit/removal criterion. |
| Persistence | **Use `klemens-morgenstern/sqlite` with SQLite WAL behind a small repository/event-store interface and serialized DB executor. Evaluate `sqlgen` in a contained spike, not as the initial persistence authority.** | The wrapper augments SQLite with typed queries, prepared statements and RAII transactions without hiding the C API. It and `sqlgen` are synchronous in the evidenced APIs, so neither defines the async boundary. |
| Reflection | **Keep `symphony_meta` as the only direct P2996 consumer. Use Glaze's P2996 backend only through codec tests.** | The release and differential compiler policy already requires this isolation. The reference projects validate that GCC 16 and clang-p2996 are usable experiments; none should become a runtime dependency. |
| Quality gates | **Use Clang warnings, `clang-tidy`, CSA checks, sanitizers, and IWYU as separate non-mutating gates.** | `clang-tidy` can run analyzer checks from `compile_commands.json`; IWYU needs a compatible Clang build and should report/verify rather than automatically rewrite headers. |

## Candidate ledger

“Curated” means a port directory was verified in the Microsoft vcpkg registry
on the access date. “Not evidenced” means no claim that it is unavailable: it
means this report did not find a primary-source curated-port record and an
adoption must first make a pinned overlay-port decision.

| Candidate | Verified facts (license; status; constraints; vcpkg) | Architecture fit and maintenance inference |
| --- | --- | --- |
| [Glaze](https://github.com/stephenberry/glaze) | MIT; header-only C++23 library. Its README documents JSON, TOML, YAML and other codecs, exception/RTTI-free operation, and P2996 support with GCC 16+ (`-std=c++26 -freflection`) and Bloomberg clang-p2996. It states CI coverage for GCC 13+, Clang 18+, MSVC, Apple Clang, Linux/macOS/Windows and big-endian QEMU. The observed upstream `HEAD` was `2dfb3555da8428f737d2edffd59b70e2450d45fa`; adoption must pin a tag or commit rather than `main`. [Curated `glaze` port verified.](https://github.com/microsoft/vcpkg/tree/master/ports/glaze) | Strong fit for typed fixture codecs and temporary YAML replacement. **Inference:** because the P2996 backend is still compiler-experimental, constrain it to codec differential fixtures; production schemas still need explicit names, unknown-field policy, limits, and redaction. |
| [Glaze HTTP/REST](https://stephenberry.github.io/glaze/networking/http-rest-support/) | The official docs state ASIO-based async server, client, REST registry, WebSocket, TLS, routing, middleware, and request body as `std::string`. Glaze’s README says networking is usable but under active development and API changes are likely. HTTP is delivered by Glaze, not a separately versioned release. | Good prototype candidate for the local status/read-only control API. **Do not accept yet:** require a pinned integration test matrix for cancellation, connection limits, max request/body/header size, TLS verification, graceful shutdown, and a no-live-tracker fixture boundary. Its string body representation makes explicit body limits mandatory. |
| [Glaze REPE RPC](https://stephenberry.github.io/glaze/rpc/repe-rpc/) | Documentation explicitly warns that `glz::asio_server`, `glz::asio_client`, and `glz::repe::registry` are unstable. It requires standalone or Boost.Asio not included by Glaze CMake, has a mutable registry that does not lock reads/writes, and is a REPE protocol implementation rather than JSON-RPC. | **Reject for the Codex/Symphony transport.** Use only as an isolated protocol experiment if an independent REPE requirement appears. It does not remove the required JSON-RPC framing/semantics, and its thread-safety allocation would conflict with one scheduler authority. |
| [openalgz/ut](https://github.com/openalgz/ut) | MIT; C++23 and CMake 3.31 required; single header, optional compile-time tests and optional C++20/23 modules. GitHub records release `v1.2.0` (2026-03-07). No curated `ut` port was found at the direct official registry path on the access date. | Suitable for unit-level state-machine, parser, and reflected-DTO tests. **Inference:** pin source through a minimal overlay port or vendored source only after the test registration/CTest and GCC16/clang-p2996 smoke fixtures pass. Pair with libFuzzer or a property test mechanism; `ut` alone is not enough conformance evidence. |
| [reflect-cpp](https://github.com/getml/reflect-cpp) | MIT; described by its authors as C++20 reflection-based serialization/deserialization/validation. It supports many optional formats and carries a `vcpkg.json`; [curated `reflectcpp` port verified.](https://github.com/microsoft/vcpkg/tree/master/ports/reflectcpp) The observed state was its `main` branch; no release tag is asserted here. | Valuable comparison and optional inbound configuration/validation adapter. **Inference:** do not adopt beside Glaze in the first architecture: two pervasive reflection/codec systems duplicate type annotations and error models. Re-evaluate only if its validation/JSON-schema features delete measured handwritten code. |
| [sqlgen](https://github.com/getml/sqlgen) | MIT; pinned vcpkg baseline version 0.6.0 is C++20 and depends on reflect-cpp 0.25.0, CTRE, yyjson, and SQLite. Its v0.6.0 docs state that `write` automatically creates a table from the reflected C++ structure, exposes `sqlgen::Result` as `rfl::Result`, and provides synchronous connection/transaction operations. [Curated `sqlgen` port verified.](https://github.com/microsoft/vcpkg/tree/master/ports/sqlgen) | **Reject for the durable event repository at the deletion gate.** Automatic reflected schema creation conflicts with explicit migrations, reflect-cpp and `rfl::Result` duplicate Glaze and `std::expected`, and the dependency does not provide the missing cancellation boundary. Re-evaluate only if a future manual-schema mode deletes measured mapper code without becoming a second durable-schema/reflection authority. |
| [`klemens-morgenstern/sqlite`](https://github.com/klemens-morgenstern/sqlite) | Boost Software License headers; active, non-archived repository at observed `master` `6cf149d052dc30cd8715586284ffe398df55d2e9`. It augments SQLite with typed queries, prepared statements, RAII transactions/savepoints, hooks, backup, JSON/custom functions and non-throwing overloads. Its build uses SQLite plus Boost headers/Describe/PFR/System. No asynchronous, coroutine, sender/receiver API or curated vcpkg port was found in the inspected source/registry. | **Adopt as the initial SQLite adapter through a pinned overlay port.** Keep it inside `symphony_persistence`; execute operations on one serialized DB executor and map errors into repository-owned types. Do not expose Boost reflection types or mistake synchronous calls for cancellable I/O. |
| [{fmt}](https://github.com/fmtlib/fmt) | MIT; no external dependencies; offers compiled or `FMT_HEADER_ONLY` use, type-safe compile-time format checking, and implementation of C++20 `std::format`/C++23 `std::print`. The official repository describes continuous fuzzing. Curated package name: `fmt` (official vcpkg manifest documentation uses it as an example). | **Adopt.** Use for diagnostics and structured log rendering at the redaction boundary; do not format secrets before redaction. Prefer compiled vcpkg target to control compile-time cost. Pin the curated baseline; this report does not assert a release number. |
| [CLI11](https://github.com/CLIUtils/CLI11) | BSD-3-Clause; header-only with no runtime dependencies. Release 2.6.2 is present in the pinned vcpkg baseline with a SHA-512-verified source archive. Official documentation covers positional arguments, strict unknown-argument handling, subcommands, help, diagnostics, and parser-owned exit codes. | **Adopt for executable argv parsing.** Glaze 7.9.0's documented CLI facility is an interactive reflected menu and does not meet the daemon/ctl argv contract. Keep CLI11 values behind repository option structs and keep workflow semantics out of parser callbacks. |
| [scnlib](https://github.com/eliaskosunen/scnlib) | Apache-2.0; modern type-safe input parsing, reference implementation for P1729, with modules support and C++23 requirement in current documentation. Repository's branch is `master`; this report does not establish a release tag or curated port. | **Defer.** Command/config parsing is not the current performance or safety bottleneck. Use standard parsing / Glaze configuration decoding until an actual CLI parsing gap warrants a deletion-test spike. |
| [Boost.Decimal](https://github.com/boostorg/decimal) | BSL-1.0; header-only/no dependency, C++14; IEEE 754 decimal types; documented vcpkg availability and test matrix includes GCC 8+, Clang 6+, MSVC 2019+, Ubuntu/macOS/Windows. Latest release shown by the project: `v6.0.1` (2026-01-27). | **Conditional adopt.** Appropriate for tracker monetary/decimal quantities only when the upstream fixture schema needs exact decimal semantics. Do not introduce it for timestamps, retry intervals, or JSON arbitrary numbers absent an explicit API contract. |
| [NVIDIA stdexec](https://github.com/NVIDIA/stdexec) | Apache-2.0; upstream describes it as the experimental C++26 `std::execution` reference implementation and documents GCC 12+, Clang 16+, structured concurrency, a static thread pool, value/error/stopped channels, and no external library dependencies for the header surface. The pinned vcpkg baseline packages commit `fee4d651494014610a277540f209cae56011e47f` as version `2026-05-25`. | **Gate for hosted worker execution.** Require exact GCC 16.1 overlap and completion-channel fixtures before scheduler migration. Keep the provider behind a project seam because its APIs may change and libstdc++ replacement is the exit condition. Fake time remains a scheduler-policy seam rather than a provider-specific timer. |
| [Intel bare-metal concurrency](https://github.com/intel/cpp-baremetal-concurrency) | BSL-1.0, header-only; its authors target single-core bare-metal microcontrollers, atomics, and critical sections. Main is C++23 and lists GCC 12–14 / Clang 18–21; no release is published. | **Reject for Symphony.** Its documented target is not a hosted Linux process with I/O and a scheduler; compiler support does not cover the project’s GCC 16 release definition. |
| [Intel bare-metal senders/receivers](https://github.com/intel/cpp-baremetal-senders-and-receivers) | BSL-1.0, header-only partial P2300 implementation for bare metal. It explicitly omits exception handling and coroutines, has missing/renamed/nonstandard functions, targets interrupts, and lists GCC 12–14 / Clang 19–22. No stable release was evidenced. | **Reject.** It is educationally useful for sender/receiver concepts but is an incompatible hosted-runtime implementation, not a bridge to standard C++26 execution. |
| [Intel compile-time-init-build](https://github.com/intel/compile-time-init-build) | BSL-1.0 header-only compile-time firmware composition library; main is C++23, listed GCC 12–14 / Clang 18–22. Upstream recommends CPM or submodule and a commit pin; no release is asserted here. | **Reject.** Compile-time firmware composition is not an application service composition/DI solution; ordinary construction plus explicit interfaces preserves testability and limits template coupling. |
| [Intel cpp-std-extensions](https://github.com/intel/cpp-std-extensions) | BSL-1.0 header-only polyfills/extensions; C++23 main and listed GCC 12–14 / Clang 18–22. No stable release is asserted here. | **Reject for the release path.** GCC 16 C++26 should use standard facilities directly. A local compatibility shim may be considered only for a demonstrated compiler-library gap and must have deletion criteria. |
| [mirror_bridge](https://github.com/FranciscoThiesen/mirror_bridge) | Apache-2.0; experimental C++26 P2996 binding generator requiring GCC 16+ or clang-p2996. Latest release displayed: `v0.3.0` (2026-06-06). It notes P3394 annotations currently need clang-p2996 and GCC ignores them. | **Reference-only.** Useful confirmation that both mandated compilers exercise P2996, but it generates foreign-language bindings, has external runtime/tool requirements, and exposes a known compiler semantic difference—unsuitable for the core meta adapter. |
| [imrefl](https://github.com/fullptr/imrefl) | Project describes an ImGui C++26-reflection library for generating struct displays. The accessed upstream page did not establish a stable release, package port, or production compiler matrix. | **Reference-only / reject.** UI inspection is outside a headless Symphony controller; it is a small experimental reflection example, not a serialization or conformance dependency. |
| [splice](https://github.com/FloofyPlasma/splice) | Project describes a header-only C++26 reflection hook/mixin library. The accessed upstream page did not establish a stable release, curated port, or GCC16/clang-p2996 support matrix. | **Reference-only / reject.** Runtime hook/mixin composition would obscure scheduler state and widen experimental P2996 coupling. |

## Persistence recommendation

### Baseline: SQLite, repository-owned schema and event envelope

**Verified:** SQLite is one of sqlgen’s explicitly supported backends, and
sqlgen documents a SQLite connection API; it is not an asynchronous API in that
documentation.  SQLite itself is public domain according to sqlgen’s dependency
table.  This makes SQLite usable in a completely local fixture environment
without production credentials or a service dependency.

**Inference / recommended shape:**

```text
scheduler strand / execution domain
  -> event_store interface (append, load, lease/update atomically)
  -> db_executor (one serialized writer, cancellable request queue)
  -> SQLite WAL database under the fixture workspace root
```

Use explicit migrations, parameterized statements, transaction-scoped updates,
and an append-only event table plus materialized run/task state.  Inject a clock
and make the database path fixture-owned.  Store protocol payloads as bounded,
redacted data with versioned envelopes; do not let a reflection library define
the durable schema.  This directly supports deterministic replay, restart-safe
retry, and the one-correction-then-stalled invariant.

Implementation order:

1. **SQLite + `klemens-morgenstern/sqlite`:** selected initial adapter, isolated
   behind the repository and serialized executor; accept the overlay only after
   GCC 16, clang-p2996/libc++, transaction, busy/restart and cancellation-queue fixtures pass.
2. **SQLite + `sqlgen` deletion test:** rejected at pinned version 0.6.0 before
   manifest adoption because reflected automatic table creation, `rfl::Result`,
   and the reflect-cpp/CTRE/yyjson closure violate the explicit-schema and
   single-reflection boundaries without adding cancellation. Re-evaluate only
   against a future manual-schema mode that deletes measured mapper code.
3. **SQLite C API + repository-owned RAII:** fallback if the selected wrapper's
   compiler closure, error semantics, or overlay maintenance fails the fixture gate.
4. **Append-only filesystem NDJSON:** acceptable only as a test oracle/export,
   not the authoritative store: atomic indexing, compaction, concurrent writer
   recovery, and query integrity would become repository-owned work.
5. **PostgreSQL/DuckDB:** do not introduce for this standalone fixture-first
   implementation. SQLgen supports them, but they expand the test and runtime
   boundary without a stated product need.

No reviewed option supplies standard C++26 `std::execution` persistence I/O.
Keep an application-owned `sender`/`awaitable` adapter boundary around the
single persistence executor so an eventual standard-execution backend is
replaceable rather than architectural.

## vcpkg reproducibility policy

**Verified:** vcpkg recommends manifest mode; manifest mode uses `vcpkg.json`,
is required for versioning and custom registries, permits a
`builtin-baseline`/overrides, and creates a project-local `vcpkg_installed`
tree.  Git registries and version files use immutable historical Git tree
references; the official guidance says not to rewrite version history.

**Recommended committed inputs:**

- `vcpkg.json`: direct dependencies, feature partitioning (`tests`,
  `analysis`, `http-prototype`), minimum versions only when the baseline needs
  an extra guard.
- `vcpkg-configuration.json`: Git default registry fixed to an audited vcpkg
  commit. Add a registry/overlay only for an approved non-curated package.
- A lock/evidence file generated by the repository check that records vcpkg
  commit, triplet, package versions and SHA-256s. Treat that as conformance
  evidence, not a substitute for the `builtin-baseline`.
- No global classic-mode install, floating `main`, unpinned `FetchContent`, or
  automatic registry rewrite.

## Static analysis and IWYU

**Verified:** LLVM documents that `clang-tidy` consumes a compilation database,
can enable `clang-analyzer-*` checks, and includes groups such as `bugprone-`,
`cert-`, `concurrency-`, `cppcoreguidelines-`, `performance-`, and
`portability-`. It provides `--verify-config`, warning escalation, and
parallel full-project execution. LLVM also warns that diff mode only filters
reported diagnostics, not analysis; it can miss errors manifested outside
changed lines. IWYU is a Clang-based include analysis tool.

**Recommended gates:**

1. Compile GCC 16 release semantics with strict warnings and `-Werror`; build
   the same reflected fixtures using clang-p2996 as differential evidence.
2. Use a pinned modern Clang analysis image to configure with
   `CMAKE_EXPORT_COMPILE_COMMANDS=ON`. Enable all supported `clang-analyzer-*`,
   `bugprone-*`, `cert-*`, `concurrency-*`, `cppcoreguidelines-*`,
   `performance-*`, and `portability-*` initially. Version the resulting
   `-list-checks` artifact; explicitly disable only individual noisy checks with
   rationale and an expiry/issue.
3. Run ASan+UBSan and, separately, TSan against deterministic fake-runtime
   tests; these are dynamic analyzers, not substitutes for clang-tidy/CSA.
4. Run IWYU from that Clang-compatible compilation database in report mode,
   limited to owned headers/sources. Apply fixes manually and require a clean
   target-scope rerun; generated/OpenAPI/reference code is excluded.
5. Never use auto-fix in CI. Treat formatting, tidy, analyzer, and IWYU as
   separate evidence artifacts so a compiler mismatch is visible.

## Primary sources

- [Glaze README and support matrix](https://github.com/stephenberry/glaze),
  [HTTP/REST documentation](https://stephenberry.github.io/glaze/networking/http-rest-support/),
  and [REPE documentation](https://stephenberry.github.io/glaze/rpc/repe-rpc/).
- [`ut` repository and release record](https://github.com/openalgz/ut).
- [vcpkg manifest mode](https://learn.microsoft.com/en-us/vcpkg/concepts/manifest-mode),
  [registries](https://learn.microsoft.com/en-us/vcpkg/concepts/registries), and
  [versioning](https://learn.microsoft.com/en-us/vcpkg/users/versioning).
- [reflect-cpp](https://github.com/getml/reflect-cpp) and
  [sqlgen](https://github.com/getml/sqlgen).
- [`klemens-morgenstern/sqlite`](https://github.com/klemens-morgenstern/sqlite).
- [{fmt}](https://github.com/fmtlib/fmt), [scnlib](https://github.com/eliaskosunen/scnlib),
  and [Boost.Decimal](https://github.com/boostorg/decimal).
- [Intel bare-metal concurrency](https://github.com/intel/cpp-baremetal-concurrency),
  [senders/receivers](https://github.com/intel/cpp-baremetal-senders-and-receivers),
  [compile-time-init-build](https://github.com/intel/compile-time-init-build), and
  [cpp-std-extensions](https://github.com/intel/cpp-std-extensions).
- [mirror_bridge](https://github.com/FranciscoThiesen/mirror_bridge),
  [imrefl](https://github.com/fullptr/imrefl), and
  [splice](https://github.com/FloofyPlasma/splice).
- [LLVM clang-tidy documentation](https://clang.llvm.org/extra/clang-tidy/) and
  [Include-What-You-Use](https://include-what-you-use.org/).

## Decisions required from the root

1. Approve the Glaze codec adoption and a bounded Glaze HTTP prototype, or retain
   the current codec/HTTP candidates.
2. Approve `ut` plus a named property/fuzz tool and its overlay-port policy.
3. Approve SQLite C API first versus a bounded `sqlgen` deletion-test spike.
4. Approve the vcpkg baseline/registry evidence policy and whether experimental
   dependencies may enter only through an explicitly versioned overlay.
5. Approve the analysis policy: a pinned Clang analysis image distinct from the
   GCC16 release image, with whole-project scheduled scans and non-mutating IWYU.
