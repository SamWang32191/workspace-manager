#!/usr/bin/env bash
set -euo pipefail

workspace_path_from_name() {
  local name="$1"
  printf '%s/%s\n' "$(workspace_root)" "$name"
}

metadata_file() {
  local workspace_path="$1"
  printf '%s/.workspace-profile\n' "$workspace_path"
}

read_profile_metadata() {
  local workspace_path="$1"
  local file
  file="$(metadata_file "$workspace_path")"
  [ -f "$file" ] || die "Missing workspace metadata: $file"
  tr -d '\n' <"$file"
}

write_profile_metadata() {
  local workspace_path="$1"
  local profile="$2"
  printf '%s\n' "$profile" >"$(metadata_file "$workspace_path")"
}

ensure_new_workspace_dir() {
  local workspace_path="$1"

  if [ -e "$workspace_path" ]; then
    if [ -f "$(metadata_file "$workspace_path")" ]; then
      die "Workspace already exists: $workspace_path. Use sync instead."
    fi
    die "Path exists but is not a managed workspace: $workspace_path"
  fi

  mkdir -p "$workspace_path"
}
