#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly repo_root
readonly expected_profile="github-actions-native-amd64"
readonly expected_image="symphony-opensymphony:osv2113-019fc0ca-ticket47"
readonly expected_builder="symphony-osv2113-019fc0ca-ticket47-builder"
readonly expected_builder_container="buildx_buildkit_symphony-osv2113-019fc0ca-ticket47-builder0"
readonly expected_builder_volume="buildx_buildkit_symphony-osv2113-019fc0ca-ticket47-builder0_state"
readonly expected_buildkit_index="sha256:6b59b7df63a8cb9902736f9ddf7fcff8261613d3e7449b8ea8b7537fc399c03a"
readonly expected_buildkit_manifest="sha256:2caaaf9bc673a82d5b0a87824f8375e6b2b36b55001dad611230516c724e9fba"
readonly expected_buildkit_ref="moby/buildkit@${expected_buildkit_manifest}"
readonly expected_upstream_container="symphony-osv2113-019fc0ca-ticket47-upstream"
readonly expected_build_container="symphony-osv2113-019fc0ca-ticket47-build"
readonly expected_config_name="symphony-osv2113-019fc0ca-ticket47-docker-config"
readonly workflow_path=".github/workflows/opensymphony-v2113-evaluation.yml"
readonly input_manifest="ops/opensymphony/evaluation/v2.11.3/input-manifest-v1.json"
readonly bake_file="containers/opensymphony-v2113-evaluation.bake.hcl"
readonly artifact_action="actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02"
readonly buildx_action="docker/setup-buildx-action@bb05f3f5519dd87d3ba754cc423b652a5edd6d2c"
readonly task_directory_marker="019fc0ca-dde9-7132-91a5-8530d7d76592:47"

fail() {
  printf 'OpenSymphony v2.11.3 GitHub Actions runner failed: %s\n' "$*" >&2
  exit 1
}

docker() {
  env \
    "DOCKER_CONFIG=${DOCKER_CONFIG}" \
    "DOCKER_HOST=${DOCKER_HOST}" \
    docker "$@"
}

require_lower_sha256() {
  [[ "$1" =~ ^[0-9a-f]{64}$ ]] || fail "$2 is not a lowercase SHA-256"
}

require_digest() {
  [[ "$1" =~ ^sha256:[0-9a-f]{64}$ ]] || fail "$2 is not an immutable digest"
}

require_github_environment() {
  test "${GITHUB_ACTIONS:-}" = true || fail "GITHUB_ACTIONS is not true"
  test "${OPENSYMPHONY_EXECUTION_PROFILE:-}" = "${expected_profile}" ||
    fail "execution profile is not the approved native profile"
  test "${OPENSYMPHONY_IMAGE:-}" = "${expected_image}" ||
    fail "image tag is not the approved task tag"
  test "${OPENSYMPHONY_BUILDER:-}" = "${expected_builder}" ||
    fail "builder is not the approved task builder"
  test "${DOCKER_HOST:-}" = "unix:///var/run/docker.sock" ||
    fail "runner Docker endpoint drifted"
  test -n "${RUNNER_TEMP:-}" || fail "RUNNER_TEMP is absent"
  test "${DOCKER_CONFIG:-}" = "/tmp/${expected_config_name}" ||
    fail "private Docker config path drifted"
  test "${OPENSYMPHONY_ARTIFACT_DIR:-}" = \
    "/tmp/opensymphony-v2113-ticket47-artifact" ||
    fail "artifact directory drifted"
}

verify_private_config() {
  test -d "${DOCKER_CONFIG}" || fail "private Docker config is absent"
  test ! -L "${DOCKER_CONFIG}" || fail "private Docker config is a symlink"
  test "$(stat -c '%a' "${DOCKER_CONFIG}")" = 700 ||
    fail "private Docker config mode is not 0700"
  if test -f "${DOCKER_CONFIG}/config.json"; then
    jq -e \
      '((.auths // {}) | length) == 0 and (has("credsStore") | not) and (has("credHelpers") | not)' \
      "${DOCKER_CONFIG}/config.json" >/dev/null ||
      fail "private Docker config contains authentication material"
  fi
}

