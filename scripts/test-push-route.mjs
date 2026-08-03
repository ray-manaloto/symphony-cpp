#!/usr/bin/env node

import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import {
  chmodSync,
  copyFileSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  renameSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import { dirname, join, resolve } from "node:path";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";
import { performance } from "node:perf_hooks";
import {
  PushRouteError,
  OPENSYMPHONY_V2113_GHA_BASE,
  OPENSYMPHONY_V2113_GHA_PATHS,
  OPENSYMPHONY_V2113_GHA_REMOTE_URL,
  buildRouteState,
  classifyPaths,
  prepareOpenSymphonyV2113GitHubActions,
  preparePush,
  verifyPrePush,
  verifyHookContext,
  verifyPublicationReceipt,
} from "./check-push-route.mjs";

const expectedOpenSymphonyV2113GhaPaths = [
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
];

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const fixtureRoot = mkdtempSync(join(tmpdir(), "symphony-push-route-"));
process.on("exit", () => rmSync(fixtureRoot, { recursive: true, force: true }));

function command(cwd, executable, args, options = {}) {
  return execFileSync(executable, args, {
    cwd,
    encoding: "utf8",
    env: options.env ?? process.env,
    stdio: options.stdio ?? "pipe",
  }).trim();
}

function git(cwd, ...args) {
  return command(cwd, "git", args);
}

const preCommitExecutable = command(resolve(scriptDirectory, ".."), "mise", [
  "which",
  "pre-commit",
]);

function write(path, value, mode) {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, value, mode === undefined ? {} : { mode });
}

function initializeFixture(name) {
  const root = join(fixtureRoot, name);
  const repo = join(root, "repo");
  const remote = join(root, "remote.git");
  mkdirSync(repo, { recursive: true });
  git(root, "init", "--bare", remote);
  git(repo, "init", "-b", "codex/implementation");
  git(repo, "config", "user.name", "fixture");
  git(repo, "config", "user.email", "fixture@example.invalid");
  git(repo, "config", "core.hooksPath", "/dev/null");
  mkdirSync(join(repo, "scripts"), { recursive: true });
  copyFileSync(
    resolve(scriptDirectory, "check-push-route.mjs"),
    join(repo, "scripts/check-push-route.mjs"),
  );
  copyFileSync(
    resolve(scriptDirectory, "check-adaptive-orchestration.mjs"),
    join(repo, "scripts/check-adaptive-orchestration.mjs"),
  );
  write(
    join(repo, "scripts/check-local-preflight.sh"),
    "#!/usr/bin/env bash\nset -euo pipefail\ntest \"${1:-}\" = quick\n",
    0o755,
  );
  write(join(repo, ".gitignore"), ".build/\n");
  write(
    join(repo, ".pre-commit-config.yaml"),
    `minimum_pre_commit_version: 4.6.0
repos:
  - repo: local
    hooks:
      - id: symphony-push-route
        name: symphony push route
        entry: node scripts/check-push-route.mjs pre-push
        language: system
        pass_filenames: false
        always_run: true
        stages: [pre-push]
`,
  );
  write(join(repo, "docs/base.md"), "# base\n");
  git(repo, "add", ".");
  git(repo, "commit", "-m", "fixture base");
  git(repo, "remote", "add", "origin", remote);
  git(repo, "push", "-u", "origin", "refs/heads/codex/implementation");
  git(repo, "config", "--unset", "core.hooksPath");
  command(repo, preCommitExecutable, ["install", "--hook-type", "pre-push"]);
  return { repo, remote };
}

function commitPath(repo, path, contents) {
  write(join(repo, path), contents);
  git(repo, "add", "--", path);
  git(repo, "commit", "-m", `change ${path}`);
}

function hookEnvironment(repo, base, overrides = {}) {
  return {
    PRE_COMMIT_FROM_REF: base,
    PRE_COMMIT_TO_REF: git(repo, "rev-parse", "HEAD"),
    PRE_COMMIT_LOCAL_BRANCH: "refs/heads/codex/implementation",
    PRE_COMMIT_REMOTE_BRANCH: "refs/heads/codex/implementation",
    PRE_COMMIT_REMOTE_NAME: "origin",
    PRE_COMMIT_REMOTE_URL: git(repo, "remote", "get-url", "--push", "origin"),
    ...overrides,
  };
}

