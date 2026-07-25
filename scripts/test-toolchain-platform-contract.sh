#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

readonly containerfile=containers/Containerfile
readonly dockerignore=.dockerignore
readonly opensymphony_containerfile=containers/OpenSymphony.Containerfile
readonly opensymphony_dockerignore=containers/OpenSymphony.Containerfile.dockerignore
readonly opensymphony_local_bake=containers/opensymphony-local.bake.hcl
readonly opensymphony_acceptance=scripts/test-opensymphony-acceptance.sh
readonly generic_bake=containers/bake.hcl
readonly gcc16_bake=containers/gcc16-separated.bake.hcl
readonly gcc16_validation_containerfile=containers/validation/gcc16.Containerfile
readonly gcc16_validation_dockerignore=containers/validation/gcc16.Containerfile.dockerignore
readonly gcc16_runtime_candidate_bake=containers/gcc16-runtime-candidate.bake.hcl
readonly gcc16_runtime_candidate_containerfile=containers/validation/gcc16-runtime-candidate.Containerfile
readonly gcc16_runtime_candidate_dockerignore=containers/validation/gcc16-runtime-candidate.Containerfile.dockerignore
readonly p2996_bake=containers/p2996-separated.bake.hcl
readonly p2996_validation_containerfile=containers/validation/clang-p2996.Containerfile
readonly p2996_validation_dockerignore=containers/validation/clang-p2996.Containerfile.dockerignore
readonly oci_platform_checker=scripts/check-oci-platform.sh
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

grep -Fq \
  'apt-get install --yes --no-install-recommends ca-certificates ccache cmake curl git jq ninja-build nodejs tar unzip zip zstd' \
  "${source_workflow}"

bash -n "${cmake_installer}"
bash -n "${devcontainer_setup}"
bash -n "${p2996_workflow_runner}"
test -x "${oci_platform_checker}"
bash -n "${oci_platform_checker}"

readonly amd64_manifest=sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
readonly arm64_manifest=sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
readonly attestation_manifest=sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
oci_index_fixture="$(
  cat <<JSON
{
  "mediaType": "application/vnd.oci.image.index.v1+json",
  "manifests": [
    {
      "mediaType": "application/vnd.oci.image.manifest.v1+json",
      "digest": "${amd64_manifest}",
      "platform": {"os": "linux", "architecture": "amd64"}
    },
    {
      "mediaType": "application/vnd.oci.image.manifest.v1+json",
      "digest": "${arm64_manifest}",
      "platform": {"os": "linux", "architecture": "arm64"}
    },
    {
      "mediaType": "application/vnd.oci.image.manifest.v1+json",
      "digest": "${attestation_manifest}",
      "platform": {"os": "unknown", "architecture": "unknown"}
    }
  ]
}
JSON
)"
readonly oci_index_fixture
test "$(
  "${oci_platform_checker}" select-index amd64 <<<"${oci_index_fixture}"
)" = "${amd64_manifest}"
test "$(
  "${oci_platform_checker}" select-index arm64 <<<"${oci_index_fixture}"
)" = "${arm64_manifest}"
printf '%s\n' '{"os":"linux","architecture":"amd64"}' |
  "${oci_platform_checker}" validate-image amd64
printf '%s\n' '{"os":"linux","architecture":"arm64"}' |
  "${oci_platform_checker}" validate-image arm64

expect_oci_check_failure() {
  local mode="$1"
  local architecture="$2"
  local fixture="$3"
  local status
  set +e
  "${oci_platform_checker}" "${mode}" "${architecture}" \
    <<<"${fixture}" >/dev/null 2>&1
  status=$?
  set -e
  test "${status}" -ne 0
}

expect_oci_check_failure \
  select-index \
  amd64 \
  "$(jq '.manifests += [.manifests[0]]' <<<"${oci_index_fixture}")"
expect_oci_check_failure \
  select-index \
  arm64 \
  "$(jq '.manifests |= map(select(.platform.architecture != "arm64"))' \
    <<<"${oci_index_fixture}")"
expect_oci_check_failure \
  select-index \
  amd64 \
  "$(jq '.mediaType = "application/vnd.oci.image.manifest.v1+json"' \
    <<<"${oci_index_fixture}")"
expect_oci_check_failure \
  select-index \
  amd64 \
  "$(jq '.manifests[0].digest = "sha256:1234"' <<<"${oci_index_fixture}")"
expect_oci_check_failure \
  select-index \
  amd64 \
  "$(jq '.manifests[0].mediaType = "application/vnd.oci.image.index.v1+json"' \
    <<<"${oci_index_fixture}")"
expect_oci_check_failure select-index amd64 '{}'
expect_oci_check_failure select-index amd64 ''
expect_oci_check_failure \
  validate-image \
  amd64 \
  '{"os":"linux","architecture":"arm64"}'
expect_oci_check_failure \
  validate-image \
  arm64 \
  '{"os":"windows","architecture":"arm64"}'

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
  "${p2996_validation_containerfile}"
grep -Fq '"/opt/clang-p2996/bin/ld.lld"' "${p2996_validation_containerfile}"
grep -Fq 'libc\+\+\.so\.1 => /opt/clang-p2996/' "${p2996_validation_containerfile}"
test -x "${p2996_workflow_runner}"
grep -Fq './scripts/run-clang-reflection-workflow.sh' "${p2996_validation_containerfile}"
grep -Fq 'bash -lc "./scripts/run-clang-reflection-workflow.sh"' \
  scripts/devcontainer-build.sh
grep -Fq 'CLANG_P2996_ARTIFACT_REF: ghcr.io/${{ github.repository_owner }}/symphony-toolchain-clang-p2996:7220baffd57ea5b0f8cf59bee494dd5b7cc2b748-amd64-77b98dd8970c509c9492ad30e19a4ce6dbb6474fc14b167b9aed6094fd9bc276' \
  .github/workflows/compiler-matrix.yml
grep -Fq 'Probe immutable clang-p2996 package' \
  .github/workflows/compiler-matrix.yml
grep -Fq 'Immutable clang-p2996 package is required for validation' \
  .github/workflows/compiler-matrix.yml
grep -Fq 'CLANG_P2996_ARTIFACT_CONTEXT: docker-image://${{ needs.clang-p2996-artifact.outputs.ref }}@${{ needs.clang-p2996-artifact.outputs.digest }}' \
  .github/workflows/compiler-matrix.yml
if grep -Fq 'cache-to: type=gha,mode=min,scope=symphony-clang-p2996-artifact-' \
    .github/workflows/compiler-matrix.yml; then
  echo "clang-p2996 package still writes its multi-gigabyte artifact to Actions cache" >&2
  exit 1
fi
grep -Fq 'GCC16_ARTIFACT_REF: ghcr.io/${{ github.repository_owner }}/symphony-toolchain-gcc:16.1.0-${{ inputs.architecture }}-6b1431c2581c93d174792a530acd054c06979d9185117aefca7f03a46830f51d' \
  .github/workflows/compiler-matrix.yml
grep -Fq 'Resolve or publish GCC 16.1 artifact' \
  .github/workflows/compiler-matrix.yml
if grep -Fq 'cache-to: type=gha,mode=min,scope=symphony-gcc16-' \
    .github/workflows/compiler-matrix.yml; then
  echo "GCC 16.1 package still writes its multi-gigabyte artifact to Actions cache" >&2
  exit 1
fi
test -f "${gcc16_runtime_candidate_bake}"
test -f "${gcc16_runtime_candidate_containerfile}"
test -f "${gcc16_runtime_candidate_dockerignore}"
grep -Fq \
  'RUNTIME_BASE_CONTEXT must be an exact docker-image:// reference pinned by sha256 digest' \
  "${gcc16_runtime_candidate_bake}"
