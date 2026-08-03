#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly repo_root
readonly image="${OPENSYMPHONY_IMAGE:-}"
readonly expected_image="symphony-opensymphony:osv2113-019fc0ca-ticket47"
readonly execution_profile="${OPENSYMPHONY_EXECUTION_PROFILE:-local-desktop-arm64}"
docker_config=""
docker_host=""
case "${execution_profile}" in
  github-actions-native-amd64)
    test "${GITHUB_ACTIONS:-}" = true || {
      printf 'OpenSymphony v2.11.3 build contract failed: GITHUB_ACTIONS is not true\n' >&2
      exit 1
    }
    test "$(dpkg --print-architecture)" = amd64 || exit 1
    test "$(uname -m)" = x86_64 || exit 1
    docker_config="${DOCKER_CONFIG:-}"
    docker_host="${DOCKER_HOST:-}"
    ;;
  local-desktop-arm64)
    docker_config="/tmp/symphony-osv2113-019fc0ca-ticket47-docker-config"
    docker_host="unix:///Users/rmanaloto/.docker/run/docker.sock"
    ;;
  *)
    printf 'OpenSymphony v2.11.3 build contract failed: unsupported execution profile\n' >&2
    exit 1
    ;;
esac
readonly docker_config docker_host
readonly build_container="symphony-osv2113-019fc0ca-ticket47-build"
readonly manifest="${repo_root}/ops/opensymphony/evaluation/v2.11.3/input-manifest-v1.json"
readonly containerfile="${repo_root}/containers/OpenSymphony-v2113-evaluation.Containerfile"
readonly bake_file="${repo_root}/containers/opensymphony-v2113-evaluation.bake.hcl"
readonly build_script="${repo_root}/scripts/build-opensymphony-v2113-evaluation.sh"
readonly input_script="${repo_root}/scripts/opensymphony-v2113-build-input-id.sh"
readonly github_actions_runner="${repo_root}/scripts/run-opensymphony-v2113-github-actions.sh"
readonly upstream_test="${repo_root}/scripts/test-opensymphony-v2113-upstream.sh"
readonly -a docker_cmd=(
  env
  "DOCKER_CONFIG=${docker_config}"
  "DOCKER_HOST=${docker_host}"
  docker
)

fail() {
  printf 'OpenSymphony v2.11.3 build contract failed: %s\n' "$*" >&2
  exit 1
}

docker_config_mode() {
  if test "${execution_profile}" = github-actions-native-amd64; then
    stat -c '%a' "${docker_config}"
  else
    stat -f '%Lp' "${docker_config}"
  fi
}

run_with_timeout() {
  local timeout_seconds="$1"
  shift
  "$@" &
  local command_pid=$!
  local deadline=$((SECONDS + timeout_seconds))
  local command_rc=0
  while kill -0 "${command_pid}" 2>/dev/null; do
    if ((SECONDS >= deadline)); then
      kill -TERM "${command_pid}" 2>/dev/null || true
      local grace_deadline=$((SECONDS + 10))
      while kill -0 "${command_pid}" 2>/dev/null &&
          ((SECONDS < grace_deadline)); do
        sleep 1 >/dev/null 2>&1
      done
      kill -KILL "${command_pid}" 2>/dev/null || true
      wait "${command_pid}" 2>/dev/null || true
      return 124
    fi
    sleep 1 >/dev/null 2>&1
  done
  wait "${command_pid}" || command_rc=$?
  return "${command_rc}"
}

build_container_id=""
cleanup_build_container() {
  local command_rc=$?
  trap - EXIT
  if test -n "${build_container_id}" &&
      "${docker_cmd[@]}" container inspect "${build_container_id}" >/dev/null 2>&1; then
    if test "$(
      "${docker_cmd[@]}" container inspect --format '{{.State.Running}}' \
        "${build_container_id}"
    )" = true; then
      "${docker_cmd[@]}" container stop --time 10 "${build_container_id}" >/dev/null
    fi
    "${docker_cmd[@]}" container rm "${build_container_id}" >/dev/null
  fi
  exit "${command_rc}"
}
trap cleanup_build_container EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

