#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import {
  existsSync,
  readFileSync,
  readdirSync,
  writeFileSync,
} from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const repositoryRoot = dirname(dirname(fileURLToPath(import.meta.url)));
const configurationPath = join(
  repositoryRoot,
  "config",
  "overlay-dependencies.json",
);
const upstreamLockPath = join(repositoryRoot, "docs", "upstream-lock.md");
const exactCommitPattern = /^[0-9a-f]{40}$/;
const sha512Pattern = /^[0-9a-f]{128}$/;

function fail(message) {
  throw new Error(`overlay dependency pins: ${message}`);
}

function loadConfiguration() {
  const configuration = JSON.parse(readFileSync(configurationPath, "utf8"));
  if (configuration["schema-version"] !== 1) {
    fail("unsupported config/overlay-dependencies.json schema");
  }
  if (
    !Array.isArray(configuration.dependencies) ||
    configuration.dependencies.length === 0
  ) {
    fail("the overlay dependency allowlist is empty");
  }

  const ports = new Set();
  for (const dependency of configuration.dependencies) {
    for (const field of ["port", "repository", "branch", "lock-name"]) {
      if (typeof dependency[field] !== "string" || dependency[field] === "") {
        fail(`allowlist entry has an invalid ${field}`);
      }
    }
    if (!/^[a-z0-9][a-z0-9-]*$/.test(dependency.port)) {
      fail(`invalid overlay port name ${dependency.port}`);
    }
    if (!/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(dependency.repository)) {
      fail(`invalid GitHub repository ${dependency.repository}`);
    }
    if (ports.has(dependency.port)) {
      fail(`duplicate allowlist entry for ${dependency.port}`);
    }
    ports.add(dependency.port);
  }
  return configuration.dependencies;
}

function portPaths(port) {
  const directory = join(repositoryRoot, "vcpkg-ports", port);
  return {
    directory,
    portfile: join(directory, "portfile.cmake"),
    manifest: join(directory, "vcpkg.json"),
  };
}

function parsePortfile(dependency) {
  const paths = portPaths(dependency.port);
  if (!existsSync(paths.portfile) || !existsSync(paths.manifest)) {
    fail(`missing overlay files for ${dependency.port}`);
  }
  const content = readFileSync(paths.portfile, "utf8");
  const repository = content.match(/^\s*REPO\s+(\S+)\s*$/m)?.[1];
  const reference = content.match(/^\s*REF\s+(\S+)\s*$/m)?.[1];
  const sha512 = content.match(
    /^\s*SHA512\s+([0-9a-f]+)\s*\)?\s*$/m,
  )?.[1];
  if (repository !== dependency.repository) {
    fail(
      `${dependency.port} declares REPO ${repository ?? "<missing>"} instead of ${dependency.repository}`,
    );
  }
  if (!exactCommitPattern.test(reference ?? "")) {
    fail(`${dependency.port} REF must be an exact 40-character commit`);
  }
  if (!sha512Pattern.test(sha512 ?? "")) {
    fail(`${dependency.port} SHA512 must be 128 lowercase hexadecimal characters`);
  }
  if (/^\s*HEAD_REF\b/m.test(content)) {
    fail(`${dependency.port} must not expose a floating HEAD_REF`);
  }
  return { content, paths, reference, sha512 };
}

function checkState() {
  const dependencies = loadConfiguration();
  const allowlistedPorts = new Set(
    dependencies.map((dependency) => dependency.port),
  );
  const overlayPorts = readdirSync(join(repositoryRoot, "vcpkg-ports"), {
    withFileTypes: true,
  })
    .filter(
      (entry) =>
        entry.isDirectory() &&
        existsSync(
          join(repositoryRoot, "vcpkg-ports", entry.name, "portfile.cmake"),
        ),
    )
    .map((entry) => entry.name);
  for (const port of overlayPorts) {
    if (!allowlistedPorts.has(port)) {
      fail(`overlay port ${port} is not in the update allowlist`);
    }
  }
  for (const port of allowlistedPorts) {
    if (!overlayPorts.includes(port)) {
      fail(`allowlisted port ${port} has no portfile.cmake`);
    }
  }

  const lockLines = readFileSync(upstreamLockPath, "utf8").split("\n");
  for (const dependency of dependencies) {
    const parsed = parsePortfile(dependency);
    const manifest = JSON.parse(readFileSync(parsed.paths.manifest, "utf8"));
    if (manifest.name !== dependency.port) {
      fail(`${dependency.port} manifest declares name ${manifest.name}`);
    }
    if (manifest["version-string"] !== `git-${parsed.reference}`) {
      fail(
        `${dependency.port} version-string must match its immutable REF`,
      );
    }
    for (const floatingVersionField of [
      "version",
      "version-date",
      "version-semver",
    ]) {
      if (floatingVersionField in manifest) {
        fail(
          `${dependency.port} must use version-string rather than ${floatingVersionField}`,
        );
      }
    }
    if (
      "port-version" in manifest &&
      (!Number.isInteger(manifest["port-version"]) ||
        manifest["port-version"] < 1)
    ) {
      fail(`${dependency.port} has an invalid port-version`);
    }

    const prefix = `| ${dependency["lock-name"]} |`;
    const matchingLines = lockLines.filter((line) => line.startsWith(prefix));
    if (matchingLines.length !== 1) {
      fail(
        `${dependency.port} requires exactly one ${dependency["lock-name"]} lock row`,
      );
    }
    if (
      !matchingLines[0].includes(`\`${parsed.reference}\``) ||
      !matchingLines[0].includes(`\`${parsed.sha512}\``)
    ) {
      fail(`${dependency.port} lock row does not match its source pin`);
    }
  }
  console.log(
    `overlay dependency pins passed: ${dependencies.length} immutable port(s)`,
  );
}

