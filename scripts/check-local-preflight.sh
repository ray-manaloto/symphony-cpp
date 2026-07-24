#!/usr/bin/env bash
set -euo pipefail

readonly mode="${1:-quick}"
case "${mode}" in
  quick | docker) ;;
  *)
    echo "usage: $0 [quick|docker]" >&2
    exit 64
    ;;
esac

test "$(actionlint -version | head -n 1)" = "1.7.12"
test "$(zizmor --version)" = "zizmor 1.28.0"
test "$(check-jsonschema --version)" = "check-jsonschema, version 0.37.4"
test "$(pre-commit --version)" = "pre-commit 4.6.1"
test "$(
  shellcheck --version |
    sed -n 's/^version: //p'
)" = "0.11.0"

git diff --cached --check
git diff --check
pre-commit validate-config .pre-commit-config.yaml
bash -n scripts/*.sh
shellcheck --severity=warning scripts/*.sh
actionlint -no-color .github/workflows/*.yml
check-jsonschema \
  --builtin-schema vendor.github-workflows \
  .github/workflows/*.yml
check-jsonschema \
  --builtin-schema custom.github-workflows-require-timeout \
  .github/workflows/*.yml
zizmor \
  --offline \
  --strict-collection \
  --persona regular \
  --min-confidence high \
  --format plain \
  --color never \
  .github/workflows/*.yml
node scripts/check-dependency-policy.mjs
./scripts/test-analysis-toolchain-contract.sh
./scripts/test-toolchain-platform-contract.sh

while IFS= read -r json_file; do
  node -e '
    const fs = require("node:fs");
    JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
  ' "${json_file}"
done < <(git ls-files '*.json')

if [[ "${mode}" == "docker" ]]; then
  readonly containerfile=containers/Containerfile
  for target in \
    symphony-gcc-validation \
    symphony-clang-validation \
    symphony-analysis-validation; do
    docker buildx build \
      --file "${containerfile}" \
      --platform linux/amd64 \
      --target "${target}" \
      --call=check \
      .
  done
  docker buildx build \
    --file "${containerfile}" \
    --platform linux/arm64 \
    --target symphony-gcc-validation \
    --call=check \
    .
fi
