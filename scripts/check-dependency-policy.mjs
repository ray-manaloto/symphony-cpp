#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";

const requiredFiles = [
  "AGENTS.md",
  ".agents/skills/dependency-first/SKILL.md",
  "docs/conventions/dependency-first.md",
  "docs/dependency-decisions.md",
  "vcpkg.json",
];

const forbiddenPatterns = [
  ["FetchContent_Declare", "FetchContent is prohibited; declare the package in vcpkg."],
  ["CPMAddPackage", "CPM is prohibited; declare the package in vcpkg."],
  ["ExternalProject_Add", "Ad hoc source builds are prohibited; use vcpkg or obtain owner authorization."],
];

let failed = false;
for (const path of requiredFiles) {
  try {
    readFileSync(path);
  } catch {
    console.error(`dependency policy: missing ${path}`);
    failed = true;
  }
}

const tracked = execFileSync("git", ["ls-files", "-z"], { encoding: "utf8" })
  .split("\0")
  .filter(Boolean)
  .filter((path) => path.endsWith(".cmake") || path.endsWith("CMakeLists.txt"));

for (const path of tracked) {
  let content;
  try {
    content = readFileSync(path, "utf8");
  } catch {
    continue;
  }
  for (const [pattern, message] of forbiddenPatterns) {
    if (content.includes(pattern)) {
      console.error(`dependency policy: ${path}: ${message}`);
      failed = true;
    }
  }
}

if (failed) process.exit(1);
console.log("dependency policy passed");
