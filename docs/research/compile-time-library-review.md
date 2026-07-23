# Compile-time library review

**Decision date:** 2026-07-23
**Owner direction:** use the supplied third-party and Intel libraries; when no curated vcpkg port
exists, pin the latest upstream Git commit immutably and keep it current through reviewed updates.

## Chosen stack

| Capability | Chosen provider | Use in Symphony |
| --- | --- | --- |
| Compile-time lookup composition | [Intel compile-time-init-build](https://github.com/intel/compile-time-init-build) | Replace handwritten exact HTTP-status branching with a consteval `cib::lookup` table |
| Compile-time values and type algorithms | [Intel cpp-std-extensions](https://github.com/intel/cpp-std-extensions) | Supplies CIB lookup's compile-time value/type machinery and isolated provider fixtures |
| Intel dependency-closure compatibility | [Intel bare-metal concurrency](https://github.com/intel/cpp-baremetal-concurrency) and [Intel bare-metal senders/receivers](https://github.com/intel/cpp-baremetal-senders-and-receivers) | Pinned overlay dependencies with an isolated GCC 16.1 provider gate; they do not replace hosted execution |
| Hosted sender/receiver execution | [NVIDIA `stdexec`](https://github.com/NVIDIA/stdexec) | Remains the sole worker execution, cancellation, and completion provider |
| Structural reflection | C++26 P2996 facilities behind `symphony_meta` | `consteval` fixed-array field descriptors; GCC 16.1 authoritative, clang-p2996 differential |
| JSON/YAML DTO metadata and codecs | [Glaze](https://github.com/stephenberry/glaze) | Compile-time DTO metadata, checked codecs, schemas, and explicit wire names |
| Compile-time tests | [`openalgz/ut`](https://github.com/openalgz/ut) plus `static_assert` | Provider feature probes and product invariants |
| Type-list algorithms | [Boost.MP11](https://www.boost.org/libs/mp11) | Curated dependency used by the Intel compile-time stack |

The Intel adoption is intentionally split at the hosted-runtime boundary. CIB and `stdx` own a
tuple-free compile-time lookup seam. NVIDIA `stdexec` continues to own hosted Linux scheduling; the
Intel bare-metal sender/receiver implementation is compiled as provider-closure evidence but is not
a second application executor.

## Intel pins and decisions

All four projects are header-only, BSL-1.0, absent from the pinned curated vcpkg registry, and
installed by repository overlay ports that copy headers directly. Their upstream CMake is not run
because it unconditionally bootstraps CPM dependencies, which repository policy prohibits.

| Library | Immutable latest-main pin reviewed on 2026-07-23 | Chosen boundary |
| --- | --- | --- |
| Intel compile-time-init-build | `f9b4cc5e5af9703ac569f3eb988af8c7e29fe032` | `cib::lookup` classifies exact HTTP failures at compile time |
| Intel cpp-std-extensions | `a35c5f2cb6d5180afd459495e9e26c279f1aa77a` | `stdx::stdx` supports CIB lookup and compile-time provider fixtures |
| Intel bare-metal concurrency | `b8a486a3bd1d166128ebbdb8e88f7a43443a5e83` | Dependency closure and hosted critical-section compatibility fixture only |
| Intel bare-metal senders/receivers | `3e3c8aaa1b0aa8035453050997ae25ab08d936f1` | Compile-time sender concept fixture only; not linked into Symphony execution |

Upstream documents GCC 12-14 rather than GCC 16.1, and its repositories internally pin older
versions of one another. Symphony deliberately tests the latest-main closure requested by the
owner, so the repository's exact GCC 16.1 provider test is required before product integration and
again after every pin update.

Exact GCC 16.1 Source CI runs `30040027088` and `30040593648` ICEd when the product instantiated
CIB callback/nexus composition through `stdx::tuple`. A standalone reproduction confirmed the
failure with modules enabled or disabled and under both C++23 and C++26. The tuple-free
`cib::lookup` surface compiled and ran on the exact compiler. Re-evaluate nexus only when a future
immutable Intel pin passes standalone tuple and callback/nexus probes on GCC 16.1; do not carry a
local patch to broad third-party tuple machinery.

## Other libraries reviewed

| Candidate | Decision |
| --- | --- |
| [Intel Safe Arithmetic](https://github.com/intel/safe-arithmetic) at `fe1deb82c0e71566183f64ad6fa16fc7c20dd257` | **Evaluate in a later arithmetic slice.** Upstream says it is pre-release, incomplete, API-changing, and not production-ready. A bounded fixture must identify a domain interval it can enforce before it crosses a product seam. |
| [Intel generic-register-operation-optimizer](https://github.com/intel/generic-register-operation-optimizer) at `2e45cc2dee6b0df6e17214254566d856f7d40eed` | **Not applicable.** Symphony has no memory-mapped hardware-register operation graph. |
| [Frozen](https://github.com/serge-sans-paille/frozen) 1.2.0 | **Available, not yet used.** Add when an immutable lookup table would otherwise require a custom compile-time index. |
| [Tesla fixed-containers](https://github.com/teslamotors/fixed-containers) version-date `2024-09-19` | **Available, not yet used.** This is the curated `fixed-containers` port; it is not an Intel project. Add when a real fixed-capacity dynamic container appears. |
| [magic_enum](https://github.com/Neargye/magic_enum) 0.9.8 | **Not selected.** C++26 standard reflection remains the enum/structure reflection authority. |

## Pin-update contract

“Latest” never means floating during configure or build. Each non-curated dependency records a
40-character Git commit and archive SHA-512 in its overlay port. A scheduled/manual updater must:

1. check whether a curated port now exists and stop for a separate migration if it does;
2. resolve the tracked upstream branch to one immutable commit;
3. recompute the source archive SHA-512 and update the port version plus `upstream-lock.md`;
4. update the four-library Intel closure atomically;
5. run the dependency policy, overlay-pin integrity check, GCC 16.1 provider/product fixtures, and
   the clang-p2996 differential gate;
6. open a reviewable draft change without force-push, auto-merge, or build-time network fallback.

The same latest-commit policy applies to other non-curated overlay sources explicitly selected by
the owner. Stable curated vcpkg dependencies continue to follow the pinned registry baseline unless
the owner directs a separate baseline update.

## Re-evaluation contract

Compile-time work must continue to delete runtime states or repetitive registration while retaining
readable diagnostics. It may not move workflow files, tracker data, database migrations, secrets,
or operator policy into template instantiation. Each new use requires:

1. a named owned mechanism that the library replaces;
2. a small compile-time/provider fixture before product wiring;
3. no third-party types across the public subsystem seam;
4. exact GCC 16.1 evidence and clang-p2996 evidence when reflection is involved;
5. a documented removal or standard-library migration trigger.
