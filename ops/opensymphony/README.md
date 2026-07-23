# OpenSymphony development orchestrator

OpenSymphony is a pinned, external development tool. It is not linked into the
C++ service and does not define Symphony conformance. The image is built on
GitHub Actions so the compiler-heavy build does not consume the development Mac.

## Containment boundary

- The target checkout is mounted read-only at `/target`.
- Issue workspaces live in a dedicated Docker volume at `/workspaces`.
- Codex authentication lives only in the `symphony-codex-auth` Docker volume.
- The repository-owned `codex-config.toml` is mounted read-only over only the
  volume's config path; it contains model policy, never authentication.
- The host home directory, Docker socket, SSH agent, and GitHub credentials are
  not mounted.
- `LINEAR_API_KEY` is accepted only from the exact launch command's environment;
  no plaintext environment file is part of this repository's runtime contract.
- The control plane is exposed only on host loopback.
- OpenSymphony invokes Codex with `danger-full-access` and approval disabled;
  the container is therefore the mandatory security boundary.

## First-run ceremony

1. Dispatch `.github/workflows/opensymphony-image.yml` and wait for the tested
   `ghcr.io/ray-manaloto/symphony-orchestrator:edge` package.
2. Human-create a least-privilege Linear key and store it through the existing
   fnox/Doppler/macOS secrets authority as `LINEAR_API_KEY`. Do not paste it into
   Codex, a shell argument, a project file, or logs.
3. Run `scripts/opensymphony-container.sh login` and complete Codex device login.
4. Run `scripts/opensymphony-container.sh memory-init`, then
   `scripts/opensymphony-container.sh preflight`. The first command seeds a
   private, persistent Docker volume from the checked-in memory policy without
   reading credentials.
5. Inject the key for exactly `scripts/opensymphony-container.sh doctor` and
   `scripts/opensymphony-container.sh dry-run` through
   the configured secret manager. Keep every Linear issue in
   Backlog so this first check performs no worker launch.
6. Inspect `http://127.0.0.1:2468` and the container logs. Activate exactly one
   fixture-only canary issue only after the dry run is healthy.

That ceremony completed against immutable image manifest
`sha256:65be3f2e87f57c9698567a3d6830ab93bd70c6268d8a36fcf1b5dad094ba6982`,
which is therefore the launcher's default. A later workflow-only rebuild moved
the mutable `edge` tag to
`sha256:56d7fd2274e2d7eda4ff1d3556a6a9315014e3a05055422e9c4c68849be36911`
and passed tool smoke tests, but it has not repeated the credential-bearing
read-only ceremony. Set `OPENSYMPHONY_IMAGE` only for an explicitly authorized
re-validation; never let `edge` silently replace the proven runtime.

`scripts/opensymphony-container.sh run` is deliberately separate from the dry
run. Running it is authorization to operate only on issues deliberately moved
into a workflow active state; it does not authorize deployment, production
credentials, force-push, or mutation outside the container workspace.

The runner is provider-neutral: it neither retrieves nor stores the secret. A
human-operated fnox or Doppler command may inject `LINEAR_API_KEY` into the exact
runner process; the runner forwards only that named value into the container and
never prints it.

## Upstream bootstrap reconciliation

The v2.10.0 `opensymphony init` command was exercised in a disposable repository
with `--non-interactive`, the `codex/implementation` target branch, this Linear
project slug, and no PR-review provider. It was not run over this checkout:
`init` fetches a mutable template payload and would overwrite repository-specific
policy. The useful generated memory policy and skill were instead adopted
selectively while retaining the stricter C++26, fixture-first, and
dependency-first rules.

The checked-in `.opensymphony/memory/memory.yaml` is only the seed policy.
Runtime capsules, indexes, and learned ontology updates live in the private
`symphony-opensymphony-state` Docker volume mounted over
`/target/.opensymphony`; they are not committed. `memory-init` is idempotent and
does not overwrite an existing learned policy. Automatic capture and the
read-only memory server are enabled, but automatic Linear archival remains
disabled. Generated topic documentation is staged under
`.opensymphony/memory/generated-docs` in that same private volume because the
canonical checkout remains read-only. Promoting generated text into tracked
documentation requires a separate review and normal repository checks.
`memory-init` also performs one narrowly scoped migration from the former
`docs`/public staging fields, preserving a backup named
`memory.yaml.pre-private-doc-staging`. Existing learned area targets under
`docs/` are redirected into the private generated-doc staging directory while
the rest of each learned area is preserved.

Use the contained operator commands:

```sh
./scripts/opensymphony-container.sh preflight
./scripts/opensymphony-container.sh memory-status
./scripts/opensymphony-container.sh memory-context GUI-5
./scripts/opensymphony-container.sh tui
./scripts/opensymphony-container.sh doctor
./scripts/opensymphony-container.sh debug GUI-5
```

`doctor` is exposed for exact upstream diagnostics. With the Codex route it
parses the configuration and workflow, renders the prompt, validates the
workspace, and correctly skips `uv` and managed OpenHands tooling. OpenSymphony
v2.10.0 still requires `cargo` and `curl` even after recognizing that the target
is not a Rust workspace. The complete image therefore retains its exact Rust
1.93 toolchain and installs `curl`; the guarded acceptance suite requires
`doctor` to pass. The contained `preflight` command additionally verifies strict Codex configuration,
login status, app-server schema generation and required lifecycle methods,
workspace and memory-volume writability, and the passing configuration,
workflow, and prompt-rendering portions of `doctor`. Do not add a second
compiler toolchain to the standalone C++ service: these tools exist only in the
external orchestrator image.

OpenSymphony v2.10.0 `rehydrate` operates on OpenHands conversation manifests,
so it is deliberately not exposed for the Codex route. Use `debug ISSUE`,
which supports persisted Codex thread unarchive and recovery.

The adopted, deferred, and rejected feature boundaries are tracked in
[`docs/opensymphony-feature-matrix.md`](../../docs/opensymphony-feature-matrix.md).

On the managed development Mac, use the machine-wide wrapper from the
`macos-development-environment` project. It prompts without echo, writes Doppler
`dotfiles/dev_personal` first, synchronizes the fnox age-encrypted cache, and
exports the value into the current shell:

```sh
mde-secret-add LINEAR_API_KEY
./scripts/opensymphony-container.sh dry-run
```

If the wrapper is not found, open a fresh zsh session or source `~/.zshrc`; do
not replace it with a repository-local secret store.

## Worker model policy

The contained Codex CLI 0.145.0 `model/list` method was probed through the
isolated login without starting a model-backed turn. It advertises
`gpt-5.6-sol` and reasoning efforts through `ultra`. OpenSymphony v2.10.0
receives `routing.model: gpt-5.6-sol`; the read-only Codex configuration overlay
sets `model_reasoning_effort = "high"`. Re-run the read-only catalog and
effective-config probes whenever the pinned image or Codex CLI changes.
The post-pin dry run must retain zero running workers and zero token usage before
the configuration is treated as healthy.
