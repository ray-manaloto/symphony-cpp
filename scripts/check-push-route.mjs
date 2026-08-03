#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import {
  closeSync,
  constants,
  fstatSync,
  openSync,
  readSync,
} from "node:fs";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

const RECEIPT_KEYS = [
  "base",
  "changedPathCount",
  "findingCount",
  "generatedAt",
  "head",
  "redacted",
  "scannedAddedLineCount",
  "schemaVersion",
];
const RECEIPT_MAX_BYTES = 64 * 1024;
const RECEIPT_MAX_AGE_MS = 15 * 60 * 1000;
const ROUTE_ORDER = [
  "opensymphony-v2113-github-actions",
  "hook-self",
  "documentation",
  "source",
  "devcontainer",
  "container-recipe",
];
export const OPENSYMPHONY_V2113_GHA_BASE =
  "b682ef362494936b38f99468b0e84788cceec17e";
export const OPENSYMPHONY_V2113_GHA_REMOTE_URL =
  "git@github.com:ray-manaloto/symphony-cpp.git";
export const OPENSYMPHONY_V2113_GHA_PATHS = Object.freeze([
  ".github/workflows/opensymphony-v2113-evaluation.yml",
  "containers/OpenSymphony-v2113-evaluation.Containerfile",
  "containers/opensymphony-v2113-evaluation.bake.hcl",
  "docs/dependency-decisions.md",
  "docs/opensymphony-v2113-evaluation-workflow.md",
  "docs/upstream-lock.md",
  "ops/opensymphony/evaluation/v2.11.3/input-manifest-v1.json",
  "scripts/build-opensymphony-v2113-evaluation.sh",
  "scripts/check-push-route.mjs",
  "scripts/opensymphony-v2113-build-input-id.sh",
  "scripts/run-opensymphony-v2113-github-actions.sh",
  "scripts/test-opensymphony-v2113-build.sh",
  "scripts/test-opensymphony-v2113-github-actions.mjs",
  "scripts/test-opensymphony-v2113-upstream.sh",
  "scripts/test-push-route.mjs",
]);
const OPENSYMPHONY_V2113_GHA_LOCAL_REF = "refs/heads/codex/implementation";
const OPENSYMPHONY_V2113_GHA_REMOTE_REF =
  "refs/heads/codex/opensymphony-v2113-gha";
const HOOK_SELF_PATHS = new Set([
  ".codex/hooks.json",
  ".pre-commit-config.yaml",
  "docs/agent-orchestration.md",
  "docs/dependency-decisions.md",
  "docs/toolchain-and-devcontainer-workflow.md",
  "scripts/check-adaptive-orchestration.mjs",
  "scripts/check-goal-routing.sh",
  "scripts/check-local-preflight.sh",
  "scripts/check-push-route.mjs",
  "scripts/codex-lifecycle-hook.mjs",
  "scripts/codex-lifecycle-receipt.py",
  "scripts/test-codex-lifecycle-hook.mjs",
  "scripts/test-codex-lifecycle-receipt.py",
  "scripts/test-goal-routing.sh",
  "scripts/test-push-route.mjs",
  "scripts/test-toolchain-platform-contract.sh",
]);
const CHECKPOINT_PATHS = [
  ".codex/goals/standalone-cpp26-v2.md",
  ".codex/notepads/",
];

export class PushRouteError extends Error {}

function fail(message) {
  throw new PushRouteError(message);
}

function run(repo, command, args, options = {}) {
  const result = spawnSync(command, args, {
    cwd: repo,
    encoding: Object.hasOwn(options, "encoding") ? options.encoding : "utf8",
    env: process.env,
    maxBuffer: 128 * 1024 * 1024,
    stdio: options.stdio ?? "pipe",
  });
  if (result.status !== 0) fail(`${options.label ?? command} failed`);
  return result.stdout;
}

function git(repo, args) {
  return run(repo, "git", args, { label: `git ${args[0]}` }).trim();
}

function gitBuffer(repo, args) {
  return run(repo, "git", args, {
    encoding: null,
    label: `git ${args[0]}`,
  });
}

function objectLength(repo) {
  const format = git(repo, ["rev-parse", "--show-object-format"]);
  if (format === "sha1") return 40;
  if (format === "sha256") return 64;
  fail("unsupported Git object format");
}

