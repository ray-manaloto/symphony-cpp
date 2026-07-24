#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

readonly containerfile=containers/Containerfile
readonly cmake_installer=scripts/install-cmake.sh
readonly cmake_presets=CMakePresets.json
readonly p2996_toolchain=cmake/toolchains/clang-p2996.cmake
readonly p2996_probe=tests/fixtures/p2996_reflection_probe.cpp
readonly devcontainer_setup=scripts/devcontainer-setup.sh
readonly p2996_workflow_runner=scripts/run-clang-reflection-workflow.sh
readonly build_log_redactor=scripts/redact-build-log.awk
readonly p2996_test=tests/p2996_tests.cpp
readonly upstream_lock=docs/upstream-lock.md
readonly ut_manifest=vcpkg-ports/ut/vcpkg.json
readonly ut_port=vcpkg-ports/ut/portfile.cmake
readonly workflow=.github/workflows/compiler-matrix.yml
readonly source_workflow=.github/workflows/source-ci.yml
readonly devcontainer_configs=(
  .devcontainer/devcontainer.json
  .devcontainer/clang-p2996/devcontainer.json
  .devcontainer/analysis/devcontainer.json
)

bash -n "${cmake_installer}"
bash -n "${devcontainer_setup}"
bash -n "${p2996_workflow_runner}"
node - "${cmake_presets}" <<'JS'
const fs = require("node:fs");
const document = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const presets = new Map(
  document.configurePresets.map((preset) => [preset.name, preset]),
);
const reflection = presets.get("clang-reflection");
const inherited = presets.get(reflection?.inherits);
if (
  reflection?.cacheVariables?.CMAKE_CXX_COMPILER !==
    "/opt/clang-p2996/bin/clang++" ||
  reflection?.cacheVariables?.VCPKG_TARGET_TRIPLET !==
    "x64-linux-clang-p2996" ||
  reflection?.cacheVariables?.VCPKG_CHAINLOAD_TOOLCHAIN_FILE !==
    "${sourceDir}/cmake/toolchains/clang-p2996.cmake" ||
  inherited?.cacheVariables?.SYMPHONY_ENABLE_REFLECTION !== "ON"
) {
  process.exit(1);
}
JS
grep -Fq 'set(CMAKE_CXX_FLAGS_INIT "-stdlib=libc++")' "${p2996_toolchain}"
grep -Fq 'set(CMAKE_EXE_LINKER_FLAGS_INIT "-fuse-ld=lld ${_symphony_p2996_rpaths}")' \
  "${p2996_toolchain}"
grep -Fq '"${PROJECT_SOURCE_DIR}/tests/fixtures/p2996_reflection_probe.cpp"' \
  cmake/CheckReflection.cmake
grep -Fq 'CMAKE_CONFIGURE_DEPENDS' cmake/CheckReflection.cmake
grep -Fq 'unset(SYMPHONY_CXX26_REFLECTION_SUPPORTED CACHE)' \
  cmake/CheckReflection.cmake
grep -Fq 'std::meta::nonstatic_data_members_of(' "${p2996_probe}"
grep -Fq 'template for (constexpr auto member : members)' "${p2996_probe}"
grep -Fq "find /opt/clang-p2996/lib -type f -name 'libc++.so.1*'" \
  "${containerfile}"
grep -Fq 'ldconfig' "${containerfile}"
grep -Fq -- '-fuse-ld=lld tests/fixtures/p2996_reflection_probe.cpp' \
  "${containerfile}"
grep -Fq '"/opt/clang-p2996/bin/ld.lld"' "${containerfile}"
grep -Fq 'libc\+\+\.so\.1 => /opt/clang-p2996/' "${containerfile}"
test -x "${p2996_workflow_runner}"
grep -Fq './scripts/run-clang-reflection-workflow.sh' "${containerfile}"
grep -Fq 'bash -lc "./scripts/run-clang-reflection-workflow.sh"' \
  scripts/devcontainer-build.sh
grep -Fq 'CLANG_P2996_ARTIFACT_REF: ghcr.io/${{ github.repository_owner }}/symphony-toolchain-clang-p2996:7220baffd57ea5b0f8cf59bee494dd5b7cc2b748-amd64-77b98dd8970c509c9492ad30e19a4ce6dbb6474fc14b167b9aed6094fd9bc276' \
  .github/workflows/compiler-matrix.yml
grep -Fq 'Probe immutable clang-p2996 package' \
  .github/workflows/compiler-matrix.yml
grep -Fq 'Immutable clang-p2996 package is required for validation' \
  .github/workflows/compiler-matrix.yml
grep -Fq 'clang-p2996-artifact=docker-image://${{ needs.clang-p2996-artifact.outputs.ref }}@${{ needs.clang-p2996-artifact.outputs.digest }}' \
  .github/workflows/compiler-matrix.yml
if grep -Fq 'cache-to: type=gha,mode=min,scope=symphony-clang-p2996-artifact-' \
    .github/workflows/compiler-matrix.yml; then
  echo "clang-p2996 package still writes its multi-gigabyte artifact to Actions cache" >&2
  exit 1
fi
test "$(grep -Fc -- '-DCMAKE_CXX_SCAN_FOR_MODULES=OFF' "${ut_port}")" -eq 1
test "$(grep -Fc -- '-DUT_ENABLE_MODULES=OFF' "${ut_port}")" -eq 1
node -e '
  const fs = require("node:fs");
  const manifest = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
  if (manifest["port-version"] !== 1) process.exit(1);
