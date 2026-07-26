# OpenSymphony development orchestrator

OpenSymphony is a pinned, external development tool. It is not linked into the
C++ service and does not define Symphony conformance. Its separate orchestrator
image is composed locally through a BuildKit Bake graph from the exact qualified
AMD64 GCC 16.1 compiler child, a clean generic Codex Universal runtime, and
independently generated runtime/rootfs validation markers. This does not repin
or qualify the separately managed development container. OpenSymphony is not
installed in the development container and its image is not published by this
repository.

## Containment boundary

- The target checkout is mounted read-only at `/target`.
- Issue workspaces live in a dedicated Docker volume at `/workspaces`.
- Codex authentication lives only in the `symphony-codex-auth` Docker volume.
- The repository-owned `codex-config.toml` is mounted read-only over only the
  volume's config path; it contains model policy, never authentication.
- The host home directory, Docker socket, SSH agent, and GitHub credentials are
  not mounted.
- `LINEAR_API_KEY` is accepted only from the exact launch command's environment
  or the contained wrapper's stdin. The wrappers capture and unset the exported
  value before invoking Docker and stream it over container stdin, rather than
  exposing it to Docker CLI subprocesses or Docker configuration metadata. It
  remains present in the OpenSymphony process environment while the process is
  running, so host access to Docker is privileged access. No plaintext
  environment file is part of this repository's runtime contract.
- The control plane is exposed only on host loopback.
- OpenSymphony invokes Codex with `danger-full-access` and approval disabled;
  the container is therefore the mandatory security boundary.

## First-run ceremony

