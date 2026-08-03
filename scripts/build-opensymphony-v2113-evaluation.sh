#!/usr/bin/env bash
set -euo pipefail

unset \
  CODEX_API_KEY \
  DOCKER_AUTH_CONFIG \
  GH_TOKEN \
  GITHUB_TOKEN \
  LINEAR_API_KEY \
  OPENAI_API_KEY

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly repo_root
readonly image="${OPENSYMPHONY_IMAGE:-}"
readonly expected_image="symphony-opensymphony:osv2113-019fc0ca-ticket47"
readonly docker_config="/tmp/symphony-osv2113-019fc0ca-ticket47-docker-config"
readonly docker_host="unix:///Users/rmanaloto/.docker/run/docker.sock"
readonly builder="symphony-osv2113-019fc0ca-ticket47-builder"
readonly builder_container="buildx_buildkit_symphony-osv2113-019fc0ca-ticket47-builder0"
readonly builder_volume="buildx_buildkit_symphony-osv2113-019fc0ca-ticket47-builder0_state"
readonly buildkit_image="moby/buildkit:v0.31.1@sha256:4eee950fb9d134cbf4e228ea3906eb4c7403323334af013c443302f7b74f2737"
readonly -a docker_cmd=(
  env
  "DOCKER_CONFIG=${docker_config}"
  "DOCKER_HOST=${docker_host}"
  docker
)

fail() {
  printf 'OpenSymphony v2.11.3 build failed: %s\n' "$*" >&2
  exit 1
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

builder_claimed=0
builder_container_id=""
buildkit_image_preexisting=0
buildkit_runtime_id=""

cleanup_builder() {
  if test "${builder_claimed}" -eq 0; then
    return
  fi
  if "${docker_cmd[@]}" buildx inspect "${builder}" >/dev/null 2>&1; then
    run_with_timeout 300 "${docker_cmd[@]}" buildx rm "${builder}" >/dev/null || true
  fi
  if "${docker_cmd[@]}" container inspect "${builder_container}" >/dev/null 2>&1; then
    if test "$(
      "${docker_cmd[@]}" container inspect --format '{{.State.Running}}' \
        "${builder_container}"
    )" = true; then
      "${docker_cmd[@]}" container stop --time 10 "${builder_container}" >/dev/null
    fi
    "${docker_cmd[@]}" container rm "${builder_container}" >/dev/null
  fi
  if "${docker_cmd[@]}" volume inspect "${builder_volume}" >/dev/null 2>&1; then
    "${docker_cmd[@]}" volume rm "${builder_volume}" >/dev/null
  fi
  builder_claimed=0
}