test "${image}" = "${expected_image}" || fail "OPENSYMPHONY_IMAGE is not the authorized tag"
for required_path in \
  "${manifest}" \
  "${containerfile}" \
  "${bake_file}" \
  "${build_script}" \
  "${input_script}" \
  "${github_actions_runner}" \
  "${upstream_test}"; do
  test -f "${required_path}" || fail "missing ${required_path#"${repo_root}/"}"
done
test -x "${build_script}" || fail "build script is not executable"
test -x "${input_script}" || fail "build-input script is not executable"
test -x "${github_actions_runner}" || fail "GitHub Actions runner is not executable"
test -x "${upstream_test}" || fail "upstream test is not executable"
for timeout_script in "${build_script}" "${upstream_test}"; do
  grep -Fq 'local deadline=$((SECONDS + timeout_seconds))' "${timeout_script}" ||
    fail "${timeout_script#"${repo_root}/"} uses a leaking long-sleep watchdog"
  grep -Fq "trap 'exit 130' INT" "${timeout_script}" ||
    fail "${timeout_script#"${repo_root}/"} lacks signal-safe interrupt cleanup"
  grep -Fq "trap 'exit 143' TERM" "${timeout_script}" ||
    fail "${timeout_script#"${repo_root}/"} lacks signal-safe termination cleanup"
done
if test "${execution_profile}" = github-actions-native-amd64; then
  grep -Fq 'readonly expected_buildkit_manifest="sha256:2caaaf9bc673a82d5b0a87824f8375e6b2b36b55001dad611230516c724e9fba"' \
    "${github_actions_runner}" || fail "native runner BuildKit child drifted"
  grep -Fq 'docker buildx inspect --bootstrap "${expected_builder}"' \
    "${github_actions_runner}" || fail "native runner lacks the pinned builder receipt"