' "${ut_manifest}"
test "$(
  grep -Fc 'openalgz/ut | `fc3f5a9c36dfc56bd2cb0eab07733005e5af7b74`; source SHA-512' \
    "${upstream_lock}"
)" -eq 1
grep -F 'openalgz/ut | `fc3f5a9c36dfc56bd2cb0eab07733005e5af7b74`; source SHA-512' \
  "${upstream_lock}" | grep -Fq 'overlay port revision `1`'
grep -Fq '#error "p2996 differential test requires reflection"' "${p2996_test}"
grep -Fq 'run_vcpkg_install()' "${devcontainer_setup}"
grep -Fq 'show_vcpkg_failure_logs()' "${devcontainer_setup}"
test "$(grep -Fc 'run_vcpkg_install ' "${devcontainer_setup}")" -eq 3

setup_fixture="$(mktemp -d)"
readonly setup_fixture
trap 'rm -rf "${setup_fixture}"' EXIT
mkdir -p "${setup_fixture}/bin"
cat >"${setup_fixture}/bin/cmake" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" != "--workflow --fresh --preset clang-reflection" ]]; then
  exit 65
fi
if [[ "${FAKE_CMAKE_WRITE_LOG:-false}" == true ]]; then
  {
    printf '%s\n' 'retained compiler diagnostic'
    printf '%s%s%s\n' 'LINEAR_API_' 'KEY ' 'must-not-appear-space'
    printf '%s\n' '  wrapper:'
    printf '%s\n' '    must-not-appear-deep-continuation'
    printf '%s\n' 'https://user:must-not-appear-url@example.invalid/'
  } >"${SYMPHONY_CMAKE_CONFIGURE_LOG}"
fi
exit "${FAKE_CMAKE_STATUS:-0}"
EOF
chmod +x "${setup_fixture}/bin/cmake"
set +e
p2996_failure="$(
  PATH="${setup_fixture}/bin:${PATH}" \
    FAKE_CMAKE_STATUS=47 \
    FAKE_CMAKE_WRITE_LOG=true \
    SYMPHONY_CMAKE_CONFIGURE_LOG="${setup_fixture}/configure.log" \
    "${p2996_workflow_runner}" 2>&1
)"
readonly p2996_status=$?
set -e
test "${p2996_status}" -eq 47
grep -Fq 'retained compiler diagnostic' <<<"${p2996_failure}"
test "$(
  grep -Fc '[redacted secret-bearing build log line]' <<<"${p2996_failure}"
)" -eq 4
if grep -Fq 'must-not-appear-' <<<"${p2996_failure}"; then
  echo "clang-reflection diagnostic runner leaked a secret-shaped value" >&2
  exit 1
fi
rm "${setup_fixture}/configure.log"
cat >"${setup_fixture}/bin/tail" <<'EOF'
#!/usr/bin/env bash
exit 9
EOF
chmod +x "${setup_fixture}/bin/tail"
set +e
p2996_render_failure="$(
  PATH="${setup_fixture}/bin:${PATH}" \
    FAKE_CMAKE_STATUS=49 \
    FAKE_CMAKE_WRITE_LOG=true \
    SYMPHONY_CMAKE_CONFIGURE_LOG="${setup_fixture}/configure.log" \
    "${p2996_workflow_runner}" 2>&1
)"
readonly p2996_render_status=$?
set -e
test "${p2996_render_status}" -eq 49
grep -Fq 'failed to render clang-reflection configure diagnostics' \
  <<<"${p2996_render_failure}"
rm "${setup_fixture}/bin/tail"
rm "${setup_fixture}/configure.log"
printf '%s\n' 'stale diagnostic must not appear' >"${setup_fixture}/configure.log"
set +e
stale_p2996_failure="$(
  PATH="${setup_fixture}/bin:${PATH}" \
    FAKE_CMAKE_STATUS=48 \
    SYMPHONY_CMAKE_CONFIGURE_LOG="${setup_fixture}/configure.log" \
    "${p2996_workflow_runner}" 2>&1
)"
readonly stale_p2996_status=$?
set -e
test "${stale_p2996_status}" -eq 64
grep -Fq 'test configure-log override must not exist before invocation' \
  <<<"${stale_p2996_failure}"
if grep -Fq 'stale diagnostic' <<<"${stale_p2996_failure}"; then
  echo "clang-reflection diagnostic runner attributed a stale log" >&2
  exit 1