function requireString(value, label) {
  if (typeof value !== "string" || value.length === 0) fail(`${label} is missing`);
}

function requireOid(value, length, label) {
  requireString(value, label);
  if (value.length !== length || !/^[0-9a-f]+$/.test(value) || /^0+$/.test(value)) {
    fail(`${label} is not a nonzero object ID`);
  }
}

function repositoryRoot(cwd) {
  return resolve(git(cwd, ["rev-parse", "--show-toplevel"]));
}

function isAncestor(repo, ancestor, descendant) {
  const result = spawnSync("git", ["merge-base", "--is-ancestor", ancestor, descendant], {
    cwd: repo,
    encoding: "utf8",
    env: process.env,
  });
  if (result.status === 0) return true;
  if (result.status === 1) return false;
  fail("git merge-base failed");
}

function isDocumentation(path) {
  return (
    path.startsWith(".codex/") ||
    path.startsWith("docs/") ||
    path.endsWith(".md") ||
    path === "AGENTS.md" ||
    path === "README" ||
    path.startsWith("README.")
  );
}

function isSource(path) {
  return (
    path === ".github/workflows/source-ci.yml" ||
    path === "CMakeLists.txt" ||
    path === "CMakePresets.json" ||
    path === "vcpkg.json" ||
    path === "vcpkg-configuration.json" ||
    path.startsWith("cmake/") ||
    path.startsWith("include/") ||
    path.startsWith("src/") ||
    path.startsWith("tests/") ||
    path.startsWith("vcpkg-ports/") ||
    path.startsWith("triplets/") ||
    path.startsWith("schemas/") ||
    path.startsWith("fixtures/")
  );
}

function isDevcontainer(path) {
  return path.startsWith(".devcontainer/") || path.startsWith("scripts/devcontainer-");
}

function isContainerRecipe(path) {
  return (
    path.startsWith("containers/") ||
    path === "scripts/install-cmake.sh" ||
    path === ".github/workflows/source-ci.yml" ||
    path === ".github/workflows/compiler-matrix.yml" ||
    path === ".github/workflows/opensymphony-image.yml"
  );
}

export function classifyPaths(paths) {
  if (!Array.isArray(paths) || paths.length === 0) fail("push range has no changed paths");
  if (
    paths.length === OPENSYMPHONY_V2113_GHA_PATHS.length &&
    OPENSYMPHONY_V2113_GHA_PATHS.every((path) => paths.includes(path))
  ) {
    return { routes: ["opensymphony-v2113-github-actions"], blocked: [] };
  }
  const routes = new Set();
  const unknown = [];
  for (const path of paths) {
    requireString(path, "changed path");
    let matched = false;
    if (HOOK_SELF_PATHS.has(path)) {
      routes.add("hook-self");
      matched = true;
    }
    if (isDocumentation(path)) {
      routes.add("documentation");
      matched = true;
    }
    if (!HOOK_SELF_PATHS.has(path) && isSource(path)) {
      routes.add("source");
      matched = true;
    }
    if (isDevcontainer(path)) {
      routes.add("devcontainer");
      matched = true;
    }
    if (isContainerRecipe(path)) {
      routes.add("container-recipe");
      matched = true;
    }
    if (!matched) unknown.push(path);
  }
  if (unknown.length !== 0) fail("push range contains an unknown route");

  const routesInOrder = ROUTE_ORDER.filter((route) => routes.has(route));
  const blocked = [];
  if (routes.has("source")) blocked.push("source push awaits the admitted GCC devcontainer route");
  if (routes.has("devcontainer")) {
    blocked.push("devcontainer push awaits its R2 validation route");
  }
  if (routes.has("container-recipe")) {
    blocked.push("container-recipe push awaits affected static-contract routing");
  }
  return { routes: routesInOrder, blocked };
}

function parseChangedPaths(buffer) {
  const fields = buffer.toString("utf8").split("\0");
  if (fields.at(-1) === "") fields.pop();
  const paths = [];
  for (let index = 0; index < fields.length; ) {
    const status = fields[index++];
    if (!/^[ACDMRTUXB][0-9]{0,3}$/.test(status)) fail("Git returned an invalid change status");
    const firstPath = fields[index++];
    requireString(firstPath, "changed path");
    paths.push(firstPath);
    if (status.startsWith("R") || status.startsWith("C")) {
      const secondPath = fields[index++];
      requireString(secondPath, "renamed or copied path");
      paths.push(secondPath);
    }
  }
  return [...new Set(paths)];
}

