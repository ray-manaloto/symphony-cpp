#!/usr/bin/env bash
set -euo pipefail

readonly verifier=./scripts/check-clang-format-version.sh
readonly source_lister="${PWD}/scripts/list-format-sources.sh"
readonly pinned_commit=ca7933e47d3a3451d81e72ac174dcb5aa28b59d1
readonly presets=CMakePresets.json
readonly tidy_config=.clang-tidy
readonly tidy_runner=scripts/check-tidy.sh
readonly containerfile=containers/Containerfile
readonly devcontainer_runner=scripts/devcontainer-build.sh
readonly compile_commands_verifier="${PWD}/scripts/check-analysis-compile-commands.py"
readonly tidy_policy_verifier="${PWD}/scripts/check-tidy-policy.sh"

grep -Fq \
  '"VCPKG_CHAINLOAD_TOOLCHAIN_FILE": "${sourceDir}/cmake/toolchains/clang-analysis.cmake"' \
  "${presets}"
"${tidy_policy_verifier}" "${tidy_config}" "${tidy_runner}"
if grep -Fq 'source_filter=' "${tidy_runner}"; then
  echo "run-clang-tidy must consume the complete validated compilation database" >&2
  exit 1
fi
grep -Fq \
  'cmake --fresh --preset clang-analysis' \
  "${containerfile}"
grep -Fq 'cmake --workflow --fresh --preset clang-rtsan' "${containerfile}"
grep -Fq 'cmake --fresh --preset ${preset}' "${devcontainer_runner}"
grep -Fq 'readonly preset="clang-rtsan"' "${devcontainer_runner}"
grep -Fq "grep -Fx '#define _GLIBCXX_RELEASE 16'" "${containerfile}"
grep -Fq '"name": "clang-rtsan"' "${presets}"
grep -Fq '"SYMPHONY_ENABLE_RTSAN": "ON"' "${presets}"
grep -Fq '"symphony_rtsan_safe_fixture"' "${presets}"
grep -Fq '"symphony_rtsan_violation_fixture"' "${presets}"
grep -Fq '"name": "^symphony_rtsan_"' "${presets}"
grep -Fq \
  '"RTSAN_OPTIONS": "halt_on_error=true:abort_on_error=false:verify_interceptors=true:symbolize=true:fast_unwind_on_fatal=true:color=never"' \
  "${presets}"

readonly project_cmake=CMakeLists.txt
readonly rtsan_probe=cmake/CheckRealtimeSanitizer.cmake
readonly rtsan_failure_driver=cmake/ExpectRtsanFailure.cmake
readonly test_cmake=tests/CMakeLists.txt
grep -Fq 'add_library(symphony_rtsan_options INTERFACE)' "${project_cmake}"
grep -Fq -- '-Werror=function-effects' "${project_cmake}"
grep -Fq -- '-Werror=perf-constraint-implies-noexcept' "${project_cmake}"
grep -Fq '__has_feature(realtime_sanitizer)' "${rtsan_probe}"
grep -Fq '#include <sanitizer/rtsan_interface.h>' "${rtsan_probe}"
grep -Fq 'SYMPHONY_RTSAN_ACCEPTED_MISSING_NOEXCEPT' "${rtsan_probe}"
grep -Fq 'SYMPHONY_RTSAN_ACCEPTED_ALLOCATION' "${rtsan_probe}"
test "$(grep -Foc '[=[' "${rtsan_probe}")" -eq 3
test "$(grep -Foc ']=]' "${rtsan_probe}")" -eq 3
if grep -Eq '^[[:space:]]*\[\[$' "${rtsan_probe}"; then
  echo "RTSan C++ probes must not use a bracket delimiter that collides with attributes" >&2
  exit 1
fi
grep -Fq 'if("${program_result}" STREQUAL "0")' "${rtsan_failure_driver}"
grep -Fq 'program_output MATCHES "${EXPECTED_REPORT}"' "${rtsan_failure_driver}"
test "$(grep -Foc 'symphony_rtsan_options)' "${test_cmake}")" -eq 2
if grep -A8 -F 'target_compile_options(symphony_options INTERFACE' \
    "${project_cmake}" | grep -Fq -- '-fsanitize=realtime'; then
  echo "RTSan instrumentation escaped the fixture-only options target" >&2
  exit 1
fi

"${verifier}" "clang-format version 22.1.8"
"${verifier}" \
  "clang-format version 22.1.8 (https://github.com/llvm/llvm-project ${pinned_commit})"

if "${verifier}" "clang-format version 22.1.9" 2>/dev/null; then
  echo "accepted a different clang-format version" >&2
  exit 1
fi

if "${verifier}" "clang-format version 22.1.8 (untrusted provenance)" 2>/dev/null; then
  echo "accepted an unrecognized clang-format provenance suffix" >&2
  exit 1
fi

if "${verifier}" \
  "clang-format version 22.1.8 (https://github.com/llvm/llvm-project deadbeef)" 2>/dev/null; then
  echo "accepted a different LLVM source revision" >&2
  exit 1
fi

