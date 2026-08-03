#!/usr/bin/env node

import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const workflowPath = ".github/workflows/opensymphony-v2113-evaluation.yml";
const runnerPath = "scripts/run-opensymphony-v2113-github-actions.sh";
const expectedPaths = [
  workflowPath,
  "containers/OpenSymphony-v2113-evaluation.Containerfile",
  "containers/opensymphony-v2113-evaluation.bake.hcl",
  "docs/dependency-decisions.md",
  "docs/opensymphony-v2113-evaluation-workflow.md",
  "docs/upstream-lock.md",
  "ops/opensymphony/evaluation/v2.11.3/input-manifest-v1.json",
  "scripts/build-opensymphony-v2113-evaluation.sh",
  "scripts/check-push-route.mjs",
  "scripts/opensymphony-v2113-build-input-id.sh",
  runnerPath,
  "scripts/test-opensymphony-v2113-build.sh",
  "scripts/test-opensymphony-v2113-github-actions.mjs",
  "scripts/test-opensymphony-v2113-upstream.sh",
  "scripts/test-push-route.mjs",
];
const checkoutPin = "actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1";
const setupBuildxPin =
  "docker/setup-buildx-action@bb05f3f5519dd87d3ba754cc423b652a5edd6d2c";
const uploadPin =
  "actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02";
const buildkitManifest =
  "sha256:2caaaf9bc673a82d5b0a87824f8375e6b2b36b55001dad611230516c724e9fba";

function fail(message) {
  throw new Error(message);
}

function requireOnce(source, needle, label = needle) {
  const count = source.split(needle).length - 1;
  if (count !== 1) fail(`${label} must appear exactly once, found ${count}`);
}

function requireInOrder(source, needles) {
  let position = -1;
  for (const needle of needles) {
    const next = source.indexOf(needle, position + 1);
    if (next === -1) fail(`missing ordered contract: ${needle}`);
    if (next <= position) fail(`out-of-order contract: ${needle}`);
    position = next;
  }
}

function extractPushPaths(workflow) {
  const match = workflow.match(
    /^    paths:\n(?<paths>(?:      - [^\n]+\n)+)  workflow_dispatch:\s*$/m,
  );
  if (!match?.groups?.paths) fail("workflow lacks the exact push path block");
  return match.groups.paths
    .trimEnd()
    .split("\n")
    .map((line) => line.replace(/^      - /, ""));
}

