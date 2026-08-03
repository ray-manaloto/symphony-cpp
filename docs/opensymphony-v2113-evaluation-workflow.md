# OpenSymphony v2.11.3 native evaluation workflow

This issue-47-only workflow builds the stock linux/amd64 evaluation image on a fresh GitHub-hosted
`ubuntu-24.04` x64 runner. It replaces the attempted Apple-Silicon emulation route; it does not
publish or admit the image, run an OpenSymphony service, or grant issue #48 authority.

## Immutable route

The initial event is one push to `refs/heads/codex/opensymphony-v2113-gha`. GitHub does not accept
`workflow_dispatch` for a workflow absent from the default branch, so the exact branch and path
filters are the initial-run boundary. Manual dispatch is retained only for a later default-branch
copy and the runner rejects a dispatch from any ref other than `refs/heads/main`.

The publication hook admits exactly one child commit of
`b682ef362494936b38f99468b0e84788cceec17e`, containing exactly these paths:

- `.github/workflows/opensymphony-v2113-evaluation.yml`
- `containers/OpenSymphony-v2113-evaluation.Containerfile`
- `containers/opensymphony-v2113-evaluation.bake.hcl`
- `docs/dependency-decisions.md`
- `docs/opensymphony-v2113-evaluation-workflow.md`
- `docs/upstream-lock.md`
- `ops/opensymphony/evaluation/v2.11.3/input-manifest-v1.json`
- `scripts/build-opensymphony-v2113-evaluation.sh`
- `scripts/check-push-route.mjs`
- `scripts/opensymphony-v2113-build-input-id.sh`
- `scripts/run-opensymphony-v2113-github-actions.sh`
- `scripts/test-opensymphony-v2113-build.sh`
- `scripts/test-opensymphony-v2113-github-actions.mjs`
- `scripts/test-opensymphony-v2113-upstream.sh`
- `scripts/test-push-route.mjs`

The route requires a clean index and clean copies of those 15 paths while permitting unrelated
pre-existing checkout dirt to remain untouched. It reruns the static workflow contracts,
ShellCheck, the dependency-policy check, the build-input identity, and the redacted publication
scanner. The pre-push hook then reads the exact zero-finding receipt twice around an independent
range check. No generic new-branch, container-recipe, unknown-path, or `--no-verify` exemption is
introduced.

The separately authorized initial publication produced commit
`e7f2bf480c79d8c1c5d6b81e3c474b576250fc55` on the exact target branch and triggered push-event
run `30839315779`, attempt 1. That run is immutable and failed before image construction: the
runner sent GitHub's 40-character lowercase `github.sha` through the 64-character SHA-256
validator. It produced no transfer artifact. The workflow also supplied `install: false` to
`docker/setup-buildx-action@bb05f3f5519dd87d3ba754cc423b652a5edd6d2c`, whose pinned action
metadata has no `install` input. The correction removes only that unsupported input and retains
the supported `cleanup: true` input.

## Exact fast-forward correction

The correction guard admits exactly one child commit of
`e7f2bf480c79d8c1c5d6b81e3c474b576250fc55`, containing exactly these six paths:

- `.github/workflows/opensymphony-v2113-evaluation.yml`
- `docs/opensymphony-v2113-evaluation-workflow.md`
- `scripts/check-push-route.mjs`
- `scripts/run-opensymphony-v2113-github-actions.sh`
- `scripts/test-opensymphony-v2113-github-actions.mjs`
- `scripts/test-push-route.mjs`

It requires local ref `refs/heads/codex/implementation`, remote `origin`, push URL
`git@github.com:ray-manaloto/symphony-cpp.git`, remote destination
`refs/heads/codex/opensymphony-v2113-gha`, and a matching remote-tracking base at the failed commit.
It rejects any wrong base or parent, extra commit, missing or extra path, dirty owned path,
destination drift, or stale remote-tracking state. The runner now validates `github.sha` as exactly
40 lowercase hexadecimal characters while retaining the distinct exact-64-character validator for
SHA-256 fields.

After a separately authorized correction commit, the preparation command and proposed
fast-forward push are:

```sh
node scripts/check-push-route.mjs prepare-opensymphony-v2113-github-actions-correction
git push origin refs/heads/codex/implementation:refs/heads/codex/opensymphony-v2113-gha
```

The separately authorized correction produced commit
`e68094924412a8d4248e67e2717aad49e0576907` and push-event run `30842061123`, run 2 attempt 1.
That immutable run also failed before image construction and before `docker buildx bake` because
`scripts/opensymphony-v2113-build-input-id.sh` unconditionally invoked BSD
`stat -f '%Lp'` on the `ubuntu-24.04` runner. Step 9 cleanup succeeded and removed the exact
builder; upload was skipped and the run has zero artifacts. Neither failed run is rerun, cancelled,
or otherwise mutated.

## Final portability correction

The final correction guard admits exactly one child commit of
`e68094924412a8d4248e67e2717aad49e0576907`, containing exactly these six paths:

- `.github/workflows/opensymphony-v2113-evaluation.yml`
- `docs/opensymphony-v2113-evaluation-workflow.md`
- `scripts/check-push-route.mjs`
- `scripts/opensymphony-v2113-build-input-id.sh`
- `scripts/test-opensymphony-v2113-github-actions.mjs`
- `scripts/test-push-route.mjs`

The build-input script selects only from exact `uname -s`: Linux uses GNU `stat -c '%a'` and
`sha256sum`; Darwin uses BSD `stat -f '%Lp'` and `shasum -a 256`; every other OS, missing or failed
tool, mode outside 644/755, or non-lowercase/non-64-character digest fails explicitly. Both branches
serialize the unchanged v2 domain and path order byte-for-byte identically. An early post-checkout,
pre-Docker workflow step proves the script emits exactly one 64-character lowercase SHA-256.