cleanup_task_buildkit_image() {
  local buildkit_inspect
  local buildkit_ref
  if test "${buildkit_image_preexisting}" -ne 0 || test -z "${buildkit_runtime_id}"; then
    return
  fi
  if ! buildkit_inspect="$(
    "${docker_cmd[@]}" image inspect "${buildkit_runtime_id}" 2>/dev/null
  )"; then
    return
  fi
  if ! jq -e '
      length == 1 and
      all((.[0].RepoTags // [])[];
        . == "moby/buildkit:v0.31.1" or
        . == "docker.io/moby/buildkit:v0.31.1" or
        . == "moby/buildkit@sha256:4eee950fb9d134cbf4e228ea3906eb4c7403323334af013c443302f7b74f2737" or
        . == "docker.io/moby/buildkit@sha256:4eee950fb9d134cbf4e228ea3906eb4c7403323334af013c443302f7b74f2737") and
      all((.[0].RepoDigests // [])[];
        . == "moby/buildkit@sha256:4eee950fb9d134cbf4e228ea3906eb4c7403323334af013c443302f7b74f2737" or
        . == "docker.io/moby/buildkit@sha256:4eee950fb9d134cbf4e228ea3906eb4c7403323334af013c443302f7b74f2737" or
        . == "moby/buildkit@sha256:6b59b7df63a8cb9902736f9ddf7fcff8261613d3e7449b8ea8b7537fc399c03a" or
        . == "docker.io/moby/buildkit@sha256:6b59b7df63a8cb9902736f9ddf7fcff8261613d3e7449b8ea8b7537fc399c03a")
    ' <<<"${buildkit_inspect}" >/dev/null; then
    printf 'Refusing BuildKit cleanup because references drifted\n' >&2
    return 1
  fi
  while IFS= read -r buildkit_ref; do
    test -n "${buildkit_ref}" || continue
    if "${docker_cmd[@]}" image inspect "${buildkit_runtime_id}" >/dev/null 2>&1; then
      "${docker_cmd[@]}" image rm "${buildkit_ref}" >/dev/null
    fi
  done < <(
    jq -r '.[0] | ((.RepoTags // []) + (.RepoDigests // []))[]' \
      <<<"${buildkit_inspect}"
  )
  if "${docker_cmd[@]}" image inspect "${buildkit_runtime_id}" >/dev/null 2>&1; then
    "${docker_cmd[@]}" image rm "${buildkit_runtime_id}" >/dev/null
  fi
}

cleanup_failed_image() {
  local failed_inspect
  if ! failed_inspect="$("${docker_cmd[@]}" image inspect "${image}" 2>/dev/null)"; then
    return
  fi
  if ! jq -e \
      --arg image "${image}" \
      '
        length == 1 and
        .[0].RepoTags == [$image] and
        (.[0].RepoDigests // []) == [] and
        .[0].Config.Labels["dev.opensymphony.eval.program"] ==
          "opensymphony-v2.11.3-three-arm" and
        .[0].Config.Labels["dev.opensymphony.eval.controller"] ==
          "019fc0ca-dde9-7132-91a5-8530d7d76592" and
        .[0].Config.Labels["dev.opensymphony.eval.ticket"] == "47" and
        .[0].Config.Labels["dev.opensymphony.eval.ownership"] == "temporary"
      ' <<<"${failed_inspect}" >/dev/null; then
    printf 'Refusing failed-image cleanup because ownership or references drifted\n' >&2
    return 1
  fi
  "${docker_cmd[@]}" image rm "${image}" >/dev/null
}

cleanup_on_failure() {
  local command_rc=$?
  trap - EXIT
  if test "${command_rc}" -ne 0; then
    cleanup_builder || true
    cleanup_task_buildkit_image || true
    cleanup_failed_image || true
    if test -e "${docker_config}" || test -L "${docker_config}"; then
      /usr/bin/trash "${docker_config}"
    fi
  fi
  exit "${command_rc}"
}
trap cleanup_on_failure EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

test "${image}" = "${expected_image}" || fail "OPENSYMPHONY_IMAGE is not the authorized tag"
test "$(
  plutil -extract CFBundleShortVersionString raw \
    /Applications/Docker.app/Contents/Info.plist
)" = 4.84.0 || fail "Docker Desktop version drifted"
test "$(
  plutil -extract CFBundleVersion raw /Applications/Docker.app/Contents/Info.plist
)" = 234817 || fail "Docker Desktop build drifted"
test -d "${docker_config}" || fail "private Docker config is absent"
test "$(stat -f '%Lp' "${docker_config}")" = 700 || fail "private Docker config mode changed"
if test -f "${docker_config}/config.json" &&
    jq -e '((.auths // {}) | length) > 0 or has("credsStore") or has("credHelpers")' \
      "${docker_config}/config.json" >/dev/null; then
  fail "private Docker config contains authentication material"
fi
test "$(shasum -a 256 "$(command -v docker)" | awk '{print $1}')" = \
  e109bb333ae9e78ff8fcef016aa65505c2803a712dda660ac6fc8f785ceb760d ||
  fail "Docker CLI binary drifted"
test "$(shasum -a 256 \
  /Applications/Docker.app/Contents/Resources/cli-plugins/docker-buildx | awk '{print $1}')" = \
  77d47bc962b3095110c153bedac111353c4729179124c780f206845b7f33c2e7 ||
  fail "Buildx binary drifted"

docker_version_json="$("${docker_cmd[@]}" version --format '{{json .}}')"
readonly docker_version_json
node --input-type=module - "${docker_version_json}" <<'NODE'
import assert from "node:assert/strict";

const version = JSON.parse(process.argv[2]);
assert.equal(version.Client.Version, "29.7.1");
assert.equal(version.Client.GitCommit, "e9452d6");
assert.equal(version.Server.Version, "29.6.2");
assert.equal(version.Server.GitCommit, "3d80467");
assert.equal(version.Server.ApiVersion, "1.55");
assert.equal(version.Server.Os, "linux");
assert.equal(version.Server.Arch, "arm64");
NODE
test "$("${docker_cmd[@]}" buildx version)" = \
  'github.com/docker/buildx v0.35.0-desktop.2 b554ce1decd8b509893b1e7c6227eabfb923d094' ||
  fail "Buildx version drifted"

if "${docker_cmd[@]}" image inspect "${image}" >/dev/null 2>&1; then
  fail "authorized image tag already exists"
fi
if "${docker_cmd[@]}" buildx inspect "${builder}" >/dev/null 2>&1; then
  fail "task builder already exists"
fi
if "${docker_cmd[@]}" container inspect "${builder_container}" >/dev/null 2>&1; then
  fail "task builder container already exists"
fi
if "${docker_cmd[@]}" volume inspect "${builder_volume}" >/dev/null 2>&1; then
  fail "task builder volume already exists"
fi
if buildkit_runtime_id="$(
  "${docker_cmd[@]}" image inspect --format '{{.Id}}' "${buildkit_image}" 2>/dev/null
)"; then
  buildkit_image_preexisting=1
  printf 'Pre-existing BuildKit image preserved: %s\n' "${buildkit_runtime_id}"