function changedPaths(repo, base, head) {
  return parseChangedPaths(
    gitBuffer(repo, [
      "diff",
      "--name-status",
      "-z",
      "--find-renames",
      "--diff-filter=ACDMRTUXB",
      base,
      head,
    ]),
  );
}

function assertOnlyCheckpointDrift(repo) {
  const index = spawnSync("git", ["diff", "--cached", "--quiet", "--exit-code"], {
    cwd: repo,
    encoding: "utf8",
    env: process.env,
  });
  if (index.status === 1) fail("index must be clean before publication");
  if (index.status !== 0) fail("git index inspection failed");
  const tracked = gitBuffer(repo, ["diff", "--name-only", "-z", "--no-renames", "HEAD"]);
  const untracked = gitBuffer(repo, ["ls-files", "--others", "--exclude-standard", "-z"]);
  const paths = Buffer.concat([tracked, untracked])
    .toString("utf8")
    .split("\0")
    .filter(Boolean);
  const disallowed = paths.filter(
    (path) =>
      path !== CHECKPOINT_PATHS[0] &&
      !path.startsWith(CHECKPOINT_PATHS[1]),
  );
  if (disallowed.length !== 0) fail("non-checkpoint worktree drift is not publishable");
}

function assertCleanIndex(repo) {
  const index = spawnSync("git", ["diff", "--cached", "--quiet", "--exit-code"], {
    cwd: repo,
    encoding: "utf8",
    env: process.env,
  });
  if (index.status === 1) fail("index must be clean before publication");
  if (index.status !== 0) fail("git index inspection failed");
}

function assertOpenSymphonyV2113GhaPathsClean(repo) {
  assertCleanIndex(repo);
  const tracked = gitBuffer(repo, ["diff", "--name-only", "-z", "--no-renames", "HEAD"]);
  const untracked = gitBuffer(repo, ["ls-files", "--others", "--exclude-standard", "-z"]);
  const dirty = new Set(
    Buffer.concat([tracked, untracked])
      .toString("utf8")
      .split("\0")
      .filter(Boolean),
  );
  const scopedDrift = OPENSYMPHONY_V2113_GHA_PATHS.filter((path) => dirty.has(path));
  if (scopedDrift.length !== 0) {
    fail("the exact #47 GitHub Actions packet must be clean before publication");
  }
}

function receiptPath(repo) {
  return resolve(repo, ".build/publication-receipt.json");
}

function exactKeys(value, keys, label) {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    fail(`${label} must be an object`);
  }
  const actual = Object.keys(value).sort();
  const expected = [...keys].sort();
  if (actual.length !== expected.length || actual.some((key, index) => key !== expected[index])) {
    fail(`${label} has unknown or missing fields`);
  }
}

function readPublicationReceipt(path, dependencies = {}) {
  let descriptor;
  try {
    descriptor = openSync(path, constants.O_RDONLY | constants.O_NOFOLLOW);
  } catch (error) {
    if (error?.code === "ENOENT") fail("exact-HEAD publication receipt is missing");
    fail("publication receipt is not a regular file or cannot be opened safely");
  }

  try {
    dependencies.afterReceiptOpen?.(path);
    const before = fstatSync(descriptor, { bigint: true });
    if (!before.isFile()) fail("publication receipt is not a regular file");
    if ((before.mode & 0o777n) !== 0o600n) {
      fail("publication receipt permissions are not mode 0600");
    }
    if (before.size > BigInt(RECEIPT_MAX_BYTES)) fail("publication receipt is oversized");

    const bytes = Buffer.alloc(RECEIPT_MAX_BYTES + 1);
    let length = 0;
    while (length < bytes.length) {
      const read = readSync(descriptor, bytes, length, bytes.length - length, null);
      if (read === 0) break;
      length += read;
    }
    if (length > RECEIPT_MAX_BYTES) fail("publication receipt is oversized");

    const after = fstatSync(descriptor, { bigint: true });
    for (const field of ["dev", "ino", "mode", "nlink", "size", "mtimeNs", "ctimeNs"]) {
      if (before[field] !== after[field]) {
        fail("publication receipt changed during verification");
      }
    }
    return bytes.subarray(0, length).toString("utf8");
  } finally {
    closeSync(descriptor);
  }
}

