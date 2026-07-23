#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
image="${OPENSYMPHONY_INTEGRATION_IMAGE:?set OPENSYMPHONY_INTEGRATION_IMAGE}"
auth_volume="${OPENSYMPHONY_CODEX_AUTH_VOLUME:?set OPENSYMPHONY_CODEX_AUTH_VOLUME}"
state_volume="${OPENSYMPHONY_STATE_VOLUME:?set OPENSYMPHONY_STATE_VOLUME}"
workspaces_volume="${OPENSYMPHONY_WORKSPACES_VOLUME:?set OPENSYMPHONY_WORKSPACES_VOLUME}"
suffix="${OPENSYMPHONY_ACCEPTANCE_SUFFIX:-$$}"
network="symphony-opensymphony-acceptance-${suffix}"
daemon="symphony-opensymphony-daemon-${suffix}"
memory_daemon="symphony-opensymphony-memory-${suffix}"
fixture_repo="$(mktemp -d /tmp/symphony-opensymphony-acceptance.XXXXXX)"
template_commit="84a6c1d49926ccc663c5ad8018d2742f777917e3"
template_tree="7960ff709b1c372cf9397f270203d3154d8fd03b"

if [[ ! "${suffix}" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*$ ]]; then
  echo "unsafe Docker acceptance suffix: ${suffix}" >&2
  exit 2
fi

expected_auth_volume="symphony-codex-auth-acceptance-${suffix}"
expected_state_volume="symphony-opensymphony-state-acceptance-${suffix}"
expected_workspaces_volume="symphony-opensymphony-workspaces-acceptance-${suffix}"
if [[ "${auth_volume}" != "${expected_auth_volume}" ]] ||
  [[ "${state_volume}" != "${expected_state_volume}" ]] ||
  [[ "${workspaces_volume}" != "${expected_workspaces_volume}" ]]; then
  echo "acceptance Docker volumes must use the exact acceptance-only names for suffix ${suffix}" >&2
  exit 2
fi

created_volumes=()
network_created=false