function commitOpenSymphonyV2113GhaPacket(repo) {
  for (const path of expectedOpenSymphonyV2113GhaPaths) {
    const absolute = join(repo, path);
    if (path === "scripts/check-push-route.mjs") {
      write(absolute, `${readFileSync(absolute, "utf8")}\n// exact #47 fixture delta\n`, 0o755);
    } else {
      write(absolute, `# exact #47 fixture: ${path}\n`, path.endsWith(".sh") ? 0o755 : undefined);
    }
  }
  git(repo, "add", "--", ...expectedOpenSymphonyV2113GhaPaths);
  git(repo, "commit", "-m", "exact #47 native workflow packet");
}

assert.deepEqual(classifyPaths(["docs/readme.md"]).routes, ["documentation"]);
assert.deepEqual(classifyPaths(["scripts/check-push-route.mjs"]).routes, ["hook-self"]);
assert.deepEqual(classifyPaths([".codex/hooks.json"]).routes, [
  "hook-self",
  "documentation",
]);
assert.deepEqual(classifyPaths([".github/workflows/source-ci.yml"]).routes, [
  "source",
  "container-recipe",
]);
assert.deepEqual(
  classifyPaths(["scripts/codex-lifecycle-hook.mjs"]).routes,
  ["hook-self"],
);
assert.deepEqual(
  classifyPaths(["scripts/test-codex-lifecycle-hook.mjs"]).routes,
  ["hook-self"],
);
assert.deepEqual(
  classifyPaths(["scripts/codex-lifecycle-receipt.py"]).routes,
  ["hook-self"],
);
assert.deepEqual(
  classifyPaths(["scripts/test-codex-lifecycle-receipt.py"]).routes,
  ["hook-self"],
);
assert.deepEqual(
  classifyPaths(["docs/readme.md", "scripts/check-push-route.mjs"]).routes,
  ["hook-self", "documentation"],
);
assert.match(classifyPaths(["src/main.cpp"]).blocked[0], /GCC devcontainer/);
assert.match(classifyPaths([".devcontainer/devcontainer.json"]).blocked[0], /R2/);
assert.match(classifyPaths(["containers/Containerfile"]).blocked[0], /static-contract/);
assert.throws(() => classifyPaths(["unknown.bin"]), /unknown route/);
assert.equal(
  OPENSYMPHONY_V2113_GHA_BASE,
  "b682ef362494936b38f99468b0e84788cceec17e",
);
assert.equal(
  OPENSYMPHONY_V2113_GHA_REMOTE_URL,
  "git@github.com:ray-manaloto/symphony-cpp.git",
);
assert.deepEqual(OPENSYMPHONY_V2113_GHA_PATHS, expectedOpenSymphonyV2113GhaPaths);
assert.deepEqual(classifyPaths(expectedOpenSymphonyV2113GhaPaths), {
  routes: ["opensymphony-v2113-github-actions"],
  blocked: [],
});
assert.throws(
  () => classifyPaths(expectedOpenSymphonyV2113GhaPaths.slice(1)),
  PushRouteError,
);
assert.throws(
  () => classifyPaths([...expectedOpenSymphonyV2113GhaPaths, "unknown.bin"]),
  /unknown route/,
);