function validateWorkflow(workflow) {
  for (const token of [
    "name: OpenSymphony v2.11.3 stock evaluation image",
    "on:\n  push:\n    branches:\n      - codex/opensymphony-v2113-gha",
    "  workflow_dispatch:",
    "permissions:\n  contents: read",
    "runs-on: ubuntu-24.04",
    "timeout-minutes: 360",
    "persist-credentials: false",
    checkoutPin,
    setupBuildxPin,
    uploadPin,
    "version: v0.35.0",
    "name: symphony-osv2113-019fc0ca-ticket47-builder",
    `image=moby/buildkit@${buildkitManifest}`,
    "cleanup: true",
    "OPENSYMPHONY_IMAGE: symphony-opensymphony:osv2113-019fc0ca-ticket47",
    "OPENSYMPHONY_EXECUTION_PROFILE: github-actions-native-amd64",
    "opensymphony-v2113-ticket47-${{ github.sha }}",
    "retention-days: 1",
    "compression-level: 0",
    "if-no-files-found: error",
    "overwrite: false",
    "include-hidden-files: false",
    "if: ${{ always() }}",
    "Prove fresh runner Docker collision boundary",
    `${runnerPath} preflight`,
  ]) {
    if (!workflow.includes(token)) fail(`workflow omitted ${token}`);
  }

  for (const pin of [checkoutPin, setupBuildxPin, uploadPin]) {
    requireOnce(workflow, `uses: ${pin}`, `uses pin ${pin}`);
  }
  assert.deepEqual(extractPushPaths(workflow), expectedPaths);
  assert.equal(
    (workflow.match(/^jobs:\n(?:.|\n)*?^  [a-z0-9-]+:\s*$/gm) ?? []).length,
    1,
    "workflow must define exactly one job",
  );
  assert.match(
    workflow,
    /test "\$\(dpkg --print-architecture\)" = amd64\n\s+test "\$\(uname -m\)" = x86_64/,
  );
  if (/^\s+install:/m.test(workflow)) {
    fail("workflow configures unsupported setup-buildx input install");
  }
  requireInOrder(workflow, [
    "Verify native x64 runner and private Docker boundary",
    'test "$(dpkg --print-architecture)" = amd64',
    'test "$(uname -m)" = x86_64',
    "Reclaim ephemeral runner disk",
    "Prove fresh runner Docker collision boundary",
    setupBuildxPin,
    "Build, test, export, and clean the stock image",
    runnerPath,
    uploadPin,
    "Prove runner-local cleanup on every exit",
  ]);

  const permissions = workflow.match(/^permissions:\n(?<body>(?:  [^\n]+\n)+)/m)?.groups?.body;
  assert.equal(permissions, "  contents: read\n", "workflow permissions must be contents-read only");
  for (const [pattern, label] of [
    [/\$\{\{\s*secrets\./i, "secret context"],
    [/GITHUB_TOKEN/i, "GitHub token"],
    [/^\s*packages:/m, "packages permission"],
    [/^\s*id-token:/m, "OIDC permission"],
    [/^\s*attestations:/m, "attestation permission"],
    [/docker\/login-action|\bdocker\s+login\b/i, "registry login"],
    [/\bdocker\s+push\b|\bbuildx\s+imagetools\s+create\b/i, "image publication"],
    [/\bgh\s+(api|workflow|run)\b/i, "GitHub client"],
    [/\bopensymphony\s+(run|tui)\b/i, "OpenSymphony service or TUI launch"],
    [/\bcodex\s+app-server\b/i, "Codex app-server launch"],
    [/\bworkflow_run\s*:/i, "ambient workflow chaining"],
    [/\bpull_request(?:_target)?\s*:/i, "pull-request trigger"],
  ]) {
    if (pattern.test(workflow)) fail(`workflow exposes prohibited ${label}`);
  }
}

function validateRunner(runner) {
  for (const token of [
    "set -euo pipefail",
    "require_lower_git_oid() {",
    "require_lower_sha256() {",
    'require_lower_git_oid "${OPENSYMPHONY_GITHUB_SHA}" "github.sha"',
    'readonly expected_profile="github-actions-native-amd64"',
    'readonly expected_image="symphony-opensymphony:osv2113-019fc0ca-ticket47"',
    'readonly expected_builder="symphony-osv2113-019fc0ca-ticket47-builder"',
    'readonly expected_buildkit_manifest="sha256:2caaaf9bc673a82d5b0a87824f8375e6b2b36b55001dad611230516c724e9fba"',
    'test "$(dpkg --print-architecture)" = amd64',
    'test "$(uname -m)" = x86_64',
    "scripts/opensymphony-v2113-build-input-id.sh",
    "containers/opensymphony-v2113-evaluation.bake.hcl",
    "scripts/test-opensymphony-v2113-upstream.sh",
    "scripts/test-opensymphony-v2113-build.sh",
    "docker buildx bake",
    "--builder \"${expected_builder}\"",
    "--progress=plain",
    "--kill-after=10s 3600",
    "docker image save",
    "--sort=name",
    "--mtime=@0",
    "--owner=0",
    "--group=0",
    "--numeric-owner",
    "gzip -n -9",
    "archiveSha256",
    "buildInputSha256",
    "imageId",
    "workflowRef",
    "workflowSha256",
    "githubRef",
    "githubSha",
    "githubRunId",
    "githubRunAttempt",
    "binarySha256",
    "schemaSha256",
    "opensymphonyBinarySha256",
    "codexBinarySha256",
    "versionsSha256",
    "artifactAction",
    "residualUncertainty",
    "cleanup",
    "trap cleanup_for_trap EXIT",
    "docker buildx rm",
    "docker image rm",
    "remove_task_buildkit_image_if_present",
    "verify_builder_ownership",
    "remove_runner_artifact_dir",
    "buildkitImage: absent",
    "\npreflight() {",
    "ownedResourceCount",
  ]) {
    if (!runner.includes(token)) fail(`runner omitted ${token}`);
  }
  requireInOrder(runner, [
    "verify_host_boundary",
    "docker buildx bake",
    "scripts/test-opensymphony-v2113-upstream.sh",
    "scripts/test-opensymphony-v2113-build.sh",
    "docker image save",
    "cleanup_owned_resources",
    "prove_zero_owned_resources",
    "write_transfer_manifest",
  ]);
  for (const [pattern, label] of [
    [/\bdocker\s+login\b/i, "registry login"],
    [/\bdocker\s+push\b|\bbuildx\s+imagetools\s+create\b/i, "image publication"],
    [/\bdocker\s+run\b/i, "unbounded run command"],
    [/\bopensymphony\s+(run|tui)\b/i, "OpenSymphony service or TUI launch"],
    [/\bcodex\s+app-server(?!\s+--help)/i, "Codex app-server service launch"],
    [/GITHUB_TOKEN|\$\{[^}]*TOKEN/i, "credential input"],
    [/--privileged|--network\s+(host|bridge)/i, "privileged or task-network surface"],
  ]) {
    if (pattern.test(runner)) fail(`runner exposes prohibited ${label}`);
  }
}

const workflow = readFileSync(resolve(root, workflowPath), "utf8");
const runner = readFileSync(resolve(root, runnerPath), "utf8");
const inputId = readFileSync(
  resolve(root, "scripts/opensymphony-v2113-build-input-id.sh"),
  "utf8",
);
const inputManifest = JSON.parse(
  readFileSync(
    resolve(root, "ops/opensymphony/evaluation/v2.11.3/input-manifest-v1.json"),
    "utf8",
  ),
);
const upstreamContract = readFileSync(
  resolve(root, "scripts/test-opensymphony-v2113-upstream.sh"),
  "utf8",
);
const buildContract = readFileSync(
  resolve(root, "scripts/test-opensymphony-v2113-build.sh"),
  "utf8",
);
validateWorkflow(workflow);
validateRunner(runner);

const validGitOid = "e7f2bf480c79d8c1c5d6b81e3c474b576250fc55";
const runGitOidValidation = (value) =>
  spawnSync(
    "bash",
    [
      "-c",
      'source "$1"; require_lower_git_oid "$2" "github.sha"',
      "opensymphony-v2113-git-oid-contract",
      resolve(root, runnerPath),
      value,
    ],
    { encoding: "utf8" },
  );

assert.equal(
  runGitOidValidation(validGitOid).status,
  0,
  "exactly 40 lowercase hexadecimal characters must be accepted as a Git OID",
);
for (const [name, value] of [
  ["39-character Git OID", "a".repeat(39)],
  ["41-character Git OID", "a".repeat(41)],
  ["64-character SHA-256", "a".repeat(64)],
  ["uppercase Git OID", "A".repeat(40)],
  ["non-hexadecimal Git OID", "g".repeat(40)],
]) {
  assert.notEqual(
    runGitOidValidation(value).status,
    0,
    `${name} must be rejected by the executable Git OID validator`,
  );
}
for (const path of [workflowPath, runnerPath, "scripts/test-opensymphony-v2113-github-actions.mjs"]) {
  assert.ok(inputId.includes(path), `build-input identity omitted ${path}`);
}
assert.ok(
  inputId.includes("opensymphony-v2113-evaluation-build-input-v2\\0"),
  "native workflow input identity must use the v2 domain",
);
assert.equal(inputManifest.buildkit.platform, "linux/amd64");
assert.equal(inputManifest.buildkit.manifest, buildkitManifest);
assert.deepEqual(inputManifest.githubActions.runner, {
  label: "ubuntu-24.04",
  os: "linux",
  architecture: "amd64",
  machine: "x86_64",
});
assert.equal(inputManifest.githubActions.checkout.commit, checkoutPin.split("@")[1]);
assert.equal(inputManifest.githubActions.setupBuildx.commit, setupBuildxPin.split("@")[1]);
assert.equal(inputManifest.githubActions.uploadArtifact.commit, uploadPin.split("@")[1]);
assert.equal(inputManifest.githubActions.uploadArtifact.retentionDays, 1);
for (const [name, contract] of [
  ["upstream", upstreamContract],
  ["build", buildContract],
]) {
  for (const token of [
    "OPENSYMPHONY_EXECUTION_PROFILE",
    "github-actions-native-amd64",
    "GITHUB_ACTIONS",
    "DOCKER_CONFIG",
    "DOCKER_HOST",
    "dpkg --print-architecture",
    "uname -m",
    "stat -c '%a'",
    'has("credsStore") | not',
    'has("credHelpers") | not',
  ]) {
    assert.ok(contract.includes(token), `${name} contract omitted native runner token ${token}`);
  }
}
assert.ok(upstreamContract.includes('grep -Fxq "task-added xfails: none"'));
assert.ok(upstreamContract.includes('grep -Fxq "task-added skips: none"'));
assert.ok(buildContract.includes(buildkitManifest));
assert.ok(!buildContract.includes("manifest.buildkit.platform, \"linux/arm64\""));

const workflowMutations = [
  ["branch", "codex/opensymphony-v2113-gha", "main"],
  ["permissions", "contents: read", "contents: write"],
  ["runner", "runs-on: ubuntu-24.04", "runs-on: ubuntu-latest"],
  ["checkout", checkoutPin, "actions/checkout@main"],
  ["buildx action", setupBuildxPin, "docker/setup-buildx-action@v4"],
  ["Buildx version", "version: v0.35.0", "version: latest"],
  ["BuildKit child", buildkitManifest, "sha256:" + "0".repeat(64)],
  ["upload action", `uses: ${uploadPin}`, "uses: actions/upload-artifact@v4"],
  ["retention", "retention-days: 1", "retention-days: 90"],
  ["cleanup", "if: ${{ always() }}", "if: ${{ success() }}"],
];
for (const [name, before, after] of workflowMutations) {
  assert.notEqual(before, after);
  assert.throws(() => validateWorkflow(workflow.replace(before, after)), undefined, name);
}
for (const path of expectedPaths) {
  const line = `      - ${path}\n`;
  assert.throws(
    () => validateWorkflow(workflow.replace(line, "")),
    undefined,
    `missing path ${path}`,
  );
}
assert.throws(
  () => validateWorkflow(workflow.replace("  workflow_dispatch:", "  pull_request:")),
  undefined,
  "hostile trigger",
);
assert.throws(
  () =>
    validateWorkflow(
      workflow.replace("          cleanup: true", "          install: false\n          cleanup: true"),
    ),
  undefined,
  "unsupported setup-buildx install input",
);
const runnerMutations = [
  ["nondeterministic archive", "--mtime=@0", "--mtime=now"],
  ["builder cleanup", "docker buildx rm", "docker buildx inspect"],
  ["BuildKit image cleanup", "remove_task_buildkit_image_if_present", "retain_buildkit_image"],
  ["build timeout", "--kill-after=10s 3600", "--kill-after=10s 7200"],
  ["binary receipt", "opensymphonyBinarySha256", "omittedOpenSymphonyDigest"],
  ["collision preflight", "\npreflight() {", "\nunchecked_preflight() {"],
  ["builder ownership", "verify_builder_ownership", "unchecked_builder_ownership"],
  ["runner artifact cleanup", "remove_runner_artifact_dir", "retain_runner_artifact_dir"],
];
for (const [name, before, after] of runnerMutations) {
  assert.throws(() => validateRunner(runner.replaceAll(before, after)), undefined, name);
}
assert.throws(
  () =>
    validateRunner(
      runner.replace(
        'require_lower_git_oid "${OPENSYMPHONY_GITHUB_SHA}" "github.sha"',
        'require_lower_sha256 "${OPENSYMPHONY_GITHUB_SHA}" "github.sha"',
      ),
    ),
  undefined,
  "GitHub SHA routed through the SHA-256 validator",
);

process.stdout.write(
  `OpenSymphony v2.11.3 GitHub Actions contracts passed: ${workflowMutations.length + expectedPaths.length + runnerMutations.length + 1} prior hostile mutations plus 7 correction hostile mutations rejected\n`,
);
