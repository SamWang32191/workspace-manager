#!/usr/bin/env bash
set -euo pipefail

ensure_profile_links() {
  local workspace_path="$1"
  local profile="$2"
  local repo
  local base_dir
  local src
  local dst

  base_dir="$(base_repo_dir)"

  while IFS= read -r repo; do
    [ -n "$repo" ] || continue
    src="$base_dir/$repo"
    dst="$workspace_path/$repo"

    if [ ! -d "$src" ]; then
      warn "Missing repo: $src"
      continue
    fi

    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
      warn "Skipping existing non-symlink: $dst"
      continue
    fi

    ln -s "$src" "$dst"
  done < <(profile_repos "$profile")
}
