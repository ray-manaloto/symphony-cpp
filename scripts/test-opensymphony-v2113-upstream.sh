#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

readonly image="${OPENSYMPHONY_IMAGE:-}"
readonly expected_image="symphony-opensymphony:osv2113-019fc0ca-ticket47"
readonly execution_profile="${OPENSYMPHONY_EXECUTION_PROFILE:-local-desktop-arm64}"
docker_config=""
docker_host=""
case "${execution_profile}" in
  github-actions-native-amd64)
    test "${GITHUB_ACTIONS:-}" = true || {
      printf 'OpenSymphony v2.11.3 upstream contract failed: GITHUB_ACTIONS is not true\n' >&2
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
    printf 'OpenSymphony v2.11.3 upstream contract failed: unsupported execution profile\n' >&2
    exit 1
    ;;
esac
readonly docker_config docker_host
readonly upstream_container="symphony-osv2113-019fc0ca-ticket47-upstream"
readonly -a docker_cmd=(
  env
  "DOCKER_CONFIG=${docker_config}"
  "DOCKER_HOST=${docker_host}"
  docker
)

fail() {
  printf 'OpenSymphony v2.11.3 upstream contract failed: %s\n' "$*" >&2
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

upstream_container_id=""
cleanup_upstream_container() {
  local command_rc=$?
  trap - EXIT
  if test -n "${upstream_container_id}" &&
      "${docker_cmd[@]}" container inspect "${upstream_container_id}" >/dev/null 2>&1; then
    if test "$(
      "${docker_cmd[@]}" container inspect --format '{{.State.Running}}' \
        "${upstream_container_id}"
    )" = true; then
      "${docker_cmd[@]}" container stop --time 10 "${upstream_container_id}" >/dev/null
    fi
    "${docker_cmd[@]}" container rm "${upstream_container_id}" >/dev/null
  fi
  exit "${command_rc}"
}
trap cleanup_upstream_container EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

test "${image}" = "${expected_image}" || fail "OPENSYMPHONY_IMAGE is not the authorized tag"
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

image_id="$("${docker_cmd[@]}" image inspect --format '{{.Id}}' "${image}")"
readonly image_id
[[ "${image_id}" =~ ^sha256:[0-9a-f]{64}$ ]] || fail "image did not resolve to one immutable ID"
test "$(
  "${docker_cmd[@]}" image inspect \
    --format '{{ index .Config.Labels "dev.opensymphony.eval.upstream-tests" }}' \
    "${image_id}"
)" = "passed-stock-unchanged" || fail "image lacks the unchanged upstream-test receipt"

if "${docker_cmd[@]}" container inspect "${upstream_container}" >/dev/null 2>&1; then
  fail "upstream test container name is already occupied"
fi
upstream_container_id="$("${docker_cmd[@]}" container create \
  --pull=never --platform linux/amd64 \
  --name "${upstream_container}" \
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
    test "$(opensymphony --version)" = "opensymphony 2.11.3"
    opensymphony --help >/tmp/top-help
    opensymphony run --help >/tmp/run-help
    opensymphony tui --help >/tmp/tui-help
    grep -Fq "Serve the local control-plane demo stream" /tmp/top-help
    grep -Fq -- "--config" /tmp/run-help
    grep -Fq -- "--url" /tmp/tui-help
    grep -aFq "/api/v1/capabilities" /usr/local/bin/opensymphony
    grep -aFq "/api/v1/control/events" /usr/local/bin/opensymphony
    test -s /opt/opensymphony/evidence/upstream-tests-v1.txt
    grep -Fxq "cargo fmt --check: passed" /opt/opensymphony/evidence/upstream-tests-v1.txt
    grep -Fxq "cargo clippy --locked --workspace --all-targets -- -D warnings: passed" /opt/opensymphony/evidence/upstream-tests-v1.txt
    grep -Fxq "cargo test --locked --workspace -- --test-threads=1: passed" /opt/opensymphony/evidence/upstream-tests-v1.txt
    grep -Fxq "patches: none" /opt/opensymphony/evidence/upstream-tests-v1.txt
    grep -Fxq "task-added xfails: none" /opt/opensymphony/evidence/upstream-tests-v1.txt
    grep -Fxq "task-added skips: none" /opt/opensymphony/evidence/upstream-tests-v1.txt
  ')"
[[ "${upstream_container_id}" =~ ^[0-9a-f]{64}$ ]] || fail "upstream test container ID was not captured"
test "$(
  "${docker_cmd[@]}" container inspect --format '{{.Name}}' "${upstream_container_id}"
)" = "/${upstream_container}" || fail "upstream test container name drifted"
test "$(
  "${docker_cmd[@]}" container inspect \
    --format '{{ index .Config.Labels "dev.opensymphony.eval.controller" }}' \
    "${upstream_container_id}"
)" = "019fc0ca-dde9-7132-91a5-8530d7d76592" || fail "upstream test ownership label drifted"
printf 'OpenSymphony v2.11.3 upstream test container: %s\n' "${upstream_container_id}"
run_with_timeout 3600 "${docker_cmd[@]}" container start --attach "${upstream_container_id}" ||
  fail "upstream test container failed or exceeded 3600 seconds"
"${docker_cmd[@]}" container rm "${upstream_container_id}" >/dev/null
upstream_container_id=""
if "${docker_cmd[@]}" container inspect "${upstream_container}" >/dev/null 2>&1; then
  fail "upstream test container was not removed"
fi

trap - EXIT
printf 'OpenSymphony v2.11.3 unchanged upstream contract passed: %s (%s)\n' \
  "${image}" "${image_id}"