else
  buildkit_runtime_id=""
fi

build_input_sha256="$("${repo_root}/scripts/opensymphony-v2113-build-input-id.sh")"
readonly build_input_sha256
[[ "${build_input_sha256}" =~ ^[0-9a-f]{64}$ ]] || fail "invalid build-input digest"

builder_claimed=1
test "$(
  "${docker_cmd[@]}" buildx create \
    --name "${builder}" \
    --driver docker-container \
    --driver-opt "image=${buildkit_image}" \
    --driver-opt restart-policy=no
)" = "${builder}" || fail "builder creation receipt drifted"
builder_inspect="$(
  run_with_timeout 3600 "${docker_cmd[@]}" buildx inspect --bootstrap "${builder}"
)" || fail "builder bootstrap failed or exceeded 3600 seconds"
readonly builder_inspect

buildkit_runtime_id="$(
  "${docker_cmd[@]}" image inspect --format '{{.Id}}' "${buildkit_image}"
)"
[[ "${buildkit_runtime_id}" =~ ^sha256:[0-9a-f]{64}$ ]] ||
  fail "BuildKit image ID was not captured"
builder_container_id="$(
  "${docker_cmd[@]}" container inspect --format '{{.Id}}' "${builder_container}"
)"
readonly builder_container_id
[[ "${builder_container_id}" =~ ^[0-9a-f]{64}$ ]] || fail "builder container ID was not captured"
test "$(
  "${docker_cmd[@]}" container inspect --format '{{.Image}}' "${builder_container_id}"
)" = "${buildkit_runtime_id}" || fail "builder image ID drifted"
grep -Eq '^BuildKit version:[[:space:]]+v0[.]31[.]1$' <<<"${builder_inspect}" ||
  fail "BuildKit version drifted"
grep -Fq 'linux/amd64' <<<"${builder_inspect}" || fail "builder lacks linux/amd64"
test "$(
  "${docker_cmd[@]}" container inspect --format '{{.Config.Image}}' "${builder_container_id}"
)" = "${buildkit_image}" || fail "builder image reference drifted"
test "$(
  "${docker_cmd[@]}" volume inspect --format '{{.Name}}' "${builder_volume}"
)" = "${builder_volume}" || fail "builder volume receipt drifted"
printf 'OpenSymphony v2.11.3 builder container: %s\n' "${builder_container_id}"
printf 'OpenSymphony v2.11.3 builder volume: %s\n' "${builder_volume}"
printf 'OpenSymphony v2.11.3 BuildKit image: %s\n' "${buildkit_runtime_id}"
printf 'OpenSymphony v2.11.3 build input: %s\n' "${build_input_sha256}"

(
  cd "${repo_root}"
  OPENSYMPHONY_IMAGE="${image}" \
    BUILD_INPUT_SHA256="${build_input_sha256}" \
    run_with_timeout 3600 "${docker_cmd[@]}" buildx bake \
      --builder "${builder}" \
      --file containers/opensymphony-v2113-evaluation.bake.hcl \
      --progress plain \
      opensymphony-v2113-evaluation
) || fail "image build failed or exceeded 3600 seconds"

image_id="$("${docker_cmd[@]}" image inspect --format '{{.Id}}' "${image}")"
readonly image_id
[[ "${image_id}" =~ ^sha256:[0-9a-f]{64}$ ]] || fail "image ID was not captured"
image_inspect="$("${docker_cmd[@]}" image inspect "${image_id}")"
readonly image_inspect
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
    .[0].Config.Labels["dev.opensymphony.eval.build-input-sha256"] == $build_input and
    .[0].Config.Labels["dev.opensymphony.eval.upstream-tests"] ==
      "passed-stock-unchanged"
  ' <<<"${image_inspect}" >/dev/null || fail "image identity receipt drifted"

cleanup_builder
cleanup_task_buildkit_image || fail "task-pulled BuildKit image cleanup failed"
if "${docker_cmd[@]}" buildx inspect "${builder}" >/dev/null 2>&1; then
  fail "builder was not removed"
fi
if "${docker_cmd[@]}" container inspect "${builder_container}" >/dev/null 2>&1; then
  fail "builder container was not removed"
fi
if "${docker_cmd[@]}" volume inspect "${builder_volume}" >/dev/null 2>&1; then
  fail "builder volume was not removed"
fi
if test "${buildkit_image_preexisting}" -eq 0 &&
    "${docker_cmd[@]}" image inspect "${buildkit_runtime_id}" >/dev/null 2>&1; then
  fail "task-pulled BuildKit image was not removed"
fi

trap - EXIT
printf 'Built immutable OpenSymphony v2.11.3 evaluation image: %s (%s)\n' \
  "${image}" "${image_id}"
