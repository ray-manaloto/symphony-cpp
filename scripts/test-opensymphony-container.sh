#!/usr/bin/env bash
set -euo pipefail

unset LINEAR_API_KEY

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_root="$(mktemp -d /tmp/symphony-opensymphony-launcher-test.XXXXXX)"
trap 'rm -rf -- "${fixture_root}"' EXIT

mkdir -p "${fixture_root}/bin"
docker_log="${fixture_root}/docker.log"
# The single quotes intentionally defer expansion to the generated Docker stub.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'if [[ -n "${LINEAR_API_KEY+x}" ]]; then' \
  '  echo "Docker CLI inherited LINEAR_API_KEY" >&2' \
  '  exit 97' \
  'fi' \
  'if [[ "${1:-}" == "image" && "${2:-}" == "inspect" ]]; then' \
  '  case "${DOCKER_IMAGE_FIXTURE_STATE:-valid}" in' \
  '    missing) exit 1 ;;' \
  '    valid) upstream_tests=passed; source_commit=0cc21ddda5d1853a8fbd11add578b43b6ebd6fcb; build_input="${DOCKER_BUILD_INPUT_FIXTURE}"; image_id=sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ;;' \
  '    candidate) upstream_tests=unverified-candidate; source_commit=0cc21ddda5d1853a8fbd11add578b43b6ebd6fcb; build_input="${DOCKER_BUILD_INPUT_FIXTURE}"; image_id=sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ;;' \
  '    wrong-source) upstream_tests=passed; source_commit=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb; build_input="${DOCKER_BUILD_INPUT_FIXTURE}"; image_id=sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ;;' \
  '    wrong-input) upstream_tests=passed; source_commit=0cc21ddda5d1853a8fbd11add578b43b6ebd6fcb; build_input=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb; image_id=sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ;;' \
  '    malformed-id) upstream_tests=passed; source_commit=0cc21ddda5d1853a8fbd11add578b43b6ebd6fcb; build_input="${DOCKER_BUILD_INPUT_FIXTURE}"; image_id=sha256:test ;;' \
  '    *) exit 2 ;;' \
  '  esac' \
  '  if [[ "$*" == *"{{.Id}}"* ]]; then' \
  '    printf "%s\n" "${image_id}"' \
  '  elif [[ "$*" == *"dev.opensymphony.upstream-tests"* ]]; then' \
  '    printf "%s\n" "${upstream_tests}"' \
  '  elif [[ "$*" == *"dev.opensymphony.source.commit"* ]]; then' \
  '    printf "%s\n" "${source_commit}"' \
  '  elif [[ "$*" == *"dev.opensymphony.build-input.sha256"* ]]; then' \
  '    printf "%s\n" "${build_input}"' \
  '  else' \
  '    exit 2' \
  '  fi' \
  '  exit 0' \
  'fi' \
  'if [[ "${1:-}" == "volume" && "${2:-}" == "inspect" ]]; then' \
  '  if [[ " $* " == *" --format "* ]]; then' \
  '    if [[ "$*" == *"dev.symphony.acceptance-owner"* ]]; then' \
  '      printf "run-opensymphony-contained\n"' \
  '    else' \
  '      printf "%s\n" "${DOCKER_VOLUME_OWNER_TOKEN:-${OPENSYMPHONY_ACCEPTANCE_OWNER_TOKEN:-own-fixt}}"' \
  '    fi' \
  '    exit 0' \
  '  fi' \
  '  exit 1' \
  'fi' \
  'printf "%q " "$@" >> "${DOCKER_LOG}"' \
  'printf "\n" >> "${DOCKER_LOG}"' \
  >"${fixture_root}/bin/docker"
chmod +x "${fixture_root}/bin/docker"

run_launcher() {
  (
    cd "${repo_root}"
    PATH="${fixture_root}/bin:${PATH}" \
      DOCKER_LOG="${docker_log}" \
      DOCKER_BUILD_INPUT_FIXTURE="$("${repo_root}/scripts/opensymphony-build-input-id.sh")" \
      OPENSYMPHONY_IMAGE="fixture-opensymphony:local" \
      OPENSYMPHONY_CODEX_AUTH_VOLUME='' \
      OPENSYMPHONY_STATE_VOLUME='' \
      OPENSYMPHONY_WORKSPACES_VOLUME='' \
      OPENSYMPHONY_TOOLS_VOLUME='' \
      OPENSYMPHONY_CCACHE_VOLUME='' \
      OPENSYMPHONY_VCPKG_ARCHIVES_VOLUME='' \
      OPENSYMPHONY_UV_CACHE_VOLUME='' \
      "$@"
  )
}

