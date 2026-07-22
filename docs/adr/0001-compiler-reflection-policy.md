# ADR-0001: GCC-defined C++26 reflection semantics

Status: Accepted

Date: 2026-07-22

## Context

C++26 static reflection is intentionally experimental and compiler behavior differs. The service
still needs one release definition and an independent compatibility signal.

## Decision

Use GCC 16.1 with `-std=c++26 -freflection` for development, tests, and executable artifacts. Compile
the reflection fixture suite with Bloomberg clang-p2996 commit `7220baff` using
`-std=c++26 -freflection-latest`. Keep reflection behind `symphony_meta`; use headers, not modules or
PCH. A Clang difference is evidence, never production semantics.

## Consequences

Linux AMD64 is the only supported build architecture initially. Compiler builds are pinned and
reproducible but slow. ARM64 waits for native compiler and conformance evidence.

## Revisit when

The standardized reflection surface ships consistently in two release compilers.

