#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/test_helper.sh
source "$REPO_ROOT/tests/test_helper.sh"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/repos/iris-auth" "$tmp_dir/repos/iris-admin-ui"

cat >"$tmp_dir/workspaces.yaml" <<EOF
base_repo_dir: $tmp_dir/repos
workspace_root: $tmp_dir/workspaces
profiles:
  iris:
    - iris-auth
    - iris-admin-ui
EOF

WORKSPACE_MANAGER_CONFIG="$tmp_dir/workspaces.yaml" "$REPO_ROOT/bin/workspace" create ticket-123 --profile iris >/tmp/workspace-create.out

workspace_path="$tmp_dir/workspaces/ticket-123"
assert_file_exists "$workspace_path/.workspace-profile"
assert_eq "$(<"$workspace_path/.workspace-profile")" "iris"
assert_symlink_target "$workspace_path/iris-auth" "$tmp_dir/repos/iris-auth"
assert_symlink_target "$workspace_path/iris-admin-ui" "$tmp_dir/repos/iris-admin-ui"

mkdir -p "$tmp_dir/workspaces/existing-dir"

set +e
output="$(WORKSPACE_MANAGER_CONFIG="$tmp_dir/workspaces.yaml" "$REPO_ROOT/bin/workspace" create existing-dir --profile iris 2>&1)"
status=$?
set -e

assert_exit_code "$status" 1
assert_contains "$output" "Path exists but is not a managed workspace"
