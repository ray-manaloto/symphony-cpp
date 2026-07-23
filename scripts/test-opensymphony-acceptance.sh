#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
image="${OPENSYMPHONY_INTEGRATION_IMAGE:?set OPENSYMPHONY_INTEGRATION_IMAGE}"
auth_volume="${OPENSYMPHONY_CODEX_AUTH_VOLUME:?set OPENSYMPHONY_CODEX_AUTH_VOLUME}"
state_volume="${OPENSYMPHONY_STATE_VOLUME:?set OPENSYMPHONY_STATE_VOLUME}"
suffix="${OPENSYMPHONY_ACCEPTANCE_SUFFIX:-$$}"
network="symphony-opensymphony-acceptance-${suffix}"
daemon="symphony-opensymphony-daemon-${suffix}"
memory_daemon="symphony-opensymphony-memory-${suffix}"
fixture_repo="$(mktemp -d /tmp/symphony-opensymphony-acceptance.XXXXXX)"

for name in "${auth_volume}" "${state_volume}" "${network}" "${daemon}" "${memory_daemon}"; do
  if [[ ! "${name}" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]+$ ]]; then
    echo "unsafe Docker test resource name: ${name}" >&2
    exit 2
  fi
done

cleanup() {
  docker rm --force "${daemon}" >/dev/null 2>&1 || true
  docker rm --force "${memory_daemon}" >/dev/null 2>&1 || true
  docker network rm "${network}" >/dev/null 2>&1 || true
  docker volume rm "${auth_volume}" "${state_volume}" >/dev/null 2>&1 || true
  rm -rf -- "${fixture_repo}"
}
trap cleanup EXIT

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
  --volume symphony-opensymphony-workspaces:/workspaces
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
    ./scripts/opensymphony-container.sh memory-init
  OPENSYMPHONY_IMAGE="${image}" \
    OPENSYMPHONY_CODEX_AUTH_VOLUME="${auth_volume}" \
    OPENSYMPHONY_STATE_VOLUME="${state_volume}" \
    ./scripts/opensymphony-container.sh preflight
  LINEAR_API_KEY=fixture-not-a-secret \
    OPENSYMPHONY_IMAGE="${image}" \
    OPENSYMPHONY_CODEX_AUTH_VOLUME="${auth_volume}" \
    OPENSYMPHONY_STATE_VOLUME="${state_volume}" \
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

docker network create "${network}" >/dev/null
docker run --detach \
  --name "${memory_daemon}" \
  --network "${network}" \
  --read-only \
  --tmpfs "/tmp:rw,noexec,nosuid,size=256m" \
  --volume "${repo_root}:/target:ro" \
  --volume "${repo_root}/ops/opensymphony/config.yaml:/orchestrator/config.yaml:ro" \
  --volume "${state_volume}:/target/.opensymphony" \
  --entrypoint opensymphony \
  "${image}" \
  memory --config /orchestrator/config.yaml serve --addr 0.0.0.0:8765 >/dev/null
for _ in $(seq 1 30); do
  if docker run --rm \
    --network "${network}" \
    --entrypoint curl \
    "${image}" \
    --fail --silent --show-error \
    "http://${memory_daemon}:8765/health" |
    grep -Fq '"status":"ok"'; then
    break
  fi
  sleep 1
done
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

echo "OpenSymphony Codex-mode acceptance passed"