fixture_root="$(mktemp -d)"
readonly fixture_root
trap 'rm -rf "${fixture_root}"' EXIT
mkdir -p \
  "${fixture_root}/include/project" \
  "${fixture_root}/src" \
  "${fixture_root}/tests/fixtures"
touch "${fixture_root}/include/project/api.hpp" \
  "${fixture_root}/src/main.cpp" \
  "${fixture_root}/src/private.hpp" \
  "${fixture_root}/src/ignored.md" \
  "${fixture_root}/tests/fixtures/formatted_fixture.cpp" \
  "${fixture_root}/tests/fixtures/p2996_reflection_probe.cpp" \
  "${fixture_root}/tests/main_tests.cxx" \
  "${fixture_root}/tests/support.hh"
git_free_sources="$(
  cd "${fixture_root}"
  "${source_lister}" | tr '\0' '\n' | LC_ALL=C sort
)"
readonly git_free_sources
expected_sources="$(
  printf '%s\n' \
    include/project/api.hpp \
    src/main.cpp \
    src/private.hpp \
    tests/fixtures/formatted_fixture.cpp \
    tests/main_tests.cxx \
    tests/support.hh
)"
readonly expected_sources
test "${git_free_sources}" = "${expected_sources}"
if grep -Fxq 'tests/fixtures/p2996_reflection_probe.cpp' <<<"${git_free_sources}"; then
  echo "byte-stable compiler recipe probe escaped its exact formatter exemption" >&2
  exit 1
fi

(
  cd "${fixture_root}"
  git init --quiet
  mkdir ignored
  touch ignored/generated.cpp
  printf '%s\n' '/ignored/' >.gitignore
  git add .
)
git_sources="$(
  cd "${fixture_root}"
  "${source_lister}" | tr '\0' '\n' | LC_ALL=C sort
)"
readonly git_sources
test "${git_sources}" = "${git_free_sources}"

touch "${fixture_root}/src/command.cpp"
cat >"${fixture_root}/compile_commands.json" <<EOF
[
  {
    "directory": "${fixture_root}",
    "file": "${fixture_root}/src/main.cpp",
    "arguments": [
      "/opt/llvm-22.1.8/bin/clang++",
      "--gcc-toolchain=/opt/gcc-16.1",
      "-std=c++26",
      "-c",
      "${fixture_root}/src/main.cpp"
    ]
  },
  {
    "directory": "${fixture_root}",
    "file": "${fixture_root}/src/command.cpp",
    "command": "ccache /opt/llvm-22.1.8/bin/clang++ --gcc-toolchain=/opt/gcc-16.1 -std=c++26 '-DNAME=with space' -c '${fixture_root}/src/command.cpp'"
  }
]
EOF
(
  cd "${fixture_root}"
  "${compile_commands_verifier}" compile_commands.json
)
cp "${fixture_root}/compile_commands.json" "${fixture_root}/compile_commands.valid.json"

mkdir -p "${fixture_root}/tests"
touch "${fixture_root}/tests/rtsan_safe_fixture.cpp" \
  "${fixture_root}/tests/rtsan_violation_fixture.cpp"
python3 - \
  "${fixture_root}/compile_commands.valid.json" \
  "${fixture_root}/compile_commands.rtsan.json" <<'PY'
import json
import sys

source, destination = sys.argv[1:]
with open(source, encoding="utf-8") as stream:
    database = json.load(stream)
root = database[0]["directory"]
for fixture in ("rtsan_safe_fixture.cpp", "rtsan_violation_fixture.cpp"):
    path = f"{root}/tests/{fixture}"
    database.append(
        {
            "directory": root,
            "file": path,
            "arguments": [
                "/opt/llvm-22.1.8/bin/clang++",
                "--gcc-toolchain=/opt/gcc-16.1",
                "-std=c++26",
                "-fsanitize=realtime",
                "-fno-omit-frame-pointer",
                "-Werror=function-effects",
                "-Werror=perf-constraint-implies-noexcept",
                "-c",
                path,
            ],
        }
    )
with open(destination, "w", encoding="utf-8") as stream:
    json.dump(database, stream)
PY
(
  cd "${fixture_root}"
  "${compile_commands_verifier}" \
    compile_commands.rtsan.json --require-rtsan-fixtures
)
for mutation in \
  missing-fixture \
  missing-sanitize \
  missing-effect \
  other-sanitizer \
  escaped-rtsan \
  disabled-effect; do
  python3 - \
    "${fixture_root}/compile_commands.rtsan.json" \
    "${fixture_root}/compile_commands.rtsan-mutated.json" \
    "${mutation}" <<'PY'
import json
import sys

source, destination, mutation = sys.argv[1:]
with open(source, encoding="utf-8") as stream:
    database = json.load(stream)
if mutation == "missing-fixture":
    database.pop()
elif mutation == "missing-sanitize":
    database[-1]["arguments"].remove("-fsanitize=realtime")
elif mutation == "missing-effect":
    database[-1]["arguments"].remove("-Werror=function-effects")
elif mutation == "other-sanitizer":
    database[-1]["arguments"].append("-fsanitize=thread")
