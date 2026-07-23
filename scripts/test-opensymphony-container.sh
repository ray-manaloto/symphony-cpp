#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_root="$(mktemp -d /tmp/symphony-opensymphony-launcher-test.XXXXXX)"
trap 'rm -rf -- "${fixture_root}"' EXIT

mkdir -p "${fixture_root}/bin"
docker_log="${fixture_root}/docker.log"
# The single quotes intentionally defer expansion to the generated Docker stub.
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf "%q " "$@" >> "${DOCKER_LOG}"' \
  'printf "\n" >> "${DOCKER_LOG}"' \
  >"${fixture_root}/bin/docker"
chmod +x "${fixture_root}/bin/docker"

run_launcher() {
  (
    cd "${repo_root}"
    PATH="${fixture_root}/bin:${PATH}" \
      DOCKER_LOG="${docker_log}" \
      OPENSYMPHONY_IMAGE="example.invalid/opensymphony@sha256:test" \
      OPENSYMPHONY_CODEX_AUTH_VOLUME='' \
      OPENSYMPHONY_STATE_VOLUME='' \
      OPENSYMPHONY_WORKSPACES_VOLUME='' \
      "$@"
  )
}

run_launcher ./scripts/opensymphony-container.sh preflight
run_launcher ./scripts/opensymphony-container.sh memory-init
run_launcher ./scripts/opensymphony-container.sh memory-status
run_launcher ./scripts/opensymphony-container.sh tui
run_launcher env LINEAR_API_KEY=fixture ./scripts/opensymphony-container.sh memory-context TEST-123
run_launcher env LINEAR_API_KEY=fixture ./scripts/opensymphony-container.sh doctor
run_launcher env LINEAR_API_KEY=fixture ./scripts/opensymphony-container.sh dry-run
run_launcher env LINEAR_API_KEY=fixture ./scripts/opensymphony-container.sh debug TEST-123

grep -Fq -- "--volume symphony-opensymphony-state:/target/.opensymphony" "${docker_log}"
grep -Fq -- "--volume symphony-opensymphony-workspaces:/workspaces" "${docker_log}"
grep -Fq -- "memory --config /orchestrator/config.yaml status" "${docker_log}"
grep -Fq -- "memory --config /orchestrator/config.yaml context --issue TEST-123" "${docker_log}"
grep -Fq -- "doctor --config /orchestrator/config.yaml" "${docker_log}"
grep -Fq -- "tui --url http://host.docker.internal:2468/" "${docker_log}"
grep -Fq -- "debug --config /orchestrator/config.yaml TEST-123" "${docker_log}"

if run_launcher ./scripts/opensymphony-container.sh debug >/dev/null 2>&1; then
  echo "debug without an issue identifier unexpectedly succeeded" >&2
  exit 1
fi

if run_launcher env -u LINEAR_API_KEY ./scripts/opensymphony-container.sh doctor >/dev/null 2>&1; then
  echo "doctor without LINEAR_API_KEY unexpectedly succeeded" >&2
  exit 1
fi

if run_launcher env -u LINEAR_API_KEY ./scripts/opensymphony-container.sh memory-context TEST-123 >/dev/null 2>&1; then
  echo "memory-context without LINEAR_API_KEY unexpectedly succeeded" >&2
  exit 1
fi

if [[ -n "${OPENSYMPHONY_INTEGRATION_IMAGE:-}" ]]; then
  (
    cd "${repo_root}"
    if [[ "${OPENSYMPHONY_SEED_FIXTURE_CODEX_LOGIN:-false}" == "true" ]]; then
      printf 'fixture-not-a-secret\n' |
        docker run --rm --interactive \
          --volume "${OPENSYMPHONY_CODEX_AUTH_VOLUME}:/home/orchestrator/.codex" \
          --entrypoint codex \
          "${OPENSYMPHONY_INTEGRATION_IMAGE}" \
          login --with-api-key
    fi
    OPENSYMPHONY_IMAGE="${OPENSYMPHONY_INTEGRATION_IMAGE}" \
      ./scripts/opensymphony-container.sh memory-init
    if [[ "${OPENSYMPHONY_TEST_LEGACY_MEMORY_MIGRATION:-false}" == "true" ]]; then
      docker run --rm \
        --user 0:0 \
        --entrypoint sh \
        --volume "${OPENSYMPHONY_STATE_VOLUME}:/state" \
        "${OPENSYMPHONY_INTEGRATION_IMAGE}" \
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
      OPENSYMPHONY_IMAGE="${OPENSYMPHONY_INTEGRATION_IMAGE}" \
        ./scripts/opensymphony-container.sh memory-init
      docker run --rm \
        --entrypoint sh \
        --volume "${OPENSYMPHONY_STATE_VOLUME}:/state:ro" \
        "${OPENSYMPHONY_INTEGRATION_IMAGE}" \
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
    OPENSYMPHONY_IMAGE="${OPENSYMPHONY_INTEGRATION_IMAGE}" \
      ./scripts/opensymphony-container.sh preflight
    OPENSYMPHONY_IMAGE="${OPENSYMPHONY_INTEGRATION_IMAGE}" \
      ./scripts/opensymphony-container.sh memory-status

    doctor_output="${fixture_root}/doctor.log"
    if ! LINEAR_API_KEY=fixture \
      OPENSYMPHONY_IMAGE="${OPENSYMPHONY_INTEGRATION_IMAGE}" \
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

    docker run --rm \
      --entrypoint codex \
      --volume "${repo_root}/ops/opensymphony/codex-config.toml:/home/orchestrator/.codex/config.toml:ro" \
      "${OPENSYMPHONY_INTEGRATION_IMAGE}" \
      --strict-config app-server --help >/dev/null
    docker run --rm \
      --entrypoint codex \
      --tmpfs /tmp:rw,noexec,nosuid,size=256m \
      --volume "${repo_root}/ops/opensymphony/codex-config.toml:/home/orchestrator/.codex/config.toml:ro" \
      "${OPENSYMPHONY_INTEGRATION_IMAGE}" \
      app-server generate-json-schema \
      --experimental \
      --out /tmp/codex-app-server-schema
  )
fi

echo "OpenSymphony container launcher tests passed"