const opensymphonyGha = initializeFixture("opensymphony-v2113-gha");
const opensymphonyGhaBase = git(opensymphonyGha.repo, "rev-parse", "HEAD");
commitOpenSymphonyV2113GhaPacket(opensymphonyGha.repo);
const opensymphonyGhaHead = git(opensymphonyGha.repo, "rev-parse", "HEAD");
const opensymphonyGhaEnvironment = hookEnvironment(opensymphonyGha.repo, "0".repeat(40), {
  PRE_COMMIT_REMOTE_BRANCH: "refs/heads/codex/opensymphony-v2113-gha",
});
const opensymphonyGhaState = verifyHookContext(
  opensymphonyGha.repo,
  opensymphonyGhaEnvironment,
  {
    expectedOpenSymphonyV2113GhaBase: opensymphonyGhaBase,
    expectedOpenSymphonyV2113GhaRemoteUrl: opensymphonyGha.remote,
  },
);
assert.equal(opensymphonyGhaState.base, opensymphonyGhaBase);
assert.equal(opensymphonyGhaState.head, opensymphonyGhaHead);
assert.deepEqual(opensymphonyGhaState.paths, expectedOpenSymphonyV2113GhaPaths);
assert.deepEqual(opensymphonyGhaState.routes, ["opensymphony-v2113-github-actions"]);
assert.throws(
  () => verifyHookContext(
    opensymphonyGha.repo,
    opensymphonyGhaEnvironment,
    {
      expectedOpenSymphonyV2113GhaBase: opensymphonyGhaBase,
      expectedOpenSymphonyV2113GhaRemoteUrl: "git@github.com:not-authorized/repository.git",
    },
  ),
  /destination/,
);
assert.throws(
  () => verifyHookContext(opensymphonyGha.repo, {
    ...opensymphonyGhaEnvironment,
    PRE_COMMIT_REMOTE_BRANCH: "refs/heads/not-authorized",
  }, { expectedOpenSymphonyV2113GhaBase: opensymphonyGhaBase }),
  PushRouteError,
);
assert.throws(
  () => verifyHookContext(opensymphonyGha.repo, {
    ...opensymphonyGhaEnvironment,
    PRE_COMMIT_FROM_REF: opensymphonyGhaBase,
  }, { expectedOpenSymphonyV2113GhaBase: opensymphonyGhaBase }),
  PushRouteError,
);
prepareOpenSymphonyV2113GitHubActions(opensymphonyGha.repo, {
  expectedOpenSymphonyV2113GhaBase: opensymphonyGhaBase,
  expectedOpenSymphonyV2113GhaRemoteUrl: opensymphonyGha.remote,
  runStaticChecks() {},
});
verifyPrePush(opensymphonyGha.repo, opensymphonyGhaEnvironment, {
  expectedOpenSymphonyV2113GhaBase: opensymphonyGhaBase,
  expectedOpenSymphonyV2113GhaRemoteUrl: opensymphonyGha.remote,
});