1. Run `scripts/test-opensymphony-upstream.sh`. The validated image target runs
   the complete pinned Rust workspace suite as the non-root orchestrator user,
   builds the release only after that stage passes, loads
   `symphony-opensymphony:local`, and prints its immutable local image ID.
   `scripts/build-opensymphony-local.sh` instead creates an explicitly labeled
   `symphony-opensymphony:candidate` only for direct immutable smoke/rootfs
   inspection when an upstream test is blocked. Guarded operator and acceptance
   launchers reject it; never use that candidate operationally. The complete pinned
   suite is mandatory and currently blocked by upstream
   [issue #227](https://github.com/kumanday/OpenSymphony/issues/227), so no
   qualified operational `symphony-opensymphony:local` can be recreated until a
   reviewed immutable upstream correction passes that unchanged gate. See
   [the upstream evolution watch](../../docs/upstream-evolution-watch.md#opensymphony).
   Steps 2–6 are unavailable until step 1 produces that admitted image.
2. Human-create a least-privilege Linear key and store it through the existing
   fnox/Doppler/macOS secrets authority as `LINEAR_API_KEY`. Do not paste it into
   Codex, a shell argument, a project file, or logs.
3. Run `scripts/opensymphony-container.sh login` and complete Codex device login.
4. Run `scripts/opensymphony-container.sh memory-init`, then
   `scripts/opensymphony-container.sh preflight`. The first command seeds a
   private, persistent Docker volume from the checked-in memory policy without
   reading credentials.
5. Inject the key for exactly `scripts/run-opensymphony-contained.sh doctor`
   and `scripts/run-opensymphony-contained.sh dry-run` through the configured
   secret manager. The wrapper refuses every pre-existing resource, creates an
   exact suffix-scoped set of volumes, marks the low-level launcher boundary as
   verified, and removes the owned volumes when the command exits. The launcher
   rejects direct `doctor` and `dry-run` calls that bypass that ceremony, so they
   cannot silently reuse operational defaults. Keep every Linear issue in
   Backlog. `doctor` can create directories/install managed tooling, and
   `run --dry-run` still creates or recovers workspaces, writes run manifests,
   and executes lifecycle hooks even though it launches no model worker.
6. Review the bounded command output. The contained no-model dry run publishes
   no host port; only an explicitly authorized live `run` exposes the gateway at
   `http://127.0.0.1:2468`. The historical `GUI-5` run already consumed the sole
   fixture-only live-canary authorization. Do not activate another Linear issue
   without a new explicit authorization.

The earlier contained ceremony completed against historical immutable image
manifest `sha256:65be3f2e87f57c9698567a3d6830ab93bd70c6268d8a36fcf1b5dad094ba6982`.
That remains evidence for the prior boundary, not the default runtime. The
launcher defaults to `symphony-opensymphony:local`, resolves the selected local
reference once to an immutable image ID, requires the exact pinned source commit
and `upstream-tests=passed` labels, and passes `--pull=never`. Repeat the
contained acceptance, doctor, and contained no-model dry run after every local
base or OpenSymphony pin change. `OPENSYMPHONY_IMAGE` may select another already
local test tag only when it satisfies the same immutable identity and label
gate; it cannot authorize a candidate or mutable registry fallback.

The graph is content-addressed but is not claimed bit-reproducible: its pinned
base digests still perform package-manager operations against moving Debian,
Ubuntu, and npm indexes. The admitted local image ID, exact OpenSymphony commit,
and exact image-policy input digest are therefore the qualification identity.
Do not infer that a later rebuild must produce the same image ID until package
snapshots and npm artifact integrity are independently pinned.

`scripts/opensymphony-container.sh run` is deliberately separate from the dry
run. Running it is authorization to operate only on issues deliberately moved
into a workflow active state; it does not authorize deployment, production
credentials, force-push, or mutation outside the container workspace.

The runner is provider-neutral: it neither retrieves nor stores the secret. A
human-operated fnox or Doppler command may inject `LINEAR_API_KEY` into the exact
runner process; the runner streams only that named value over container stdin and
never prints it or places it in Docker container configuration metadata.

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
./scripts/run-opensymphony-contained.sh doctor
```

`tui` requires an explicitly authorized live `run`; the contained no-model dry
run publishes no gateway port. `debug ISSUE` is a separately authorized manual
recovery action because it may repair archived state and invoke interactive
Codex resume. Do not use retained `GUI-5` state as a routine debug fixture.

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
separate local orchestrator image. Composing the clean generic GCC runtime from
the qualified compiler child gives Codex workers the same compiler semantics
without coupling the orchestrator to the developer's interactive container or
placing Symphony source, vcpkg installations, or `/opt/symphony-cpp-seed` in
the image.

OpenSymphony v2.10.0 `rehydrate` operates on OpenHands conversation manifests.
The Codex-oriented operational wrapper exposes no `rehydrate` command for
either route; future OpenHands proof must invoke the pinned CLI only inside a
disposable fixture. Separately authorized `debug ISSUE` supports persisted
Codex thread unarchive and recovery.

The adopted, deferred, and rejected feature boundaries are tracked in
[`docs/opensymphony-feature-matrix.md`](../../docs/opensymphony-feature-matrix.md).

On the managed development Mac, use the machine-wide wrapper from the
`macos-development-environment` project. It prompts without echo, writes Doppler
`dotfiles/dev_personal` first, synchronizes the fnox age-encrypted cache, and
exports the value into the current shell:

```sh
mde-secret-add LINEAR_API_KEY
# Then run the documented suffix-scoped contained dry-run ceremony.
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
the configuration is treated as healthy, but it is a no-model route execution,
not a read-only operation.

The `codex:` map currently present in `WORKFLOW.md` is repository policy
metadata only. OpenSymphony v2.10.0 ignores its effort escalation and context
rollover fields, and it does not enforce `agent.max_turns`. While an issue
remains active, a successful worker is continued after one second and retryable
failures have no maximum retry count. A separate local C++26 supervisor will
enforce the approved four-run, 90-minute, repeated-failure, no-progress, and
45/50/55% context boundaries around the stock process. It may stop, checkpoint,
and restart its child and select only preapproved Codex overlays; it must not
replace OpenSymphony's issue discovery, priority, concurrency, or retry
scheduler. Keep concurrency at one until write-lane isolation is fixture-proven.
