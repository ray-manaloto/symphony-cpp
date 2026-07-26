#!/usr/bin/env bash
set -euo pipefail

script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly script_directory
readonly checker="${script_directory}/check-goal-routing.sh"
real_git="$(PATH="$(getconf PATH)" command -v git)"
readonly real_git
fixture_root="$(mktemp -d)"
readonly fixture_root
trap 'rm -rf "${fixture_root}"' EXIT

readonly goal_directory=".codex/goals"
readonly canonical_goal_path="${goal_directory}/standalone-cpp26-v2.md"
readonly legacy_goal_path="${goal_directory}/standalone-cpp26.md"
readonly goal_archive_path="${goal_directory}/archive/standalone-cpp26-2026-07-26-pre-reset.md"
readonly notepad_archive_path=".codex/notepads/archive/root-2026-07-26-pre-reset.md"

new_case() {
  local case_name="$1"
  local case_directory="${fixture_root}/${case_name}"

  mkdir -p \
    "${case_directory}/${goal_directory}/archive" \
    "${case_directory}/.codex/notepads/archive" \
    "${case_directory}/docs"
  printf '%s\n' '# active v2 goal' >"${case_directory}/${canonical_goal_path}"
  printf '%s\n' "${legacy_goal_path}" >"${case_directory}/${goal_archive_path}"
  printf '%s\n' "${legacy_goal_path}" >"${case_directory}/${notepad_archive_path}"
  printf '%s\n' "${canonical_goal_path}" >"${case_directory}/docs/live.md"

  git -C "${case_directory}" init -q
  git -C "${case_directory}" config core.hooksPath /dev/null
  git -C "${case_directory}" config user.name fixture
  git -C "${case_directory}" config user.email fixture@example.invalid
  git -C "${case_directory}" add .
  git -C "${case_directory}" commit -qm baseline
  printf '%s\n' "${case_directory}"
}

expect_rejection() {
  local case_name="$1"
  local case_directory="$2"
  if "${checker}" "${case_directory}" >"${fixture_root}/${case_name}.log" 2>&1; then
    echo "goal-routing checker accepted hostile case: ${case_name}" >&2
    exit 1
  fi
}

expect_rejection_with_message() {
  local case_name="$1"
  local case_directory="$2"
  local expected_message="$3"

  expect_rejection "${case_name}" "${case_directory}"
  if ! grep -Fq -- "${expected_message}" "${fixture_root}/${case_name}.log"; then
    echo "goal-routing checker rejected ${case_name} for the wrong reason" >&2
    exit 1
  fi
}

case_directory="$(new_case valid)"
"${checker}" "${case_directory}"

case_directory="$(new_case canonical-missing-index)"
git -C "${case_directory}" rm -q --cached -- "${canonical_goal_path}"
expect_rejection canonical-missing-index "${case_directory}"

case_directory="$(new_case canonical-missing-worktree)"
rm "${case_directory}/${canonical_goal_path}"
expect_rejection canonical-missing-worktree "${case_directory}"

case_directory="$(new_case archive-missing-index)"
git -C "${case_directory}" rm -q --cached -- "${goal_archive_path}"
expect_rejection archive-missing-index "${case_directory}"

case_directory="$(new_case archive-missing-worktree)"
rm "${case_directory}/${notepad_archive_path}"
expect_rejection archive-missing-worktree "${case_directory}"

case_directory="$(new_case legacy-index-only)"
printf '%s\n' '# staged v1 goal' >"${case_directory}/${legacy_goal_path}"
git -C "${case_directory}" add -- "${legacy_goal_path}"
rm "${case_directory}/${legacy_goal_path}"
expect_rejection legacy-index-only "${case_directory}"

case_directory="$(new_case legacy-worktree-only)"
printf '%s\n' '# untracked v1 goal' >"${case_directory}/${legacy_goal_path}"
expect_rejection legacy-worktree-only "${case_directory}"

case_directory="$(new_case stale-reference-index-only)"
printf '%s\n' "${legacy_goal_path}" >"${case_directory}/docs/live.md"
git -C "${case_directory}" add -- docs/live.md
git -C "${case_directory}" restore --source=HEAD --worktree -- docs/live.md
expect_rejection stale-reference-index-only "${case_directory}"

case_directory="$(new_case stale-reference-untracked)"
printf '%s\n' "${legacy_goal_path}" >"${case_directory}/docs/untracked.md"
expect_rejection stale-reference-untracked "${case_directory}"

case_directory="$(new_case stale-reference-tracked-worktree)"
printf '%s\n' "${legacy_goal_path}" >"${case_directory}/docs/live.md"
expect_rejection stale-reference-tracked-worktree "${case_directory}"

case_directory="$(new_case stale-reference-ignored)"
printf '%s\n' 'ignored.md' >"${case_directory}/.gitignore"
git -C "${case_directory}" add -- .gitignore
git -C "${case_directory}" commit -qm ignore-fixture
printf '%s\n' "${legacy_goal_path}" >"${case_directory}/ignored.md"
expect_rejection stale-reference-ignored "${case_directory}"

case_directory="$(new_case grep-fatal)"
missing_blob="$(git -C "${case_directory}" rev-parse :docs/live.md)"
readonly missing_blob
mv \
  "${case_directory}/.git/objects/${missing_blob:0:2}/${missing_blob:2}" \
  "${case_directory}/.git/objects/${missing_blob:0:2}/${missing_blob:2}.missing"
expect_rejection_with_message \
  grep-fatal \
  "${case_directory}" \
  "failed to inspect live repository content"

case_directory="$(new_case ls-files-fatal)"
mkdir -p "${case_directory}/bin"
# shellcheck disable=SC2016 # The generated wrapper expands REAL_GIT at fixture runtime.
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'if [[ "$1" == "ls-files" && "$2" == "--stage" && "$3" == "--" && "$4" == "${LEGACY_GOAL_PATH}" ]]; then' \
  '  echo "simulated ls-files failure" >&2' \
  '  exit 2' \
  'fi' \
  'exec "${REAL_GIT}" "$@"' >"${case_directory}/bin/git"
chmod +x "${case_directory}/bin/git"
if PATH="${case_directory}/bin:${PATH}" \
  REAL_GIT="${real_git}" \
  LEGACY_GOAL_PATH="${legacy_goal_path}" \
  "${checker}" "${case_directory}" >"${fixture_root}/ls-files-fatal.log" 2>&1; then
  echo "goal-routing checker accepted hostile case: ls-files-fatal" >&2
  exit 1
fi
if ! grep -Fq \
  -- "failed to inspect legacy goal index state" \
  "${fixture_root}/ls-files-fatal.log"; then
  echo "goal-routing checker rejected ls-files-fatal for the wrong reason" >&2
  exit 1
fi

case_directory="$(new_case canonical-worktree-symlink)"
rm "${case_directory}/${canonical_goal_path}"
ln -s /dev/null "${case_directory}/${canonical_goal_path}"
expect_rejection canonical-worktree-symlink "${case_directory}"
