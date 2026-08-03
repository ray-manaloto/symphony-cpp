#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly repo_root
readonly -a input_paths=(
  .github/workflows/opensymphony-v2113-evaluation.yml
  containers/OpenSymphony-v2113-evaluation.Containerfile
  containers/opensymphony-v2113-evaluation.bake.hcl
  ops/opensymphony/evaluation/v2.11.3/input-manifest-v1.json
  scripts/build-opensymphony-v2113-evaluation.sh
  scripts/opensymphony-v2113-build-input-id.sh
  scripts/run-opensymphony-v2113-github-actions.sh
  scripts/test-opensymphony-v2113-build.sh
  scripts/test-opensymphony-v2113-github-actions.mjs
  scripts/test-opensymphony-v2113-upstream.sh
)

(
  cd "${repo_root}"
  printf 'opensymphony-v2113-evaluation-build-input-v2\0'
  for input_path in "${input_paths[@]}"; do
    test -f "${input_path}"
    input_mode="$(stat -f '%Lp' "${input_path}")"
    input_sha256="$(shasum -a 256 "${input_path}" | awk '{print $1}')"
    printf '%s\0%s\0%s\n' "${input_path}" "${input_mode}" "${input_sha256}"
  done
) | shasum -a 256 | awk '{print $1}'
