#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
image="${OPENSYMPHONY_INTEGRATION_IMAGE:?set OPENSYMPHONY_INTEGRATION_IMAGE}"
auth_volume="${OPENSYMPHONY_CODEX_AUTH_VOLUME:?set OPENSYMPHONY_CODEX_AUTH_VOLUME}"
state_volume="${OPENSYMPHONY_STATE_VOLUME:?set OPENSYMPHONY_STATE_VOLUME}"
workspaces_volume="${OPENSYMPHONY_WORKSPACES_VOLUME:?set OPENSYMPHONY_WORKSPACES_VOLUME}"
tools_volume="${OPENSYMPHONY_TOOLS_VOLUME:?set OPENSYMPHONY_TOOLS_VOLUME}"
ccache_volume="${OPENSYMPHONY_CCACHE_VOLUME:?set OPENSYMPHONY_CCACHE_VOLUME}"
vcpkg_archives_volume="${OPENSYMPHONY_VCPKG_ARCHIVES_VOLUME:?set OPENSYMPHONY_VCPKG_ARCHIVES_VOLUME}"
uv_cache_volume="${OPENSYMPHONY_UV_CACHE_VOLUME:?set OPENSYMPHONY_UV_CACHE_VOLUME}"
suffix="${OPENSYMPHONY_ACCEPTANCE_SUFFIX:-$$}"
owner_token="acceptance-${suffix}-${RANDOM}-${RANDOM}"
network="symphony-opensymphony-acceptance-${suffix}"
daemon="symphony-opensymphony-daemon-${suffix}"
memory_daemon="symphony-opensymphony-memory-${suffix}"
linear_fixture="symphony-opensymphony-linear-fixture-${suffix}"
no_model_daemon="symphony-opensymphony-no-model-${suffix}"
recovery_daemon="symphony-opensymphony-recovery-${suffix}"
fixture_repo=""
ast_fixture_root=""
template_commit="84a6c1d49926ccc663c5ad8018d2742f777917e3"
template_tree="7960ff709b1c372cf9397f270203d3154d8fd03b"
runtime_cpus="${OPENSYMPHONY_ACCEPTANCE_CPUS:-4}"
runtime_memory="${OPENSYMPHONY_ACCEPTANCE_MEMORY:-8g}"

if [[ ! "${suffix}" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*$ ]]; then
  echo "unsafe Docker acceptance suffix: ${suffix}" >&2
  exit 2
fi

expected_auth_volume="symphony-codex-auth-acceptance-${suffix}"
expected_state_volume="symphony-opensymphony-state-acceptance-${suffix}"
expected_workspaces_volume="symphony-opensymphony-workspaces-acceptance-${suffix}"
expected_tools_volume="symphony-opensymphony-tools-acceptance-${suffix}"
expected_ccache_volume="symphony-opensymphony-gcc16-ccache-acceptance-${suffix}"
expected_vcpkg_archives_volume="symphony-opensymphony-vcpkg-archives-acceptance-${suffix}"
expected_uv_cache_volume="symphony-opensymphony-uv-cache-acceptance-${suffix}"
if [[ "${auth_volume}" != "${expected_auth_volume}" ]] ||
  [[ "${state_volume}" != "${expected_state_volume}" ]] ||
  [[ "${workspaces_volume}" != "${expected_workspaces_volume}" ]] ||
  [[ "${tools_volume}" != "${expected_tools_volume}" ]] ||
  [[ "${ccache_volume}" != "${expected_ccache_volume}" ]] ||
  [[ "${vcpkg_archives_volume}" != "${expected_vcpkg_archives_volume}" ]] ||
  [[ "${uv_cache_volume}" != "${expected_uv_cache_volume}" ]]; then
  echo "acceptance Docker volumes must use the exact acceptance-only names for suffix ${suffix}" >&2
  exit 2
fi

created_volumes=()
network_created=false

