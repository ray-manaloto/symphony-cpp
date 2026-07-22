# OpenSymphony development orchestrator

OpenSymphony is a pinned, external development tool. It is not linked into the
C++ service and does not define Symphony conformance. The image is built on
GitHub Actions so the compiler-heavy build does not consume the development Mac.

## Containment boundary

- The target checkout is mounted read-only at `/target`.
- Issue workspaces live in a dedicated Docker volume at `/workspaces`.
- Codex authentication lives only in the `symphony-codex-auth` Docker volume.
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
4. Inject the key for exactly `scripts/opensymphony-container.sh dry-run` through
   the configured secret manager. Keep every Linear issue in
   Backlog so this first check performs no worker launch.
5. Inspect `http://127.0.0.1:2468` and the container logs. Activate exactly one
   fixture-only canary issue only after the dry run is healthy.

`scripts/opensymphony-container.sh run` is deliberately separate from the dry
run. Running it is authorization to operate only on issues deliberately moved
into a workflow active state; it does not authorize deployment, production
credentials, force-push, or mutation outside the container workspace.

The runner is provider-neutral: it neither retrieves nor stores the secret. A
human-operated fnox or Doppler command may inject `LINEAR_API_KEY` into the exact
runner process; the runner forwards only that named value into the container and
never prints it.

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