export function verifyPublicationReceipt(
  repoInput,
  base,
  head,
  now = Date.now(),
  dependencies = {},
) {
  const repo = repositoryRoot(repoInput);
  const path = receiptPath(repo);
  let receipt;
  try {
    receipt = JSON.parse(readPublicationReceipt(path, dependencies));
  } catch (error) {
    if (error instanceof PushRouteError) throw error;
    fail("publication receipt is malformed");
  }
  exactKeys(receipt, RECEIPT_KEYS, "publication receipt");
  const generatedAt = Date.parse(receipt.generatedAt);
  if (
    receipt.schemaVersion !== 1 ||
    receipt.base !== base ||
    receipt.head !== head ||
    !Number.isSafeInteger(receipt.changedPathCount) ||
    receipt.changedPathCount !== scanChangedPathCount(repo, base, head) ||
    !Number.isSafeInteger(receipt.scannedAddedLineCount) ||
    receipt.scannedAddedLineCount < 0 ||
    receipt.findingCount !== 0 ||
    receipt.redacted !== true ||
    Number.isNaN(generatedAt)
  ) {
    fail("publication receipt is not an exact zero-finding result");
  }
  if (generatedAt > now) fail("publication receipt timestamp is in the future");
  if (now - generatedAt > RECEIPT_MAX_AGE_MS) fail("publication receipt is stale");
  return receipt;
}

function scanChangedPathCount(repo, base, head) {
  const fields = gitBuffer(repo, [
    "diff",
    "--name-only",
    "-z",
    "--find-renames",
    "--diff-filter=ACDMRTUXB",
    base,
    head,
  ])
    .toString("utf8")
    .split("\0")
    .filter(Boolean);
  return fields.length;
}

function configuredUpstream(repo) {
  const localRef = git(repo, ["symbolic-ref", "--quiet", "HEAD"]);
  const branch = localRef.slice("refs/heads/".length);
  const remoteName = git(repo, ["config", "--get", `branch.${branch}.remote`]);
  const remoteRef = git(repo, ["config", "--get", `branch.${branch}.merge`]);
  if (remoteName === "." || !remoteRef.startsWith("refs/heads/")) {
    fail("only a configured remote branch is publishable");
  }
  const pushUrls = git(repo, ["remote", "get-url", "--push", "--all", remoteName])
    .split("\n")
    .filter(Boolean);
  if (pushUrls.length !== 1) fail("exactly one push URL must be configured");
  const remoteBranch = remoteRef.slice("refs/heads/".length);
  const remoteHead = git(repo, [
    "rev-parse",
    "--verify",
    `refs/remotes/${remoteName}/${remoteBranch}^{commit}`,
  ]);
  return {
    localRef,
    remoteName,
    remoteRef,
    pushUrl: pushUrls[0],
    remoteHead,
  };
}

export function buildRouteState(repoInput, baseInput, headInput) {
  const repo = repositoryRoot(repoInput);
  const oidLength = objectLength(repo);
  requireOid(baseInput, oidLength, "push base");
  requireOid(headInput, oidLength, "push head");
  const base = git(repo, ["rev-parse", "--verify", `${baseInput}^{commit}`]);
  const head = git(repo, ["rev-parse", "--verify", `${headInput}^{commit}`]);
  if (base !== baseInput || head !== headInput) fail("push range must use exact commit IDs");
  if (!isAncestor(repo, base, head)) fail("push is not a fast-forward");
  const paths = changedPaths(repo, base, head);
  const plan = classifyPaths(paths);
  return { repo, base, head, paths, ...plan };
}

function isZeroOid(value, length) {
  return value.length === length && new RegExp(`^0{${length}}$`).test(value);
}

