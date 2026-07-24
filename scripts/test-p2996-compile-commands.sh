#!/usr/bin/env bash
set -euo pipefail

readonly verifier="${PWD}/scripts/check-p2996-compile-commands.py"
fixture_root="$(mktemp -d)"
readonly fixture_root
trap 'rm -rf "${fixture_root}"' EXIT

valid_command=(
  ccache
  /opt/clang-p2996/bin/clang++
  -std=c++26
  -stdlib=libc++
  -freflection
  -fexpansion-statements
  -c
  "${PWD}/tests/p2996_tests.cpp"
)
readonly valid_command

python3 - "${fixture_root}/valid.json" "${PWD}" "${valid_command[@]}" <<'PY'
import json
import sys

destination, root, *arguments = sys.argv[1:]
entry = {
    "directory": root,
    "file": f"{root}/tests/p2996_tests.cpp",
    "arguments": arguments,
}
with open(destination, "w", encoding="utf-8") as stream:
    json.dump([entry], stream)
PY
"${verifier}" "${fixture_root}/valid.json"
printf '%s\n' \
  ': && /opt/clang-p2996/bin/clang++ -stdlib=libc++ -fuse-ld=lld -Wl,-rpath,/opt/clang-p2996/lib tests/p2996_tests.cpp.o -o tests/symphony_p2996_tests && :' \
  >"${fixture_root}/valid-link.txt"
"${verifier}" "${fixture_root}/valid.json" "${fixture_root}/valid-link.txt"

for mutation in \
  wrong-driver \
  missing-standard \
  conflicting-standard \
  missing-libcxx \
  conflicting-stdlib \
  missing-reflection \
  missing-expansion \
  umbrella-reflection \
  gcc-toolchain \
  sysroot \
  no-standard-includes \
  system-libstdcxx-include \
  target \
  duplicate-command; do
  python3 - \
    "${fixture_root}/valid.json" \
    "${fixture_root}/mutated.json" \
    "${mutation}" <<'PY'
import json
import sys

source, destination, mutation = sys.argv[1:]
with open(source, encoding="utf-8") as stream:
    database = json.load(stream)
arguments = database[0]["arguments"]
if mutation == "wrong-driver":
    arguments[1] = "/usr/bin/clang++"
elif mutation == "missing-standard":
    arguments.remove("-std=c++26")
elif mutation == "conflicting-standard":
    arguments.append("-std=c++23")
elif mutation == "missing-libcxx":
    arguments.remove("-stdlib=libc++")
elif mutation == "conflicting-stdlib":
    arguments.append("-stdlib=libstdc++")
elif mutation == "missing-reflection":
    arguments.remove("-freflection")
elif mutation == "missing-expansion":
    arguments.remove("-fexpansion-statements")
elif mutation == "umbrella-reflection":
    arguments.append("-freflection-latest")
elif mutation == "gcc-toolchain":
    arguments.append("--gcc-toolchain=/usr")
elif mutation == "sysroot":
    arguments.append("--sysroot=/tmp/sysroot")
elif mutation == "no-standard-includes":
    arguments.append("-nostdinc++")
elif mutation == "system-libstdcxx-include":
    arguments.extend(["-isystem", "/usr/include/c++/13"])
elif mutation == "target":
    arguments.append("--target=x86_64-unknown-linux-gnu")
elif mutation == "duplicate-command":
    database.append(dict(database[0]))
else:
    raise ValueError(f"unknown mutation: {mutation}")
with open(destination, "w", encoding="utf-8") as stream:
    json.dump(database, stream)
PY
  if "${verifier}" "${fixture_root}/mutated.json" >/dev/null 2>&1; then
    echo "accepted invalid p2996 compile command mutation: ${mutation}" >&2
    exit 1
  fi
done

for mutation in \
  wrong-driver \
  missing-libcxx \
  missing-lld \
  missing-rpath \
  active-prefix \
  active-suffix \
  duplicate-link; do
  python3 - \
    "${fixture_root}/valid-link.txt" \
    "${fixture_root}/mutated-link.txt" \
    "${mutation}" <<'PY'
import sys

source, destination, mutation = sys.argv[1:]
with open(source, encoding="utf-8") as stream:
    command = stream.read()
if mutation == "wrong-driver":
    command = command.replace("/opt/clang-p2996/bin/clang++", "/usr/bin/clang++")
elif mutation == "missing-libcxx":
    command = command.replace("-stdlib=libc++ ", "")
elif mutation == "missing-lld":
    command = command.replace("-fuse-ld=lld ", "")
elif mutation == "missing-rpath":
    command = command.replace("-Wl,-rpath,/opt/clang-p2996/lib ", "")
elif mutation == "active-prefix":
    command = command.replace(": && ", "false && ", 1)
elif mutation == "active-suffix":
    command = command.replace(" && :\n", " && true\n")
elif mutation == "duplicate-link":
    command = f"{command.rstrip()}\n{command}"
else:
    raise ValueError(f"unknown mutation: {mutation}")
with open(destination, "w", encoding="utf-8") as stream:
    stream.write(command)
PY
  if "${verifier}" \
      "${fixture_root}/valid.json" \
      "${fixture_root}/mutated-link.txt" >/dev/null 2>&1; then
    echo "accepted invalid p2996 link command mutation: ${mutation}" >&2
    exit 1
  fi
done