grep -Fq \
  'condition     = can(regex("^docker-image://[^@[:space:]]+@sha256:[0-9a-f]{64}$", RUNTIME_BASE_CONTEXT))' \
  "${gcc16_runtime_candidate_bake}"
test "$(grep -Fxc '  output = ["type=cacheonly"]' \
  "${gcc16_runtime_candidate_bake}")" -eq 1
if grep -Eq \
  '(^|[[:space:]])(tags|cache-from|cache-to)[[:space:]]*=|type=(registry|image|oci|docker|local)' \
    "${gcc16_runtime_candidate_bake}"; then
  echo "read-only GCC runtime candidate graph contains an unapproved output or cache" >&2
  exit 1
fi
grep -Fq 'FROM scratch AS runtime-base' "${gcc16_runtime_candidate_containerfile}"
grep -Fq \
  'FROM ghcr.io/containerd/busybox@sha256:52f73a0a43a16cf37cd0720c90887ce972fe60ee06a687ee71fb93a7ca601df7 AS gcc16-runtime-candidate-rootfs-audit' \
  "${gcc16_runtime_candidate_containerfile}"
if grep -Fq 'AUDIT_BASE' "${gcc16_runtime_candidate_containerfile}"; then
  echo "trusted GCC runtime audit image must not be caller-overridable" >&2
  exit 1
fi
grep -Fq \
  'source=tests/fixtures/p2996_reflection_probe.cpp,target=/tmp/gcc16-reflection-probe.cpp,ro' \
  "${gcc16_runtime_candidate_containerfile}"
grep -Fq \
  'from=runtime-base,source=/,target=/candidate,ro' \
  "${gcc16_runtime_candidate_containerfile}"
grep -Fq 'env -u LD_LIBRARY_PATH ldd' "${gcc16_runtime_candidate_containerfile}"
grep -Fq 'test -z "${LD_LIBRARY_PATH+x}"' \
  "${gcc16_runtime_candidate_containerfile}"
grep -Fq 'test "$(command -v gcc)" = "/opt/gcc-16.1/bin/gcc"' \
  "${gcc16_runtime_candidate_containerfile}"
grep -Fq 'test "$(command -v g++)" = "/opt/gcc-16.1/bin/g++"' \
  "${gcc16_runtime_candidate_containerfile}"
grep -Fq '/opt/symphony-cpp-seed' "${gcc16_runtime_candidate_containerfile}"
grep -Fq 'vcpkg_installed' "${gcc16_runtime_candidate_containerfile}"
grep -Fq '.opensymphony' "${gcc16_runtime_candidate_containerfile}"
grep -Fq '/usr/local/bin/opensymphony' \
  "${gcc16_runtime_candidate_containerfile}"
grep -Fq '/opt/opensymphony' "${gcc16_runtime_candidate_containerfile}"
grep -Fq '/tmp/install-cmake.sh' "${gcc16_runtime_candidate_containerfile}"
grep -Fq '/root/.npmrc' "${gcc16_runtime_candidate_containerfile}"
if grep -Fq -- '-o -name .npmrc' "${gcc16_runtime_candidate_containerfile}"; then
  echo "runtime audit must not classify provider-owned nested npm configuration as a credential" >&2
  exit 1
fi
grep -Fq -- "-path '/candidate/root/.azure/*'" \
  "${gcc16_runtime_candidate_containerfile}"
if grep -Fq -- "-path '*/.azure/*'" "${gcc16_runtime_candidate_containerfile}"; then
  echo "runtime audit must not classify provider source fixtures as home credentials" >&2
  exit 1
fi
test "$(grep -Ec '^RUN --network=none' \
  "${gcc16_runtime_candidate_containerfile}")" -eq 3
test "$(
  grep -Ec '^RUN([[:space:]]|$)' "${gcc16_runtime_candidate_containerfile}"
)" -eq "$(
  grep -Ec '^RUN --network=none' "${gcc16_runtime_candidate_containerfile}"
)"
test "$(grep -Fc -- '--mount=' \
  "${gcc16_runtime_candidate_containerfile}")" -eq 2
test "$(grep -Ec '^FROM[[:space:]]' \
  "${gcc16_runtime_candidate_containerfile}")" -eq 4
test "$(
  grep -E '^FROM[[:space:]]' "${gcc16_runtime_candidate_containerfile}" |
    tail -n 1
)" = 'FROM scratch AS gcc16-runtime-candidate-validation'
test "$(grep -Ec '^COPY[[:space:]]' \
  "${gcc16_runtime_candidate_containerfile}")" -eq 2
grep -Fq '/validation/gcc16-runtime-candidate-execution' \
  "${gcc16_runtime_candidate_containerfile}"
grep -Fq '/validation/gcc16-runtime-candidate-rootfs' \
  "${gcc16_runtime_candidate_containerfile}"
if grep -Eq \
  '(^|[[:space:]])(ADD|ONBUILD)([[:space:]]|$)|--mount=type=(secret|ssh)|source=\.|\[\[' \
  "${gcc16_runtime_candidate_containerfile}"; then
  echo "GCC runtime candidate validation contains an unapproved context or secret input" >&2
  exit 1
fi
cmp -s \
  <(printf '%s\n' \
    '**' \
    '!containers/validation/gcc16-runtime-candidate.Containerfile' \
    '!tests/fixtures/p2996_reflection_probe.cpp') \
  "${gcc16_runtime_candidate_dockerignore}"
grep -Fq \
  '"containers/validation/gcc16-runtime-candidate.Containerfile:gcc16-runtime-candidate-validation"' \
  scripts/check-local-preflight.sh
grep -Fq 'containers/gcc16-runtime-candidate.bake.hcl' \
  scripts/check-local-preflight.sh
grep -Fq \
  'for analysis_target in symphony-analysis-format-validation symphony-analysis-source-validation; do' \
  scripts/check-local-preflight.sh
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
  ': && /opt/clang-p2996/bin/clang++ -stdlib=libc++ -fuse-ld=lld -Wl,-rpath,/opt/clang-p2996/lib -o tests/symphony_p2996_tests && :'
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
readonly gcc_artifact_recipe_sha256=6b1431c2581c93d174792a530acd054c06979d9185117aefca7f03a46830f51d

clang_recipe_sha256="$(
  {
    awk '/^FROM compiler-build-base AS gcc-builder/{exit} {print}' "${containerfile}"
    cat "${cmake_installer}"
    awk '
      /^FROM compiler-build-base AS clang-builder/ { emit = 1 }
      /^FROM scratch AS clang-p2996-artifact-input/ { exit }
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

gcc_recipe_sha256="$(
  {
    awk '/^FROM scratch AS gcc16-artifact-input/{exit} {print}' "${containerfile}"
    cat "${cmake_installer}"
    cat "${p2996_probe}"
  } | if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  else
    shasum -a 256 | awk '{print $1}'
  fi
)"
readonly gcc_recipe_sha256
test "${gcc_recipe_sha256}" = "${gcc_artifact_recipe_sha256}"

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

toolchain_runtime_base="$(stage_block toolchain-runtime-base)"
grep -Fq 'FROM ${CODEX_BASE} AS toolchain-runtime-base' <<<"${toolchain_runtime_base}"
grep -Fq \
  'RUN --mount=type=bind,source=scripts/install-cmake.sh,target=/tmp/install-cmake.sh,ro' \
  <<<"${toolchain_runtime_base}"