function buildOpenSymphonyV2113GhaState(
  repo,
  headInput,
  expectedBase = OPENSYMPHONY_V2113_GHA_BASE,
) {
  const oidLength = objectLength(repo);
  requireOid(expectedBase, oidLength, "#47 GitHub Actions base");
  requireOid(headInput, oidLength, "push head");
  const head = git(repo, ["rev-parse", "--verify", `${headInput}^{commit}`]);
  if (head !== headInput) fail("push head must use an exact commit ID");
  const parents = git(repo, ["rev-list", "--parents", "-n", "1", head]).split(" ");
  if (parents.length !== 2 || parents[1] !== expectedBase) {
    fail("#47 GitHub Actions publication must be one exact commit on the approved base");
  }
  const state = buildRouteState(repo, expectedBase, head);
  if (
    state.routes.length !== 1 ||
    state.routes[0] !== "opensymphony-v2113-github-actions" ||
    state.blocked.length !== 0
  ) {
    fail("push range is not the exact #47 GitHub Actions packet");
  }
  return state;
}

export function verifyHookContext(repoInput, environment = process.env, dependencies = {}) {
  const repo = repositoryRoot(repoInput);
  const oidLength = objectLength(repo);
  const base = environment.PRE_COMMIT_FROM_REF ?? "";
  const head = environment.PRE_COMMIT_TO_REF ?? "";
  const localRef = environment.PRE_COMMIT_LOCAL_BRANCH ?? "";
  const remoteRef = environment.PRE_COMMIT_REMOTE_BRANCH ?? "";
  const remoteName = environment.PRE_COMMIT_REMOTE_NAME ?? "";
  const remoteUrl = environment.PRE_COMMIT_REMOTE_URL ?? "";
  requireOid(head, oidLength, "pre-push head");
  requireString(remoteName, "pre-push remote name");
  requireString(remoteUrl, "pre-push remote URL");
  const upstream = configuredUpstream(repo);
  const currentHead = git(repo, ["rev-parse", "--verify", "HEAD^{commit}"]);
  if (head !== currentHead) {
    fail("pre-push update is not the current checked-out HEAD");
  }
  if (isZeroOid(base, oidLength)) {
    const expectedRemoteUrl =
      dependencies.expectedOpenSymphonyV2113GhaRemoteUrl ??
      OPENSYMPHONY_V2113_GHA_REMOTE_URL;
    if (
      localRef !== OPENSYMPHONY_V2113_GHA_LOCAL_REF ||
      localRef !== upstream.localRef ||
      remoteRef !== OPENSYMPHONY_V2113_GHA_REMOTE_REF ||
      remoteName !== "origin" ||
      remoteName !== upstream.remoteName ||
      remoteUrl !== upstream.pushUrl ||
      remoteUrl !== expectedRemoteUrl
    ) {
      fail("new-branch destination is not the exact #47 GitHub Actions route");
    }
    assertOpenSymphonyV2113GhaPathsClean(repo);
    return buildOpenSymphonyV2113GhaState(
      repo,
      head,
      dependencies.expectedOpenSymphonyV2113GhaBase,
    );
  }
  requireOid(base, oidLength, "pre-push base");
  if (!localRef.startsWith("refs/heads/") || !remoteRef.startsWith("refs/heads/")) {
    fail("only an existing branch update is supported");
  }
  if (localRef !== upstream.localRef) {
    fail("pre-push update is not the current checked-out branch");
  }
  if (
    remoteName !== upstream.remoteName ||
    remoteRef !== upstream.remoteRef ||
    remoteUrl !== upstream.pushUrl ||
    base !== upstream.remoteHead
  ) {
    fail("pre-push update does not match the configured existing upstream");
  }
  assertOnlyCheckpointDrift(repo);
  const state = buildRouteState(repo, base, head);
  if (state.blocked.length !== 0) fail(state.blocked[0]);
  return state;
}