The guard retains the same local ref, remote, push URL, and destination constraints while requiring
the remote-tracking base to equal `e68094924412a8d4248e67e2717aad49e0576907`. Its local preparation
command and proposed fast-forward push are:

```sh
node scripts/check-push-route.mjs prepare-opensymphony-v2113-github-actions-portability-correction
git push origin refs/heads/codex/implementation:refs/heads/codex/opensymphony-v2113-gha
```

This final local correction does not authorize or perform that push. A separately approved third
push and its new automatic Actions run are required, and no success is claimed here. Another
pre-build harness failure ends further OpenSymphony correction rather than opening another patch
cycle.

## Native build and evidence

The single job grants only `contents: read`. Checkout disables credential persistence. The job
asserts `dpkg --print-architecture=amd64` and `uname -m=x86_64`, creates a private mode-0700 Docker
configuration with no authentication material, and only then invokes the exact pinned Buildx
action. The named builder uses Buildx `v0.35.0` and the linux/amd64 child
`sha256:2caaaf9bc673a82d5b0a87824f8375e6b2b36b55001dad611230516c724e9fba` from the pinned
BuildKit `v0.31.1` index.

The runner computes the domain-separated build-input v2 identity, executes the existing Bake
target, and requires the resulting image to have the exact tag, linux/amd64 platform, immutable
image ID and manifest digest, build-input label, source labels, and unchanged-stock-test label. It
then runs the unchanged upstream and component/image one-shot contracts. Those containers are
network-disabled, read-only, name-bound, label-bound, and removed by captured ID. Version and help
checks prove the real OpenSymphony binary, gateway/run command, shipped TUI command, and Codex
app-server command are present; no daemon, gateway, TUI, app-server service, tracker, or model is
started.

`docker image save` supplies the exact tagged image bytes. GNU tar rewrites only archive-container
metadata using sorted names, epoch mtime, numeric uid/gid zero, and a fixed format; `gzip -n -9`
removes filename/time variability. Two serializations of the same saved image must be byte
identical. This proves deterministic transfer serialization of one image ID, not cross-run
reproducibility of the mutable hosted-runner environment.

The cleanup-transfer manifest binds:

- workflow path/ref/SHA-256, event, Git ref, Git commit, run ID, and run attempt;
- Buildx action, BuildKit index/child, builder, build-input SHA-256, and target platform;
- image tag, image ID, manifest digest, inspect SHA-256, labels, binary-hash receipt, and Codex
  app-server schema-hash receipt;
- unchanged stock, component/image, and double-serialization test results;
- archive path, byte count, and SHA-256; and
- upload action commit, artifact name, one-day retention, cleanup readback, and residual
  uncertainty.

Before the upload step, the runner removes only the exact task test containers, image tag/ID,
builder container, builder volume, builder record, and private configuration after ownership and
reference checks. The always-run cleanup repeats the exact zero-state proof on success or failure.
No task network is created. A private ownership marker protects the two exact runner-local work
directories; it is excluded from upload, and the always-run step removes both directories after a
successful upload or on failure. The successful compressed archive and evidence packet in the
authenticated Actions service are then the only residual.

## Temporary artifact and owner readback

The artifact name is `opensymphony-v2113-ticket47-${GITHUB_SHA}`, uploaded by
`actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02` with retention one day,
no overwrite, and no hidden files. It is an authenticated GitHub Actions transfer to issue #48,
not a package, image registry publication, release, deployment, or admission result.

After separately authorizing GitHub reads and the workflow run, the owner readback operations are:

```sh
gh run list --repo ray-manaloto/symphony-cpp --workflow opensymphony-v2113-evaluation.yml --branch codex/opensymphony-v2113-gha --event push --limit 1 --json databaseId,headBranch,headSha,status,conclusion,workflowName,url
gh run view RUN_ID --repo ray-manaloto/symphony-cpp --json attempt,conclusion,createdAt,databaseId,event,headBranch,headSha,jobs,name,status,updatedAt,url,workflowDatabaseId,workflowName
gh api repos/ray-manaloto/symphony-cpp/actions/runs/RUN_ID/artifacts
gh run download RUN_ID --repo ray-manaloto/symphony-cpp --name opensymphony-v2113-ticket47-GITHUB_SHA --dir DOWNLOAD_DIRECTORY
sha256sum DOWNLOAD_DIRECTORY/opensymphony-v2113-ticket47-image.tar.gz DOWNLOAD_DIRECTORY/cleanup-transfer-v1.json
```

Replace `RUN_ID`, `GITHUB_SHA`, and `DOWNLOAD_DIRECTORY` only with values independently read from
the successful exact run. Compare the API artifact ID, name, size, expiry, and service digest to
the run and local packet before issue #48 consumes anything. The service artifact expires after
one day; early deletion, if later authorized, is the exact operation
`gh api --method DELETE repos/ray-manaloto/symphony-cpp/actions/artifacts/ARTIFACT_ID` after an
independent ID/name/run/SHA readback. This issue does not perform that deletion or any #48 action.

## Exclusions

The workflow has no registry login, package write, OIDC, attestation, secret expression, cache,
image push, release, deployment, live credential, daemon, gateway, TUI, Codex app-server service,
model, tracker, relay, proxy, pre-existing container, or successor operation. Local verification
does not invoke Docker. A hosted runner label is mutable and artifact availability/readback is an
authenticated GitHub service property; both remain explicit residual uncertainties.