const hostile = initializeFixture("hostile");
const hostileBase = git(hostile.repo, "rev-parse", "HEAD");
commitPath(hostile.repo, "docs/change.md", "# change\n");
const validEnvironment = hookEnvironment(hostile.repo, hostileBase);
const validState = verifyHookContext(hostile.repo, validEnvironment);
assert.deepEqual(validState.routes, ["documentation"]);
assert.throws(
  () => verifyPublicationReceipt(hostile.repo, hostileBase, validEnvironment.PRE_COMMIT_TO_REF),
  /missing/,
);
preparePush(hostile.repo);
const hostileReceiptPath = join(hostile.repo, ".build/publication-receipt.json");
const hostileReceipt = JSON.parse(readFileSync(hostileReceiptPath, "utf8"));
verifyPublicationReceipt(hostile.repo, hostileBase, validEnvironment.PRE_COMMIT_TO_REF);
for (const [field, value, pattern] of [
  ["base", validEnvironment.PRE_COMMIT_TO_REF, /exact zero-finding/],
  ["head", hostileBase, /exact zero-finding/],
  ["findingCount", 1, /exact zero-finding/],
  ["redacted", false, /exact zero-finding/],
  ["generatedAt", new Date(Date.now() - 901_000).toISOString(), /stale/],
  ["generatedAt", new Date(Date.now() + 60_000).toISOString(), /future/],
]) {
  const changed = { ...hostileReceipt, [field]: value };
  writeFileSync(hostileReceiptPath, `${JSON.stringify(changed)}\n`);
  assert.throws(
    () => verifyPublicationReceipt(hostile.repo, hostileBase, validEnvironment.PRE_COMMIT_TO_REF),
    pattern,
  );
}
writeFileSync(hostileReceiptPath, "{");
assert.throws(
  () => verifyPublicationReceipt(hostile.repo, hostileBase, validEnvironment.PRE_COMMIT_TO_REF),
  /malformed/,
);
writeFileSync(
  hostileReceiptPath,
  `${JSON.stringify({ ...hostileReceipt, extra: true })}\n`,
);
assert.throws(
  () => verifyPublicationReceipt(hostile.repo, hostileBase, validEnvironment.PRE_COMMIT_TO_REF),
  /unknown or missing/,
);
writeFileSync(hostileReceiptPath, "x".repeat(70 * 1024));
assert.throws(
  () => verifyPublicationReceipt(hostile.repo, hostileBase, validEnvironment.PRE_COMMIT_TO_REF),
  /oversized/,
);
writeFileSync(hostileReceiptPath, `${JSON.stringify(hostileReceipt)}\n`);
chmodSync(hostileReceiptPath, 0o644);
assert.throws(
  () => verifyPublicationReceipt(hostile.repo, hostileBase, validEnvironment.PRE_COMMIT_TO_REF),
  /mode 0600/,
);
chmodSync(hostileReceiptPath, 0o600);
rmSync(hostileReceiptPath);
symlinkSync(join(hostile.repo, "docs/base.md"), hostileReceiptPath);
assert.throws(
  () => verifyPublicationReceipt(hostile.repo, hostileBase, validEnvironment.PRE_COMMIT_TO_REF),
  /regular file/,
);
rmSync(hostileReceiptPath);
writeFileSync(hostileReceiptPath, `${JSON.stringify(hostileReceipt)}\n`, { mode: 0o600 });
const openedReceiptPath = `${hostileReceiptPath}.opened`;
verifyPublicationReceipt(
  hostile.repo,
  hostileBase,
  validEnvironment.PRE_COMMIT_TO_REF,
  Date.now(),
  {
    afterReceiptOpen(path) {
      renameSync(path, openedReceiptPath);
      writeFileSync(path, "{", { mode: 0o600 });
    },
  },
);
assert.throws(
  () => verifyPublicationReceipt(hostile.repo, hostileBase, validEnvironment.PRE_COMMIT_TO_REF),
  /malformed/,
);
rmSync(hostileReceiptPath);
renameSync(openedReceiptPath, hostileReceiptPath);
assert.throws(
  () =>
    verifyPrePush(hostile.repo, validEnvironment, {
      afterFirstReceipt() {
        writeFileSync(hostileReceiptPath, "{");
      },
    }),
  /malformed/,
);
writeFileSync(hostileReceiptPath, `${JSON.stringify(hostileReceipt)}\n`);
for (const [field, value] of [
  ["PRE_COMMIT_FROM_REF", "0".repeat(hostileBase.length)],
  ["PRE_COMMIT_TO_REF", hostileBase],
  ["PRE_COMMIT_LOCAL_BRANCH", "refs/tags/not-a-branch"],
  ["PRE_COMMIT_REMOTE_BRANCH", "refs/tags/not-a-branch"],
  ["PRE_COMMIT_REMOTE_NAME", ""],
  ["PRE_COMMIT_REMOTE_URL", ""],
]) {
  assert.throws(
    () => verifyHookContext(hostile.repo, { ...validEnvironment, [field]: value }),
    PushRouteError,
  );
}
write(join(hostile.repo, "src/dirty.cpp"), "int dirty;\n");
assert.throws(
  () => verifyHookContext(hostile.repo, validEnvironment),
  /non-checkpoint worktree drift/,
);
rmSync(join(hostile.repo, "src/dirty.cpp"));
write(join(hostile.repo, ".codex/notepads/checkpoint.md"), "durable checkpoint\n");
verifyHookContext(hostile.repo, validEnvironment);
git(hostile.repo, "add", ".codex/notepads/checkpoint.md");
assert.throws(
  () => verifyHookContext(hostile.repo, validEnvironment),
  /index must be clean/,
);
git(hostile.repo, "rm", "-q", "--cached", ".codex/notepads/checkpoint.md");
rmSync(join(hostile.repo, ".codex/notepads/checkpoint.md"));
write(
  join(hostile.repo, "scripts/check-local-preflight.sh"),
  `#!/usr/bin/env bash
set -euo pipefail
test "\${1:-}" = quick
printf '%s\\n' '# moved during validation' >docs/moved.md
git add -- docs/moved.md
git commit -qm 'move during validation'
`,
);
git(hostile.repo, "add", "scripts/check-local-preflight.sh");
git(hostile.repo, "commit", "-m", "moving preflight fixture");
assert.throws(() => preparePush(hostile.repo), /push range changed/);