function runOpenSymphonyV2113GhaStaticChecks(repo) {
  run(repo, "node", ["scripts/test-opensymphony-v2113-github-actions.mjs"], {
    label: "#47 GitHub Actions workflow contracts",
    stdio: "inherit",
  });
  run(
    repo,
    "bash",
    [
      "-n",
      "scripts/run-opensymphony-v2113-github-actions.sh",
      "scripts/test-opensymphony-v2113-build.sh",
      "scripts/test-opensymphony-v2113-upstream.sh",
      "scripts/opensymphony-v2113-build-input-id.sh",
    ],
    { label: "#47 shell syntax", stdio: "inherit" },
  );
  run(
    repo,
    "mise",
    [
      "exec",
      "--",
      "shellcheck",
      "scripts/run-opensymphony-v2113-github-actions.sh",
      "scripts/test-opensymphony-v2113-build.sh",
      "scripts/test-opensymphony-v2113-upstream.sh",
      "scripts/opensymphony-v2113-build-input-id.sh",
    ],
    { label: "#47 ShellCheck", stdio: "inherit" },
  );
  const inputId = run(repo, "./scripts/opensymphony-v2113-build-input-id.sh", [], {
    label: "#47 build-input identity",
  }).trim();
  if (!/^[0-9a-f]{64}$/.test(inputId)) fail("#47 build-input identity is invalid");
  run(repo, "node", ["scripts/check-dependency-policy.mjs"], {
    label: "dependency policy",
    stdio: "inherit",
  });
  run(repo, "node", ["scripts/test-push-route.mjs", "--quick"], {
    label: "push-route fixtures",
    stdio: "inherit",
  });
  run(
    repo,
    "mise",
    ["exec", "--", "actionlint", ".github/workflows/opensymphony-v2113-evaluation.yml"],
    { label: "#47 actionlint", stdio: "inherit" },
  );
  for (const schema of [
    "vendor.github-workflows",
    "custom.github-workflows-require-timeout",
  ]) {
    run(
      repo,
      "mise",
      [
        "exec",
        "--",
        "check-jsonschema",
        "--builtin-schema",
        schema,
        ".github/workflows/opensymphony-v2113-evaluation.yml",
      ],
      { label: `#47 ${schema}`, stdio: "inherit" },
    );
  }
  run(
    repo,
    "mise",
    [
      "exec",
      "--",
      "zizmor",
      "--offline",
      "--strict-collection",
      "--persona",
      "regular",
      "--min-confidence",
      "high",
      "--format",
      "plain",
      "--color",
      "never",
      ".github/workflows/opensymphony-v2113-evaluation.yml",
    ],
    { label: "#47 zizmor", stdio: "inherit" },
  );
}

export function prepareOpenSymphonyV2113GitHubActions(
  repoInput = process.cwd(),
  dependencies = {},
) {
  const repo = repositoryRoot(repoInput);
  assertOpenSymphonyV2113GhaPathsClean(repo);
  const upstream = configuredUpstream(repo);
  if (upstream.localRef !== OPENSYMPHONY_V2113_GHA_LOCAL_REF) {
    fail("#47 GitHub Actions publication must originate from codex/implementation");
  }
  const head = git(repo, ["rev-parse", "--verify", "HEAD^{commit}"]);
  const expectedBase =
    dependencies.expectedOpenSymphonyV2113GhaBase ?? OPENSYMPHONY_V2113_GHA_BASE;
  const expectedRemoteUrl =
    dependencies.expectedOpenSymphonyV2113GhaRemoteUrl ?? OPENSYMPHONY_V2113_GHA_REMOTE_URL;
  if (upstream.remoteName !== "origin" || upstream.pushUrl !== expectedRemoteUrl) {
    fail("#47 GitHub Actions publication destination drifted");
  }
  const before = buildOpenSymphonyV2113GhaState(repo, head, expectedBase);
  (dependencies.runStaticChecks ?? runOpenSymphonyV2113GhaStaticChecks)(repo);
  run(
    repo,
    "node",
    ["scripts/check-adaptive-orchestration.mjs", "--publication-scan", before.base, before.head],
    { label: "publication scan", stdio: "inherit" },
  );
  const afterUpstream = configuredUpstream(repo);
  const afterHead = git(repo, ["rev-parse", "--verify", "HEAD^{commit}"]);
  const after = buildOpenSymphonyV2113GhaState(repo, afterHead, expectedBase);
  assertOpenSymphonyV2113GhaPathsClean(repo);
  if (
    before.base !== after.base ||
    before.head !== after.head ||
    upstream.localRef !== afterUpstream.localRef ||
    upstream.remoteName !== afterUpstream.remoteName ||
    upstream.pushUrl !== afterUpstream.pushUrl ||
    JSON.stringify(before.paths) !== JSON.stringify(after.paths)
  ) {
    fail("#47 GitHub Actions push range changed during receipt preparation");
  }
  verifyPublicationReceipt(repo, after.base, after.head);
  process.stdout.write(`exact #47 GitHub Actions receipt prepared: ${after.head}\n`);
  return after;
}