run_launcher ./scripts/opensymphony-container.sh preflight
run_launcher ./scripts/opensymphony-container.sh memory-init
run_launcher ./scripts/opensymphony-container.sh memory-status
run_launcher ./scripts/opensymphony-container.sh tui
run_launcher env LINEAR_API_KEY=fixture ./scripts/opensymphony-container.sh memory-context TEST-123
acceptance_suffix=launcher-fixture
alternate_gcc_context="docker-image://example.invalid/gcc@sha256:$(printf '0%.0s' {1..64})"
alternate_build_input_sha256="$(
  GCC16_ARTIFACT_CONTEXT="${alternate_gcc_context}" \
    "${repo_root}/scripts/opensymphony-build-input-id.sh"
)"
readonly alternate_gcc_context
readonly alternate_build_input_sha256
run_launcher env \
  LINEAR_API_KEY=fixture \
  OPENSYMPHONY_ACCEPTANCE_SUFFIX="${acceptance_suffix}" \
  OPENSYMPHONY_ACCEPTANCE_RESOURCES_VERIFIED=true \
  OPENSYMPHONY_ACCEPTANCE_OWNER_TOKEN=own-fixt \
  OPENSYMPHONY_STATE_VOLUME="symphony-opensymphony-state-acceptance-${acceptance_suffix}" \
  OPENSYMPHONY_CODEX_AUTH_VOLUME="symphony-codex-auth-acceptance-${acceptance_suffix}" \
  OPENSYMPHONY_WORKSPACES_VOLUME="symphony-opensymphony-workspaces-acceptance-${acceptance_suffix}" \
  OPENSYMPHONY_TOOLS_VOLUME="symphony-opensymphony-tools-acceptance-${acceptance_suffix}" \
  OPENSYMPHONY_CCACHE_VOLUME="symphony-opensymphony-gcc16-ccache-acceptance-${acceptance_suffix}" \
  OPENSYMPHONY_VCPKG_ARCHIVES_VOLUME="symphony-opensymphony-vcpkg-archives-acceptance-${acceptance_suffix}" \
  OPENSYMPHONY_UV_CACHE_VOLUME="symphony-opensymphony-uv-cache-acceptance-${acceptance_suffix}" \
  ./scripts/opensymphony-container.sh doctor
run_launcher env \
  LINEAR_API_KEY=fixture \
  OPENSYMPHONY_ACCEPTANCE_SUFFIX="${acceptance_suffix}" \
  OPENSYMPHONY_ACCEPTANCE_RESOURCES_VERIFIED=true \
  OPENSYMPHONY_ACCEPTANCE_OWNER_TOKEN=own-fixt \
  OPENSYMPHONY_STATE_VOLUME="symphony-opensymphony-state-acceptance-${acceptance_suffix}" \
  OPENSYMPHONY_CODEX_AUTH_VOLUME="symphony-codex-auth-acceptance-${acceptance_suffix}" \
  OPENSYMPHONY_WORKSPACES_VOLUME="symphony-opensymphony-workspaces-acceptance-${acceptance_suffix}" \
  OPENSYMPHONY_TOOLS_VOLUME="symphony-opensymphony-tools-acceptance-${acceptance_suffix}" \
  OPENSYMPHONY_CCACHE_VOLUME="symphony-opensymphony-gcc16-ccache-acceptance-${acceptance_suffix}" \
  OPENSYMPHONY_VCPKG_ARCHIVES_VOLUME="symphony-opensymphony-vcpkg-archives-acceptance-${acceptance_suffix}" \
  OPENSYMPHONY_UV_CACHE_VOLUME="symphony-opensymphony-uv-cache-acceptance-${acceptance_suffix}" \
  ./scripts/opensymphony-container.sh dry-run
if grep -Fq -- "--publish" "${docker_log}"; then
  echo "contained doctor or no-model dry run exposed the write-capable gateway" >&2
  exit 1