if grep -Eq '^(ADD|COPY|ONBUILD)[[:space:]]' <<<"${toolchain_runtime_base}"; then
  echo "generic toolchain runtime base must not retain repository files in image layers" >&2
  exit 1
fi

gcc_runtime="$(stage_block symphony-gcc-runtime)"
grep -Fq 'FROM toolchain-runtime-base AS symphony-gcc-runtime' <<<"${gcc_runtime}"
grep -Fq 'ARG SOURCE_REVISION=unknown' <<<"${gcc_runtime}"
grep -Fq 'org.opencontainers.image.revision="${SOURCE_REVISION}"' <<<"${gcc_runtime}"
grep -Fq 'ENTRYPOINT []' <<<"${gcc_runtime}"
test "$(grep -Ec '^COPY ' <<<"${gcc_runtime}")" -eq 1
grep -Fq 'COPY --from=gcc16-artifact-input /opt/gcc-16.1 /opt/gcc-16.1' \
  <<<"${gcc_runtime}"
grep -Fq '/etc/ld.so.conf.d/00-gcc-16.1.conf' <<<"${gcc_runtime}"
if grep -Fq 'LD_LIBRARY_PATH=' <<<"${gcc_runtime}"; then
  echo "GCC runtime must establish deterministic default loader ordering without LD_LIBRARY_PATH" >&2
  exit 1
fi
gcc_artifact_input="$(stage_block gcc16-artifact-input)"
test "${gcc_artifact_input}" = 'FROM scratch AS gcc16-artifact-input'
if grep -Fq 'COPY --from=symphony-gcc16' <<<"${gcc_runtime}"; then
  echo "GCC runtime assembly must fail closed without the external artifact context" >&2
  exit 1
fi

gcc_artifact="$(stage_block gcc16-artifact)"
grep -Fq 'FROM scratch AS gcc16-artifact' <<<"${gcc_artifact}"
grep -Fq 'COPY --from=gcc-builder /opt/gcc-16.1 /opt/gcc-16.1' \
  <<<"${gcc_artifact}"
test "$(grep -Ec '^COPY ' <<<"${gcc_artifact}")" -eq 1
if grep -Eq '^(ADD|ONBUILD)[[:space:]]|(/tmp/|/build/|/src/)' <<<"${gcc_artifact}"; then
  echo "GCC artifact stage must not copy compiler build intermediates" >&2
  exit 1
fi
gcc_package="$(stage_block symphony-gcc16)"
grep -Fq 'FROM compiler-build-base AS symphony-gcc16' <<<"${gcc_package}"
grep -Fq 'COPY --from=gcc16-artifact /opt/gcc-16.1 /opt/gcc-16.1' \
  <<<"${gcc_package}"
grep -Fq 'test "$(/opt/gcc-16.1/bin/g++ -dumpfullversion)" = "16.1.0"' \
  "${containerfile}"
grep -Fq 'libgcc_s.so.1 => /opt/gcc-16.1/lib64/libgcc_s.so.1' \
  "${containerfile}"
if grep -Fq 'FROM symphony-gcc-runtime AS symphony-gcc-validation' "${containerfile}" ||
  grep -Fq 'gcc-${TARGETARCH}-vcpkg-' "${containerfile}"; then
  echo "generic toolchain Containerfile must not contain project GCC validation" >&2
  exit 1
fi
grep -Fq 'FROM runtime-base AS gcc16-validation-execution' \
  "${gcc16_validation_containerfile}"
grep -Fq 'FROM scratch AS runtime-base' "${gcc16_validation_containerfile}"
grep -Fq 'FROM scratch AS gcc16-validation' "${gcc16_validation_containerfile}"
grep -Fq \
  'COPY --from=gcc16-validation-execution /validation/gcc16 /gcc16-validation-passed' \
  "${gcc16_validation_containerfile}"
test "$(grep -Ec '^FROM[[:space:]]' "${gcc16_validation_containerfile}")" -eq 3
test "$(
  grep -E '^FROM[[:space:]]' "${gcc16_validation_containerfile}" | tail -n 1
)" = 'FROM scratch AS gcc16-validation'
test "$(grep -Ec '^(COPY|ADD)[[:space:]]' "${gcc16_validation_containerfile}")" -eq 1
grep -Fq 'CCACHE_COMPILERCHECK=content' "${gcc16_validation_containerfile}"
grep -Fq 'libstdc++.so.6 => /opt/gcc-16.1/lib64/libstdc++.so.6' \
  "${gcc16_validation_containerfile}"
grep -Fq 'libgcc_s.so.1 => /opt/gcc-16.1/lib64/libgcc_s.so.1' \
  "${gcc16_validation_containerfile}"
grep -Fq 'test "$(env -u LD_LIBRARY_PATH /tmp/gcc-runtime-check)" = "16"' \
  "${gcc16_validation_containerfile}"
grep -Fq 'vcpkg_cache_bytes="$(du -sb /var/cache/vcpkg | cut -f1)"' \
  "${gcc16_validation_containerfile}"
grep -Fq "printf 'vcpkg-cache bytes=%s files=%s" \
  "${gcc16_validation_containerfile}"
cmp -s "${dockerignore}" "${gcc16_validation_dockerignore}"
grep -Fq '"gcc16-artifact-input" = GCC16_ARTIFACT_CONTEXT' "${gcc16_bake}"
grep -Fq '"runtime-base" = "target:gcc16-runtime"' "${gcc16_bake}"
grep -Fq 'platforms  = ["linux/${GCC16_ARCH}"]' "${gcc16_bake}"
test "$(grep -Fc 'output = ["type=cacheonly"]' "${gcc16_bake}")" -eq 2
grep -Fq 'default     = ""' "${gcc16_bake}"
grep -Fq 'contains(["amd64", "arm64"], GCC16_ARCH)' "${gcc16_bake}"
grep -Fq 'SOURCE_REVISION = SOURCE_REVISION' "${gcc16_bake}"

analysis_runtime="$(stage_block symphony-analysis)"
grep -Fq 'FROM symphony-gcc-runtime AS symphony-analysis' <<<"${analysis_runtime}"
grep -Fq 'ARG SOURCE_REVISION=unknown' <<<"${analysis_runtime}"
grep -Fq 'org.opencontainers.image.revision="${SOURCE_REVISION}"' <<<"${analysis_runtime}"
test "$(grep -Ec '^COPY ' <<<"${analysis_runtime}")" -eq 1
grep -Fq 'COPY --from=llvm-analysis-tools /opt/llvm-22.1.8 /opt/llvm-22.1.8' \
  <<<"${analysis_runtime}"
if grep -Fq 'check-clang-format-version' <<<"${analysis_runtime}"; then
  echo "generic analysis runtime must not retain repository build helpers" >&2
  exit 1
fi
analysis_validation="$(stage_block symphony-analysis-validation)"
grep -Fq \
  'RUN --mount=type=bind,source=scripts/check-clang-format-version.sh,target=/usr/local/bin/check-clang-format-version,ro \' \
  <<<"${analysis_validation}"
analysis_format_validation="$(stage_block symphony-analysis-format-validation)"
grep -Fq 'FROM symphony-analysis AS symphony-analysis-format-validation' \
  <<<"${analysis_format_validation}"
grep -Fq \
  'RUN --network=none --mount=type=bind,source=.,target=/workspaces/symphony-cpp,ro \' \
  <<<"${analysis_format_validation}"