cleanup() {
  result=$?
  cleanup_failed=false
  trap - EXIT
  for name in "${daemon}" "${memory_daemon}"; do
    if docker container inspect "${name}" >/dev/null 2>&1 &&
      ! docker rm --force "${name}" >/dev/null 2>&1; then
      echo "failed to remove owned Docker acceptance container: ${name}" >&2
      cleanup_failed=true
    fi
  done
  if [[ "${network_created}" == "true" ]]; then
    if ! docker network rm "${network}" >/dev/null 2>&1; then
      echo "failed to remove owned Docker acceptance network: ${network}" >&2
      cleanup_failed=true
    fi
  fi
  if (( ${#created_volumes[@]} > 0 )); then
    if ! docker volume rm "${created_volumes[@]}" >/dev/null 2>&1; then
      echo "failed to remove owned Docker acceptance volumes" >&2
      cleanup_failed=true
    fi
  fi
  if ! rm -rf -- "${fixture_repo}"; then
    echo "failed to remove disposable OpenSymphony init fixture" >&2
    cleanup_failed=true
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

for name in "${auth_volume}" "${state_volume}" "${workspaces_volume}"; do
  if docker volume inspect "${name}" >/dev/null 2>&1; then
    echo "refusing to reuse pre-existing Docker acceptance volume: ${name}" >&2
    exit 2
  fi
done
if docker network inspect "${network}" >/dev/null 2>&1; then
  echo "refusing to reuse pre-existing Docker acceptance network: ${network}" >&2
  exit 2
fi
for name in "${daemon}" "${memory_daemon}"; do
  if docker container inspect "${name}" >/dev/null 2>&1; then
    echo "refusing to reuse pre-existing Docker acceptance container: ${name}" >&2
    exit 2
  fi
done
for name in "${auth_volume}" "${state_volume}" "${workspaces_volume}"; do
  docker volume create "${name}" >/dev/null
  created_volumes+=("${name}")
done
docker network create "${network}" >/dev/null
network_created=true

common_args=(
  --rm
  --read-only
  --tmpfs "/tmp:rw,noexec,nosuid,size=256m"
  --env LINEAR_API_KEY=fixture-not-a-secret
  --volume "${repo_root}:/target:ro"
  --volume "${repo_root}/WORKFLOW.md:/orchestrator/WORKFLOW.md:ro"
  --volume "${repo_root}/ops/opensymphony/config.yaml:/orchestrator/config.yaml:ro"
  --volume "${repo_root}/ops/opensymphony/fixtures:/fixtures:ro"
  --volume "${repo_root}/ops/opensymphony/codex-config.toml:/home/orchestrator/.codex/config.toml:ro"
  --volume "${auth_volume}:/home/orchestrator/.codex"
  --volume "${state_volume}:/target/.opensymphony"
  --volume "${workspaces_volume}:/workspaces"
)

printf 'fixture-not-a-secret\n' |
  docker run --rm --interactive \
    --volume "${auth_volume}:/home/orchestrator/.codex" \
    --entrypoint codex \
    "${image}" \
    login --with-api-key

(
  cd "${repo_root}"
  OPENSYMPHONY_IMAGE="${image}" \
    OPENSYMPHONY_CODEX_AUTH_VOLUME="${auth_volume}" \
    OPENSYMPHONY_STATE_VOLUME="${state_volume}" \
    OPENSYMPHONY_WORKSPACES_VOLUME="${workspaces_volume}" \
    ./scripts/opensymphony-container.sh memory-init
  OPENSYMPHONY_IMAGE="${image}" \
    OPENSYMPHONY_CODEX_AUTH_VOLUME="${auth_volume}" \
    OPENSYMPHONY_STATE_VOLUME="${state_volume}" \
    OPENSYMPHONY_WORKSPACES_VOLUME="${workspaces_volume}" \
    ./scripts/opensymphony-container.sh preflight
  LINEAR_API_KEY=fixture-not-a-secret \
    OPENSYMPHONY_IMAGE="${image}" \
    OPENSYMPHONY_CODEX_AUTH_VOLUME="${auth_volume}" \
    OPENSYMPHONY_STATE_VOLUME="${state_volume}" \
    OPENSYMPHONY_WORKSPACES_VOLUME="${workspaces_volume}" \
    ./scripts/opensymphony-container.sh doctor
)

docker run "${common_args[@]}" \
  "${image}" memory --config /orchestrator/config.yaml import FIX-100 \
  --source-file /fixtures/completed-memory.yaml
docker run "${common_args[@]}" \
  "${image}" memory --config /orchestrator/config.yaml sync-docs \
  --issues FIX-100 \
  --with-diagrams
memory_status="$(
  docker run "${common_args[@]}" \
    "${image}" memory --config /orchestrator/config.yaml status
)"
printf '%s\n' "${memory_status}" | grep -Fq "Issues captured: 1"
printf '%s\n' "${memory_status}" | grep -Fq "Capture warnings: 0"

docker run --rm --read-only \
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
  docker run --rm --read-only \
    --entrypoint sh \
    --volume "${state_volume}:/state:ro" \
    "${image}" \
    -euc 'find /state -type f -exec sha256sum {} \; | sort | sha256sum'
)"
docker run --detach \
  --name "${memory_daemon}" \
  --network "${network}" \
  --read-only \
  --tmpfs "/tmp:rw,noexec,nosuid,size=256m" \
  --volume "${repo_root}:/target:ro" \
  --volume "${repo_root}/ops/opensymphony/config.yaml:/orchestrator/config.yaml:ro" \
  --volume "${state_volume}:/target/.opensymphony:ro" \
  --entrypoint opensymphony \
  "${image}" \
  memory --config /orchestrator/config.yaml serve --addr 0.0.0.0:8765 >/dev/null
memory_health=""
for _ in $(seq 1 30); do
  if memory_health="$(docker run --rm \
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
memory_admin_response="$(
  docker run --rm \
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
  docker run --rm --read-only \
    --entrypoint sh \
    --volume "${state_volume}:/state:ro" \
    "${image}" \
    -euc 'find /state -type f -exec sha256sum {} \; | sort | sha256sum'
)"
test "${memory_state_after}" = "${memory_state_before}"

docker run --detach \
  --name "${daemon}" \
  --network "${network}" \
  --entrypoint opensymphony \
  "${image}" \
  daemon --bind 0.0.0.0:2468 --sample-interval-ms 100 >/dev/null
for _ in $(seq 1 30); do
  if docker run --rm \
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
  --network "${network}" \
  --entrypoint opensymphony \
  "${image}" \
  tui --url "http://${daemon}:2468/" --exit-after-ms 1000

chmod 0777 "${fixture_repo}"
docker run --rm \
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

echo "OpenSymphony Codex-mode acceptance passed"