fi
run_launcher env LINEAR_API_KEY=fixture ./scripts/opensymphony-container.sh run
grep -Fq -- "--publish 127.0.0.1:2468:2468" "${docker_log}"
run_launcher env LINEAR_API_KEY=fixture ./scripts/opensymphony-container.sh debug TEST-123
run_launcher env LINEAR_API_KEY=fixture ./scripts/run-opensymphony-contained.sh doctor
run_launcher env LINEAR_API_KEY=fixture ./scripts/run-opensymphony-contained.sh dry-run

grep -Fq -- "--volume symphony-opensymphony-state:/target/.opensymphony" "${docker_log}"
grep -Fq -- "--volume symphony-opensymphony-workspaces:/workspaces" "${docker_log}"
grep -Fq -- "--volume symphony-opensymphony-tools:/home/orchestrator/.opensymphony" "${docker_log}"
grep -Fq -- "--volume symphony-opensymphony-gcc16-ccache:/home/orchestrator/.cache/ccache" "${docker_log}"
grep -Fq -- "--volume symphony-opensymphony-vcpkg-archives:/home/orchestrator/.cache/vcpkg/archives" "${docker_log}"
grep -Fq -- "--volume symphony-opensymphony-uv-cache:/home/orchestrator/.cache/uv" "${docker_log}"
grep -Fq -- "--cap-drop ALL" "${docker_log}"
grep -Fq -- "--pull=never" "${docker_log}"
grep -Fq -- \
  "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" \
  "${docker_log}"
grep -Fq -- "--security-opt no-new-privileges" "${docker_log}"
grep -Fq -- "--pids-limit 2048" "${docker_log}"
grep -Fq -- \
  "memory --config /target/.opensymphony/memory/memory.yaml status" \
  "${docker_log}"
grep -Fq -- \
  "memory --config /target/.opensymphony/memory/memory.yaml context --issue TEST-123" \
  "${docker_log}"
grep -Fq -- "doctor --config /orchestrator/config.yaml" "${docker_log}"
grep -Fq -- "tui --url http://host.docker.internal:2468/" "${docker_log}"
grep -Fq -- "debug --config /orchestrator/config.yaml TEST-123" "${docker_log}"
grep -Fq -- "--label dev.symphony.acceptance-owner=run-opensymphony-contained" "${docker_log}"
grep -Fq -- "volume rm symphony-codex-auth-acceptance-live-doctor-" "${docker_log}"
grep -Fq -- "volume rm symphony-codex-auth-acceptance-live-dry-run-" "${docker_log}"
if grep -Fq -- "--env LINEAR_API_KEY" "${docker_log}"; then
  echo "launcher exposed LINEAR_API_KEY through Docker configuration metadata" >&2
  exit 1
fi

if run_launcher ./scripts/opensymphony-container.sh debug >/dev/null 2>&1; then
  echo "debug without an issue identifier unexpectedly succeeded" >&2
  exit 1
fi

if run_launcher env -u LINEAR_API_KEY ./scripts/opensymphony-container.sh doctor >/dev/null 2>&1; then
  echo "doctor without LINEAR_API_KEY unexpectedly succeeded" >&2
  exit 1
fi

if run_launcher env LINEAR_API_KEY=fixture ./scripts/opensymphony-container.sh doctor >/dev/null 2>&1; then
  echo "doctor without the contained-resource ceremony unexpectedly succeeded" >&2
  exit 1
fi

if run_launcher env -u LINEAR_API_KEY ./scripts/opensymphony-container.sh memory-context TEST-123 >/dev/null 2>&1; then
  echo "memory-context without LINEAR_API_KEY unexpectedly succeeded" >&2
  exit 1
fi

if run_launcher env LINEAR_API_KEY=fixture ./scripts/opensymphony-container.sh dry-run >/dev/null 2>&1; then
  echo "dry-run with persistent operational volumes unexpectedly succeeded" >&2
  exit 1
fi

if run_launcher env \
  DOCKER_IMAGE_FIXTURE_STATE=missing \
  ./scripts/opensymphony-container.sh memory-status >/dev/null 2>&1; then
  echo "launcher accepted an image that is not present in the local image store" >&2
  exit 1
fi