elif mutation == "escaped-rtsan":
    database[0]["arguments"].append("-fsanitize=realtime")
elif mutation == "disabled-effect":
    database[-1]["arguments"].append("-Wno-function-effects")
else:
    raise ValueError(f"unknown mutation: {mutation}")
with open(destination, "w", encoding="utf-8") as stream:
    json.dump(database, stream)
PY
  if (
    cd "${fixture_root}"
    "${compile_commands_verifier}" \
      compile_commands.rtsan-mutated.json --require-rtsan-fixtures 2>/dev/null
  ); then
    echo "accepted invalid RTSan compile command mutation: ${mutation}" >&2
    exit 1
  fi
done

touch "${fixture_root}/src/unlisted.cpp"
if (
  cd "${fixture_root}"
  "${compile_commands_verifier}" compile_commands.json 2>/dev/null
); then
  echo "accepted a project source without a compile command" >&2
  exit 1
fi
rm "${fixture_root}/src/unlisted.cpp"

for mutation in \
  missing-gcc \
  wrong-driver \
  conflicting-gcc \
  missing-standard \
  conflicting-standard \
  libcxx \
  system-include \
  sysroot \
  cxx-system-include \
  stdlib-system-include \
  target \
  no-standard-includes; do
  python3 - \
    "${fixture_root}/compile_commands.valid.json" \
    "${fixture_root}/compile_commands.json" \
    "${mutation}" <<'PY'
import json
import sys

source, destination, mutation = sys.argv[1:]
with open(source, encoding="utf-8") as stream:
    database = json.load(stream)
arguments = database[0]["arguments"]
if mutation == "missing-gcc":
    arguments.remove("--gcc-toolchain=/opt/gcc-16.1")
elif mutation == "wrong-driver":
    arguments.insert(0, "/usr/bin/g++")
elif mutation == "conflicting-gcc":
    arguments.append("--gcc-toolchain=/usr")
elif mutation == "missing-standard":
    arguments.remove("-std=c++26")
elif mutation == "conflicting-standard":
    arguments.append("-std=c++23")
elif mutation == "libcxx":
    arguments.append("-stdlib=libc++")
elif mutation == "system-include":
    arguments.extend(["-isystem", "/usr/include/c++/13"])
elif mutation == "sysroot":
    arguments.append("--sysroot=/tmp/alternate-root")
elif mutation == "cxx-system-include":
    arguments.extend(["-cxx-isystem", "/tmp/alternate-cxx"])
elif mutation == "stdlib-system-include":
    arguments.extend(["-stdlib++-isystem", "/tmp/alternate-stdlib"])
elif mutation == "target":
    arguments.append("--target=aarch64-linux-gnu")
elif mutation == "no-standard-includes":
    arguments.append("-nostdinc")
else:
    raise ValueError(f"unknown mutation: {mutation}")
with open(destination, "w", encoding="utf-8") as stream:
    json.dump(database, stream)
PY
  if (
    cd "${fixture_root}"
    "${compile_commands_verifier}" compile_commands.json 2>/dev/null
  ); then
    echo "accepted invalid analysis compile command mutation: ${mutation}" >&2
    exit 1
  fi
done

printf '%s\n' "WarningsAsErrors: '*'" >"${fixture_root}/warnings-as-errors.yml"
if "${tidy_policy_verifier}" \
  "${fixture_root}/warnings-as-errors.yml" "${tidy_runner}" 2>/dev/null; then
  echo "accepted nonempty clang-tidy WarningsAsErrors" >&2
  exit 1
fi
printf '%s\n' 'run-clang-tidy -warnings-as-errors=*' >"${fixture_root}/single-dash-runner.sh"
if "${tidy_policy_verifier}" \
  "${tidy_config}" "${fixture_root}/single-dash-runner.sh" 2>/dev/null; then
  echo "accepted single-dash run-clang-tidy warning promotion" >&2
  exit 1
fi
printf '%s\n' 'run-clang-tidy --warnings-as-errors=*' >"${fixture_root}/double-dash-runner.sh"
if "${tidy_policy_verifier}" \
  "${tidy_config}" "${fixture_root}/double-dash-runner.sh" 2>/dev/null; then
  echo "accepted double-dash run-clang-tidy warning promotion" >&2
  exit 1
fi
for config_option in -config= -config-file= --config= --config-file=; do
  printf '%s\n' "run-clang-tidy ${config_option}${fixture_root}/warnings-as-errors.yml" \
    >"${fixture_root}/config-runner.sh"
  if "${tidy_policy_verifier}" \
    "${tidy_config}" "${fixture_root}/config-runner.sh" 2>/dev/null; then
    echo "accepted run-clang-tidy project config override: ${config_option}" >&2
    exit 1
  fi
done
mkdir -p "${fixture_root}/src/nested"
printf '%s\n' "WarningsAsErrors: '*'" >"${fixture_root}/src/nested/.clang-tidy"
if "${tidy_policy_verifier}" \
  "${tidy_config}" "${tidy_runner}" "${fixture_root}" 2>/dev/null; then
  echo "accepted nested clang-tidy warning promotion" >&2
  exit 1
fi