else
  grep -Fq "grep -Eq '^BuildKit version:[[:space:]]+v0[.]31[.]1\$'" "${build_script}" ||
    fail "build script does not parse the pinned Buildx BuildKit version receipt"
  test "$(grep -Fc 'moby/buildkit@sha256:4eee950fb9d134cbf4e228ea3906eb4c7403323334af013c443302f7b74f2737' "${build_script}")" = 4 ||
    fail "build script does not accept Docker's digest-shaped BuildKit RepoTag receipt"
  builder_id_line="$(grep -nF 'builder_container_id="$(' "${build_script}" | cut -d: -f1)"
  buildkit_check_line="$(grep -nF "grep -Eq '^BuildKit version:" "${build_script}" | cut -d: -f1)"
  test -n "${builder_id_line}" && test -n "${buildkit_check_line}" &&
    test "${builder_id_line}" -lt "${buildkit_check_line}" ||
    fail "build script does not capture task-owned IDs before receipt validation"
fi

node --input-type=module - "${manifest}" <<'NODE'
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const manifest = JSON.parse(readFileSync(process.argv[2], "utf8"));
assert.equal(manifest.schemaVersion, 1);
assert.equal(manifest.kind, "opensymphony_v2113_evaluation_build_inputs");
assert.equal(manifest.program, "opensymphony-v2.11.3-three-arm");
assert.equal(manifest.controller, "019fc0ca-dde9-7132-91a5-8530d7d76592");
assert.equal(manifest.ticket, 47);
assert.equal(manifest.platform, "linux/amd64");
assert.deepEqual(manifest.openSymphony, {
  repository: "https://github.com/kumanday/OpenSymphony",
  tag: "v2.11.3",
  tagObject: "ed265b58f1b17c0184775635444e1e2be383177f",
  commit: "af6a65459385104fcef4e249980701bf8e7964d4",
  tree: "ddde2287e4bd975dc721b131f039cec6b32f437b",
  archiveUrl: "https://codeload.github.com/kumanday/OpenSymphony/tar.gz/refs/tags/v2.11.3",
  archiveSha256: "6376662ac21d930f0b4b488a7d13e5b8e7fbf94a02d67ab552d7e341ae257a1c",
  cargoLockSha256: "99f92f0a22a89c42a33474bf7b34f4433ef877371f0da10ff532c47b20b74301",
  rust: "1.97.1",
  license: "MIT",
  licenseSha256: "d22aeaebdf4cf94f10801bddcfb204b296581a94023ab92350b18b24c631199f",
});
assert.equal(manifest.codex.tag, "rust-v0.146.0");
assert.equal(manifest.codex.tagObject, "be449751a978f02e5bbba886999662956c7f38f5");
assert.equal(manifest.codex.commit, "e363b08c9175ac1cbe5893615dd2cb9ddf95043b");
assert.equal(manifest.codex.assetSha256, "5ba3b9405543953081f661d0854d266f76e2abbe51d41349355a36de7673776a");
assert.equal(manifest.codex.binarySha256, "2e863156ed35ecc5253b1e2f907a9143077b9f7cb51942070c61996471ff6e04");
assert.equal(manifest.rustImage.manifest, "sha256:389c1ae98c20fbcadca68a685482749267cec3c90893ae4671c5a37cc894c416");
assert.equal(manifest.buildkit.platform, "linux/amd64");
assert.equal(manifest.buildkit.manifest, "sha256:2caaaf9bc673a82d5b0a87824f8375e6b2b36b55001dad611230516c724e9fba");
assert.equal(manifest.githubActions.runner.label, "ubuntu-24.04");
assert.equal(manifest.githubActions.runner.architecture, "amd64");
assert.equal(manifest.githubActions.setupBuildx.commit, "bb05f3f5519dd87d3ba754cc423b652a5edd6d2c");
assert.equal(manifest.githubActions.uploadArtifact.commit, "ea165f8d65b6e75b540449e92b4886f43607fa02");
assert.equal(manifest.githubActions.uploadArtifact.retentionDays, 1);
assert.equal(manifest.dockerfileFrontend.digest, "sha256:865e5dd094beca432e8c0a1d5e1c465db5f998dca4e439981029b3b81fb39ed5");
assert.deepEqual(manifest.exclusions, [
  "standalone-cpp26-product",
  "devcontainer",
  "credentials",
  "daemon-launch",
  "tracker",
  "relay",
  "proxy",
  "tui-launch",
  "codex-app-server-launch",
  "model",
  "publication",
  "deployment",
]);
NODE

grep -Fq 'cargo fmt --check' "${containerfile}"
grep -Fq 'cargo clippy --locked --workspace --all-targets -- -D warnings' "${containerfile}"
grep -Fq 'cargo test --locked --workspace -- --test-threads=1' "${containerfile}"
grep -Fq 'USER opensymphony-build' "${containerfile}" ||
  fail "unchanged upstream tests are not run as a non-root user"
grep -Fq 'uid=10001,gid=10001' "${containerfile}" ||
  fail "non-root Cargo caches lack explicit immutable ownership"
test "$(grep -Fc 'task-added xfails: none' "${containerfile}")" = 1 ||
  fail "upstream evidence does not record zero task-added xfails"
test "$(grep -Fc 'task-added skips: none' "${containerfile}")" = 1 ||
  fail "upstream evidence does not record zero task-added skips"
if sed \
  -e '/task-added xfails: none/d' \
  -e '/task-added skips: none/d' \
  -e '/patches: none/d' \
  "${containerfile}" | grep -Eiq '(^|[^[:alnum:]_])(xfail|--skip|patch)([^[:alnum:]_]|$)'; then
  fail "Containerfile contains a patch, xfail, or skipped-test path"
fi
if grep -Eiq 'git clone|npm (install|ci)|apt-get|fetchcontent|externalproject|cpm' "${containerfile}"; then
  fail "Containerfile bypasses the selected immutable dependency path"
fi
for required_label in \
  'dev.opensymphony.eval.program=opensymphony-v2.11.3-three-arm' \
  'dev.opensymphony.eval.controller=019fc0ca-dde9-7132-91a5-8530d7d76592' \
  'dev.opensymphony.eval.ticket=47' \
  'dev.opensymphony.eval.ownership=temporary' \
  'dev.opensymphony.eval.source.tag-object=ed265b58f1b17c0184775635444e1e2be383177f' \
  'dev.opensymphony.eval.source.commit=af6a65459385104fcef4e249980701bf8e7964d4' \
  'dev.opensymphony.eval.source.tree=ddde2287e4bd975dc721b131f039cec6b32f437b' \
  'dev.opensymphony.eval.source.archive-sha256=6376662ac21d930f0b4b488a7d13e5b8e7fbf94a02d67ab552d7e341ae257a1c' \
  'dev.opensymphony.eval.codex.tag-object=be449751a978f02e5bbba886999662956c7f38f5' \
  'dev.opensymphony.eval.codex.commit=e363b08c9175ac1cbe5893615dd2cb9ddf95043b'; do
  grep -Fq "${required_label}" "${containerfile}" || fail "missing required label ${required_label}"
done

build_input_sha256="$(${input_script})"
readonly build_input_sha256
[[ "${build_input_sha256}" =~ ^[0-9a-f]{64}$ ]] || fail "invalid build-input digest"

test -n "${docker_config}" || fail "private Docker config path is absent"
test -n "${docker_host}" || fail "Docker endpoint is absent"
test -d "${docker_config}" || fail "private Docker config is absent"
test "$(docker_config_mode)" = "700" || fail "private Docker config mode changed"
if test -f "${docker_config}/config.json"; then
  jq -e \
    '((.auths // {}) | length) == 0 and (has("credsStore") | not) and (has("credHelpers") | not)' \
    "${docker_config}/config.json" >/dev/null ||
    fail "private Docker config is malformed or contains authentication material"
fi

graph="$(
  cd "${repo_root}"
  OPENSYMPHONY_IMAGE="${image}" \
    BUILD_INPUT_SHA256="${build_input_sha256}" \
    "${docker_cmd[@]}" buildx bake \
      --file containers/opensymphony-v2113-evaluation.bake.hcl \
      --print \
      opensymphony-v2113-evaluation
)"
readonly graph
jq -e \
  --arg image "${image}" \
  --arg build_input "${build_input_sha256}" \
  '
    (.target | keys) == ["opensymphony-v2113-evaluation"] and
    .target["opensymphony-v2113-evaluation"].context == "." and
    .target["opensymphony-v2113-evaluation"].dockerfile ==
      "containers/OpenSymphony-v2113-evaluation.Containerfile" and
    .target["opensymphony-v2113-evaluation"].target == "evaluation-image" and
    .target["opensymphony-v2113-evaluation"].platforms == ["linux/amd64"] and
    .target["opensymphony-v2113-evaluation"].tags == [$image] and
    .target["opensymphony-v2113-evaluation"].args.BUILD_INPUT_SHA256 == $build_input and
    .target["opensymphony-v2113-evaluation"].output == [{type:"docker"}]
  ' <<<"${graph}" >/dev/null