verify_host_boundary() {
  require_github_environment
  test "$(dpkg --print-architecture)" = amd64 || fail "runner package architecture is not amd64"
  test "$(uname -m)" = x86_64 || fail "runner machine is not x86_64"
  verify_private_config
  test "$(git -C "${repo_root}" rev-parse --verify 'HEAD^{commit}')" = \
    "${OPENSYMPHONY_GITHUB_SHA}" || fail "checkout HEAD does not match github.sha"
  case "${OPENSYMPHONY_GITHUB_EVENT_NAME:-}" in
    push)
      test "${OPENSYMPHONY_GITHUB_REF:-}" = \
        "refs/heads/codex/opensymphony-v2113-gha" ||
        fail "initial push ref is not the exact #47 branch"
      ;;
    workflow_dispatch)
      test "${OPENSYMPHONY_GITHUB_REF:-}" = "refs/heads/main" ||
        fail "manual dispatch is allowed only after the workflow reaches default branch"
      ;;
    *) fail "unsupported workflow event" ;;
  esac
  require_lower_sha256 "${OPENSYMPHONY_GITHUB_SHA}" "github.sha"
  [[ "${OPENSYMPHONY_GITHUB_RUN_ID:-}" =~ ^[1-9][0-9]*$ ]] || fail "invalid run ID"
  [[ "${OPENSYMPHONY_GITHUB_RUN_ATTEMPT:-}" =~ ^[1-9][0-9]*$ ]] ||
    fail "invalid run attempt"
  test "${OPENSYMPHONY_ARTIFACT_ACTION:-}" = "${artifact_action}" ||
    fail "artifact action identity drifted"
  test "${OPENSYMPHONY_BUILDX_ACTION:-}" = "${buildx_action}" ||
    fail "Buildx action identity drifted"
  test "${OPENSYMPHONY_ARTIFACT_NAME:-}" = \
    "opensymphony-v2113-ticket47-${OPENSYMPHONY_GITHUB_SHA}" ||
    fail "artifact name drifted"
}

task_container_id() {
  local name="$1"
  docker container inspect --format '{{.Id}}' "${name}" 2>/dev/null || true
}

verify_task_container() {
  local id="$1"
  local expected_name="$2"
  test "$(docker container inspect --format '{{.Name}}' "${id}")" = "/${expected_name}" ||
    fail "task container name drifted"
  test "$(docker container inspect --format '{{ index .Config.Labels "dev.opensymphony.eval.controller" }}' "${id}")" = \
    "019fc0ca-dde9-7132-91a5-8530d7d76592" || fail "task container controller label drifted"
  test "$(docker container inspect --format '{{ index .Config.Labels "dev.opensymphony.eval.ticket" }}' "${id}")" = 47 ||
    fail "task container ticket label drifted"
  test "$(docker container inspect --format '{{ index .Config.Labels "dev.opensymphony.eval.ownership" }}' "${id}")" = temporary ||
    fail "task container ownership label drifted"
}

remove_task_container_if_present() {
  local name="$1"
  local id
  id="$(task_container_id "${name}")"
  test -z "${id}" && return 0
  [[ "${id}" =~ ^[0-9a-f]{64}$ ]] || fail "invalid task container ID"
  verify_task_container "${id}" "${name}"
  if test "$(docker container inspect --format '{{.State.Running}}' "${id}")" = true; then
    docker container stop --time 10 "${id}" >/dev/null
  fi
  docker container rm "${id}" >/dev/null
}