if run_launcher env \
  DOCKER_IMAGE_FIXTURE_STATE=candidate \
  ./scripts/opensymphony-container.sh memory-status >/dev/null 2>&1; then
  echo "launcher accepted an OpenSymphony image without passed upstream tests" >&2
  exit 1
fi

if run_launcher env \
  DOCKER_IMAGE_FIXTURE_STATE=wrong-source \
  ./scripts/opensymphony-container.sh memory-status >/dev/null 2>&1; then
  echo "launcher accepted an OpenSymphony image built from the wrong source revision" >&2
  exit 1
fi

if run_launcher env \
  DOCKER_IMAGE_FIXTURE_STATE=wrong-input \
  ./scripts/opensymphony-container.sh memory-status >/dev/null 2>&1; then
  echo "launcher accepted an OpenSymphony image built from different policy inputs" >&2
  exit 1
fi

if run_launcher env \
  GCC16_ARTIFACT_CONTEXT="${alternate_gcc_context}" \
  DOCKER_BUILD_INPUT_FIXTURE="${alternate_build_input_sha256}" \
  ./scripts/opensymphony-container.sh memory-status >/dev/null 2>&1; then
  echo "launcher let ambient GCC16_ARTIFACT_CONTEXT redefine image admission" >&2
  exit 1
fi

if run_launcher env \
  DOCKER_IMAGE_FIXTURE_STATE=malformed-id \
  ./scripts/opensymphony-container.sh memory-status >/dev/null 2>&1; then
  echo "launcher accepted a non-immutable local image identity" >&2
  exit 1
fi

if run_launcher env \
  LINEAR_API_KEY=fixture \
  DOCKER_VOLUME_OWNER_TOKEN=own-other \
  OPENSYMPHONY_ACCEPTANCE_SUFFIX="${acceptance_suffix}" \
  OPENSYMPHONY_ACCEPTANCE_RESOURCES_VERIFIED=true \
  OPENSYMPHONY_ACCEPTANCE_OWNER_TOKEN=own-fixt \
  OPENSYMPHONY_STATE_VOLUME="symphony-opensymphony-state-acceptance-${acceptance_suffix}" \
  OPENSYMPHONY_CODEX_AUTH_VOLUME="symphony-codex-auth-acceptance-${acceptance_suffix}" \
  OPENSYMPHONY_WORKSPACES_VOLUME="symphony-opensymphony-workspaces-acceptance-${acceptance_suffix}" \
  OPENSYMPHONY_TOOLS_VOLUME="symphony-opensymphony-tools-acceptance-${acceptance_suffix}" \
  OPENSYMPHONY_CCACHE_VOLUME="symphony-opensymphony-gcc16-ccache-acceptance-${acceptance_suffix}" \
  OPENSYMPHONY_VCPKG_ARCHIVES_VOLUME="symphony-opensymphony-vcpkg-archives-acceptance-${acceptance_suffix}" \
  OPENSYMPHONY_UV_CACHE_VOLUME="symphony-opensymphony-uv-cache-acceptance-${acceptance_suffix}" \
  ./scripts/opensymphony-container.sh doctor >/dev/null 2>&1; then
  echo "doctor accepted volumes with a foreign owner token" >&2
  exit 1
fi

