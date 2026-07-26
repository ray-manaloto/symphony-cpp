#!/usr/bin/env bash
set -euo pipefail

readonly requested_root="${1:-.}"
repository_root="$(git -C "${requested_root}" rev-parse --show-toplevel)"
readonly repository_root
cd "${repository_root}"

readonly goal_directory=".codex/goals"
readonly canonical_goal_path="${goal_directory}/standalone-cpp26-v2.md"
readonly legacy_goal_path="${goal_directory}/standalone-cpp26.md"
readonly required_reset_paths=(
  "${canonical_goal_path}"
  "${goal_directory}/archive/standalone-cpp26-2026-07-26-pre-reset.md"
  ".codex/notepads/archive/root-2026-07-26-pre-reset.md"
)

index_entry=""
for required_reset_path in "${required_reset_paths[@]}"; do
  if [[ ! -f "${required_reset_path}" || -L "${required_reset_path}" ]]; then
    echo "missing regular worktree reset artifact: ${required_reset_path}" >&2
    exit 1
  fi

  index_entry="$(git ls-files --stage -- "${required_reset_path}")"
  if [[ -z "${index_entry}" || "${index_entry}" == *$'\n'* ]]; then
    echo "missing unique indexed reset artifact: ${required_reset_path}" >&2
    exit 1
  fi
  read -r index_mode _ index_stage indexed_path <<<"${index_entry}"
  if [[ "${index_mode}" != "100644" ||
        "${index_stage}" != "0" ||
        "${indexed_path}" != "${required_reset_path}" ]]; then
    echo "invalid indexed reset artifact: ${required_reset_path}" >&2
    exit 1
  fi
done

if [[ -e "${legacy_goal_path}" || -L "${legacy_goal_path}" ]]; then
  echo "legacy canonical goal remains in the worktree" >&2
  exit 1
fi
legacy_index_entry=""
set +e
legacy_index_entry="$(git ls-files --stage -- "${legacy_goal_path}" 2>&1)"
ls_files_status=$?
set -e
if [[ "${ls_files_status}" -ne 0 ]]; then
  if [[ -n "${legacy_index_entry}" ]]; then
    printf '%s\n' "${legacy_index_entry}" >&2
  fi
  echo "failed to inspect legacy goal index state" >&2
  exit "${ls_files_status}"
fi
if [[ -n "${legacy_index_entry}" ]]; then
  echo "legacy canonical goal remains in the index" >&2
  exit 1
fi

readonly live_pathspecs=(
  .
  ":(exclude).codex/goals/archive/**"
  ":(exclude).codex/notepads/archive/**"
)
for scan_mode in --cached --untracked; do
  scan_options=("${scan_mode}")
  if [[ "${scan_mode}" == "--untracked" ]]; then
    scan_options+=(--no-exclude-standard)
  fi

  grep_output=""
  set +e
  grep_output="$(
    git grep \
      "${scan_options[@]}" \
      -l \
      -F \
      -e "${legacy_goal_path}" \
      -- "${live_pathspecs[@]}" 2>&1
  )"
  grep_status=$?
  set -e
  case "${grep_status}" in
    0)
      printf '%s\n' "${grep_output}" >&2
      echo "live repository content references the archived canonical goal" >&2
      exit 1
      ;;
    1)
      if [[ -n "${grep_output}" ]]; then
        printf '%s\n' "${grep_output}" >&2
        echo "failed to inspect live repository content" >&2
        exit 2
      fi
      ;;
    *)
      if [[ -n "${grep_output}" ]]; then
        printf '%s\n' "${grep_output}" >&2
      fi
      echo "failed to inspect live repository content" >&2
      exit "${grep_status}"
      ;;
  esac
done