cleanup() {
  result=$?
  cleanup_failed=false
  trap - EXIT
  for name in \
    "${daemon}" \
    "${memory_daemon}" \
    "${linear_fixture}" \
    "${no_model_daemon}" \
    "${recovery_daemon}"; do
    if docker container inspect "${name}" >/dev/null 2>&1; then
      if (( result != 0 )); then
        printf '%s\n' "last owned fixture log lines: ${name}" >&2
        docker logs --tail 80 "${name}" >&2 || true
      fi
      if [[ "$(
        docker container inspect \
          --format '{{ index .Config.Labels "dev.symphony.acceptance-run" }}' \
          "${name}" 2>/dev/null
      )" != "${owner_token}" ]]; then
        echo "refusing to remove a Docker container without the expected owner token: ${name}" >&2
        cleanup_failed=true
      elif ! docker rm --force "${name}" >/dev/null 2>&1; then
        echo "failed to remove owned Docker acceptance container: ${name}" >&2
        cleanup_failed=true
      fi
    fi
  done
  if [[ "${network_created}" == "true" ]]; then
    if [[ "$(
      docker network inspect \
        --format '{{ index .Labels "dev.symphony.acceptance-run" }}' \
        "${network}" 2>/dev/null
    )" != "${owner_token}" ]]; then
      echo "refusing to remove a Docker network without the expected owner token: ${network}" >&2
      cleanup_failed=true
    elif ! docker network rm "${network}" >/dev/null 2>&1; then
      echo "failed to remove owned Docker acceptance network: ${network}" >&2
      cleanup_failed=true
    fi
  fi
  for name in "${created_volumes[@]}"; do
    if [[ "$(
      docker volume inspect \
        --format '{{ index .Labels "dev.symphony.acceptance-run" }}' \
        "${name}" 2>/dev/null
    )" != "${owner_token}" ]]; then
      echo "refusing to remove a Docker volume without the expected owner token: ${name}" >&2
      cleanup_failed=true
    elif ! docker volume rm "${name}" >/dev/null 2>&1; then
      echo "failed to remove owned Docker acceptance volumes" >&2
      cleanup_failed=true
    fi
  done
  if [[ -n "${fixture_repo}" ]]; then
    if [[ "${fixture_repo}" != /tmp/symphony-opensymphony-acceptance.* ]] ||
      ! rm -rf -- "${fixture_repo}"; then
      echo "failed to remove disposable OpenSymphony init fixture" >&2
      cleanup_failed=true
    fi
  fi
  if [[ -n "${ast_fixture_root}" ]]; then
    if [[ "${ast_fixture_root}" != /tmp/symphony-opensymphony-ast.* ]] ||
      ! rm -rf -- "${ast_fixture_root}"; then
      echo "failed to remove disposable OpenSymphony AST fixture" >&2
      cleanup_failed=true
    fi
  fi
  if (( result != 0 )); then
    exit "${result}"
  fi
  if [[ "${cleanup_failed}" == "true" ]]; then
    exit 1
  fi
  exit 0
}
trap cleanup EXIT
fixture_repo="$(mktemp -d /tmp/symphony-opensymphony-acceptance.XXXXXX)"
ast_fixture_root="$(mktemp -d /tmp/symphony-opensymphony-ast.XXXXXX)"
printf '%s\n' \
  'pub fn ast_rust_entry() { ast_rust_helper(); }' \
  'fn ast_rust_helper() {}' \
  >"${ast_fixture_root}/fixture.rs"
printf '%s\n' \
  'function astTsEntry(): void { astTsHelper(); }' \
  'function astTsHelper(): void {}' \
  >"${ast_fixture_root}/fixture.ts"
printf '%s\n' \
  'function AstTsxEntry() { return <div>{astTsxHelper()}</div>; }' \
  'function astTsxHelper() { return "tsx"; }' \
  >"${ast_fixture_root}/fixture.tsx"
printf '%s\n' \
  'function astJsEntry() { astJsHelper(); }' \
  'function astJsHelper() {}' \
  >"${ast_fixture_root}/fixture.js"
printf '%s\n' \
  'function AstJsxEntry() { return <div>{astJsxHelper()}</div>; }' \
  'function astJsxHelper() { return "jsx"; }' \
  >"${ast_fixture_root}/fixture.jsx"
printf '%s\n' \
  'def ast_python_entry():' \
  '    ast_python_helper()' \
  '' \
  'def ast_python_helper():' \
  '    return None' \
  >"${ast_fixture_root}/fixture.py"
printf '%s\n' '{"fixture": "json"}' >"${ast_fixture_root}/fixture.json"
printf '%s\n' 'fixture: yaml' >"${ast_fixture_root}/fixture.yaml"
printf '%s\n' 'fixture = "toml"' >"${ast_fixture_root}/fixture.toml"
printf '%s\n' '# Fixture Markdown' >"${ast_fixture_root}/fixture.md"
printf '%s\n' 'void unsupported_cpp() {}' >"${ast_fixture_root}/unsupported.cpp"

for name in \
  "${auth_volume}" \
  "${state_volume}" \
  "${workspaces_volume}" \
  "${tools_volume}" \
  "${ccache_volume}" \
  "${vcpkg_archives_volume}" \
  "${uv_cache_volume}"; do
  if docker volume inspect "${name}" >/dev/null 2>&1; then
    echo "refusing to reuse pre-existing Docker acceptance volume: ${name}" >&2
    exit 2
  fi
done
if docker network inspect "${network}" >/dev/null 2>&1; then
  echo "refusing to reuse pre-existing Docker acceptance network: ${network}" >&2
  exit 2
fi
for name in \
  "${daemon}" \
  "${memory_daemon}" \
  "${linear_fixture}" \
  "${no_model_daemon}" \
  "${recovery_daemon}"; do
  if docker container inspect "${name}" >/dev/null 2>&1; then
    echo "refusing to reuse pre-existing Docker acceptance container: ${name}" >&2
    exit 2
  fi
done
for name in \
  "${auth_volume}" \
  "${state_volume}" \
  "${workspaces_volume}" \
  "${tools_volume}" \
  "${ccache_volume}" \
  "${vcpkg_archives_volume}" \
  "${uv_cache_volume}"; do
  docker volume create \
    --label "dev.symphony.acceptance-run=${owner_token}" \
    "${name}" >/dev/null
  if [[ "$(
    docker volume inspect \
      --format '{{ index .Labels "dev.symphony.acceptance-run" }}' \
      "${name}" 2>/dev/null
  )" != "${owner_token}" ]]; then
    echo "failed to prove Docker acceptance-volume ownership: ${name}" >&2
    exit 2
  fi
  created_volumes+=("${name}")
done
docker network create \
  --internal \
  --label "dev.symphony.acceptance-run=${owner_token}" \
  "${network}" >/dev/null
if [[ "$(
  docker network inspect \
    --format '{{ index .Labels "dev.symphony.acceptance-run" }}' \
    "${network}" 2>/dev/null
)" != "${owner_token}" ]]; then
  echo "failed to prove Docker acceptance-network ownership: ${network}" >&2
  exit 2
fi
network_created=true

hardening_args=(
  --read-only
  --cap-drop ALL
  --security-opt no-new-privileges
  --pids-limit 2048
  --tmpfs "/tmp:rw,noexec,nosuid,size=256m"
)
limit_args=(
  --cpus "${runtime_cpus}"
  --memory "${runtime_memory}"
  --memory-swap "${runtime_memory}"
)
common_args=(
  --rm
  --workdir /target
  "${hardening_args[@]}"
  "${limit_args[@]}"
  --network "${network}"
  --env LINEAR_API_KEY=fixture-key
  --env CCACHE_DIR=/home/orchestrator/.cache/ccache
  --env UV_CACHE_DIR=/home/orchestrator/.cache/uv
  --env VCPKG_DEFAULT_BINARY_CACHE=/home/orchestrator/.cache/vcpkg/archives
  --volume "${repo_root}:/target:ro"
  --volume "${repo_root}/WORKFLOW.md:/orchestrator/WORKFLOW.md:ro"
  --volume "${repo_root}/ops/opensymphony/config.yaml:/orchestrator/config.yaml:ro"
  --volume "${repo_root}/ops/opensymphony/fixtures:/fixtures:ro"
  --volume "${auth_volume}:/home/orchestrator/.codex"
  --volume "${repo_root}/ops/opensymphony/codex-config.toml:/home/orchestrator/.codex/config.toml:ro"
  --volume "${tools_volume}:/home/orchestrator/.opensymphony"
  --volume "${ccache_volume}:/home/orchestrator/.cache/ccache"
  --volume "${vcpkg_archives_volume}:/home/orchestrator/.cache/vcpkg/archives"
  --volume "${uv_cache_volume}:/home/orchestrator/.cache/uv"
  --volume "${state_volume}:/target/.opensymphony"
  --volume "${workspaces_volume}:/workspaces"
)

printf 'fixture-key\n' |
  docker run --rm --interactive \
    "${hardening_args[@]}" \
    "${limit_args[@]}" \
    --network "${network}" \
    --volume "${auth_volume}:/home/orchestrator/.codex" \
    --entrypoint codex \
    "${image}" \
    login --with-api-key

(
  cd "${repo_root}"
  OPENSYMPHONY_IMAGE="${image}" \
    OPENSYMPHONY_NETWORK="${network}" \
    OPENSYMPHONY_CODEX_AUTH_VOLUME="${auth_volume}" \
    OPENSYMPHONY_STATE_VOLUME="${state_volume}" \
    OPENSYMPHONY_WORKSPACES_VOLUME="${workspaces_volume}" \
    OPENSYMPHONY_TOOLS_VOLUME="${tools_volume}" \
    OPENSYMPHONY_CCACHE_VOLUME="${ccache_volume}" \
    OPENSYMPHONY_VCPKG_ARCHIVES_VOLUME="${vcpkg_archives_volume}" \
    OPENSYMPHONY_UV_CACHE_VOLUME="${uv_cache_volume}" \
    ./scripts/opensymphony-container.sh memory-init
  OPENSYMPHONY_IMAGE="${image}" \
    OPENSYMPHONY_NETWORK="${network}" \
    OPENSYMPHONY_CODEX_AUTH_VOLUME="${auth_volume}" \
    OPENSYMPHONY_STATE_VOLUME="${state_volume}" \
    OPENSYMPHONY_WORKSPACES_VOLUME="${workspaces_volume}" \
    OPENSYMPHONY_TOOLS_VOLUME="${tools_volume}" \
    OPENSYMPHONY_CCACHE_VOLUME="${ccache_volume}" \
    OPENSYMPHONY_VCPKG_ARCHIVES_VOLUME="${vcpkg_archives_volume}" \
    OPENSYMPHONY_UV_CACHE_VOLUME="${uv_cache_volume}" \
    ./scripts/opensymphony-container.sh preflight
  LINEAR_API_KEY=fixture-key \
    OPENSYMPHONY_IMAGE="${image}" \
    OPENSYMPHONY_NETWORK="${network}" \
    OPENSYMPHONY_ACCEPTANCE_SUFFIX="${suffix}" \
    OPENSYMPHONY_ACCEPTANCE_RESOURCES_VERIFIED=true \
    OPENSYMPHONY_ACCEPTANCE_OWNER_TOKEN="${owner_token}" \
    OPENSYMPHONY_CODEX_AUTH_VOLUME="${auth_volume}" \
    OPENSYMPHONY_STATE_VOLUME="${state_volume}" \
    OPENSYMPHONY_WORKSPACES_VOLUME="${workspaces_volume}" \
    OPENSYMPHONY_TOOLS_VOLUME="${tools_volume}" \
    OPENSYMPHONY_CCACHE_VOLUME="${ccache_volume}" \
    OPENSYMPHONY_VCPKG_ARCHIVES_VOLUME="${vcpkg_archives_volume}" \
    OPENSYMPHONY_UV_CACHE_VOLUME="${uv_cache_volume}" \
    ./scripts/opensymphony-container.sh doctor
)

docker run --detach \
  --name "${linear_fixture}" \
  --label "dev.symphony.acceptance-run=${owner_token}" \
  --network "${network}" \
  --network-alias linear-fixture \
  "${hardening_args[@]}" \
  "${limit_args[@]}" \
  --tmpfs "/audit:rw,noexec,nosuid,size=1m,uid=10001,gid=10001,mode=0700" \
  --env FIXTURE_LINEAR_AUDIT_LOG=/audit/operations.jsonl \
  --env FIXTURE_LINEAR_MODE=active \
  --volume "${repo_root}/ops/opensymphony/fixtures/fake-linear.py:/fixtures/fake-linear.py:ro" \
  --entrypoint python3 \
  "${image}" \
  /fixtures/fake-linear.py >/dev/null
linear_health=""
for _ in $(seq 1 30); do
  if linear_health="$(docker run --rm \
    "${hardening_args[@]}" \
    "${limit_args[@]}" \
    --network "${network}" \
    --entrypoint curl \
    "${image}" \
    --fail --silent --show-error \
    "http://${linear_fixture}:8080/health")" &&
    printf '%s\n' "${linear_health}" | grep -Fq '"status":"ok"'; then
    break
  fi
  sleep 1
done
printf '%s\n' "${linear_health}" | grep -Fq '"status":"ok"'

docker run --detach \
  --name "${no_model_daemon}" \
  --label "dev.symphony.acceptance-run=${owner_token}" \
  --network "${network}" \
  "${hardening_args[@]}" \
  "${limit_args[@]}" \
  --env LINEAR_API_KEY=fixture-key \
  --env CCACHE_DIR=/home/orchestrator/.cache/ccache \
  --env UV_CACHE_DIR=/home/orchestrator/.cache/uv \
  --env VCPKG_DEFAULT_BINARY_CACHE=/home/orchestrator/.cache/vcpkg/archives \
  --volume "${repo_root}:/target:ro" \
  --volume "${repo_root}/ops/opensymphony/fixtures/WORKFLOW.no-model.md:/target/WORKFLOW.md:ro" \
  --volume "${repo_root}/ops/opensymphony/config.yaml:/orchestrator/config.yaml:ro" \
  --volume "${auth_volume}:/home/orchestrator/.codex" \
  --volume "${repo_root}/ops/opensymphony/codex-config.toml:/home/orchestrator/.codex/config.toml:ro" \
  --volume "${tools_volume}:/home/orchestrator/.opensymphony" \
  --volume "${ccache_volume}:/home/orchestrator/.cache/ccache" \
  --volume "${vcpkg_archives_volume}:/home/orchestrator/.cache/vcpkg/archives" \
  --volume "${uv_cache_volume}:/home/orchestrator/.cache/uv" \
  --volume "${state_volume}:/target/.opensymphony" \
  --volume "${workspaces_volume}:/workspaces" \
  "${image}" run --config /orchestrator/config.yaml --dry-run >/dev/null
no_model_snapshot=""
for _ in $(seq 1 60); do
  if no_model_snapshot="$(docker run --rm \
    "${hardening_args[@]}" \
    "${limit_args[@]}" \
    --network "${network}" \
    --entrypoint curl \
    "${image}" \
    --fail --silent --show-error \
    "http://${no_model_daemon}:2468/api/v1/snapshot")" &&
    printf '%s\n' "${no_model_snapshot}" | grep -Fq '"identifier":"FIX-901"' &&
    printf '%s\n' "${no_model_snapshot}" | grep -Fq '"transport_target":"codex_app_server"' &&
    printf '%s\n' "${no_model_snapshot}" | grep -Fq '"running_issues":0'; then
    break
  fi
  sleep 1
done
printf '%s\n' "${no_model_snapshot}" | grep -Fq '"identifier":"FIX-901"'
printf '%s\n' "${no_model_snapshot}" | grep -Fq '"transport_target":"codex_app_server"'
printf '%s\n' "${no_model_snapshot}" | grep -Fq '"running_issues":0'
printf '%s\n' "${no_model_snapshot}" | grep -Fq '"input_tokens":0'
printf '%s\n' "${no_model_snapshot}" | grep -Fq '"output_tokens":0'
printf '%s\n' "${no_model_snapshot}" | grep -Fq '"total_tokens":0'
printf '%s\n' "${no_model_snapshot}" | grep -Fq '"turn_count":0'
printf '%s\n' "${no_model_snapshot}" | grep -Fq '"conversation_count":0'
if printf '%s\n' "${no_model_snapshot}" | grep -Fq '"codex_thread_id":'; then
  printf '%s\n' "no-model dry run unexpectedly created a Codex thread identifier" >&2
  exit 1
fi
if docker exec "${linear_fixture}" grep -F -q '"mutation": true' /audit/operations.jsonl; then
  echo "contained no-model route attempted a tracker mutation" >&2
  exit 1
fi
if [[ "$(
  docker container inspect \
    --format '{{ index .Config.Labels "dev.symphony.acceptance-run" }}' \
    "${no_model_daemon}" 2>/dev/null
)" != "${owner_token}" ]]; then
  echo "refusing to stop a no-model container without the expected owner token" >&2
  exit 1
fi
docker stop --signal SIGINT --time 10 "${no_model_daemon}" >/dev/null
test "$(docker container inspect --format '{{ .State.ExitCode }}' "${no_model_daemon}")" = "0"
docker rm "${no_model_daemon}" >/dev/null

workspace_fingerprint_before="$(
  docker run --rm \
    "${hardening_args[@]}" \
    "${limit_args[@]}" \
    --network "${network}" \
    --volume "${workspaces_volume}:/workspaces:ro" \
    --entrypoint sh \
    "${image}" \
    -euc '
      if ! test "$(find /workspaces -type f -path "*/.opensymphony/run.json" | wc -l)" -eq 1; then
        printf "unexpected dry-run workspace layout:\n" >&2
        find /workspaces -maxdepth 3 -print | sort >&2
        exit 1
      fi
      run_manifest="$(find /workspaces -type f -path "*/.opensymphony/run.json" -print -quit)"
      if ! grep -F -q "\"status\": \"succeeded\"" "${run_manifest}"; then
        printf "unexpected dry-run manifest state:\n" >&2
        sed -n "1,80p" "${run_manifest}" >&2
        exit 1
      fi
      workspace="${run_manifest%/.opensymphony/run.json}"
      for artifact in \
        "${workspace}/.opensymphony/issue.json" \
        "${workspace}/.opensymphony.after_create.json" \
        "${workspace}/.opensymphony-fixture-after-create" \
        "${workspace}/.opensymphony-fixture-before-run" \
        "${workspace}/.opensymphony-fixture-after-run"; do
        if ! test -s "${artifact}"; then
          printf "missing expected workspace artifact: %s\n" "${artifact}" >&2
          find "${workspace}" -maxdepth 2 -type f -print | sort >&2
          exit 1
        fi
      done
      test ! -e "${workspace}/.opensymphony-fixture-before-remove"
      test ! -e "${workspace}/.opensymphony/conversation.json"
      sha256sum \
        "${workspace}/.opensymphony/issue.json" \
        "${workspace}/.opensymphony/run.json" \
        "${workspace}/.opensymphony.after_create.json" \
        "${workspace}/.opensymphony-fixture-after-create" \
        "${workspace}/.opensymphony-fixture-before-run" \
        "${workspace}/.opensymphony-fixture-after-run" |
        sort |
        sha256sum |
        cut -d " " -f 1
    '
)"
test -n "${workspace_fingerprint_before}"

if [[ "$(
  docker container inspect \
    --format '{{ index .Config.Labels "dev.symphony.acceptance-run" }}' \
    "${linear_fixture}" 2>/dev/null
)" != "${owner_token}" ]]; then
  echo "refusing to replace a Linear fixture without the expected owner token" >&2
  exit 1
fi
docker rm --force "${linear_fixture}" >/dev/null
docker run --detach \
  --name "${linear_fixture}" \
  --label "dev.symphony.acceptance-run=${owner_token}" \
  --network "${network}" \
  --network-alias linear-fixture \
  "${hardening_args[@]}" \
  "${limit_args[@]}" \
  --tmpfs "/audit:rw,noexec,nosuid,size=1m,uid=10001,gid=10001,mode=0700" \
  --env FIXTURE_LINEAR_AUDIT_LOG=/audit/operations.jsonl \
  --env FIXTURE_LINEAR_MODE=terminal \
  --volume "${repo_root}/ops/opensymphony/fixtures/fake-linear.py:/fixtures/fake-linear.py:ro" \
  --entrypoint python3 \
  "${image}" \
  /fixtures/fake-linear.py >/dev/null
linear_health=""
for _ in $(seq 1 30); do
  if linear_health="$(docker run --rm \
    "${hardening_args[@]}" \
    "${limit_args[@]}" \
    --network "${network}" \
    --entrypoint curl \
    "${image}" \
    --fail --silent --show-error \
    "http://${linear_fixture}:8080/health")" &&
    printf '%s\n' "${linear_health}" | grep -Fq '"status":"ok"'; then
    break
  fi
  sleep 1
done
printf '%s\n' "${linear_health}" | grep -Fq '"status":"ok"'

docker run --detach \
  --name "${recovery_daemon}" \
  --label "dev.symphony.acceptance-run=${owner_token}" \
  --network "${network}" \
  "${hardening_args[@]}" \
  "${limit_args[@]}" \
  --env LINEAR_API_KEY=fixture-key \
  --env CCACHE_DIR=/home/orchestrator/.cache/ccache \
  --env UV_CACHE_DIR=/home/orchestrator/.cache/uv \
  --env VCPKG_DEFAULT_BINARY_CACHE=/home/orchestrator/.cache/vcpkg/archives \
  --volume "${repo_root}:/target:ro" \
  --volume "${repo_root}/ops/opensymphony/fixtures/WORKFLOW.no-model.md:/target/WORKFLOW.md:ro" \
  --volume "${repo_root}/ops/opensymphony/config.yaml:/orchestrator/config.yaml:ro" \
  --volume "${auth_volume}:/home/orchestrator/.codex" \
  --volume "${repo_root}/ops/opensymphony/codex-config.toml:/home/orchestrator/.codex/config.toml:ro" \
  --volume "${tools_volume}:/home/orchestrator/.opensymphony" \
  --volume "${ccache_volume}:/home/orchestrator/.cache/ccache" \
  --volume "${vcpkg_archives_volume}:/home/orchestrator/.cache/vcpkg/archives" \
  --volume "${uv_cache_volume}:/home/orchestrator/.cache/uv" \
  --volume "${state_volume}:/target/.opensymphony" \
  --volume "${workspaces_volume}:/workspaces" \
  "${image}" run --config /orchestrator/config.yaml --dry-run >/dev/null
recovery_snapshot=""
for _ in $(seq 1 60); do
  if recovery_snapshot="$(docker run --rm \
    "${hardening_args[@]}" \
    "${limit_args[@]}" \
    --network "${network}" \
    --entrypoint curl \
    "${image}" \
    --fail --silent --show-error \
    "http://${recovery_daemon}:2468/api/v1/snapshot")" &&
    printf '%s\n' "${recovery_snapshot}" |
      grep -Fq 'recovered startup state; running=0, retry_queue=0' &&
    printf '%s\n' "${recovery_snapshot}" | grep -Fq '"running_issues":0'; then
    break
  fi
  sleep 1
done
printf '%s\n' "${recovery_snapshot}" |
  grep -Fq 'recovered startup state; running=0, retry_queue=0'
printf '%s\n' "${recovery_snapshot}" | grep -Fq '"running_issues":0'
printf '%s\n' "${recovery_snapshot}" | grep -Fq '"input_tokens":0'
printf '%s\n' "${recovery_snapshot}" | grep -Fq '"output_tokens":0'
printf '%s\n' "${recovery_snapshot}" | grep -Fq '"total_tokens":0'
printf '%s\n' "${recovery_snapshot}" | grep -Fq '"conversation_count":0'
if printf '%s\n' "${recovery_snapshot}" | grep -Fq '"codex_thread_id":'; then
  printf '%s\n' "terminal recovery unexpectedly created a Codex thread identifier" >&2
  exit 1
fi
if docker exec "${linear_fixture}" grep -F -q '"mutation": true' /audit/operations.jsonl; then
  echo "terminal recovery attempted a tracker mutation" >&2
  exit 1
fi
if [[ "$(
  docker container inspect \
    --format '{{ index .Config.Labels "dev.symphony.acceptance-run" }}' \
    "${recovery_daemon}" 2>/dev/null
)" != "${owner_token}" ]]; then
  echo "refusing to stop a recovery container without the expected owner token" >&2
  exit 1
fi
docker stop --signal SIGINT --time 10 "${recovery_daemon}" >/dev/null
test "$(docker container inspect --format '{{ .State.ExitCode }}' "${recovery_daemon}")" = "0"
docker rm "${recovery_daemon}" >/dev/null

workspace_fingerprint_after="$(
  docker run --rm \
    "${hardening_args[@]}" \
    "${limit_args[@]}" \
    --network "${network}" \
    --volume "${workspaces_volume}:/workspaces:ro" \
    --entrypoint sh \
    "${image}" \
    -euc '
      test "$(find /workspaces -type f -path "*/.opensymphony/run.json" | wc -l)" -eq 1
      run_manifest="$(find /workspaces -type f -path "*/.opensymphony/run.json" -print -quit)"
      grep -F -q "\"status\": \"succeeded\"" "${run_manifest}"
      workspace="${run_manifest%/.opensymphony/run.json}"
      test "$(wc -l < "${workspace}/.opensymphony-fixture-before-remove")" -eq 1
      grep -F -x -q "before-remove" "${workspace}/.opensymphony-fixture-before-remove"
      test ! -e "${workspace}/.opensymphony/conversation.json"
      sha256sum \
        "${workspace}/.opensymphony/issue.json" \
        "${workspace}/.opensymphony/run.json" \
        "${workspace}/.opensymphony.after_create.json" \
        "${workspace}/.opensymphony-fixture-after-create" \
        "${workspace}/.opensymphony-fixture-before-run" \
        "${workspace}/.opensymphony-fixture-after-run" |
        sort |
        sha256sum |
        cut -d " " -f 1
    '
)"
test "${workspace_fingerprint_after}" = "${workspace_fingerprint_before}"

docker run "${common_args[@]}" \
  "${image}" memory --config /target/.opensymphony/memory/memory.yaml import FIX-100 \
  --source-file /fixtures/completed-memory.yaml
docker run "${common_args[@]}" \
  "${image}" memory --config /target/.opensymphony/memory/memory.yaml sync-docs \
  --issues FIX-100 \
  --with-diagrams
memory_status="$(
  docker run "${common_args[@]}" \
    "${image}" memory --config /target/.opensymphony/memory/memory.yaml status
)"
printf '%s\n' "${memory_status}" | grep -Fq "Issues captured: 1"
printf '%s\n' "${memory_status}" | grep -Fq "Capture warnings: 0"

docker run --rm \
  "${hardening_args[@]}" \
  "${limit_args[@]}" \
  --entrypoint sh \
  --volume "${state_volume}:/state:ro" \
  "${image}" \
  -euc '
    test -s /state/memory/issues/FIX-100.md
    test -s /state/memory/memory.duckdb
    test -s /state/memory/generated-docs/orchestration.md
    grep -F -q "FIX-100" /state/memory/generated-docs/orchestration.md
  '

memory_state_before="$(
  docker run --rm \
    "${hardening_args[@]}" \
    "${limit_args[@]}" \
    --entrypoint sh \
    --volume "${state_volume}:/state:ro" \
    "${image}" \
    -euc 'find /state -type f -exec sha256sum {} \; | sort | sha256sum'
)"
docker run --detach \
  --name "${memory_daemon}" \
  --label "dev.symphony.acceptance-run=${owner_token}" \
  --network "${network}" \
  --workdir /target \
  "${hardening_args[@]}" \
  "${limit_args[@]}" \
  --volume "${repo_root}:/target:ro" \
  --volume "${ast_fixture_root}:/target/ops/opensymphony/fixtures:ro" \
  --volume "${repo_root}/ops/opensymphony/config.yaml:/orchestrator/config.yaml:ro" \
  --volume "${state_volume}:/target/.opensymphony:ro" \
  --entrypoint opensymphony \
  "${image}" \
  memory --config /target/.opensymphony/memory/memory.yaml serve --addr 0.0.0.0:8765 >/dev/null
memory_health=""
for _ in $(seq 1 30); do
  if memory_health="$(docker run --rm \
    "${hardening_args[@]}" \
    "${limit_args[@]}" \
    --network "${network}" \
    --entrypoint curl \
    "${image}" \
    --fail --silent --show-error \
    "http://${memory_daemon}:8765/health")" &&
    printf '%s\n' "${memory_health}" | grep -Fq '"status":"ok"'; then
    break
  fi
  sleep 1
done
printf '%s\n' "${memory_health}" | grep -Fq '"mode":"read_only"'
printf '%s\n' "${memory_health}" | grep -Fq '"adminTools":false'
memory_initialize="$(
  docker run --rm \
    "${hardening_args[@]}" \
    "${limit_args[@]}" \
    --network "${network}" \
    --entrypoint curl \
    "${image}" \
    --fail --silent --show-error \
    --header "content-type: application/json" \
    --data '{"jsonrpc":"2.0","id":"acceptance","method":"initialize","params":{}}' \
    "http://${memory_daemon}:8765/mcp"
)"
printf '%s\n' "${memory_initialize}" | grep -Fq '"name":"opensymphony-memory"'
memory_tools="$(
  docker run --rm \
    "${hardening_args[@]}" \
    "${limit_args[@]}" \
    --network "${network}" \
    --entrypoint curl \
    "${image}" \
    --fail --silent --show-error \
    --header "content-type: application/json" \
    --data '{"jsonrpc":"2.0","id":"tools","method":"tools/list","params":{}}' \
    "http://${memory_daemon}:8765/mcp"
)"
printf '%s\n' "${memory_tools}" | grep -Fq '"name":"memory.status"'
printf '%s\n' "${memory_tools}" | grep -Fq '"name":"memory.context"'
for ast_tool in \
  code.ast.status \
  code.ast.outline \
  code.ast.symbols \
  code.ast.references \
  code.ast.query \
  code.ast.context \
  code.ast.diagnostics; do
  printf '%s\n' "${memory_tools}" | grep -Fq "\"name\":\"${ast_tool}\""
done
ast_status="$(
  docker run --rm \
    "${hardening_args[@]}" \
    "${limit_args[@]}" \
    --network "${network}" \
    --entrypoint curl \
    "${image}" \
    --fail --silent --show-error \
    --header "content-type: application/json" \
    --data '{"jsonrpc":"2.0","id":"ast-status","method":"tools/call","params":{"name":"code.ast.status","arguments":{}}}' \
    "http://${memory_daemon}:8765/mcp"
)"
printf '%s\n' "${ast_status}" |
  docker run --rm --interactive \
    "${hardening_args[@]}" \
    "${limit_args[@]}" \
    --entrypoint python3 \
    "${image}" \
    -c '
import json
import sys

response = json.load(sys.stdin)
if "error" in response:
    raise AssertionError("AST status MCP error: {!r}".format(response["error"]))
result = response.get("result")
assert isinstance(result, dict), f"AST status omitted object result; keys={sorted(response)}"
assert result["provider"] == "tree-sitter-ast"
assert result["available"] is True
assert result["parserVersion"] == "0.26.9"
assert result["languages"] == [
    "rust",
    "typescript",
    "tsx",
    "javascript",
    "jsx",
    "python",
]
assert result["queryPackVersions"] == {
    "rust": "rust-query-pack-v2",
    "typescript": "typescript-query-pack-v1",
    "tsx": "tsx-query-pack-v1",
    "javascript": "javascript-query-pack-v1",
    "jsx": "jsx-query-pack-v1",
    "python": "python-query-pack-v1",
}
'
ast_outline="$(
  docker run --rm \
    "${hardening_args[@]}" \
    "${limit_args[@]}" \
    --network "${network}" \
    --entrypoint curl \
    "${image}" \
    --fail --silent --show-error \
    --header "content-type: application/json" \
    --data '{"jsonrpc":"2.0","id":"ast-outline","method":"tools/call","params":{"name":"code.ast.outline","arguments":{"paths":["ops/opensymphony/fixtures"],"limit":100}}}' \
    "http://${memory_daemon}:8765/mcp"
)"
printf '%s\n' "${ast_outline}" |
  docker run --rm --interactive \
    "${hardening_args[@]}" \
    "${limit_args[@]}" \
    --entrypoint python3 \
    "${image}" \
    -c '