remove_task_image_if_present() {
  local image_id
  image_id="$(docker image inspect --format '{{.Id}}' "${expected_image}" 2>/dev/null || true)"
  test -z "${image_id}" && return 0
  require_digest "${image_id}" "task image ID"
  local inspect
  inspect="$(docker image inspect "${image_id}")"
  jq -e --arg tag "${expected_image}" '
    length == 1 and
    .[0].RepoTags == [$tag] and
    (.[0].RepoDigests // []) == [] and
    .[0].Config.Labels["dev.opensymphony.eval.controller"] ==
      "019fc0ca-dde9-7132-91a5-8530d7d76592" and
    .[0].Config.Labels["dev.opensymphony.eval.ticket"] == "47" and
    .[0].Config.Labels["dev.opensymphony.eval.ownership"] == "temporary"
  ' <<<"${inspect}" >/dev/null || fail "task image has an unexpected reference or ownership"
  docker image rm "${expected_image}" >/dev/null
}

verify_builder_ownership() {
  local receipt
  receipt="$(docker buildx inspect "${expected_builder}")"
  grep -Eq "^Name:[[:space:]]+${expected_builder}$" <<<"${receipt}" ||
    fail "builder record name drifted"
  grep -Eq '^Driver:[[:space:]]+docker-container$' <<<"${receipt}" ||
    fail "builder driver drifted"
  local builder_container_id
  builder_container_id="$(task_container_id "${expected_builder_container}")"
  if test -n "${builder_container_id}"; then
    [[ "${builder_container_id}" =~ ^[0-9a-f]{64}$ ]] || fail "builder container ID is invalid"
    test "$(docker container inspect --format '{{.Config.Image}}' "${builder_container_id}")" = \
      "${expected_buildkit_ref}" || fail "builder container image drifted"
  fi
}

remove_task_builder_if_present() {
  if docker buildx inspect "${expected_builder}" >/dev/null 2>&1; then
    verify_builder_ownership
    docker buildx rm "${expected_builder}" >/dev/null
  fi
  local builder_container_id
  builder_container_id="$(task_container_id "${expected_builder_container}")"
  if test -n "${builder_container_id}"; then
    test "$(docker container inspect --format '{{.Config.Image}}' "${builder_container_id}")" = \
      "moby/buildkit@${expected_buildkit_manifest}" ||
      fail "orphaned builder container image is not task-owned"
    if test "$(docker container inspect --format '{{.State.Running}}' "${builder_container_id}")" = true; then
      docker container stop --time 10 "${builder_container_id}" >/dev/null
    fi
    docker container rm "${builder_container_id}" >/dev/null
  fi
  if docker volume inspect "${expected_builder_volume}" >/dev/null 2>&1; then
    docker volume rm "${expected_builder_volume}" >/dev/null
  fi
}

remove_task_buildkit_image_if_present() {
  local image_id
  image_id="$(docker image inspect --format '{{.Id}}' "${expected_buildkit_ref}" 2>/dev/null || true)"
  test -z "${image_id}" && return 0
  require_digest "${image_id}" "BuildKit image ID"
  docker image inspect "${image_id}" | jq -e --arg digest "${expected_buildkit_manifest}" '
    length == 1 and
    (.[0].RepoTags // []) == [] and
    (.[0].RepoDigests | length) == 1 and
    (.[0].RepoDigests[0] == ("moby/buildkit@" + $digest) or
      .[0].RepoDigests[0] == ("docker.io/moby/buildkit@" + $digest))
  ' >/dev/null || fail "BuildKit image has an unexpected reference"
  docker image rm "${expected_buildkit_ref}" >/dev/null
}

assert_no_task_networks() {
  if docker network ls --format '{{.Name}}' |
      grep -Eq 'osv2113|v2113|2[.]11[.]3'; then
    fail "a task-shaped Docker network exists"
  fi
}

cleanup_owned_resources() {
  verify_private_config
  remove_task_container_if_present "${expected_upstream_container}"
  remove_task_container_if_present "${expected_build_container}"
  remove_task_image_if_present
  remove_task_builder_if_present
  remove_task_buildkit_image_if_present
  assert_no_task_networks
}

count_exact_resources() {
  local count=0
  for name in "${expected_upstream_container}" "${expected_build_container}" "${expected_builder_container}"; do
    test -z "$(task_container_id "${name}")" || count=$((count + 1))
  done
  docker image inspect "${expected_image}" >/dev/null 2>&1 && count=$((count + 1))
  docker buildx inspect "${expected_builder}" >/dev/null 2>&1 && count=$((count + 1))
  docker volume inspect "${expected_builder_volume}" >/dev/null 2>&1 && count=$((count + 1))
  docker image inspect "${expected_buildkit_ref}" >/dev/null 2>&1 && count=$((count + 1))
  printf '%s\n' "${count}"
}

prove_zero_owned_resources() {
  local output_path="${1:-/dev/null}"
  local count
  count="$(count_exact_resources)"
  test "${count}" = 0 || fail "${count} exact task-owned Docker resources remain"
  {
    printf 'ownedResourceCount: 0\n'
    printf 'image: absent\n'
    printf 'builder: absent\n'
    printf 'builderContainer: absent\n'
    printf 'builderVolume: absent\n'
    printf 'buildkitImage: absent\n'
    printf 'upstreamContainer: absent\n'
    printf 'buildContainer: absent\n'
    printf 'taskNetwork: never-created\n'
  } >"${output_path}"
}

remove_private_config() {
  verify_private_config
  rm -rf -- "${DOCKER_CONFIG}"
  test ! -e "${DOCKER_CONFIG}" || fail "private Docker config was not removed"
}

remove_owned_directory() {
  local directory="$1"
  test ! -e "${directory}" && return 0
  test -d "${directory}" && test ! -L "${directory}" ||
    fail "task directory is not a regular directory"
  test -f "${directory}/.task-owned" || fail "task directory ownership marker is absent"
  test "$(cat "${directory}/.task-owned")" = "${task_directory_marker}" ||
    fail "task directory ownership marker drifted"
  rm -rf -- "${directory}"
  test ! -e "${directory}" || fail "task directory was not removed"
}

remove_runner_artifact_dir() {
  remove_owned_directory "${OPENSYMPHONY_ARTIFACT_DIR}"
  remove_owned_directory "${RUNNER_TEMP}/symphony-osv2113-019fc0ca-ticket47-work"
}

cleanup_for_trap() {
  local command_rc=$?
  trap - EXIT
  if test -d "${DOCKER_CONFIG:-/nonexistent}"; then
    cleanup_owned_resources || command_rc=$?
    prove_zero_owned_resources || command_rc=$?
    remove_private_config || command_rc=$?
  fi
  remove_runner_artifact_dir || command_rc=$?
  exit "${command_rc}"
}

create_evidence_container() {
  local image_id="$1"
  local container_id
  container_id="$(docker container create \
    --pull=never --platform linux/amd64 \
    --name "${expected_build_container}" \
    --network none --read-only \
    --tmpfs /tmp:rw,noexec,nosuid,size=64m \
    --label dev.opensymphony.eval.program=opensymphony-v2.11.3-three-arm \
    --label dev.opensymphony.eval.controller=019fc0ca-dde9-7132-91a5-8530d7d76592 \
    --label dev.opensymphony.eval.ticket=47 \
    --label dev.opensymphony.eval.ownership=temporary \
    --entrypoint /bin/bash \
    "${image_id}" \
    -euo pipefail -c '
      opensymphony --version
      rustc --version
      cargo --version
      codex --version
      codex app-server --help >/dev/null
      printf "codex-app-server: present-help-only\\n"
    ')"
  [[ "${container_id}" =~ ^[0-9a-f]{64}$ ]] || fail "evidence container ID was not captured"
  verify_task_container "${container_id}" "${expected_build_container}"
  printf '%s\n' "${container_id}"
}

normalize_archive() {
  local source_dir="$1"
  local output_path="$2"
  tar \
    --sort=name \
    --mtime=@0 \
    --owner=0 \
    --group=0 \
    --numeric-owner \
    --format=gnu \
    -C "${source_dir}" \
    -cf - . | gzip -n -9 >"${output_path}"
}

write_transfer_manifest() {
  local artifact_dir="$1"
  local image_id="$2"
  local image_digest="$3"
  local build_input_sha256="$4"
  local archive_sha256="$5"
  local workflow_sha256="$6"
  local image_inspect_sha256="$7"
  local binaries_sha256="$8"
  local schema_sha256="$9"
  local cleanup_sha256="${10}"
  local opensymphony_binary_sha256="${11}"
  local codex_binary_sha256="${12}"
  local versions_sha256="${13}"
  local archive_bytes
  archive_bytes="$(stat -c '%s' "${artifact_dir}/opensymphony-v2113-ticket47-image.tar.gz")"
  jq -n \
    --arg imageId "${image_id}" \
    --arg imageDigest "${image_digest}" \
    --arg buildInputSha256 "${build_input_sha256}" \
    --arg archiveSha256 "${archive_sha256}" \
    --arg workflowRef "${OPENSYMPHONY_WORKFLOW_REF}" \
    --arg workflowSha256 "${workflow_sha256}" \
    --arg githubEventName "${OPENSYMPHONY_GITHUB_EVENT_NAME}" \
    --arg githubRef "${OPENSYMPHONY_GITHUB_REF}" \
    --arg githubSha "${OPENSYMPHONY_GITHUB_SHA}" \
    --arg binarySha256 "${binaries_sha256}" \
    --arg schemaSha256 "${schema_sha256}" \
    --arg imageInspectSha256 "${image_inspect_sha256}" \
    --arg cleanupSha256 "${cleanup_sha256}" \
    --arg opensymphonyBinarySha256 "${opensymphony_binary_sha256}" \
    --arg codexBinarySha256 "${codex_binary_sha256}" \
    --arg versionsSha256 "${versions_sha256}" \
    --arg artifactName "${OPENSYMPHONY_ARTIFACT_NAME}" \
    --arg artifactAction "${artifact_action}" \
    --arg buildxAction "${buildx_action}" \
    --arg buildkitIndex "${expected_buildkit_index}" \
    --arg buildkitManifest "${expected_buildkit_manifest}" \
    --argjson archiveBytes "${archive_bytes}" \
    --argjson githubRunId "${OPENSYMPHONY_GITHUB_RUN_ID}" \
    --argjson githubRunAttempt "${OPENSYMPHONY_GITHUB_RUN_ATTEMPT}" '
      {
        schemaVersion: 1,
        kind: "opensymphony_v2113_ticket47_cleanup_transfer",
        program: "opensymphony-v2.11.3-three-arm",
        controller: "019fc0ca-dde9-7132-91a5-8530d7d76592",
        ticket: 47,
        workflow: {
          path: ".github/workflows/opensymphony-v2113-evaluation.yml",
          ref: $workflowRef,
          sha256: $workflowSha256,
          eventName: $githubEventName,
          githubRef: $githubRef,
          githubSha: $githubSha,
          githubRunId: $githubRunId,
          githubRunAttempt: $githubRunAttempt
        },
        build: {
          buildInputSha256: $buildInputSha256,
          builder: "symphony-osv2113-019fc0ca-ticket47-builder",
          buildxAction: $buildxAction,
          buildxVersion: "v0.35.0",
          buildkitIndex: $buildkitIndex,
          buildkitManifest: $buildkitManifest,
          platform: "linux/amd64"
        },
        image: {
          tag: "symphony-opensymphony:osv2113-019fc0ca-ticket47",
          imageId: $imageId,
          imageDigest: $imageDigest,
          imageInspectSha256: $imageInspectSha256,
          binaryReceiptSha256: $binarySha256,
          opensymphonyBinarySha256: $opensymphonyBinarySha256,
          codexBinarySha256: $codexBinarySha256,
          versionsSha256: $versionsSha256,
          schemaSha256: $schemaSha256,
          labels: {
            program: "opensymphony-v2.11.3-three-arm",
            controller: "019fc0ca-dde9-7132-91a5-8530d7d76592",
            ticket: "47",
            ownership: "temporary",
            buildInputSha256: $buildInputSha256,
            upstreamTests: "passed-stock-unchanged"
          }
        },
        tests: [
          {name: "stock-upstream", result: "passed-unchanged"},
          {name: "component-and-image", result: "passed"},
          {name: "deterministic-archive", result: "passed-twice"}
        ],
        archive: {
          path: "opensymphony-v2113-ticket47-image.tar.gz",
          mediaType: "application/vnd.docker.distribution.image.v1.tar+gzip",
          archiveSha256: $archiveSha256,
          bytes: $archiveBytes
        },
        artifact: {
          name: $artifactName,
          action: $artifactAction,
          retentionDays: 1,
          publication: false,
          transferTargetTicket: 48
        },
        cleanup: {
          performedBeforeTransfer: true,
          ownedResourceCount: 0,
          privateDockerConfigAbsent: true,
          readbackSha256: $cleanupSha256
        },
        residualUncertainty: [
          "github-hosted ubuntu-24.04 runner image is mutable behind its label",
          "artifact availability and service-side artifact digest require authenticated post-run readback",
          "this packet proves build transfer only and grants no issue-48 or admission authority"
        ]
      }
    ' >"${artifact_dir}/cleanup-transfer-v1.json"
}

execute_build() {
  verify_host_boundary
  trap cleanup_for_trap EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM

  for name in "${expected_upstream_container}" "${expected_build_container}"; do
    test -z "$(task_container_id "${name}")" || fail "task container name collision: ${name}"
  done
  docker image inspect "${expected_image}" >/dev/null 2>&1 && fail "task image tag collision"

  local builder_receipt
  builder_receipt="$(docker buildx inspect --bootstrap "${expected_builder}")"
  grep -Eq '^BuildKit version:[[:space:]]+v0[.]31[.]1$' <<<"${builder_receipt}" ||
    fail "builder did not report BuildKit v0.31.1"
  grep -Eq '^Platforms:.*linux/amd64' <<<"${builder_receipt}" ||
    fail "builder lacks native linux/amd64"
  local builder_container_id
  builder_container_id="$(task_container_id "${expected_builder_container}")"
  [[ "${builder_container_id}" =~ ^[0-9a-f]{64}$ ]] || fail "builder container ID was not captured"
  test "$(docker container inspect --format '{{.Config.Image}}' "${builder_container_id}")" = \
    "moby/buildkit@${expected_buildkit_manifest}" || fail "builder child manifest drifted"
  local buildkit_image_id
  buildkit_image_id="$(docker image inspect --format '{{.Id}}' "${expected_buildkit_ref}")"
  require_digest "${buildkit_image_id}" "BuildKit image ID"

  local build_input_sha256
  build_input_sha256="$("${repo_root}/scripts/opensymphony-v2113-build-input-id.sh")"
  require_lower_sha256 "${build_input_sha256}" "build-input identity"
  test "$(jq -r '.buildkit.platform' "${repo_root}/${input_manifest}")" = "linux/amd64" ||
    fail "input manifest BuildKit platform drifted"
  test "$(jq -r '.buildkit.manifest' "${repo_root}/${input_manifest}")" = \
    "${expected_buildkit_manifest}" || fail "input manifest BuildKit child drifted"

  local work_dir="${RUNNER_TEMP}/symphony-osv2113-019fc0ca-ticket47-work"
  test ! -e "${work_dir}" || fail "work directory collision"
  install -d -m 0700 "${work_dir}"
  printf '%s\n' "${task_directory_marker}" >"${work_dir}/.task-owned"
  local artifact_dir="${OPENSYMPHONY_ARTIFACT_DIR}"
  test ! -e "${artifact_dir}" || fail "artifact directory collision"
  install -d -m 0700 "${artifact_dir}" "${artifact_dir}/evidence"
  printf '%s\n' "${task_directory_marker}" >"${artifact_dir}/.task-owned"

  (
    cd "${repo_root}"
    BUILD_INPUT_SHA256="${build_input_sha256}" \
      OPENSYMPHONY_IMAGE="${expected_image}" \
      timeout --signal=TERM --kill-after=10s 3600 \
      env "DOCKER_CONFIG=${DOCKER_CONFIG}" "DOCKER_HOST=${DOCKER_HOST}" \
      docker buildx bake \
        --builder "${expected_builder}" \
        --file "${bake_file}" \
        --progress=plain \
        --metadata-file "${work_dir}/build-metadata.json" \
        opensymphony-v2113-evaluation
  )

  local image_id
  image_id="$(docker image inspect --format '{{.Id}}' "${expected_image}")"
  require_digest "${image_id}" "image ID"
  local image_digest
  image_digest="$(jq -r '.["opensymphony-v2113-evaluation"]["containerimage.digest"]' \
    "${work_dir}/build-metadata.json")"
  require_digest "${image_digest}" "image manifest digest"
  docker image inspect "${image_id}" >"${artifact_dir}/image-inspect.json"
  jq -e \
    --arg image "${expected_image}" \
    --arg image_id "${image_id}" \
    --arg input "${build_input_sha256}" '
      length == 1 and
      .[0].Id == $image_id and
      .[0].Os == "linux" and
      .[0].Architecture == "amd64" and
      .[0].RepoTags == [$image] and
      (.[0].RepoDigests // []) == [] and
      .[0].Config.Labels["dev.opensymphony.eval.program"] ==
        "opensymphony-v2.11.3-three-arm" and
      .[0].Config.Labels["dev.opensymphony.eval.controller"] ==
        "019fc0ca-dde9-7132-91a5-8530d7d76592" and
      .[0].Config.Labels["dev.opensymphony.eval.ticket"] == "47" and
      .[0].Config.Labels["dev.opensymphony.eval.ownership"] == "temporary" and
      .[0].Config.Labels["dev.opensymphony.eval.source.tag-object"] ==
        "ed265b58f1b17c0184775635444e1e2be383177f" and
      .[0].Config.Labels["dev.opensymphony.eval.source.commit"] ==
        "af6a65459385104fcef4e249980701bf8e7964d4" and
      .[0].Config.Labels["dev.opensymphony.eval.source.tree"] ==
        "ddde2287e4bd975dc721b131f039cec6b32f437b" and
      .[0].Config.Labels["dev.opensymphony.eval.source.archive-sha256"] ==
        "6376662ac21d930f0b4b488a7d13e5b8e7fbf94a02d67ab552d7e341ae257a1c" and
      .[0].Config.Labels["dev.opensymphony.eval.codex.tag-object"] ==
        "be449751a978f02e5bbba886999662956c7f38f5" and
      .[0].Config.Labels["dev.opensymphony.eval.codex.commit"] ==
        "e363b08c9175ac1cbe5893615dd2cb9ddf95043b" and
      .[0].Config.Labels["dev.opensymphony.eval.build-input-sha256"] == $input and
      .[0].Config.Labels["dev.opensymphony.eval.upstream-tests"] == "passed-stock-unchanged"
    ' "${artifact_dir}/image-inspect.json" >/dev/null || fail "image identity or labels drifted"

  (
    cd "${repo_root}"
    OPENSYMPHONY_EXECUTION_PROFILE="${expected_profile}" \
      OPENSYMPHONY_IMAGE="${expected_image}" \
      scripts/test-opensymphony-v2113-upstream.sh
    OPENSYMPHONY_EXECUTION_PROFILE="${expected_profile}" \
      OPENSYMPHONY_IMAGE="${expected_image}" \
      scripts/test-opensymphony-v2113-build.sh
  )

  local evidence_container_id
  evidence_container_id="$(create_evidence_container "${image_id}")"
  docker container start --attach "${evidence_container_id}" >"${artifact_dir}/versions.txt"
  docker container cp \
    "${evidence_container_id}:/opt/opensymphony/evidence/." \
    "${artifact_dir}/evidence/"
  docker container rm "${evidence_container_id}" >/dev/null
  test -s "${artifact_dir}/evidence/binaries.sha256" || fail "binary evidence is absent"
  test -s "${artifact_dir}/evidence/codex-app-server-schema.sha256" ||
    fail "schema evidence is absent"

  docker image save --output "${work_dir}/image-save.tar" "${expected_image}"
  install -d -m 0700 "${work_dir}/image-save"
  tar -xf "${work_dir}/image-save.tar" -C "${work_dir}/image-save"
  normalize_archive "${work_dir}/image-save" "${work_dir}/image-a.tar.gz"
  normalize_archive "${work_dir}/image-save" "${work_dir}/image-b.tar.gz"
  cmp -s "${work_dir}/image-a.tar.gz" "${work_dir}/image-b.tar.gz" ||
    fail "deterministic archive serializer diverged"
  mv "${work_dir}/image-a.tar.gz" \
    "${artifact_dir}/opensymphony-v2113-ticket47-image.tar.gz"
  rm -f -- "${work_dir}/image-b.tar.gz" "${work_dir}/image-save.tar"

  printf '%s\n' "${builder_receipt}" >"${artifact_dir}/builder-inspect.txt"
  {
    printf 'dpkgArchitecture: %s\n' "$(dpkg --print-architecture)"
    printf 'machine: %s\n' "$(uname -m)"
    printf 'runnerImage: %s\n' "${ImageOS:-unknown}"
    docker version
    tar --version | head -n 1
    gzip --version | head -n 1
  } >"${artifact_dir}/runner-environment.txt"
  cp "${work_dir}/build-metadata.json" "${artifact_dir}/build-metadata.json"

  cleanup_owned_resources
  prove_zero_owned_resources "${artifact_dir}/cleanup-readback.txt"
  remove_private_config

  local archive_sha256 workflow_sha256 image_inspect_sha256 binaries_sha256 schema_sha256 cleanup_sha256
  local opensymphony_binary_sha256 codex_binary_sha256 versions_sha256
  archive_sha256="$(sha256sum "${artifact_dir}/opensymphony-v2113-ticket47-image.tar.gz" | awk '{print $1}')"
  workflow_sha256="$(sha256sum "${repo_root}/${workflow_path}" | awk '{print $1}')"
  image_inspect_sha256="$(sha256sum "${artifact_dir}/image-inspect.json" | awk '{print $1}')"
  binaries_sha256="$(sha256sum "${artifact_dir}/evidence/binaries.sha256" | awk '{print $1}')"
  schema_sha256="$(sha256sum "${artifact_dir}/evidence/codex-app-server-schema.sha256" | awk '{print $1}')"
  cleanup_sha256="$(sha256sum "${artifact_dir}/cleanup-readback.txt" | awk '{print $1}')"
  opensymphony_binary_sha256="$(awk '$2 == "/usr/local/bin/opensymphony" {print $1}' \
    "${artifact_dir}/evidence/binaries.sha256")"
  codex_binary_sha256="$(awk '$2 == "/usr/local/bin/codex" {print $1}' \
    "${artifact_dir}/evidence/binaries.sha256")"
  versions_sha256="$(sha256sum "${artifact_dir}/versions.txt" | awk '{print $1}')"
  for digest in "${archive_sha256}" "${workflow_sha256}" "${image_inspect_sha256}" \
    "${binaries_sha256}" "${schema_sha256}" "${cleanup_sha256}" \
    "${opensymphony_binary_sha256}" "${codex_binary_sha256}" "${versions_sha256}"; do
    require_lower_sha256 "${digest}" "transfer evidence digest"
  done
  test "${codex_binary_sha256}" = \
    "$(jq -r '.codex.binarySha256' "${repo_root}/${input_manifest}")" ||
    fail "contained Codex binary digest drifted"
  write_transfer_manifest \
    "${artifact_dir}" "${image_id}" "${image_digest}" "${build_input_sha256}" \
    "${archive_sha256}" "${workflow_sha256}" "${image_inspect_sha256}" \
    "${binaries_sha256}" "${schema_sha256}" "${cleanup_sha256}" \
    "${opensymphony_binary_sha256}" "${codex_binary_sha256}" "${versions_sha256}"
  remove_owned_directory "${work_dir}"
  trap - EXIT INT TERM
  printf 'OpenSymphony v2.11.3 native transfer packet ready: %s\n' "${artifact_dir}"
}

cleanup_only() {
  require_github_environment
  if test ! -e "${DOCKER_CONFIG}"; then
    install -d -m 0700 "${DOCKER_CONFIG}"
  fi
  verify_private_config
  cleanup_owned_resources
  prove_zero_owned_resources
  remove_private_config
  remove_runner_artifact_dir
}

preflight() {
  require_github_environment
  test "$(dpkg --print-architecture)" = amd64 || fail "runner package architecture is not amd64"
  test "$(uname -m)" = x86_64 || fail "runner machine is not x86_64"
  verify_private_config
  test "$(docker version --format '{{.Server.Os}}/{{.Server.Arch}}')" = "linux/amd64" ||
    fail "runner Docker Engine is not native linux/amd64"
  for name in "${expected_upstream_container}" "${expected_build_container}" \
    "${expected_builder_container}"; do
    test -z "$(task_container_id "${name}")" || fail "task container collision: ${name}"
  done
  docker image inspect "${expected_image}" >/dev/null 2>&1 && fail "task image collision"
  docker image inspect "${expected_buildkit_ref}" >/dev/null 2>&1 &&
    fail "BuildKit image collision"
  docker buildx inspect "${expected_builder}" >/dev/null 2>&1 && fail "task builder collision"
  docker volume inspect "${expected_builder_volume}" >/dev/null 2>&1 &&
    fail "task builder volume collision"
  assert_no_task_networks
  test ! -e "${OPENSYMPHONY_ARTIFACT_DIR}" || fail "artifact directory collision"
  test ! -e "${RUNNER_TEMP}/symphony-osv2113-019fc0ca-ticket47-work" ||
    fail "work directory collision"
  printf 'OpenSymphony v2.11.3 runner collision boundary passed\n'
}

case "${1:-}" in
  preflight) preflight ;;
  execute) execute_build ;;
  cleanup-only) cleanup_only ;;
  *) fail "usage: run-opensymphony-v2113-github-actions.sh preflight | execute | cleanup-only" ;;
esac
