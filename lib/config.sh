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
  config_query profile-repos "$profile" >/dev/null 2>&1
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