if (
  cd "${repo_root}"
  OPENSYMPHONY_IMAGE='example.invalid/not-authorized:latest' \
    BUILD_INPUT_SHA256="${build_input_sha256}" \
    "${docker_cmd[@]}" buildx bake \
      --file containers/opensymphony-v2113-evaluation.bake.hcl \
      --print \
      opensymphony-v2113-evaluation
) >/dev/null 2>&1; then
  fail "Bake accepted an unauthorized image tag"
fi

image_id="$("${docker_cmd[@]}" image inspect --format '{{.Id}}' "${image}")"
readonly image_id
[[ "${image_id}" =~ ^sha256:[0-9a-f]{64}$ ]] || fail "image did not resolve to one immutable ID"
inspect="$("${docker_cmd[@]}" image inspect "${image_id}")"
readonly inspect
jq -e \
  --arg image "${image}" \
  --arg image_id "${image_id}" \
  --arg build_input "${build_input_sha256}" \
  '
    length == 1 and
    .[0].Id == $image_id and
    .[0].Os == "linux" and
    .[0].Architecture == "amd64" and
    .[0].RepoTags == [$image] and
    (.[0].RepoDigests // []) == [] and
    .[0].Config.User == "orchestrator" and
    .[0].Config.Cmd == ["opensymphony", "--help"] and
    (.[0].Config.ExposedPorts // {}) == {} and
    .[0].Config.Labels["dev.opensymphony.eval.build-input-sha256"] == $build_input and
    .[0].Config.Labels["dev.opensymphony.eval.upstream-tests"] == "passed-stock-unchanged"
  ' <<<"${inspect}" >/dev/null

if "${docker_cmd[@]}" container inspect "${build_container}" >/dev/null 2>&1; then
  fail "build test container name is already occupied"
fi
build_container_id="$("${docker_cmd[@]}" container create \
  --pull=never --platform linux/amd64 \
  --name "${build_container}" \
  --network none \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=64m \
  --label dev.opensymphony.eval.program=opensymphony-v2.11.3-three-arm \
  --label dev.opensymphony.eval.controller=019fc0ca-dde9-7132-91a5-8530d7d76592 \
  --label dev.opensymphony.eval.ticket=47 \
  --label dev.opensymphony.eval.ownership=temporary \
  --entrypoint /bin/bash \
  "${image_id}" \
  -euo pipefail -c '
    test "$(rustc --version)" = "rustc 1.97.1 (3dea8f2f2 2026-06-16)"
    test "$(cargo --version | awk "{print \$1, \$2}")" = "cargo 1.97.1"
    test "$(codex --version)" = "codex-cli 0.146.0"
    codex app-server --help >/dev/null
    test -x /usr/local/bin/opensymphony
    test -x /usr/local/bin/codex
    test -s /opt/opensymphony/evidence/binaries.sha256
    test -s /opt/opensymphony/evidence/codex-app-server-schema.sha256
    cd /
    sha256sum --check /opt/opensymphony/evidence/binaries.sha256
    sha256sum --check /opt/opensymphony/evidence/codex-app-server-schema.sha256
  ')"
[[ "${build_container_id}" =~ ^[0-9a-f]{64}$ ]] || fail "build test container ID was not captured"
test "$(
  "${docker_cmd[@]}" container inspect --format '{{.Name}}' "${build_container_id}"
)" = "/${build_container}" || fail "build test container name drifted"
test "$(
  "${docker_cmd[@]}" container inspect \
    --format '{{ index .Config.Labels "dev.opensymphony.eval.controller" }}' \
    "${build_container_id}"
)" = "019fc0ca-dde9-7132-91a5-8530d7d76592" || fail "build test ownership label drifted"
printf 'OpenSymphony v2.11.3 build test container: %s\n' "${build_container_id}"
run_with_timeout 3600 "${docker_cmd[@]}" container start --attach "${build_container_id}" ||
  fail "build test container failed or exceeded 3600 seconds"
"${docker_cmd[@]}" container rm "${build_container_id}" >/dev/null
build_container_id=""
if "${docker_cmd[@]}" container inspect "${build_container}" >/dev/null 2>&1; then
  fail "build test container was not removed"
fi

trap - EXIT
printf 'OpenSymphony v2.11.3 build contract passed: %s (%s)\n' "${image}" "${image_id}"