import json
import re
import sys

response = json.load(sys.stdin)
if "error" in response:
    raise AssertionError("AST outline MCP error: {!r}".format(response["error"]))
result = response.get("result")
assert isinstance(result, dict), f"AST outline omitted object result; keys={sorted(response)}"
documents = result["documents"]
assert len(documents) == 10
by_language = {document["language"]: document for document in documents}
expected = {
    "rust": (
        "ast_rust_entry",
        "tree-sitter-rust-0.24.2:0.26.9",
        "rust-query-pack-v2",
    ),
    "typescript": (
        "astTsEntry",
        "tree-sitter-typescript-0.23.2:0.26.9",
        "typescript-query-pack-v1",
    ),
    "tsx": (
        "AstTsxEntry",
        "tree-sitter-typescript-0.23.2:0.26.9",
        "tsx-query-pack-v1",
    ),
    "javascript": (
        "astJsEntry",
        "tree-sitter-javascript-0.25.0:0.26.9",
        "javascript-query-pack-v1",
    ),
    "jsx": (
        "AstJsxEntry",
        "tree-sitter-javascript-0.25.0:0.26.9",
        "jsx-query-pack-v1",
    ),
    "python": (
        "ast_python_entry",
        "tree-sitter-python-0.25.0:0.26.9",
        "python-query-pack-v1",
    ),
}
for language, (symbol, parser, query_pack) in expected.items():
    document = by_language[language]
    assert document["parserVersion"] == parser
    assert document["queryPackVersion"] == query_pack
    assert document["diagnostics"] == []
    assert re.fullmatch(r"[0-9a-f]{64}", document["contentSha256"])
    assert symbol in {item["name"] for item in document["symbols"]}