grep -Fq '&& ./scripts/check-format.sh' <<<"${analysis_format_validation}"
test "$(grep -Ec '^RUN ' <<<"${analysis_format_validation}")" -eq 1
if grep -Eq \
  'source=\.,target=/workspaces/symphony-cpp,rw|type=cache|vcpkg|cmake|ccache' \
  <<<"${analysis_format_validation}"; then
  echo "format validation leaf escaped its read-only, project-dependency-free boundary" >&2
  exit 1
fi
analysis_source_validation="$(stage_block symphony-analysis-source-validation)"
grep -Fq \
  'FROM symphony-analysis-validation AS symphony-analysis-source-validation' \
  <<<"${analysis_source_validation}"
grep -Fq '&& ./scripts/check-format.sh' <<<"${analysis_source_validation}"

clang_runtime="$(stage_block symphony-ci-clang)"
grep -Fq 'FROM toolchain-runtime-base AS symphony-ci-clang' <<<"${clang_runtime}"
grep -Fq 'ARG SOURCE_REVISION=unknown' <<<"${clang_runtime}"
grep -Fq 'org.opencontainers.image.revision="${SOURCE_REVISION}"' <<<"${clang_runtime}"
grep -Fq 'ENTRYPOINT []' <<<"${clang_runtime}"
test "$(grep -Ec '^COPY ' <<<"${clang_runtime}")" -eq 1
grep -Fq 'COPY --from=symphony-clang-p2996 /opt/clang-p2996 /opt/clang-p2996' \
  <<<"${clang_runtime}"

clang_artifact="$(stage_block clang-p2996-artifact)"
grep -Fq 'FROM scratch AS clang-p2996-artifact' <<<"${clang_artifact}"
grep -Fq 'COPY --from=clang-builder /opt/clang-p2996 /opt/clang-p2996' \
  <<<"${clang_artifact}"
test "$(grep -Ec '^COPY ' <<<"${clang_artifact}")" -eq 1
if grep -Eq '^(ADD|ONBUILD)[[:space:]]|(/tmp/|/build/|/src/)' <<<"${clang_artifact}"; then
  echo "clang-p2996 artifact stage must not copy compiler build intermediates" >&2
  exit 1
fi

clang_package="$(stage_block symphony-clang-p2996)"
grep -Fq 'FROM clang-p2996-artifact-input AS symphony-clang-p2996' \
  <<<"${clang_package}"
clang_artifact_input="$(stage_block clang-p2996-artifact-input)"
test "${clang_artifact_input}" = 'FROM scratch AS clang-p2996-artifact-input'
if grep -Eq '^(COPY|ADD)[[:space:]]' <<<"${clang_package}"; then
  echo "clang runtime assembly must fail closed without the external artifact context" >&2
  exit 1
fi
if grep -Fq 'FROM symphony-ci-clang AS symphony-clang-validation' "${containerfile}" ||
  grep -Fq 'clang-p2996-vcpkg-' "${containerfile}"; then
  echo "generic toolchain Containerfile must not contain project p2996 validation" >&2
  exit 1
fi
grep -Fq 'FROM runtime-base AS p2996-validation-execution' \
  "${p2996_validation_containerfile}"
grep -Fq 'FROM scratch AS runtime-base' "${p2996_validation_containerfile}"
grep -Fq 'FROM scratch AS clang-p2996-validation' "${p2996_validation_containerfile}"
grep -Fq \
  'COPY --from=p2996-validation-execution /validation/clang-p2996 /clang-p2996-validation-passed' \
  "${p2996_validation_containerfile}"
test "$(grep -Ec '^(COPY|ADD)[[:space:]]' "${p2996_validation_containerfile}")" -eq 1
if grep -Eq '^(LABEL|ENTRYPOINT)[[:space:]]' "${p2996_validation_containerfile}"; then
  echo "project validation marker image must not present itself as a reusable runtime" >&2
  exit 1
fi
grep -Fq '"clang-p2996-artifact-input" = CLANG_P2996_ARTIFACT_CONTEXT' "${p2996_bake}"
grep -Fq '"runtime-base" = "target:clang-p2996-runtime"' "${p2996_bake}"
test "$(grep -Fc 'output = ["type=cacheonly"]' "${p2996_bake}")" -eq 2
grep -Fq 'default     = ""' "${p2996_bake}"
grep -Fq \
  'condition     = can(regex("^docker-image://[^@[:space:]]+@sha256:[0-9a-f]{64}$", CLANG_P2996_ARTIFACT_CONTEXT))' \
  "${p2996_bake}"
cmp -s "${dockerignore}" "${p2996_validation_dockerignore}"
grep -Fq '"clang-p2996-artifact-input" = CLANG_P2996_ARTIFACT_CONTEXT' \
  "${generic_bake}"
grep -Fq '"gcc16-artifact-input" = GCC16_ARTIFACT_CONTEXT' "${generic_bake}"
if grep -Fq 'target "symphony-clang-p2996"' "${generic_bake}" ||
  grep -Fq 'target "symphony-gcc16"' "${generic_bake}"; then
  echo "generic Bake graph must not expose the external compiler package as a build target" >&2
  exit 1
fi
test "$(grep -Fhc 'default     = ""' "${p2996_bake}" "${gcc16_bake}" | awk '{sum += $1} END {print sum}')" -eq 3
grep -Fq \
  'default     = "docker-image://invalid.invalid/required-clang-p2996-artifact@sha256:0000000000000000000000000000000000000000000000000000000000000000"' \
  "${generic_bake}"
grep -Fq \
  'default     = "docker-image://invalid.invalid/required-gcc16-artifact@sha256:0000000000000000000000000000000000000000000000000000000000000000"' \
  "${generic_bake}"
test "$(
  grep -Fhc \
    'condition     = can(regex("^docker-image://[^@[:space:]]+@sha256:[0-9a-f]{64}$", CLANG_P2996_ARTIFACT_CONTEXT))' \
    "${generic_bake}" "${p2996_bake}" |
    awk '{sum += $1} END {print sum}'
)" -eq 2
test "$(grep -Ec '^FROM[[:space:]]' "${p2996_validation_containerfile}")" -eq 3
test "$(
  grep -E '^FROM[[:space:]]' "${p2996_validation_containerfile}" | tail -n 1
)" = 'FROM scratch AS clang-p2996-validation'
grep -Fq 'CCACHE_COMPILERCHECK=content' "${p2996_validation_containerfile}"

grep -Fq 'default: amd64' "${workflow}"
seed_input="$(workflow_input_block seed_clang_artifact_package)"
grep -Fxq '        required: false' <<<"${seed_input}"
grep -Fxq '        default: false' <<<"${seed_input}"
grep -Fxq '        type: boolean' <<<"${seed_input}"
gcc_seed_input="$(workflow_input_block seed_gcc_artifact_package)"
grep -Fxq '        required: false' <<<"${gcc_seed_input}"
grep -Fxq '        default: false' <<<"${gcc_seed_input}"
grep -Fxq '        type: boolean' <<<"${gcc_seed_input}"
grep -Fq "runs-on: \${{ inputs.architecture == 'arm64' && 'ubuntu-24.04-arm' || 'ubuntu-24.04' }}" \
  "${workflow}"
grep -Fq 'platforms: ${{ env.TOOLCHAIN_PLATFORM }}' "${workflow}"
grep -Fq 'scope=symphony-gcc16-${{ inputs.architecture }}-min-v3' "${workflow}"
grep -Fq 'if: ${{ inputs.architecture == '\''arm64'\'' && inputs.lineage != '\''gcc16'\'' }}' \
  "${workflow}"
if grep -Fq 'target: symphony-gcc-validation' "${workflow}"; then
  echo "GCC project validation must use the separated Bake graph" >&2
  exit 1
