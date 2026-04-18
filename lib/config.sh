#!/usr/bin/env bash
set -euo pipefail

config_path() {
  printf '%s\n' "${WORKSPACE_MANAGER_CONFIG:-$HOME/.config/workspace-manager/workspaces.yaml}"
}

ensure_config_exists() {
  local path
  path="$(config_path)"
  [ -f "$path" ] || die "Config not found: $path"
}

config_query() {
  ensure_config_exists
  ruby "$REPO_ROOT/scripts/config_query.rb" "$(config_path)" "$@"
}

list_profiles() {
  config_query list-profiles
}

profile_exists() {
  local profile="$1"
  local output
  local status

  set +e
  output="$(config_query profile-repos "$profile" 2>&1 >/dev/null)"
  status=$?
  set -e

  if [ "$status" -eq 0 ]; then
    return 0
  fi

  if [ "$status" -eq 3 ]; then
    return 1
  fi

  [ -z "$output" ] || printf '%s\n' "$output" >&2
  return "$status"
}

profile_repos() {
  config_query profile-repos "$1"
}

base_repo_dir() {
  config_query base-repo-dir
}

workspace_root() {
  config_query workspace-root
}

ensure_existing_directory() {
  local path="$1"
  local label="$2"

  [ -d "$path" ] || die "Invalid config: $label does not exist: $path"
}

ensure_base_repo_dir_exists() {
  ensure_existing_directory "$(base_repo_dir)" "base_repo_dir"
}

ensure_workspace_root_exists() {
  ensure_existing_directory "$(workspace_root)" "workspace_root"
}

ensure_workspace_paths_exist() {
  ensure_workspace_root_exists
  ensure_base_repo_dir_exists
}