fi
rm "${setup_fixture}/configure.log"
cat >"${setup_fixture}/bin/python3" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" != "./scripts/check-p2996-compile-commands.py" ||
      "$2" != "build/clang-reflection/compile_commands.json" ||
      "$3" != /tmp/* ]]; then
  exit 66
fi
EOF
chmod +x "${setup_fixture}/bin/python3"
cat >"${setup_fixture}/bin/ninja" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" != "-C build/clang-reflection -t commands symphony_p2996_tests" ]]; then
  exit 67
fi
printf '%s\n' \
  '/opt/clang-p2996/bin/clang++ -stdlib=libc++ -fuse-ld=lld -Wl,-rpath,/opt/clang-p2996/lib -o tests/symphony_p2996_tests'
EOF
chmod +x "${setup_fixture}/bin/ninja"
test -z "$(
  PATH="${setup_fixture}/bin:${PATH}" \
    FAKE_CMAKE_STATUS=0 \
    SYMPHONY_CMAKE_CONFIGURE_LOG="${setup_fixture}/configure.log" \
    "${p2996_workflow_runner}" 2>&1
)"
rm "${setup_fixture}/bin/python3" "${setup_fixture}/bin/ninja"
test -s "${build_log_redactor}"
mkdir -p "${setup_fixture}/.build/vcpkg/buildtrees/stale"
printf '%s\n' 'stale cached diagnostic' \
  >"${setup_fixture}/.build/vcpkg/buildtrees/stale/install-stale-out.log"
cat >"${setup_fixture}/.build/vcpkg/vcpkg" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

readonly status="${FAKE_VCPKG_STATUS:-0}"
if [[ "${status}" -eq 0 ]]; then
  exit 0
fi
if [[ "${FAKE_VCPKG_WRITE_LOGS:-true}" != true ]]; then
  exit "${status}"
fi

mkdir -p .build/vcpkg/buildtrees/current
second=1
for name in z-oldest y-older x-current w-current v-current u-current t-current; do
  log_path=".build/vcpkg/buildtrees/current/install-${name}-out.log"
  printf 'current log %s\n' "${name}" \
    >"${log_path}"
  printf -v timestamp '203001010000.%02d' "${second}"
  touch -t "${timestamp}" "${log_path}"
  second=$((second + 1))
done
{
  printf '%s\n' 'pre-tail sentinel must not appear'
  line=1
  while [[ "${line}" -le 130 ]]; do
    printf 'bounded line %03d\n' "${line}"
    line=$((line + 1))
  done
  readonly hidden_suffix='must-not-appear'
  printf '%s%s%s\n' 'LINEAR_API_' 'KEY=' "linear-${hidden_suffix}"
  printf '%s%s%s\n' 'pass' 'word=' "password-${hidden_suffix}"
  printf '%s%s%s\n' 'to' 'ken=' "token-${hidden_suffix}"
  printf '%s%s%s\n' 'sec' 'ret=' "secret-${hidden_suffix}"
  printf '%s%s%s\n' 'AWS_SECRET_ACCESS_' 'KEY=' "aws-${hidden_suffix}"
  printf '%s%s%s\n' 'Author' 'ization: Basic ' "basic-${hidden_suffix}"
  printf '%s%s%s\n' 'DOCKER_VOLUME_OWNER_' 'TOKEN=' "docker-${hidden_suffix}"
  printf '%s%s%s\n' 'OPENSYMPHONY_ACCEPTANCE_OWNER_' 'TOKEN=' \
    "acceptance-${hidden_suffix}"
  printf '%s%s%s\n' 'SYMPHONY_FIXTURE_TRACKER_' 'SECRET=' \
    "fixture-${hidden_suffix}"
  printf '%0400d\n' 0
  printf '%s\n' 'canonical stdout final sentinel'
} >.build/vcpkg/buildtrees/current/stdout-a-newest.log
touch -t 203001010000.08 .build/vcpkg/buildtrees/current/stdout-a-newest.log
exit "${status}"
EOF
chmod +x "${setup_fixture}/.build/vcpkg/vcpkg"

setup_success="$(
  cd "${setup_fixture}"
  # shellcheck source=/dev/null
  source "${OLDPWD}/${devcontainer_setup}"
  FAKE_VCPKG_STATUS=0 run_vcpkg_install --clean-after-build 2>&1
)"
readonly setup_success
if [[ -n "${setup_success}" ]]; then
  echo "successful vcpkg install emitted unexpected diagnostics" >&2
  exit 1
fi

set +e
setup_failure="$(
  cd "${setup_fixture}"
  # shellcheck source=/dev/null
  source "${OLDPWD}/${devcontainer_setup}"
  FAKE_VCPKG_STATUS=42 run_vcpkg_install --clean-after-build 2>&1
)"
setup_status=$?
set -e
readonly setup_failure setup_status
if [[ "${setup_status}" -ne 42 ]]; then
  echo "vcpkg diagnostic wrapper did not preserve failure status 42" >&2
  exit 1
fi
if [[ "$(grep -Fc '===== ' <<<"${setup_failure}")" -ne 6 ]]; then
  echo "vcpkg diagnostics did not emit exactly six current logs" >&2
  exit 1
fi
if [[ "$(
  grep -F '===== ' <<<"${setup_failure}" | sed -n '1p'
)" != "===== .build/vcpkg/buildtrees/current/stdout-a-newest.log =====" ]]; then
  echo "vcpkg diagnostics did not emit the newest log first" >&2
  exit 1
fi
if ! grep -Fq 'canonical stdout final sentinel' <<<"${setup_failure}"; then
  echo "vcpkg diagnostics omitted the final line of the newest log" >&2
  exit 1
fi
if grep -Fq 'pre-tail sentinel must not appear' <<<"${setup_failure}"; then
  echo "vcpkg diagnostics exceeded the 120-line tail bound" >&2
  exit 1
fi
if [[ "$(grep -Fc '[redacted secret-bearing build log line]' <<<"${setup_failure}")" -ne 9 ]]; then
  echo "vcpkg diagnostics did not suppress every credential-shaped fixture line" >&2
  exit 1
fi
if grep -Eq '(linear|password|token|secret|aws|basic|docker|acceptance|fixture)-must-not-appear' \
    <<<"${setup_failure}"; then
  echo "vcpkg diagnostics exposed a secret-bearing line" >&2
  exit 1
fi
if grep -Fq 'stale cached diagnostic' <<<"${setup_failure}"; then
  echo "vcpkg diagnostics emitted a stale cached log" >&2
  exit 1
fi
if grep -Fq 'current log z-oldest' <<<"${setup_failure}" ||
    grep -Fq 'current log y-older' <<<"${setup_failure}"; then
  echo "vcpkg diagnostics exceeded the six-newest-log bound" >&2
  exit 1
fi
if awk 'length($0) > 320 { exit 1 }' <<<"${setup_failure}"; then
  :
else
  echo "vcpkg diagnostic line exceeded the output bound" >&2
  exit 1
fi
if ! awk 'length($0) == 303 && /\.\.\.$/ { found=1 } END { exit !found }' \
    <<<"${setup_failure}"; then
  echo "vcpkg diagnostic wrapper did not truncate the benign long line" >&2
  exit 1
fi

rm -rf "${setup_fixture}/.build/vcpkg/buildtrees/current"
set +e
setup_without_logs="$(
  cd "${setup_fixture}"
  # shellcheck source=/dev/null
  source "${OLDPWD}/${devcontainer_setup}"
  FAKE_VCPKG_STATUS=23 FAKE_VCPKG_WRITE_LOGS=false \
    run_vcpkg_install --clean-after-build 2>&1
)"
setup_without_logs_status=$?
set -e
readonly setup_without_logs setup_without_logs_status
if [[ "${setup_without_logs_status}" -ne 23 ]]; then
  echo "vcpkg empty-log diagnostic did not preserve failure status 23" >&2
  exit 1
fi
if ! grep -Fq 'current vcpkg attempt produced no nonempty build logs' \
    <<<"${setup_without_logs}"; then
  echo "vcpkg empty-log failure lacked an explicit current-attempt diagnostic" >&2
  exit 1
fi
if grep -Fq 'stale cached diagnostic' <<<"${setup_without_logs}"; then
  echo "vcpkg diagnostics substituted a stale log for an empty attempt" >&2
  exit 1
fi

stage_block() {
  local stage="$1"
  awk -v target="${stage}" '
    $0 ~ ("^FROM .* AS " target "$") {
      printing = 1
    }
    printing && seen && /^FROM / {
      exit
    }
    printing {
      print
      seen = 1
    }
  ' "${containerfile}"
}

workflow_step_block() {
  local step="$1"
  awk -v target="${step}" '
    $0 == "      - name: " target {
      printing = 1
    }
    printing && seen && /^      - (name:|uses:)/ {
      exit
    }
    printing {
      print
      seen = 1
    }
  ' <<<"${llvm_analysis_job}"
}

workflow_step_block_for_job() {
  local job_text="$1"
  local step="$2"
  awk -v target="${step}" '
    $0 == "      - name: " target {
      printing = 1
    }
    printing && seen && /^      - (name:|uses:)/ {
      exit
    }
    printing {
      print
      seen = 1
    }
  ' <<<"${job_text}"
}

workflow_job_block() {
  local job="$1"
  awk -v target="${job}" '
    $0 == "  " target ":" {
      printing = 1
    }
    printing && seen && /^  [[:alnum:]_-]+:/ {
      exit
    }
    printing {
      print
      seen = 1
    }
  ' "${workflow}"
}

workflow_input_block() {
  local input="$1"
  awk -v target="${input}" '
    $0 == "      " target ":" {
      printing = 1
    }
    printing && seen &&
      (/^      [[:alnum:]_-]+:/ || /^[^[:space:]]/) {
      exit
    }
    printing {
      print
      seen = 1
    }
  ' "${workflow}"
}

readonly clang_commit=7220baffd57ea5b0f8cf59bee494dd5b7cc2b748
readonly clang_artifact_scope="symphony-clang-p2996-artifact-${clang_commit}-v1"
readonly clang_artifact_recipe_sha256=77b98dd8970c509c9492ad30e19a4ce6dbb6474fc14b167b9aed6094fd9bc276

clang_recipe_sha256="$(
  {
    awk '/^FROM compiler-build-base AS gcc-builder/{exit} {print}' "${containerfile}"
    cat "${cmake_installer}"
    awk '
      /^FROM compiler-build-base AS clang-builder/ { emit = 1 }
      /^FROM compiler-build-base AS symphony-clang-p2996/ { exit }
      emit { print }
    ' "${containerfile}"
    cat "${p2996_probe}"
  } | if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  else
    shasum -a 256 | awk '{print $1}'
  fi
)"
readonly clang_recipe_sha256
test "${clang_recipe_sha256}" = "${clang_artifact_recipe_sha256}"

grep -Fq \
  'ARG CODEX_BASE=ghcr.io/openai/codex-universal@sha256:905e512f36460e1be4cfedb30928a8a28299edb0fcd5de7998ceaa72d27fe304' \
  "${containerfile}"
grep -Fq \
  '# syntax=docker/dockerfile:1.10@sha256:865e5dd094beca432e8c0a1d5e1c465db5f998dca4e439981029b3b81fb39ed5' \
  "${containerfile}"

grep -Fq 'x86_64)' "${cmake_installer}"
grep -Fq 'readonly CMAKE_PLATFORM=linux-x86_64' "${cmake_installer}"
grep -Fq \
  'readonly CMAKE_SHA256=3864eb649b4466ae126a64bbde1657adad78efbbaa068bf38201de5cf1b5349f' \
  "${cmake_installer}"
grep -Fq 'aarch64 | arm64)' "${cmake_installer}"
grep -Fq 'readonly CMAKE_PLATFORM=linux-aarch64' "${cmake_installer}"
grep -Fq \
  'readonly CMAKE_SHA256=e98bb53e0b00a8f672424517d34c05bb9b94fd1c888c89e0b81bc8df51d1a94b' \
  "${cmake_installer}"

grep -Fq 'amd64) llvm_target=X86' "${containerfile}"
grep -Fq 'arm64) llvm_target=AArch64' "${containerfile}"
grep -Fq \
  'amd64) llvm_platform=X64; llvm_sha256=df0e1ecf16caf3489a272a5eea4eec9b0d82878f6477fa309504f918a0006384' \
  "${containerfile}"
grep -Fq \
  'arm64) llvm_platform=ARM64; llvm_sha256=805efad2bb91cb4967fa569e0881d10c0f69c04461cf671cccbae19f547acc34' \
  "${containerfile}"
test "$(grep -Fc 'compile_jobs="$(nproc)"' "${containerfile}")" = "1"
test "$(
  grep -Fc 'if ((compile_jobs > 4)); then compile_jobs=4; fi' "${containerfile}"
)" = "1"
grep -Fq 'LLVM_PARALLEL_COMPILE_JOBS="${compile_jobs}"' "${containerfile}"
grep -Fq 'LLVM_PARALLEL_LINK_JOBS=1' "${containerfile}"
test "$(grep -Fc "ARG CLANG_P2996_COMMIT=${clang_commit}" "${containerfile}")" -eq 2
grep -Fq "| bloomberg/clang-p2996 | \`${clang_commit}\`" "${upstream_lock}"
grep -Fq 'cmake --build /tmp/llvm-build --target install-distribution-stripped -j "${compile_jobs}"' \
  "${containerfile}"
grep -Fq 'https://ftpmirror.gnu.org/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.xz' \
  "${containerfile}"
test "$(
  grep -Fc \
    -- 'curl --fail --location --retry 5 --retry-all-errors --retry-max-time 3600' \
    "${containerfile}"
)" = "6"
test "$(
  grep -Fc \
    -- '--connect-timeout 30 --max-time 1800 --speed-limit 1024 --speed-time 120' \
    "${containerfile}"
)" = "6"
if grep -Fq 'xz --test llvm.tar.xz' "${containerfile}" ||
  grep -Fq 'tar -tf llvm.tar.xz' "${containerfile}"; then
  echo "LLVM release archive must be authenticated and decompressed exactly once" >&2
  exit 1
fi
test "$(grep -Fc 'tar -xJf llvm.tar.xz' "${containerfile}")" = "1"

if grep -Fq 'libc6,x86-64' "${containerfile}"; then
  echo "toolchain runtime contract still depends on an AMD64 ldconfig presentation string" >&2
  exit 1
fi

gcc_runtime="$(stage_block symphony-gcc-runtime)"
grep -Fq 'ARG SOURCE_REVISION=unknown' <<<"${gcc_runtime}"
grep -Fq 'org.opencontainers.image.revision="${SOURCE_REVISION}"' <<<"${gcc_runtime}"
grep -Fq 'ENTRYPOINT []' <<<"${gcc_runtime}"

analysis_runtime="$(stage_block symphony-analysis)"
grep -Fq 'FROM symphony-gcc-runtime AS symphony-analysis' <<<"${analysis_runtime}"
grep -Fq 'ARG SOURCE_REVISION=unknown' <<<"${analysis_runtime}"
grep -Fq 'org.opencontainers.image.revision="${SOURCE_REVISION}"' <<<"${analysis_runtime}"

clang_runtime="$(stage_block symphony-ci-clang)"
grep -Fq 'ARG SOURCE_REVISION=unknown' <<<"${clang_runtime}"
grep -Fq 'org.opencontainers.image.revision="${SOURCE_REVISION}"' <<<"${clang_runtime}"
grep -Fq 'ENTRYPOINT []' <<<"${clang_runtime}"

clang_artifact="$(stage_block clang-p2996-artifact)"
grep -Fq 'FROM scratch AS clang-p2996-artifact' <<<"${clang_artifact}"
grep -Fq 'COPY --from=clang-builder /opt/clang-p2996 /opt/clang-p2996' \
  <<<"${clang_artifact}"

clang_package="$(stage_block symphony-clang-p2996)"
grep -Fq 'FROM compiler-build-base AS symphony-clang-p2996' <<<"${clang_package}"
grep -Fq 'COPY --from=clang-p2996-artifact /opt/clang-p2996 /opt/clang-p2996' \
  <<<"${clang_package}"

grep -Fq 'default: amd64' "${workflow}"
seed_input="$(workflow_input_block seed_clang_artifact_package)"
grep -Fxq '        required: false' <<<"${seed_input}"
grep -Fxq '        default: false' <<<"${seed_input}"
grep -Fxq '        type: boolean' <<<"${seed_input}"
grep -Fq "runs-on: \${{ inputs.architecture == 'arm64' && 'ubuntu-24.04-arm' || 'ubuntu-24.04' }}" \
  "${workflow}"
grep -Fq 'platforms: ${{ env.TOOLCHAIN_PLATFORM }}' "${workflow}"
grep -Fq 'scope=symphony-gcc16-${{ inputs.architecture }}-min-v3' "${workflow}"
grep -Fq 'if: ${{ inputs.architecture == '\''arm64'\'' && inputs.lineage != '\''gcc16'\'' }}' \
  "${workflow}"
grep -Fq 'target: symphony-gcc-validation' "${workflow}"
grep -Fq 'target: symphony-clang-validation' "${workflow}"
gcc_job="$(workflow_job_block gcc16)"
clang_job="$(workflow_job_block clang-p2996)"
clang_artifact_job="$(workflow_job_block clang-p2996-artifact)"
validate_job="$(workflow_job_block validate-inputs)"
grep -Fq \
  'group: compiler-matrix-${{ github.ref }}-${{ inputs.lineage }}-${{ inputs.architecture }}' \
  "${workflow}"
grep -Fq \
  "group: clang-p2996-artifact-${clang_commit}-amd64-${clang_artifact_recipe_sha256}" \
  <<<"${clang_artifact_job}"
grep -Fq '      cancel-in-progress: false' <<<"${clang_artifact_job}"
publication_boundary_step="$(
  workflow_step_block_for_job "${validate_job}" \
    "Restrict clang artifact publication to its exact lane"
)"
grep -Fxq \
  "        if: \${{ inputs.seed_clang_artifact_package && (inputs.lineage != 'clang-p2996' || inputs.architecture != 'amd64') }}" \
  <<<"${publication_boundary_step}"
grep -Fq \
  'clang artifact publication requires lineage=clang-p2996 and architecture=amd64' \
  <<<"${publication_boundary_step}"
gcc_base_step="$(
  workflow_step_block_for_job "${gcc_job}" \
    "Persist stable GCC 16.1 base before source validation"
)"
gcc_validation_step="$(
  workflow_step_block_for_job "${gcc_job}" \
    "Build and validate GCC toolchain without loading it"
)"
clang_probe_step="$(
  workflow_step_block_for_job "${clang_artifact_job}" \
    "Probe immutable clang-p2996 package"
)"
clang_publish_step="$(
  workflow_step_block_for_job "${clang_artifact_job}" \
    "Publish isolated clang-p2996 package before source validation"
)"
clang_select_step="$(
  workflow_step_block_for_job "${clang_artifact_job}" \
    "Select captured clang-p2996 package digest"
)"
clang_validation_step="$(
  workflow_step_block_for_job "${clang_job}" \
    "Build and validate clang-p2996 without loading it"
)"
grep -Fxq '          target: symphony-gcc-runtime' <<<"${gcc_base_step}"
grep -Fxq '          target: symphony-gcc-validation' <<<"${gcc_validation_step}"
grep -Fxq \
  "        if: \${{ steps.clang-artifact-probe.outputs.hit != 'true' && inputs.seed_clang_artifact_package }}" \
  <<<"${clang_publish_step}"
grep -Fxq '          target: clang-p2996-artifact' <<<"${clang_publish_step}"
grep -Fxq '          target: symphony-clang-validation' <<<"${clang_validation_step}"
for step in "${gcc_base_step}" "${gcc_validation_step}"; do
  grep -Fxq \
    '        uses: docker/build-push-action@53b7df96c91f9c12dcc8a07bcb9ccacbed38856a' \
    <<<"${step}"
  grep -Fxq '          context: .' <<<"${step}"
  grep -Fxq '          file: containers/Containerfile' <<<"${step}"
  grep -Fxq '          platforms: ${{ env.TOOLCHAIN_PLATFORM }}' <<<"${step}"
  grep -Fxq '          outputs: type=cacheonly' <<<"${step}"
  grep -Fxq '          load: false' <<<"${step}"
  grep -Fxq '          push: false' <<<"${step}"
  grep -Fxq '          builder: ${{ steps.buildx.outputs.name }}' <<<"${step}"
  grep -Fxq \
    '          cache-from: type=gha,scope=symphony-gcc16-${{ inputs.architecture }}-min-v3' \
    <<<"${step}"
done
grep -Fxq \
  '        uses: docker/build-push-action@53b7df96c91f9c12dcc8a07bcb9ccacbed38856a' \
  <<<"${clang_publish_step}"
grep -Fxq '          context: .' <<<"${clang_publish_step}"
grep -Fxq '          file: containers/Containerfile' <<<"${clang_publish_step}"
grep -Fxq '          platforms: linux/amd64' <<<"${clang_publish_step}"
grep -Fxq '          push: true' <<<"${clang_publish_step}"
grep -Fxq '          provenance: mode=max' <<<"${clang_publish_step}"
grep -Fxq '          sbom: true' <<<"${clang_publish_step}"
grep -Fxq '          load: false' <<<"${clang_publish_step}"
grep -Fxq '          builder: ${{ steps.buildx.outputs.name }}' <<<"${clang_publish_step}"
grep -Fxq \
  "          cache-from: type=gha,scope=${clang_artifact_scope}" \
  <<<"${clang_publish_step}"
grep -Fq 'echo "digest=${digest}"' <<<"${clang_probe_step}"
grep -Fq 'PROBED_DIGEST: ${{ steps.clang-artifact-probe.outputs.digest }}' \
  <<<"${clang_select_step}"
grep -Fq 'PUBLISHED_DIGEST: ${{ steps.clang-artifact-publish.outputs.digest }}' \
  <<<"${clang_select_step}"
grep -Fq 'digest="${PROBED_DIGEST}"' <<<"${clang_select_step}"
grep -Fq 'digest="${PUBLISHED_DIGEST}"' <<<"${clang_select_step}"
grep -Fxq \
  '        uses: docker/build-push-action@53b7df96c91f9c12dcc8a07bcb9ccacbed38856a' \
  <<<"${clang_validation_step}"
grep -Fxq '          context: .' <<<"${clang_validation_step}"
grep -Fxq '          file: containers/Containerfile' <<<"${clang_validation_step}"
grep -Fxq '          outputs: type=cacheonly' <<<"${clang_validation_step}"
grep -Fxq '          load: false' <<<"${clang_validation_step}"
grep -Fxq '          push: false' <<<"${clang_validation_step}"
grep -Fxq '          builder: ${{ steps.buildx.outputs.name }}' <<<"${clang_validation_step}"
grep -Fq \
  'clang-p2996-artifact=docker-image://${{ needs.clang-p2996-artifact.outputs.ref }}@${{ needs.clang-p2996-artifact.outputs.digest }}' \
  <<<"${clang_validation_step}"
grep -Fxq \
  '          cache-to: type=gha,mode=min,scope=symphony-gcc16-${{ inputs.architecture }}-min-v3,timeout=30m,ignore-error=true' \
  <<<"${gcc_base_step}"
if grep -Fq '          cache-to:' <<<"${clang_artifact_job}"; then
  echo "clang artifact package must not consume GitHub Actions cache storage" >&2
  exit 1
fi
test "$(grep -Fc "scope=${clang_artifact_scope}" <<<"${clang_artifact_job}")" -eq 1
if grep -Fq '          cache-to:' <<<"${gcc_validation_step}" ||
  grep -Fq '          cache-to:' <<<"${clang_validation_step}"; then
  echo "source validation must not overwrite a stable toolchain cache scope" >&2
  exit 1
fi
test "$(
  grep -Fn '      - name: Persist stable GCC 16.1 base before source validation' \
    <<<"${gcc_job}" | cut -d: -f1
)" -lt "$(
  grep -Fn '      - name: Build and validate GCC toolchain without loading it' \
    <<<"${gcc_job}" | cut -d: -f1
)"
grep -Fq '      packages: write' <<<"${clang_artifact_job}"
grep -Fq '      packages: read' <<<"${clang_job}"
if grep -Fq '      packages: write' <<<"${clang_job}"; then
  echo "source validation must not retain compiler-package publication authority" >&2
  exit 1
fi
gcc_setup_line="$(
  grep -Fn \
    '      - uses: docker/setup-buildx-action@bb05f3f5519dd87d3ba754cc423b652a5edd6d2c' \
    <<<"${gcc_job}" | cut -d: -f1
)"
gcc_base_line="$(
  grep -Fn '      - name: Persist stable GCC 16.1 base before source validation' \
    <<<"${gcc_job}" | cut -d: -f1
)"
gcc_restore_line="$(
  grep -Fn '      - name: Restore bounded GCC compiler cache' \
    <<<"${gcc_job}" | cut -d: -f1
)"
gcc_bridge_line="$(
  grep -Fn '      - name: Bridge GCC compiler cache into BuildKit' \
    <<<"${gcc_job}" | cut -d: -f1
)"
gcc_validation_line="$(
  grep -Fn '      - name: Build and validate GCC toolchain without loading it' \
    <<<"${gcc_job}" | cut -d: -f1
)"
test "${gcc_setup_line}" -lt "${gcc_base_line}"
test "${gcc_base_line}" -lt "${gcc_restore_line}"
test "${gcc_restore_line}" -lt "${gcc_bridge_line}"
test "${gcc_bridge_line}" -lt "${gcc_validation_line}"

clang_setup_line="$(
  grep -Fn \
    '      - uses: docker/setup-buildx-action@bb05f3f5519dd87d3ba754cc423b652a5edd6d2c' \
    <<<"${clang_job}" | cut -d: -f1
)"
clang_restore_line="$(
  grep -Fn '      - name: Restore bounded clang-p2996 compiler cache' \
    <<<"${clang_job}" | cut -d: -f1
)"
clang_bridge_line="$(
  grep -Fn '      - name: Bridge clang-p2996 compiler cache into BuildKit' \
    <<<"${clang_job}" | cut -d: -f1
)"
clang_validation_line="$(
  grep -Fn '      - name: Build and validate clang-p2996 without loading it' \
    <<<"${clang_job}" | cut -d: -f1
)"
test "${clang_setup_line}" -lt "${clang_restore_line}"
test "${clang_restore_line}" -lt "${clang_bridge_line}"
test "${clang_bridge_line}" -lt "${clang_validation_line}"
clang_artifact_setup_line="$(
  grep -Fn \
    '      - uses: docker/setup-buildx-action@bb05f3f5519dd87d3ba754cc423b652a5edd6d2c' \
    <<<"${clang_artifact_job}" | cut -d: -f1
)"
clang_probe_line="$(
  grep -Fn '      - name: Probe immutable clang-p2996 package' \
    <<<"${clang_artifact_job}" | cut -d: -f1
)"
clang_publish_line="$(
  grep -Fn '      - name: Publish isolated clang-p2996 package before source validation' \
    <<<"${clang_artifact_job}" | cut -d: -f1
)"
clang_select_line="$(
  grep -Fn '      - name: Select captured clang-p2996 package digest' \
    <<<"${clang_artifact_job}" | cut -d: -f1
)"
test "${clang_artifact_setup_line}" -lt "${clang_probe_line}"
test "${clang_probe_line}" -lt "${clang_publish_line}"
test "${clang_publish_line}" -lt "${clang_select_line}"
llvm_analysis_job="$(workflow_job_block llvm-analysis)"
analysis_base_step="$(
  workflow_step_block "Persist stable LLVM analysis base before source validation"
)"
analysis_validation_step="$(
  workflow_step_block "Build and validate LLVM analysis without loading it"
)"
for step in "${analysis_base_step}" "${analysis_validation_step}"; do
  grep -Fxq \
    '        uses: docker/build-push-action@53b7df96c91f9c12dcc8a07bcb9ccacbed38856a' \
    <<<"${step}"
  grep -Fxq '          context: .' <<<"${step}"
  grep -Fxq '          file: containers/Containerfile' <<<"${step}"
  grep -Fxq '          platforms: linux/amd64' <<<"${step}"
  grep -Fxq '          builder: ${{ steps.buildx.outputs.name }}' <<<"${step}"
  grep -Fxq '          outputs: type=cacheonly' <<<"${step}"
  grep -Fxq '          load: false' <<<"${step}"
  grep -Fxq '          push: false' <<<"${step}"
  grep -Fxq '          cache-from: type=gha,scope=symphony-llvm-analysis-min-v2' <<<"${step}"
  for key in uses context file target platforms outputs load push builder cache-from; do
    test "$(grep -Ec "^[[:space:]]+${key}:" <<<"${step}")" = "1"
  done
done
grep -Fxq \
  '          cache-to: type=gha,mode=min,scope=symphony-llvm-analysis-min-v2,timeout=30m,ignore-error=true' \
  <<<"${analysis_base_step}"
if grep -Fq '          cache-to:' <<<"${analysis_validation_step}"; then
  echo "analysis validation must not overwrite the stable analysis cache scope" >&2
  exit 1
fi
grep -Fxq '          target: symphony-analysis' <<<"${analysis_base_step}"
grep -Fxq '          target: symphony-analysis-validation' <<<"${analysis_validation_step}"
setup_buildx_line="$(
  grep -Fn \
    '      - uses: docker/setup-buildx-action@bb05f3f5519dd87d3ba754cc423b652a5edd6d2c' \
    <<<"${llvm_analysis_job}" |
    cut -d: -f1
)"
setup_buildx_id_line="$(
  grep -Fn '        id: buildx' <<<"${llvm_analysis_job}" |
    cut -d: -f1
)"
base_step_line="$(
  grep -Fn \
    '      - name: Persist stable LLVM analysis base before source validation' \
    <<<"${llvm_analysis_job}" |
    cut -d: -f1
)"
restore_ccache_line="$(
  grep -Fn '      - name: Restore bounded analysis compiler cache' <<<"${llvm_analysis_job}" |
    cut -d: -f1
)"
bridge_ccache_line="$(
  grep -Fn '      - name: Bridge analysis compiler cache into BuildKit' <<<"${llvm_analysis_job}" |
    cut -d: -f1
)"
validation_step_line="$(
  grep -Fn \
    '      - name: Build and validate LLVM analysis without loading it' \
    <<<"${llvm_analysis_job}" |
    cut -d: -f1
)"
test "${setup_buildx_line}" -lt "${setup_buildx_id_line}"
test "${setup_buildx_id_line}" -lt "${base_step_line}"
test "${base_step_line}" -lt "${restore_ccache_line}"
test "${restore_ccache_line}" -lt "${bridge_ccache_line}"
test "${bridge_ccache_line}" -lt "${validation_step_line}"
test "$(grep -Fc 'outputs: type=cacheonly' "${workflow}")" = "5"
test "$(grep -Fc 'load: false' "${workflow}")" = "6"
test "$(grep -Fc 'version: v0.35.0' "${workflow}")" = "4"
grep -Fq \
  'uses: reproducible-containers/buildkit-cache-dance@5422eac04292c961a382e0f584ea0f03ad9da723' \
  "${workflow}"
grep -Fq \
  'uses: actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9' \
  "${workflow}"
grep -Fq \
  'utility-image: ghcr.io/containerd/busybox@sha256:52f73a0a43a16cf37cd0720c90887ce972fe60ee06a687ee71fb93a7ca601df7' \
  "${workflow}"

test "$(grep -Fc 'push: false' "${workflow}")" = "5"
test "$(grep -Ec '^permissions:$' "${workflow}")" = "1"
test "$(grep -Ec '^[[:space:]]*permissions:' "${workflow}")" = "3"
test "$(grep -Ec '^  contents: read$' "${workflow}")" = "1"
test "$(grep -Ec '^[[:space:]]+packages: write$' "${workflow}")" = "1"
if grep -Eq '(^|[[:space:]])write-all([[:space:]]|$)' "${workflow}"; then
  echo "compiler validation workflow must not request write-all permission" >&2
  exit 1
fi
if grep -E '^[[:space:]]+[[:alnum:]_-]+:[[:space:]]+write([[:space:]]|$)' "${workflow}" |
  grep -Fqv 'packages: write'; then
  echo "compiler workflow requested an unexpected write permission" >&2
  exit 1
fi
test "$(grep -Fc '${{ secrets.GITHUB_TOKEN }}' "${workflow}")" = "2"
if grep -F '${{ secrets.' "${workflow}" |
  grep -Fqv '${{ secrets.GITHUB_TOKEN }}'; then
  echo "compiler workflow must not consume repository secrets other than its scoped token" >&2
  exit 1
fi
test "$(grep -Ec '^[[:space:]]+push:[[:space:]]+true([[:space:]]|$)' "${workflow}")" = "1"
if grep -Eq '(^|[[:space:]])docker[[:space:]]+(buildx[[:space:]]+)?push([[:space:]]|$)|(^|[[:space:]])--push([[:space:]]|$)' \
  "${workflow}"; then
  echo "compiler workflow must not contain raw image-push commands" >&2
  exit 1
fi
if grep -Fq 'continue-on-error:' "${workflow}"; then
  echo "compiler validation workflow must fail closed" >&2
  exit 1
fi
if grep -Fq 'load: true' "${workflow}"; then
  echo "validation jobs must not import large toolchain images into Docker Engine" >&2
  exit 1
fi
if grep -Fq 'type=docker' "${workflow}"; then
  echo "validation jobs must use the cache-only exporter" >&2
  exit 1
fi
if grep -Eq '^  publish:' "${workflow}"; then
  echo "publication must remain absent until a direct-push digest ceremony is reviewed" >&2
  exit 1
fi

source_gcc_job="$(
  awk '
    $0 == "  gcc16:" {
      printing = 1
    }
    printing && seen && /^  [[:alnum:]_-]+:/ {
      exit
    }
    printing {
      print
      seen = 1
    }
  ' "${source_workflow}"
)"
grep -Fxq '    needs: metadata' <<<"${source_gcc_job}"

if grep -Fq 'setup-qemu-action' "${workflow}"; then
  echo "native compiler qualification must not install QEMU" >&2
  exit 1
fi

for config in "${devcontainer_configs[@]}"; do
  grep -Fq '"postCreateCommand": "./scripts/devcontainer-local-setup.sh ' "${config}"
  grep -Fq 'source=symphony-cpp-mise,target=/root/.local/share/mise,type=volume' "${config}"
  grep -Fq 'source=symphony-cpp-pre-commit,target=/root/.cache/pre-commit,type=volume' "${config}"
done
