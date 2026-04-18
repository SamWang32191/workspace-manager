#!/usr/bin/env bash
set -euo pipefail

ensure_profile_links() {
  local workspace_path="$1"
  local profile="$2"
  local repo
  local base_dir
  local src
  local dst
  local current_target

  base_dir="$(base_repo_dir)"

  while IFS= read -r repo; do
    [ -n "$repo" ] || continue
    src="$base_dir/$repo"
    dst="$workspace_path/$repo"

    if [ ! -d "$src" ]; then
      warn "Missing repo: $src"
      continue
    fi

    if [ -L "$dst" ]; then
      current_target="$(readlink "$dst")"
      if [ "$current_target" = "$src" ]; then
        continue
      fi
      rm -f "$dst"
      ln -s "$src" "$dst"
      continue
    fi

    if [ -e "$dst" ]; then
      warn "Skipping existing non-symlink: $dst"
      continue
    fi

    ln -s "$src" "$dst"
  done < <(profile_repos "$profile")
}

doctor_profile_links() {
  local workspace_path="$1"
  local profile="$2"
  local repo
  local base_dir
  local src
  local dst
  local current_target
  local had_error=0

  base_dir="$(base_repo_dir)"

  while IFS= read -r repo; do
    [ -n "$repo" ] || continue
    src="$base_dir/$repo"
    dst="$workspace_path/$repo"

    if [ ! -d "$src" ]; then
      printf 'WARNING: missing repo source %s\n' "$src"
      continue
    fi

    if [ -L "$dst" ]; then
      current_target="$(readlink "$dst")"
      if [ "$current_target" = "$src" ]; then
        printf 'OK: %s\n' "$repo"
      else
        printf 'ERROR: wrong symlink target for %s\n' "$repo"
        had_error=1
      fi
      continue
    fi

    if [ -e "$dst" ]; then
      printf 'ERROR: managed path is not a symlink for %s\n' "$repo"
      had_error=1
      continue
    fi

    printf 'ERROR: missing managed link for %s\n' "$repo"
    had_error=1
  done < <(profile_repos "$profile")

  return "$had_error"
}