fi
if grep -Fq 'target: symphony-clang-validation' "${workflow}"; then
  echo "clang project validation must use the separated Bake graph" >&2
  exit 1
fi
test "$(
  grep -Fc '      - name: Verify native runner architecture and capacity' "${workflow}"
)" -eq 2
test "$(
  grep -Fc '      - name: Reclaim ephemeral runner disk' "${workflow}"
)" -eq 5
gcc_job="$(workflow_job_block gcc16)"
gcc_artifact_job="$(workflow_job_block gcc16-artifact)"
clang_job="$(workflow_job_block clang-p2996)"
clang_artifact_job="$(workflow_job_block clang-p2996-artifact)"
validate_job="$(workflow_job_block validate-inputs)"
grep -Fxq \
  "    if: \${{ inputs.lineage == 'all' || inputs.lineage == 'gcc16' || inputs.lineage == 'llvm-analysis' }}" \
  <<<"${gcc_artifact_job}"
grep -Fxq \
  "    if: \${{ inputs.lineage == 'all' || inputs.lineage == 'gcc16' }}" \
  <<<"${gcc_job}"
grep -Fq \
  'group: compiler-matrix-${{ github.ref }}-${{ inputs.lineage }}-${{ inputs.architecture }}' \
  "${workflow}"
grep -Fq \
  "group: clang-p2996-artifact-${clang_commit}-amd64-${clang_artifact_recipe_sha256}" \
  <<<"${clang_artifact_job}"
grep -Fq '      cancel-in-progress: false' <<<"${clang_artifact_job}"
grep -Fq \
  "group: gcc16-artifact-\${{ inputs.architecture }}-${gcc_artifact_recipe_sha256}" \
  <<<"${gcc_artifact_job}"
grep -Fq '      cancel-in-progress: false' <<<"${gcc_artifact_job}"
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
gcc_publication_boundary_step="$(
  workflow_step_block_for_job "${validate_job}" \
    "Restrict GCC artifact publication to its exact lane"
)"
grep -Fxq \
  "        if: \${{ inputs.seed_gcc_artifact_package && inputs.lineage != 'gcc16' }}" \
  <<<"${gcc_publication_boundary_step}"
grep -Fq 'GCC artifact publication requires lineage=gcc16' \
  <<<"${gcc_publication_boundary_step}"
gcc_validation_step="$(
  workflow_step_block_for_job "${gcc_job}" \
    "Build and validate GCC toolchain without loading it"
)"
gcc_vcpkg_restore_step="$(
  workflow_step_block_for_job "${gcc_job}" \
    "Restore exact GCC vcpkg binary archives"
)"
gcc_cache_bridge_step="$(
  workflow_step_block_for_job "${gcc_job}" \
    "Bridge scoped GCC validation caches into BuildKit"
)"
grep -Fq \
  'VCPKG_DANCE_DIR: ${{ github.workspace }}/.build/toolchain-cache/vcpkg-archives/gcc/${{ inputs.architecture }}' \
  <<<"${gcc_job}"
grep -Fxq '        id: gcc-vcpkg-archives' <<<"${gcc_vcpkg_restore_step}"
grep -Fxq \
  '        uses: actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9' \
  <<<"${gcc_vcpkg_restore_step}"
grep -Fxq '          path: ${{ env.VCPKG_DANCE_DIR }}' \
  <<<"${gcc_vcpkg_restore_step}"
grep -Fq \
  "gcc16-vcpkg-archives-v1-\${{ needs.gcc16-artifact.outputs.digest }}-\${{ inputs.architecture == 'arm64' && 'arm64-linux' || 'x64-linux' }}-" \
  <<<"${gcc_vcpkg_restore_step}"
grep -Fq \
  "hashFiles('containers/Containerfile', 'containers/validation/gcc16.Containerfile', 'vcpkg.json', 'vcpkg-configuration.json', 'vcpkg-ports/**', 'vcpkg-triplets/**', 'scripts/bootstrap-vcpkg.sh', 'scripts/devcontainer-setup.sh', 'scripts/install-cmake.sh')" \
  <<<"${gcc_vcpkg_restore_step}"
if grep -Fq 'restore-keys:' <<<"${gcc_vcpkg_restore_step}"; then
  echo "GCC vcpkg archive cache must not use a prefix restore" >&2
  exit 1
fi
if grep -Eq 'path:.*(\.build/vcpkg|vcpkg_installed|/build($|/))' \
    <<<"${gcc_vcpkg_restore_step}"; then
  echo "GCC Actions cache includes non-archive project or vcpkg state" >&2
  exit 1
fi
grep -Fq '"${{ env.VCPKG_DANCE_DIR }}": {' <<<"${gcc_cache_bridge_step}"
grep -Fq '"target": "/var/cache/vcpkg"' <<<"${gcc_cache_bridge_step}"
grep -Fq '"id": "gcc-${{ inputs.architecture }}-vcpkg-archives"' \
  <<<"${gcc_cache_bridge_step}"
grep -Fxq \
  "          skip-extraction: \${{ steps.gcc-ccache.outputs.cache-hit == 'true' && steps.gcc-vcpkg-archives.outputs.cache-hit == 'true' }}" \
  <<<"${gcc_cache_bridge_step}"
gcc_vcpkg_restore_line="$(
  grep -nF '      - name: Restore exact GCC vcpkg binary archives' \
    <<<"${gcc_job}" | cut -d: -f1
)"
gcc_cache_bridge_line="$(
  grep -nF '      - name: Bridge scoped GCC validation caches into BuildKit' \
    <<<"${gcc_job}" | cut -d: -f1
)"
gcc_validation_line="$(
  grep -nF '      - name: Build and validate GCC toolchain without loading it' \
    <<<"${gcc_job}" | cut -d: -f1
)"
test "${gcc_vcpkg_restore_line}" -lt "${gcc_cache_bridge_line}"
test "${gcc_cache_bridge_line}" -lt "${gcc_validation_line}"
gcc_probe_step="$(
  workflow_step_block_for_job "${gcc_artifact_job}" \
    "Probe immutable GCC 16.1 package"
)"
gcc_publish_step="$(
  workflow_step_block_for_job "${gcc_artifact_job}" \
    "Publish isolated GCC 16.1 package before source validation"
)"
gcc_select_step="$(
  workflow_step_block_for_job "${gcc_artifact_job}" \
    "Select captured GCC 16.1 package digest"
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
grep -Fxq \
  "        if: \${{ steps.gcc-artifact-probe.outputs.hit != 'true' && inputs.seed_gcc_artifact_package }}" \
  <<<"${gcc_publish_step}"
grep -Fxq '          target: gcc16-artifact' <<<"${gcc_publish_step}"
grep -Fxq \
  "        if: \${{ steps.clang-artifact-probe.outputs.hit != 'true' && inputs.seed_clang_artifact_package }}" \
  <<<"${clang_publish_step}"
grep -Fxq '          target: clang-p2996-artifact' <<<"${clang_publish_step}"
grep -Fxq \
  '        uses: docker/build-push-action@53b7df96c91f9c12dcc8a07bcb9ccacbed38856a' \
  <<<"${gcc_publish_step}"
