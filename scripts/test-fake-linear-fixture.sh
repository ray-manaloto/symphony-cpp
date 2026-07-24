#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_root="$(mktemp -d /tmp/symphony-fake-linear-test.XXXXXX)"
audit_log="${fixture_root}/audit.jsonl"
server_log="${fixture_root}/server.log"
port=$((18000 + $$ % 1000))
server_pid=""

stop_server() {
  if [[ -n "${server_pid}" ]]; then
    kill "${server_pid}" >/dev/null 2>&1 || true
    wait "${server_pid}" >/dev/null 2>&1 || true
    server_pid=""
  fi
}

start_server() {
  local mode="$1"
  : >"${audit_log}"
  : >"${server_log}"
  FIXTURE_LINEAR_AUDIT_LOG="${audit_log}" \
    FIXTURE_LINEAR_MODE="${mode}" \
    FIXTURE_LINEAR_PORT="${port}" \
    python3 "${repo_root}/ops/opensymphony/fixtures/fake-linear.py" \
    >"${server_log}" 2>&1 &
  server_pid=$!

  local health=""
  for _ in $(seq 1 30); do
    if health="$(curl --fail --silent --show-error "http://127.0.0.1:${port}/health" 2>/dev/null)"; then
      break
    fi
    sleep 0.1
  done
  printf '%s\n' "${health}" | grep -Fq '"status":"ok"'
}

cleanup() {
  result=$?
  trap - EXIT
  stop_server
  rm -- \
    "${audit_log}" \
    "${server_log}" \
    "${fixture_root}/mutation.json" \
    "${fixture_root}/rejected.json" \
    "${fixture_root}/unauthorized.json" \
    "${fixture_root}/wrong-path.json" \
    2>/dev/null || true
  rmdir -- "${fixture_root}" 2>/dev/null || true
  exit "${result}"
}
trap cleanup EXIT

start_server active

active_response="$(
  curl --fail --silent --show-error \
    --header "authorization: fixture-key" \
    --header "content-type: application/json" \
    --data '{"query":"query IssuesByState { issues { nodes { id } } }","variables":{"stateNames":["In Progress"]}}' \
    "http://127.0.0.1:${port}/graphql"
)"
printf '%s\n' "${active_response}" | grep -Fq '"identifier":"FIX-901"'

for mutation_query in \
  'mutation IssueArchive { issueArchive(id:"fixture") { success } }' \
  $'mutation\nIssueArchive { issueArchive(id:"fixture") { success } }' \
  $'mutation\tIssueArchive { issueArchive(id:"fixture") { success } }' \
  'mutation{ issueArchive(id:"fixture") { success } }'; do
  mutation_status="$(
    curl --silent --show-error \
      --output "${fixture_root}/mutation.json" \
      --write-out '%{http_code}' \
      --header "authorization: fixture-key" \
      --header "content-type: application/json" \
      --data "$(printf '{"query":%s,"variables":{}}' \
        "$(python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' <<<"${mutation_query}")")" \
      "http://127.0.0.1:${port}/graphql"
  )"
  test "${mutation_status}" = "409"
  grep -Fq 'fixture rejects tracker mutation' "${fixture_root}/mutation.json"
done
grep -Fq '"operation": "IssueArchive"' "${audit_log}"
grep -Fq '"mutation": true' "${audit_log}"

for rejected_query in \
  'query UnknownOperation { viewer { id } }' \
  'subscription Updates { issue { id } }' \
  '{"extensions":{"persistedQuery":{"version":1}}}' \
  '{"query":7}'; do
  if [[ "${rejected_query}" == \{* ]]; then
    rejected_body="${rejected_query}"
  else
    rejected_body="$(printf '{"query":%s}' \
      "$(python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' <<<"${rejected_query}")")"
  fi
  rejected_status="$(
    curl --silent --show-error \
      --output "${fixture_root}/rejected.json" \
      --write-out '%{http_code}' \
      --header "authorization: fixture-key" \
      --header "content-type: application/json" \
      --data "${rejected_body}" \
      "http://127.0.0.1:${port}/graphql"
  )"
  test "${rejected_status}" = "422"
  grep -Fq 'fixture rejects unknown operation' "${fixture_root}/rejected.json"
done

unauthorized_status="$(
  curl --silent --show-error \
    --output "${fixture_root}/unauthorized.json" \
    --write-out '%{http_code}' \
    --header "content-type: application/json" \
    --data '{"query":"query IssuesByState { issues { nodes { id } } }","variables":{}}' \
    "http://127.0.0.1:${port}/graphql"
)"
test "${unauthorized_status}" = "401"

wrong_path_status="$(
  curl --silent --show-error \
    --output "${fixture_root}/wrong-path.json" \
    --write-out '%{http_code}' \
    --header "authorization: fixture-key" \
    --header "content-type: application/json" \
    --data '{"query":"query IssuesByState { issues { nodes { id } } }","variables":{}}' \
    "http://127.0.0.1:${port}/wrong"
)"
test "${wrong_path_status}" = "404"

stop_server
start_server terminal

terminal_response="$(
  curl --fail --silent --show-error \
    --header "authorization: fixture-key" \
    --header "content-type: application/json" \
    --data '{"query":"query IssuesByState { issues { nodes { id identifier state { name type } } } }","variables":{"stateNames":["Done"]}}' \
    "http://127.0.0.1:${port}/graphql"
)"
printf '%s\n' "${terminal_response}" | grep -Fq '"identifier":"FIX-901"'
printf '%s\n' "${terminal_response}" | grep -Fq '"name":"Done","type":"completed"'

terminal_active_response="$(
  curl --fail --silent --show-error \
    --header "authorization: fixture-key" \
    --header "content-type: application/json" \
    --data '{"query":"query IssuesByState { issues { nodes { id } } }","variables":{"stateNames":["In Progress"]}}' \
    "http://127.0.0.1:${port}/graphql"
)"
printf '%s\n' "${terminal_active_response}" | grep -Fq '"nodes":[]'
if printf '%s\n' "${terminal_active_response}" | grep -Fq '"identifier":"FIX-901"'; then
  echo "terminal fixture returned an active issue" >&2
  exit 1
fi

terminal_state_response="$(
  curl --fail --silent --show-error \
    --header "authorization: fixture-key" \
    --header "content-type: application/json" \
    --data '{"query":"query IssueStatesByIds { issues { nodes { id identifier updatedAt state { id name type } } } }","variables":{"issueIds":["fixture-issue-901"]}}' \
    "http://127.0.0.1:${port}/graphql"
)"
printf '%s\n' "${terminal_state_response}" | grep -Fq '"identifier":"FIX-901"'
printf '%s\n' "${terminal_state_response}" | grep -Fq '"name":"Done","type":"completed"'
if grep -Fq '"mutation": true' "${audit_log}"; then
  echo "terminal fake Linear fixture recorded a mutation" >&2
  exit 1
fi

echo "fake Linear fixture tests passed"
