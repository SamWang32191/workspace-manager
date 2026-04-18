#!/usr/bin/env bash
set -euo pipefail

resolve_existing_dir() {
  local path="$1"

  (cd "$path" 2>/dev/null && pwd -P)
}

resolve_symlink_dir_target() {
  local path="$1"
  local target

  target="$(readlink "$path")" || return 1

  if [[ "$target" = /* ]]; then
    resolve_existing_dir "$target"
    return
  fi

  resolve_existing_dir "$(dirname "$path")/$target"
}

symlink_points_to_dir() {
  local path="$1"
  local expected_target="$2"
  local resolved_target
  local resolved_expected

  resolved_target="$(resolve_symlink_dir_target "$path")" || return 1
  resolved_expected="$(resolve_existing_dir "$expected_target")" || return 1
  [ "$resolved_target" = "$resolved_expected" ]
}

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

    if [ -L "$dst" ]; then
      if symlink_points_to_dir "$dst" "$src"; then
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
      if symlink_points_to_dir "$dst" "$src"; then
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