grep -Fxq '          context: .' <<<"${gcc_publish_step}"
grep -Fxq '          file: containers/Containerfile' <<<"${gcc_publish_step}"
grep -Fxq '          platforms: ${{ env.TOOLCHAIN_PLATFORM }}' <<<"${gcc_publish_step}"
grep -Fxq '          push: true' <<<"${gcc_publish_step}"
grep -Fxq '          provenance: mode=max' <<<"${gcc_publish_step}"
grep -Fxq '          sbom: true' <<<"${gcc_publish_step}"
grep -Fxq '          load: false' <<<"${gcc_publish_step}"
grep -Fxq '          builder: ${{ steps.buildx.outputs.name }}' <<<"${gcc_publish_step}"
grep -Fxq \
  '          cache-from: type=gha,scope=symphony-gcc16-${{ inputs.architecture }}-min-v3' \
  <<<"${gcc_publish_step}"
grep -Fq 'echo "index_digest=${digest}"' <<<"${gcc_probe_step}"
grep -Fq 'PROBED_INDEX_DIGEST: ${{ steps.gcc-artifact-probe.outputs.index_digest }}' \
  <<<"${gcc_select_step}"
grep -Fq 'PUBLISHED_INDEX_DIGEST: ${{ steps.gcc-artifact-publish.outputs.digest }}' \
  <<<"${gcc_select_step}"
grep -Fq 'TARGET_ARCH: ${{ inputs.architecture }}' <<<"${gcc_select_step}"
grep -Fq 'index_digest="${PROBED_INDEX_DIGEST}"' <<<"${gcc_select_step}"
grep -Fq 'index_digest="${PUBLISHED_INDEX_DIGEST}"' <<<"${gcc_select_step}"
grep -Fq './scripts/check-oci-platform.sh \' <<<"${gcc_select_step}"
grep -Fq '              select-index \' <<<"${gcc_select_step}"
grep -Fq '              "${TARGET_ARCH}" <<<"${index_json}"' <<<"${gcc_select_step}"
grep -Fq '"${ARTIFACT_REF}@${digest}"' <<<"${gcc_select_step}"
grep -Fq \
  './scripts/check-oci-platform.sh validate-image "${TARGET_ARCH}"' \
  <<<"${gcc_select_step}"
grep -Fq 'echo "digest=${digest}"' <<<"${gcc_select_step}"
grep -Fq 'echo "index_digest=${index_digest}"' <<<"${gcc_select_step}"
grep -Fxq '        env:' <<<"${gcc_validation_step}"
grep -Fxq \
  '          BUILDX_BUILDER: ${{ steps.buildx.outputs.name }}' \
  <<<"${gcc_validation_step}"
grep -Fq \
  '          GCC16_ARTIFACT_CONTEXT: docker-image://${{ needs.gcc16-artifact.outputs.ref }}@${{ needs.gcc16-artifact.outputs.digest }}' \
  <<<"${gcc_validation_step}"
grep -Fxq '          GCC16_ARCH: ${{ inputs.architecture }}' <<<"${gcc_validation_step}"
grep -Fxq '          SOURCE_REVISION: ${{ github.sha }}' <<<"${gcc_validation_step}"
grep -Fq 'docker buildx bake \' <<<"${gcc_validation_step}"
grep -Fq -- '--builder "${BUILDX_BUILDER}" \' <<<"${gcc_validation_step}"
grep -Fq -- '--file containers/gcc16-separated.bake.hcl \' \
  <<<"${gcc_validation_step}"
grep -Fq -- '--progress=plain \' <<<"${gcc_validation_step}"
grep -Fxq '            gcc16-validation' <<<"${gcc_validation_step}"
if grep -Eq '^[[:space:]]+uses:' <<<"${gcc_validation_step}" ||
  grep -Fq -- '--load' <<<"${gcc_validation_step}" ||
  grep -Fq -- '--push' <<<"${gcc_validation_step}" ||
  grep -Fq -- '--output' <<<"${gcc_validation_step}" ||
  grep -Fq -- '--set' <<<"${gcc_validation_step}" ||
  grep -Fq 'cache-to:' <<<"${gcc_validation_step}" ||
  grep -Fq 'tags:' <<<"${gcc_validation_step}" ||
  grep -Eq 'type=(registry|docker|oci|local)' <<<"${gcc_validation_step}"; then
  echo "GCC Bake validation must remain cache-only and non-publishing" >&2
  exit 1
fi
grep -Fq \
  'gcc16-ccache-v2-${{ needs.gcc16-artifact.outputs.digest }}-' \
  <<<"${gcc_job}"
if grep -Fq 'gcc16-ccache-v1-' <<<"${gcc_job}"; then
  echo "GCC compiler cache must remain scoped to the selected compiler manifest" >&2
  exit 1
fi
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
grep -Fq 'echo "index_digest=${digest}"' <<<"${clang_probe_step}"
grep -Fq 'PROBED_INDEX_DIGEST: ${{ steps.clang-artifact-probe.outputs.index_digest }}' \
  <<<"${clang_select_step}"
grep -Fq 'PUBLISHED_INDEX_DIGEST: ${{ steps.clang-artifact-publish.outputs.digest }}' \
  <<<"${clang_select_step}"
grep -Fq 'index_digest="${PROBED_INDEX_DIGEST}"' <<<"${clang_select_step}"
grep -Fq 'index_digest="${PUBLISHED_INDEX_DIGEST}"' <<<"${clang_select_step}"
grep -Fq './scripts/check-oci-platform.sh \' <<<"${clang_select_step}"
grep -Fq '              select-index \' <<<"${clang_select_step}"
grep -Fq '              amd64 <<<"${index_json}"' <<<"${clang_select_step}"
grep -Fq '"${ARTIFACT_REF}@${digest}"' <<<"${clang_select_step}"
grep -Fq \
  './scripts/check-oci-platform.sh validate-image amd64' \
  <<<"${clang_select_step}"
grep -Fq 'echo "digest=${digest}"' <<<"${clang_select_step}"
grep -Fq 'echo "index_digest=${index_digest}"' <<<"${clang_select_step}"
grep -Fxq '        env:' <<<"${clang_validation_step}"
grep -Fxq \
  '          BUILDX_BUILDER: ${{ steps.buildx.outputs.name }}' \
  <<<"${clang_validation_step}"
grep -Fxq \
  '          CLANG_P2996_ARTIFACT_CONTEXT: docker-image://${{ needs.clang-p2996-artifact.outputs.ref }}@${{ needs.clang-p2996-artifact.outputs.digest }}' \
  <<<"${clang_validation_step}"
grep -Fq 'docker buildx bake \' <<<"${clang_validation_step}"
grep -Fq -- '--builder "${BUILDX_BUILDER}" \' <<<"${clang_validation_step}"
grep -Fq -- '--file containers/p2996-separated.bake.hcl \' \
  <<<"${clang_validation_step}"
grep -Fq -- '--progress=plain \' <<<"${clang_validation_step}"
grep -Fxq '            clang-p2996-validation' <<<"${clang_validation_step}"
if grep -Eq '^[[:space:]]+uses:' <<<"${clang_validation_step}" ||
  grep -Fq -- '--load' <<<"${clang_validation_step}" ||
  grep -Fq -- '--push' <<<"${clang_validation_step}" ||
  grep -Fq -- '--output' <<<"${clang_validation_step}" ||
  grep -Fq -- '--set' <<<"${clang_validation_step}" ||
  grep -Fq 'cache-to:' <<<"${clang_validation_step}" ||
  grep -Fq 'tags:' <<<"${clang_validation_step}" ||
  grep -Eq 'type=(registry|docker|oci|local)' <<<"${clang_validation_step}" ||
  grep -Fq 'docker buildx build' <<<"${clang_validation_step}" ||
  grep -Fq 'docker buildx imagetools create' <<<"${clang_validation_step}"; then
  echo "clang Bake validation must remain cache-only and non-publishing" >&2
  exit 1