const multiDestination = initializeFixture("multi-destination");
const multiBase = git(multiDestination.repo, "rev-parse", "HEAD");
const secondRemote = join(fixtureRoot, "multi-destination", "second.git");
git(fixtureRoot, "init", "--bare", secondRemote);
git(
  secondRemote,
  "fetch",
  multiDestination.repo,
  "refs/heads/codex/implementation:refs/heads/codex/implementation",
);
commitPath(multiDestination.repo, "docs/change.md", "# change\n");
git(
  multiDestination.repo,
  "remote",
  "set-url",
  "--add",
  "--push",
  "origin",
  multiDestination.remote,
);
git(
  multiDestination.repo,
  "remote",
  "set-url",
  "--add",
  "--push",
  "origin",
  secondRemote,
);
assert.throws(() => preparePush(multiDestination.repo), /exactly one push URL/);
assert.throws(
  () => git(multiDestination.repo, "push", "origin", "refs/heads/codex/implementation"),
  /Command failed/,
);
assert.equal(
  git(multiDestination.remote, "rev-parse", "refs/heads/codex/implementation"),
  multiBase,
);
assert.equal(git(secondRemote, "rev-parse", "refs/heads/codex/implementation"), multiBase);

if (!process.argv.includes("--quick")) {
  const deletion = initializeFixture("deletion");
  commitPath(deletion.repo, "docs/delete.md", "# delete\n");
  const deletionBase = git(deletion.repo, "rev-parse", "HEAD");
  git(deletion.repo, "rm", "docs/delete.md");
  git(deletion.repo, "commit", "-m", "delete docs path");
  assert.deepEqual(
    buildRouteState(deletion.repo, deletionBase, git(deletion.repo, "rev-parse", "HEAD")).routes,
    ["documentation"],
  );

  const rename = initializeFixture("rename");
  commitPath(rename.repo, "docs/rename.md", "# rename\n");
  const renameBase = git(rename.repo, "rev-parse", "HEAD");
  git(rename.repo, "mv", "docs/rename.md", "unknown.bin");
  git(rename.repo, "commit", "-m", "rename out of route");
  assert.throws(
    () => buildRouteState(rename.repo, renameBase, git(rename.repo, "rev-parse", "HEAD")),
    /unknown route/,
  );

  const typeChange = initializeFixture("type-change");
  commitPath(typeChange.repo, "docs/type.md", "# regular\n");
  const typeBase = git(typeChange.repo, "rev-parse", "HEAD");
  rmSync(join(typeChange.repo, "docs/type.md"));
  symlinkSync("base.md", join(typeChange.repo, "docs/type.md"));
  git(typeChange.repo, "add", "docs/type.md");
  git(typeChange.repo, "commit", "-m", "change docs path type");
  assert.deepEqual(
    buildRouteState(typeChange.repo, typeBase, git(typeChange.repo, "rev-parse", "HEAD")).routes,
    ["documentation"],
  );

  const golden = initializeFixture("golden");
  commitPath(golden.repo, "docs/change.md", "# change\n");
  const goldenHead = git(golden.repo, "rev-parse", "HEAD");
  assert.throws(
    () => git(golden.repo, "push", "origin", "refs/heads/codex/implementation"),
    /Command failed/,
  );
  command(golden.repo, "node", ["scripts/check-push-route.mjs", "prepare"]);
  const pushStartedAt = performance.now();
  git(golden.repo, "push", "origin", "refs/heads/codex/implementation");
  const pushElapsedMs = performance.now() - pushStartedAt;
  assert.ok(pushElapsedMs < 5_000, `pre-push verification took ${pushElapsedMs.toFixed(0)} ms`);
  assert.equal(
    git(golden.remote, "rev-parse", "refs/heads/codex/implementation"),
    goldenHead,
  );
  const publication = JSON.parse(
    readFileSync(join(golden.repo, ".build/publication-receipt.json"), "utf8"),
  );
  assert.equal(publication.head, goldenHead);
  assert.equal(publication.findingCount, 0);
}

process.stdout.write("push-route fixtures passed\n");
