#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $0 JOB_NAME COMMAND [ARG ...]" >&2
  exit 64
fi

job_name=$1
shift

if docker container inspect "$job_name" >/dev/null 2>&1; then
  state=$(docker container inspect "$job_name" --format '{{.State.Status}}')
  if [[ "$state" == "running" ]]; then
    echo "$job_name is already running" >&2
    exit 75
  fi
  docker container rm "$job_name" >/dev/null
fi

docker run --detach --name "$job_name" \
  --volume "$PWD:/workspace" \
  --workdir /workspace \
  ghcr.io/openai/codex-universal@sha256:1641c7bc30b00e0c5d4858b3e4da750123e9802fdb8086e9baa5afa2bc99393c \
  "$@"

echo "started $job_name; inspect with: docker container inspect $job_name"