fi
grep -Fq \
  'clang-p2996-ccache-v2-${{ needs.clang-p2996-artifact.outputs.digest }}-' \
  <<<"${clang_job}"
if grep -Fq 'clang-p2996-ccache-v1-' <<<"${clang_job}"; then
  echo "clang compiler cache must remain scoped to the selected compiler manifest" >&2
  exit 1
fi
if grep -Fq '          cache-to:' <<<"${gcc_artifact_job}"; then
  echo "GCC artifact package must not consume GitHub Actions cache storage" >&2
  exit 1
fi
test "$(
  grep -Fc 'scope=symphony-gcc16-${{ inputs.architecture }}-min-v3' \
    <<<"${gcc_artifact_job}"
)" -eq 1
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
grep -Fq '      packages: write' <<<"${gcc_artifact_job}"
grep -Fq '      packages: read' <<<"${gcc_job}"
if grep -Fq '      packages: write' <<<"${gcc_job}"; then
  echo "GCC source validation must not retain package publication authority" >&2
  exit 1
fi
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
gcc_restore_line="$(
  grep -Fn '      - name: Restore bounded GCC compiler cache' \
    <<<"${gcc_job}" | cut -d: -f1
)"
gcc_bridge_line="$(
  grep -Fn '      - name: Bridge scoped GCC validation caches into BuildKit' \
    <<<"${gcc_job}" | cut -d: -f1
)"
gcc_validation_line="$(
  grep -Fn '      - name: Build and validate GCC toolchain without loading it' \
    <<<"${gcc_job}" | cut -d: -f1
)"
test "${gcc_setup_line}" -lt "${gcc_restore_line}"
test "${gcc_restore_line}" -lt "${gcc_bridge_line}"
test "${gcc_bridge_line}" -lt "${gcc_validation_line}"
gcc_artifact_setup_line="$(
  grep -Fn \
    '      - uses: docker/setup-buildx-action@bb05f3f5519dd87d3ba754cc423b652a5edd6d2c' \
    <<<"${gcc_artifact_job}" | cut -d: -f1
)"
gcc_probe_line="$(
  grep -Fn '      - name: Probe immutable GCC 16.1 package' \
    <<<"${gcc_artifact_job}" | cut -d: -f1
)"
gcc_publish_line="$(
  grep -Fn '      - name: Publish isolated GCC 16.1 package before source validation' \
    <<<"${gcc_artifact_job}" | cut -d: -f1
)"
gcc_select_line="$(
  grep -Fn '      - name: Select captured GCC 16.1 package digest' \
    <<<"${gcc_artifact_job}" | cut -d: -f1
)"
test "${gcc_artifact_setup_line}" -lt "${gcc_probe_line}"
test "${gcc_probe_line}" -lt "${gcc_publish_line}"
test "${gcc_publish_line}" -lt "${gcc_select_line}"

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
grep -Fxq '      - validate-inputs' <<<"${llvm_analysis_job}"
grep -Fxq '      - gcc16-artifact' <<<"${llvm_analysis_job}"
grep -Fxq '      packages: read' <<<"${llvm_analysis_job}"
grep -Fxq \
  "    if: \${{ inputs.lineage == 'all' || inputs.lineage == 'llvm-analysis' }}" \
  <<<"${llvm_analysis_job}"
analysis_login_step="$(
  workflow_step_block "Log in to GitHub Container Registry for GCC artifact"
)"
grep -Fxq \
  '        uses: docker/login-action@af1e73f918a031802d376d3c8bbc3fe56130a9b0' \
  <<<"${analysis_login_step}"
grep -Fxq '          registry: ghcr.io' <<<"${analysis_login_step}"
grep -Fxq '          username: ${{ github.actor }}' <<<"${analysis_login_step}"
grep -Fxq '          password: ${{ secrets.GITHUB_TOKEN }}' <<<"${analysis_login_step}"
analysis_format_step="$(
  workflow_step_block "Validate exact LLVM formatting before source analysis"
)"
analysis_validation_step="$(
  workflow_step_block "Build and validate LLVM analysis without loading it"
)"
for step in "${analysis_format_step}" "${analysis_validation_step}"; do
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
  grep -Fq \
    'gcc16-artifact-input=docker-image://${{ needs.gcc16-artifact.outputs.ref }}@${{ needs.gcc16-artifact.outputs.digest }}' \
    <<<"${step}"
  for key in uses context file target platforms outputs load push builder cache-from build-contexts; do
    test "$(grep -Ec "^[[:space:]]+${key}:" <<<"${step}")" = "1"
  done
done
if grep -Fq '          cache-to:' <<<"${llvm_analysis_job}"; then
  echo "analysis validation must not write image layers to GitHub Actions cache" >&2
  exit 1
fi
if grep -Eq \
  '^[[:space:]]+(build-args|tags|secrets):|type=(registry|image|oci|docker|local)' \
  <<<"${analysis_format_step}"; then
  echo "format validation received an output, secret, or mutable build argument" >&2
  exit 1
fi
grep -Fxq '          target: symphony-analysis-format-validation' \
  <<<"${analysis_format_step}"
grep -Fxq '          target: symphony-analysis-source-validation' \
  <<<"${analysis_validation_step}"
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
format_step_line="$(
  grep -Fn \
    '      - name: Validate exact LLVM formatting before source analysis' \
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
test "${setup_buildx_id_line}" -lt "${format_step_line}"
test "${format_step_line}" -lt "${restore_ccache_line}"
test "${restore_ccache_line}" -lt "${bridge_ccache_line}"
test "${bridge_ccache_line}" -lt "${validation_step_line}"
test "$(grep -Fc 'outputs: type=cacheonly' "${workflow}")" = "2"
test "$(grep -Fc 'load: false' "${workflow}")" = "4"
test "$(grep -Fc 'version: v0.35.0' "${workflow}")" = "5"
grep -Fq \
  'uses: reproducible-containers/buildkit-cache-dance@5422eac04292c961a382e0f584ea0f03ad9da723' \
  "${workflow}"
grep -Fq \
  'uses: actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9' \
  "${workflow}"
grep -Fq \
  'utility-image: ghcr.io/containerd/busybox@sha256:52f73a0a43a16cf37cd0720c90887ce972fe60ee06a687ee71fb93a7ca601df7' \
  "${workflow}"

test "$(grep -Fc 'push: false' "${workflow}")" = "2"
test "$(grep -Ec '^permissions:$' "${workflow}")" = "1"
test "$(grep -Ec '^[[:space:]]*permissions:' "${workflow}")" = "6"
test "$(grep -Ec '^  contents: read$' "${workflow}")" = "1"
test "$(grep -Ec '^[[:space:]]+packages: write$' "${workflow}")" = "2"
if grep -Eq '(^|[[:space:]])write-all([[:space:]]|$)' "${workflow}"; then
  echo "compiler validation workflow must not request write-all permission" >&2
  exit 1
fi
if grep -E '^[[:space:]]+[[:alnum:]_-]+:[[:space:]]+write([[:space:]]|$)' "${workflow}" |
  grep -Fqv 'packages: write'; then
  echo "compiler workflow requested an unexpected write permission" >&2
  exit 1
fi
test "$(grep -Fc '${{ secrets.GITHUB_TOKEN }}' "${workflow}")" = "5"
if grep -F '${{ secrets.' "${workflow}" |
  grep -Fqv '${{ secrets.GITHUB_TOKEN }}'; then
  echo "compiler workflow must not consume repository secrets other than its scoped token" >&2
  exit 1
fi
test "$(grep -Ec '^[[:space:]]+push:[[:space:]]+true([[:space:]]|$)' "${workflow}")" = "2"
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

