# Architecture

Dependencies point inward: executables depend on services, services depend on abstract boundaries,
and the domain has no I/O dependency.

```text
symphonyd / symphonyctl
  -> scheduler + workflow + observability
  -> tracker | workspace | codex runtime interfaces
  -> domain + meta
```

The single scheduler object owns mutable run and retry state. Adapters return values and events; they
do not mutate scheduler state. All clocks are injected. Workspace paths are derived beneath one
canonical root and revalidated before hooks or cleanup.

Reflection is isolated in `symphony_meta`. GCC 16.1 supplies the release semantics. The
clang-p2996 job compiles the same reflected fixtures and records differences; it never creates a
release artifact. Conventional headers avoid the fork's documented serialization limitations.

