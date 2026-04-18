#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/test_helper.sh
source "$REPO_ROOT/tests/test_helper.sh"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p \
  "$tmp_dir/repos/iris-auth" \
  "$tmp_dir/repos/iris-admin-ui" \
  "$tmp_dir/repos/manual-extra" \
  "$tmp_dir/repos/wrong-target" \
  "$tmp_dir/workspaces/ticket-123"

cat >"$tmp_dir/workspaces.yaml" <<EOF
base_repo_dir: $tmp_dir/repos
workspace_root: $tmp_dir/workspaces
profiles:
  iris:
    - iris-auth
    - iris-admin-ui
    - iris-finance
EOF

printf 'iris\n' >"$tmp_dir/workspaces/ticket-123/.workspace-profile"
ln -s "../../repos/iris-auth" "$tmp_dir/workspaces/ticket-123/iris-auth"
ln -s "$tmp_dir/repos/wrong-target" "$tmp_dir/workspaces/ticket-123/iris-admin-ui"
ln -s "$tmp_dir/repos/manual-extra" "$tmp_dir/workspaces/ticket-123/manual-extra"

original_relative_target="$(readlink "$tmp_dir/workspaces/ticket-123/iris-auth")"
output="$(WORKSPACE_MANAGER_CONFIG="$tmp_dir/workspaces.yaml" "$REPO_ROOT/bin/workspace" sync "$tmp_dir/workspaces/ticket-123" 2>&1)"

assert_eq "$(readlink "$tmp_dir/workspaces/ticket-123/iris-auth")" "$original_relative_target"
assert_symlink_target "$tmp_dir/workspaces/ticket-123/iris-admin-ui" "$tmp_dir/repos/iris-admin-ui"
assert_symlink_target "$tmp_dir/workspaces/ticket-123/manual-extra" "$tmp_dir/repos/manual-extra"
assert_contains "$output" "Warning: Missing repo: $tmp_dir/repos/iris-finance"

mkdir -p "$tmp_dir/external/external-ticket"
printf 'iris\n' >"$tmp_dir/external/external-ticket/.workspace-profile"
ln -s "$tmp_dir/repos/wrong-target" "$tmp_dir/external/external-ticket/iris-auth"

cat >"$tmp_dir/missing-workspace-root.yaml" <<EOF
base_repo_dir: $tmp_dir/repos
workspace_root: $tmp_dir/missing-workspaces
profiles:
  iris:
    - iris-auth
    - iris-admin-ui
EOF

external_output="$(WORKSPACE_MANAGER_CONFIG="$tmp_dir/missing-workspace-root.yaml" "$REPO_ROOT/bin/workspace" sync "$tmp_dir/external/external-ticket" 2>&1)"

assert_symlink_target "$tmp_dir/external/external-ticket/iris-auth" "$tmp_dir/repos/iris-auth"
assert_symlink_target "$tmp_dir/external/external-ticket/iris-admin-ui" "$tmp_dir/repos/iris-admin-ui"
assert_contains "$external_output" "Synced workspace: $tmp_dir/external/external-ticket"

cat >"$tmp_dir/missing-base-repo-dir.yaml" <<EOF
base_repo_dir: $tmp_dir/missing-repos
workspace_root: $tmp_dir/workspaces
profiles:
  iris:
    - iris-auth
EOF

set +e
output="$(WORKSPACE_MANAGER_CONFIG="$tmp_dir/missing-base-repo-dir.yaml" "$REPO_ROOT/bin/workspace" sync "$tmp_dir/workspaces/ticket-123" 2>&1)"
status=$?
set -e

assert_exit_code "$status" 1
assert_contains "$output" "base_repo_dir"

set +e
output="$(WORKSPACE_MANAGER_CONFIG="$tmp_dir/workspaces.yaml" "$REPO_ROOT/bin/workspace" sync "$tmp_dir/workspaces/ticket-123" extra 2>&1)"
status=$?
set -e

assert_exit_code "$status" 1
assert_contains "$output" "Usage: workspace sync <path>"