for language in ("json", "yaml", "toml", "markdown"):
    document = by_language[language]
    assert document["parserVersion"] == "lightweight-text:n/a"
    assert document["queryPackVersion"] == f"{language}-lightweight-v1"
    assert document["diagnostics"] == []
    assert re.fullmatch(r"[0-9a-f]{64}", document["contentSha256"])
    assert document["symbols"]

assert not any(document["path"].endswith("unsupported.cpp") for document in documents)
assert "parsed 10 file(s)" in result["trace"]
'
memory_admin_response="$(
  docker run --rm \
    "${hardening_args[@]}" \
    "${limit_args[@]}" \
    --network "${network}" \
    --entrypoint curl \
    "${image}" \
    --silent --show-error \
    --write-out $'\n%{http_code}' \
    --header "content-type: application/json" \
    --data '{"jsonrpc":"2.0","id":"admin","method":"tools/call","params":{"name":"memory.sync_docs","arguments":{}}}' \
    "http://${memory_daemon}:8765/mcp"
)"
memory_admin_status="${memory_admin_response##*$'\n'}"
memory_admin_body="${memory_admin_response%$'\n'*}"
test "${memory_admin_status}" = "403"
printf '%s\n' "${memory_admin_body}" | grep -Fq '"code":"admin_token_required"'
memory_state_after="$(
  docker run --rm \
    "${hardening_args[@]}" \
    "${limit_args[@]}" \
    --entrypoint sh \
    --volume "${state_volume}:/state:ro" \
    "${image}" \
    -euc 'find /state -type f -exec sha256sum {} \; | sort | sha256sum'
)"
test "${memory_state_after}" = "${memory_state_before}"