if [[ -n "${OPENSYMPHONY_INTEGRATION_IMAGE:-}" ]]; then
  (
    cd "${repo_root}"
    integration_image_id="$(
      docker image inspect --format '{{.Id}}' "${OPENSYMPHONY_INTEGRATION_IMAGE}"
    )"
    readonly integration_image_id
    if [[ ! "${integration_image_id}" =~ ^sha256:[0-9a-f]{64}$ ]]; then
      echo "integration image did not resolve to an immutable local image ID" >&2
      exit 2
    fi
    test "$(
      docker image inspect \
        --format '{{ index .Config.Labels "dev.opensymphony.upstream-tests" }}' \
        "${integration_image_id}"
    )" = "passed"
    test "$(
      docker image inspect \
        --format '{{ index .Config.Labels "dev.opensymphony.source.commit" }}' \
        "${integration_image_id}"
    )" = "0cc21ddda5d1853a8fbd11add578b43b6ebd6fcb"
    test "$(
      docker image inspect \
        --format '{{ index .Config.Labels "dev.opensymphony.build-input.sha256" }}' \
        "${integration_image_id}"
    )" = "$("${repo_root}/scripts/opensymphony-build-input-id.sh")"
    if [[ "${OPENSYMPHONY_SEED_FIXTURE_CODEX_LOGIN:-false}" == "true" ]]; then
      printf 'fixture-key\n' |
        docker run --rm --pull=never --interactive \
          --volume "${OPENSYMPHONY_CODEX_AUTH_VOLUME}:/home/orchestrator/.codex" \
          --entrypoint codex \
          "${integration_image_id}" \
          login --with-api-key
    fi
    OPENSYMPHONY_IMAGE="${integration_image_id}" \
      ./scripts/opensymphony-container.sh memory-init
    if [[ "${OPENSYMPHONY_TEST_LEGACY_MEMORY_MIGRATION:-false}" == "true" ]]; then
      docker run --rm --pull=never \
        --user 0:0 \
        --entrypoint sh \
        --volume "${OPENSYMPHONY_STATE_VOLUME}:/state" \
        "${integration_image_id}" \
        -euc '
          sed -i \
            -e "s|^  public_root: .opensymphony/memory/generated-docs$|  public_root: docs|" \
            -e "s|^  default_visibility: private$|  default_visibility: public|" \
            /state/memory/memory.yaml
          sed -i \
            "/^areas: {}$/c\\
areas:\\
  retained-area:\\
    title: Retained Area\\
    docs_target: docs/retained.md" \
            /state/memory/memory.yaml
        '
      OPENSYMPHONY_IMAGE="${integration_image_id}" \
        ./scripts/opensymphony-container.sh memory-init
      docker run --rm --pull=never \
        --entrypoint sh \
        --volume "${OPENSYMPHONY_STATE_VOLUME}:/state:ro" \
        "${integration_image_id}" \
        -euc '
          grep -F -x -q \
            "  public_root: .opensymphony/memory/generated-docs" \
            /state/memory/memory.yaml
          grep -F -x -q \
            "  default_visibility: private" \
            /state/memory/memory.yaml
          grep -F -x -q \
            "    title: Retained Area" \
            /state/memory/memory.yaml
          grep -F -x -q \
            "    docs_target: .opensymphony/memory/generated-docs/retained.md" \
            /state/memory/memory.yaml
          test -r /state/memory/memory.yaml.pre-private-doc-staging
        '
    fi
    OPENSYMPHONY_IMAGE="${integration_image_id}" \
      ./scripts/opensymphony-container.sh preflight
    OPENSYMPHONY_IMAGE="${integration_image_id}" \
      ./scripts/opensymphony-container.sh memory-status

    doctor_output="${fixture_root}/doctor.log"
    if ! LINEAR_API_KEY=fixture \
      OPENSYMPHONY_ACCEPTANCE_RESOURCES_VERIFIED=true \
      OPENSYMPHONY_IMAGE="${integration_image_id}" \
      ./scripts/opensymphony-container.sh doctor >"${doctor_output}" 2>&1; then
      cat "${doctor_output}" >&2
      echo "contained OpenSymphony doctor failed" >&2
      exit 1
    fi
    grep -Fq "[PASS] config:" "${doctor_output}"
    grep -Fq "[PASS] workflow:" "${doctor_output}"
    grep -Fq "[PASS] workflow-prompt:" "${doctor_output}"
    grep -Fq "[PASS] prereq-cargo:" "${doctor_output}"
    grep -Fq "[PASS] prereq-curl:" "${doctor_output}"

    docker run --rm --pull=never \
      --entrypoint codex \
      --volume "${repo_root}/ops/opensymphony/codex-config.toml:/home/orchestrator/.codex/config.toml:ro" \
      "${integration_image_id}" \
      --strict-config app-server --help >/dev/null
    docker run --rm --pull=never \
      --entrypoint codex \
      --tmpfs /tmp:rw,noexec,nosuid,size=256m \
      --volume "${repo_root}/ops/opensymphony/codex-config.toml:/home/orchestrator/.codex/config.toml:ro" \
      "${integration_image_id}" \
      app-server generate-json-schema \
      --experimental \
      --out /tmp/codex-app-server-schema
  )
fi

echo "OpenSymphony container launcher tests passed"