function resolveBranch(dependency) {
  const output = execFileSync(
    "git",
    [
      "ls-remote",
      `https://github.com/${dependency.repository}.git`,
      `refs/heads/${dependency.branch}`,
    ],
    { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] },
  ).trim();
  const lines = output.split("\n").filter(Boolean);
  if (lines.length !== 1) {
    fail(
      `expected one ${dependency.repository} ${dependency.branch} branch result`,
    );
  }
  const [reference, remoteName] = lines[0].split(/\s+/);
  if (
    !exactCommitPattern.test(reference ?? "") ||
    remoteName !== `refs/heads/${dependency.branch}`
  ) {
    fail(`invalid branch result for ${dependency.repository}`);
  }
  return reference;
}

async function archiveSha512(dependency, reference) {
  const response = await fetch(
    `https://github.com/${dependency.repository}/archive/${reference}.tar.gz`,
    {
      headers: {
        Accept: "application/octet-stream",
        "User-Agent": "symphony-cpp-overlay-updater",
      },
      redirect: "follow",
    },
  );
  if (!response.ok) {
    fail(
      `${dependency.repository} archive download returned HTTP ${response.status}`,
    );
  }
  const hash = createHash("sha512");
  for await (const chunk of response.body) {
    hash.update(chunk);
  }
  return hash.digest("hex");
}

function replacePortfilePin(parsed, reference, sha512) {
  let content = parsed.content.replace(
    /^(\s*REF\s+)\S+(\s*)$/m,
    `$1${reference}$2`,
  );
  content = content.replace(
    /^(\s*SHA512\s+)[0-9a-f]+(\s*\)?\s*)$/m,
    `$1${sha512}$2`,
  );
  content = content.replace(
    /^(\s*)HEAD_REF\s+\S+\s*\)\s*$/m,
    "$1)",
  );
  content = content.replace(/^\s*HEAD_REF\s+\S+\s*$/m, "");
  return content;
}

function updateManifest(parsed, reference) {
  const manifest = JSON.parse(readFileSync(parsed.paths.manifest, "utf8"));
  for (const versionField of [
    "version",
    "version-date",
    "version-semver",
    "version-string",
  ]) {
    delete manifest[versionField];
  }
  const ordered = {
    name: manifest.name,
    "version-string": `git-${reference}`,
    ...manifest,
  };
  ordered["version-string"] = `git-${reference}`;
  if (parsed.reference !== reference) {
    delete ordered["port-version"];
  }
  return `${JSON.stringify(ordered, null, 2)}\n`;
}

function updateLockRow(
  lockContent,
  dependency,
  reference,
  sha512,
  manifestContent,
) {
  const manifest = JSON.parse(manifestContent);
  const revision =
    "port-version" in manifest
      ? `; overlay port revision \`${manifest["port-version"]}\``
      : "";
  const prefix = `| ${dependency["lock-name"]} |`;
  const lines = lockContent.split("\n");
  const index = lines.findIndex((line) => line.startsWith(prefix));
  if (index < 0) {
    fail(`missing lock row for ${dependency["lock-name"]}`);
  }
  const cells = lines[index].split("|");
  if (cells.length < 5) {
    fail(`malformed lock row for ${dependency["lock-name"]}`);
  }
  cells[2] =
    ` \`${reference}\`; source SHA-512 \`${sha512}\`${revision} `;
  lines[index] = cells.join("|");
  return lines.join("\n");
}

async function updateState() {
  const dependencies = loadConfiguration();
  for (const dependency of dependencies) {
    const curatedPort = join(
      repositoryRoot,
      ".build",
      "vcpkg",
      "ports",
      dependency.port,
    );
    if (existsSync(curatedPort)) {
      fail(
        `${dependency.port} now exists in the pinned curated registry; migrate it separately`,
      );
    }
  }

  const resolutions = await Promise.all(
    dependencies.map(async (dependency) => {
      const reference = resolveBranch(dependency);
      const sha512 = await archiveSha512(dependency, reference);
      if (!sha512Pattern.test(sha512)) {
        fail(`invalid computed SHA512 for ${dependency.port}`);
      }
      return { dependency, reference, sha512 };
    }),
  );

  let lockContent = readFileSync(upstreamLockPath, "utf8");
  for (const { dependency, reference, sha512 } of resolutions) {
    const parsed = parsePortfile(dependency);
    const portfileContent = replacePortfilePin(parsed, reference, sha512);
    const manifestContent = updateManifest(parsed, reference);
    writeFileSync(parsed.paths.portfile, portfileContent);
    writeFileSync(parsed.paths.manifest, manifestContent);
    lockContent = updateLockRow(
      lockContent,
      dependency,
      reference,
      sha512,
      manifestContent,
    );
    const disposition =
      parsed.reference === reference && parsed.sha512 === sha512
        ? "unchanged"
        : `${parsed.reference} -> ${reference}`;
    console.log(`${dependency.port}: ${disposition}`);
  }
  writeFileSync(upstreamLockPath, lockContent);
  checkState();
}

const mode = process.argv[2];
if (process.argv.length !== 3 || !["--check", "--update"].includes(mode)) {
  console.error(
    "usage: update-overlay-dependencies.mjs --check|--update",
  );
  process.exit(64);
}

try {
  if (mode === "--check") {
    checkState();
  } else {
    await updateState();
  }
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
}