docker run --detach \
  --name "${daemon}" \
  --label "dev.symphony.acceptance-run=${owner_token}" \
  --network "${network}" \
  "${hardening_args[@]}" \
  "${limit_args[@]}" \
  --entrypoint opensymphony \
  "${image}" \
  daemon --bind 0.0.0.0:2468 --sample-interval-ms 100 >/dev/null
for _ in $(seq 1 30); do
  if docker run --rm \
    "${hardening_args[@]}" \
    "${limit_args[@]}" \
    --network "${network}" \
    --entrypoint curl \
    "${image}" \
    --fail --silent --show-error \
    "http://${daemon}:2468/healthz" >/dev/null; then
    break
  fi
  sleep 1
done
docker run --rm \
  --tty \
  "${hardening_args[@]}" \
  "${limit_args[@]}" \
  --network "${network}" \
  --entrypoint opensymphony \
  "${image}" \
  tui --url "http://${daemon}:2468/" --exit-after-ms 1000

chmod 0777 "${fixture_repo}"
docker run --rm \
  "${hardening_args[@]}" \
  "${limit_args[@]}" \
  --workdir /fixture \
  --volume "${fixture_repo}:/fixture" \
  --env "OPENSYMPHONY_TEMPLATE_BASE_URL=https://raw.githubusercontent.com/kumanday/OpenSymphony-template/${template_commit}/" \
  --env "OPENSYMPHONY_TEMPLATE_TREE_URL=https://api.github.com/repos/kumanday/OpenSymphony-template/git/trees/${template_tree}?recursive=1" \
  --entrypoint sh \
  "${image}" \
  -euc '
    git init --quiet
    git config user.name Fixture
    git config user.email fixture@example.invalid
    touch README.md
    git add README.md
    git commit --quiet -m fixture
    opensymphony init \
      --non-interactive \
      --review-provider none \
      --linear-project-slug symphony-cpp-bf04553735be \
      --target-branch codex/implementation \
      --conflict-policy abort
  '
test -s "${fixture_repo}/WORKFLOW.md"
test -s "${fixture_repo}/config.yaml"
test -s "${fixture_repo}/.opensymphony/memory/memory.yaml"
test -s "${fixture_repo}/.agents/skills/opensymphony-memory/SKILL.md"
grep -Fq 'project_slug: "symphony-cpp-bf04553735be"' "${fixture_repo}/WORKFLOW.md"
grep -Fq 'Active review provider: `none`' "${fixture_repo}/WORKFLOW.md"
grep -Fq 'origin/codex/implementation' "${fixture_repo}/WORKFLOW.md"
if grep -Fq 'origin/YOUR-TARGET-BRANCH' "${fixture_repo}/WORKFLOW.md"; then
  echo "pinned init left the target branch placeholder unresolved" >&2
  exit 1
fi
grep -Fq 'auto_archive: false' "${fixture_repo}/config.yaml"
grep -Fq 'tool_dir: ~/.opensymphony/openhands-server' "${fixture_repo}/config.yaml"

echo "OpenSymphony contained Codex-route smoke acceptance passed"