export function preparePush(repoInput = process.cwd()) {
  const repo = repositoryRoot(repoInput);
  assertOnlyCheckpointDrift(repo);
  const beforeUpstream = configuredUpstream(repo);
  const base = beforeUpstream.remoteHead;
  const head = git(repo, ["rev-parse", "--verify", "HEAD^{commit}"]);
  const before = buildRouteState(repo, base, head);
  if (before.blocked.length !== 0) fail(before.blocked[0]);
  run(repo, "./scripts/check-local-preflight.sh", ["quick"], {
    label: "quick preflight",
    stdio: "inherit",
  });
  run(
    repo,
    "node",
    ["scripts/check-adaptive-orchestration.mjs", "--publication-scan", base, head],
    { label: "publication scan", stdio: "inherit" },
  );
  const afterUpstream = configuredUpstream(repo);
  const afterBase = afterUpstream.remoteHead;
  const afterHead = git(repo, ["rev-parse", "--verify", "HEAD^{commit}"]);
  if (
    base !== afterBase ||
    head !== afterHead ||
    beforeUpstream.localRef !== afterUpstream.localRef ||
    beforeUpstream.remoteName !== afterUpstream.remoteName ||
    beforeUpstream.remoteRef !== afterUpstream.remoteRef ||
    beforeUpstream.pushUrl !== afterUpstream.pushUrl
  ) {
    fail("push range changed during receipt preparation");
  }
  const after = buildRouteState(repo, afterBase, afterHead);
  assertOnlyCheckpointDrift(repo);
  if (
    before.base !== after.base ||
    before.head !== after.head ||
    JSON.stringify(before.routes) !== JSON.stringify(after.routes)
  ) {
    fail("push range changed during receipt preparation");
  }
  verifyPublicationReceipt(repo, base, head);
  process.stdout.write(`exact-HEAD receipt prepared: ${head}\n`);
  return after;
}

export function verifyPrePush(
  repoInput = process.cwd(),
  environment = process.env,
  dependencies = {},
) {
  const before = verifyHookContext(repoInput, environment, dependencies);
  verifyPublicationReceipt(
    before.repo,
    before.base,
    before.head,
    dependencies.now?.() ?? Date.now(),
    dependencies.firstReceipt,
  );
  dependencies.afterFirstReceipt?.();
  const after = verifyHookContext(before.repo, environment, dependencies);
  if (before.base !== after.base || before.head !== after.head) {
    fail("push range changed during receipt verification");
  }
  verifyPublicationReceipt(
    after.repo,
    after.base,
    after.head,
    dependencies.now?.() ?? Date.now(),
    dependencies.secondReceipt,
  );
  return after;
}

function runPrePush() {
  const state = verifyPrePush();
  process.stdout.write(`exact-HEAD receipt verified: ${state.routes.join(",")}\n`);
}

function main() {
  const [, , operation, ...args] = process.argv;
  if (operation === "prepare" && args.length === 0) {
    preparePush();
    return;
  }
  if (operation === "prepare-opensymphony-v2113-github-actions" && args.length === 0) {
    prepareOpenSymphonyV2113GitHubActions();
    return;
  }
  if (operation === "pre-push" && args.length === 0) {
    runPrePush();
    return;
  }
  if (operation === "classify" && args.length === 2) {
    const state = buildRouteState(process.cwd(), args[0], args[1]);
    if (state.blocked.length !== 0) fail(state.blocked[0]);
    process.stdout.write(`${state.routes.join(",")}\n`);
    return;
  }
  fail(
    "usage: check-push-route.mjs prepare | prepare-opensymphony-v2113-github-actions | pre-push | classify BASE HEAD",
  );
}

if (process.argv[1] && pathToFileURL(resolve(process.argv[1])).href === import.meta.url) {
  try {
    main();
  } catch (error) {
    const message = error instanceof PushRouteError ? error.message : "unexpected push-route failure";
    process.stderr.write(`push route rejected: ${message}\n`);
    process.exit(1);
  }
}
