#!/usr/bin/env node

import { chmodSync, mkdirSync, renameSync, rmSync, writeFileSync } from "node:fs";
import { spawnSync } from "node:child_process";

const [, , operation, baseRef, reviewedHead] = process.argv;
if (operation !== "--publication-scan" || !baseRef || !reviewedHead) {
  process.stderr.write("usage: check-adaptive-orchestration.mjs --publication-scan BASE REVIEWED_HEAD\n");
  process.exit(64);
}

function git(args, encoding = "utf8") {
  const result = spawnSync("git", args, { encoding, maxBuffer: 128 * 1024 * 1024 });
  if (result.status !== 0) {
    process.stderr.write("publication scan failed while resolving Git objects\n");
    process.exit(2);
  }
  return result.stdout;
}

const base = git(["rev-parse", "--verify", `${baseRef}^{commit}`]).trim();
const head = git(["rev-parse", "--verify", `${reviewedHead}^{commit}`]).trim();
if (head !== reviewedHead) {
  process.stderr.write("publication scan requires an exact reviewed commit ID\n");
  process.exit(2);
}

const changedPaths = git([
  "diff",
  "--name-only",
  "-z",
  "--find-renames",
  "--diff-filter=ACDMRTUXB",
  base,
  head,
])
  .split("\0")
  .filter(Boolean);
const diff = git(["diff", "--no-ext-diff", "--unified=0", base, head]);
const addedLines = diff
  .split("\n")
  .filter((line) => line.startsWith("+") && !line.startsWith("+++"))
  .map((line) => line.slice(1));

const secretShapes = [
  /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/i,
  /(?:^|[^A-Za-z0-9])sk-[A-Za-z0-9_-]{20,}/,
  /(?:^|[^A-Za-z0-9])ghp_[A-Za-z0-9]{30,}/,
  /github_pat_[A-Za-z0-9_]{30,}/,
  /AKIA[0-9A-Z]{16}/,
  /(?:authorization|password|passwd|secret|token)\s*[:=]\s*["']?[A-Za-z0-9/+_.-]{12,}/i,
];

let findingCount = 0;
for (const line of addedLines) {
  for (const pattern of secretShapes) {
    if (pattern.test(line)) ++findingCount;
  }
}

const receipt = {
  schemaVersion: 1,
  base,
  head,
  changedPathCount: changedPaths.length,
  scannedAddedLineCount: addedLines.length,
  findingCount,
  redacted: true,
  generatedAt: new Date().toISOString(),
};
mkdirSync(".build", { recursive: true });
const receiptPath = ".build/publication-receipt.json";
const temporaryReceiptPath = `${receiptPath}.tmp-${process.pid}`;
rmSync(receiptPath, { force: true });
rmSync(temporaryReceiptPath, { force: true });

if (findingCount !== 0) {
  process.stderr.write(`publication scan blocked: ${findingCount} redacted finding(s) require classification\n`);
  process.exit(1);
}
writeFileSync(temporaryReceiptPath, `${JSON.stringify(receipt, null, 2)}\n`, { mode: 0o600 });
renameSync(temporaryReceiptPath, receiptPath);
chmodSync(receiptPath, 0o600);
process.stdout.write(
  `publication scan passed: ${changedPaths.length} path(s), ${addedLines.length} added line(s), 0 redacted findings\n`,
);
