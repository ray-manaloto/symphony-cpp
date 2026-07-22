#!/usr/bin/env node

import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";

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

const skippedDirectories = new Set([".build", ".git", "build", "fixtures", "vcpkg_installed"]);
const cmakeInputs = [];
function collectCmakeInputs(directory) {
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    if (entry.isDirectory()) {
      if (!skippedDirectories.has(entry.name)) collectCmakeInputs(join(directory, entry.name));
    } else if (entry.name === "CMakeLists.txt" || entry.name.endsWith(".cmake")) {
      cmakeInputs.push(join(directory, entry.name));
    }
  }
}
collectCmakeInputs(".");

for (const path of cmakeInputs) {
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