expected_dockerignore="$(
  printf '%s\n' \
    '.git' \
    '.github' \
    '.codex' \
    'build' \
    '.build' \
    '.cache' \
    '.ccache' \
    '.direnv' \
    '.env*' \
    '.opensymphony' \
    'compile_commands.json' \
    'vcpkg_installed' \
    'cmake-build-*' \
    'node_modules' \
    'target' \
    'out' \
    'dist' \
    '.DS_Store' \
    'core' \
    'core.*' \
    '*.log' \
    '*.tmp' \
    '*.swp' \
    '*~'
)"
test "$(cat "${dockerignore}")" = "${expected_dockerignore}"
if grep -Eq '^!' "${dockerignore}"; then
  echo "Docker build context containment must not contain negated ignore rules" >&2
  exit 1
fi

test "$(wc -l <"${opensymphony_dockerignore}")" -eq 1
grep -Fxq '**' "${opensymphony_dockerignore}"
test -f "${opensymphony_local_bake}"
rust_arg_line="$(
  grep -n -m1 '^ARG RUST_IMAGE=' "${opensymphony_containerfile}" | cut -d: -f1
)"
first_from_line="$(
  grep -n -m1 '^FROM ' "${opensymphony_containerfile}" | cut -d: -f1
)"
test "${rust_arg_line}" -lt "${first_from_line}"
if grep -Eq '^(ADD|COPY)[[:space:]]+[^-]' "${opensymphony_containerfile}"; then
  echo "OpenSymphony local image must remain independent of the repository build context" >&2
  exit 1
fi
if grep -Eq '^ADD[[:space:]]' "${opensymphony_containerfile}"; then
  echo "OpenSymphony local image must not use ADD" >&2
  exit 1
fi
while IFS= read -r copy_instruction; do
  if [[ "${copy_instruction}" != *"--from="* ]]; then
    echo "OpenSymphony COPY must select an explicit stage or named context" >&2
    exit 1
  fi
done < <(grep -E '^COPY[[:space:]]' "${opensymphony_containerfile}")

test "$(grep -Fc 'test ! -e /opt/symphony-cpp-seed' "${containerfile}")" -eq 2
if grep -Fq 'ghcr.io/ray-manaloto/symphony-dev' "${opensymphony_containerfile}"; then
  echo "OpenSymphony must not fall back to the contaminated legacy development image" >&2
  exit 1
fi
grep -Fq 'FROM scratch AS symphony-cpp-base' "${opensymphony_containerfile}"
grep -Fq 'FROM scratch AS symphony-cpp-base-validation' \
  "${opensymphony_containerfile}"
grep -Fq \
  'from=symphony-cpp-base-validation,source=/gcc16-runtime-candidate-execution-passed' \
  "${opensymphony_containerfile}"
grep -Fq \
  'from=symphony-cpp-base-validation,source=/gcc16-runtime-candidate-rootfs-audit-passed' \
  "${opensymphony_containerfile}"
grep -Fq '"gcc16-artifact-input" = GCC16_ARTIFACT_CONTEXT' \
  "${opensymphony_local_bake}"
grep -Fq 'OPENSYMPHONY_IMAGE must use the local symphony-opensymphony namespace' \
  "${opensymphony_local_bake}"
grep -Fq 'SOURCE_REVISION must be an exact lowercase 40-hex Git revision' \
  "${opensymphony_local_bake}"
grep -Fq 'condition     = can(regex("^[0-9a-f]{40}$", SOURCE_REVISION))' \
  "${opensymphony_local_bake}"
grep -Fq 'condition     = can(regex("^symphony-opensymphony:[a-z0-9][a-z0-9._-]*$", OPENSYMPHONY_IMAGE))' \
  "${opensymphony_local_bake}"
grep -Fq 'BUILD_INPUT_SHA256 must be an exact lowercase SHA-256 digest' \
  "${opensymphony_local_bake}"
grep -Eq '"runtime-base"[[:space:]]*=[[:space:]]*"target:opensymphony-gcc-runtime"' \
  "${opensymphony_local_bake}"
grep -Eq '"symphony-cpp-base"[[:space:]]*=[[:space:]]*"target:opensymphony-gcc-runtime"' \
  "${opensymphony_local_bake}"
grep -Eq \
  '"symphony-cpp-base-validation"[[:space:]]*=[[:space:]]*"target:opensymphony-gcc-runtime-validation"' \
  "${opensymphony_local_bake}"
test "$(grep -Fc 'output = ["type=docker"]' "${opensymphony_local_bake}")" -eq 1
test "$(grep -Fc 'output = ["type=cacheonly"]' "${opensymphony_local_bake}")" -eq 2
if grep -Eq 'type=(registry|image|oci|local)|(^|[[:space:]])(push|cache-to)[[:space:]]*=' \
  "${opensymphony_local_bake}"; then
  echo "OpenSymphony local Bake graph contains a publication or external cache output" >&2
  exit 1
fi
for script in scripts/build-opensymphony-local.sh scripts/test-opensymphony-upstream.sh; do
  grep -Fq 'containers/opensymphony-local.bake.hcl' "${script}"
  grep -Fq 'GCC16_ARTIFACT_CONTEXT=' "${script}"
  grep -Fq 'cd "${repo_root}"' "${script}"
  grep -Fq 'docker image inspect --format '\''{{.Id}}'\''' "${script}"
  grep -Fq 'dev.opensymphony.source.commit' "${script}"
  grep -Fq 'dev.symphony.source.revision' "${script}"
  if grep -Fq 'docker buildx build' "${script}"; then
    echo "${script} bypasses the validated local OpenSymphony Bake graph" >&2
    exit 1
  fi
done
grep -Fq 'dev.symphony.source.revision="${SOURCE_REVISION}"' \
  "${opensymphony_containerfile}"
grep -Fq 'dev.opensymphony.build-input.sha256="${BUILD_INPUT_SHA256}"' \
  "${opensymphony_containerfile}"
grep -Fq 'org.opencontainers.image.version="v2.10.0"' \
  "${opensymphony_containerfile}"
test -x scripts/opensymphony-build-input-id.sh
test -x scripts/test-opensymphony-bake-graph.sh
test "$(./scripts/opensymphony-build-input-id.sh | wc -c)" -eq 65
test "$(grep -Fc 'env -u LINEAR_API_KEY' WORKFLOW.md)" -eq 4
grep -Fq 'docker image inspect --format '\''{{.Id}}'\''' \
  "${opensymphony_acceptance}"
grep -Fq 'dev.opensymphony.upstream-tests' "${opensymphony_acceptance}"
grep -Fq 'dev.opensymphony.source.commit' "${opensymphony_acceptance}"
grep -Fq '0cc21ddda5d1853a8fbd11add578b43b6ebd6fcb' \
  "${opensymphony_acceptance}"
test "$(
  grep -Fc \
    'RUN --mount=type=bind,source=.,target=/workspaces/symphony-cpp,rw \' \
    "${containerfile}"
)" -eq 1
test "$(
  grep -Fc \
    'RUN --mount=type=bind,source=.,target=/workspaces/symphony-cpp,rw \' \
    "${gcc16_validation_containerfile}"
)" -eq 1
test "$(
  grep -Fc \
    'RUN --mount=type=bind,source=.,target=/workspaces/symphony-cpp,rw \' \
    "${p2996_validation_containerfile}"
)" -eq 1
if grep -Fq 'WORKDIR /workspaces/symphony-cpp' "${containerfile}"; then
  echo "generic compiler images must not embed a project-specific working directory" >&2
  exit 1
fi
