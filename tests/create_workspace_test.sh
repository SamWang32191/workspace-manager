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
workspace_root: $tmp_dir/root/workspaces
profiles:
  iris:
    - iris-auth
    - iris-admin-ui
EOF

WORKSPACE_MANAGER_CONFIG="$tmp_dir/workspaces.yaml" "$REPO_ROOT/bin/workspace" create ticket-123 --profile iris >/tmp/workspace-create.out

workspace_path="$tmp_dir/root/workspaces/ticket-123"
assert_file_exists "$workspace_path/.workspace-profile"
assert_eq "$(<"$workspace_path/.workspace-profile")" "iris"
assert_symlink_target "$workspace_path/iris-auth" "$tmp_dir/repos/iris-auth"
assert_symlink_target "$workspace_path/iris-admin-ui" "$tmp_dir/repos/iris-admin-ui"

mkdir -p "$tmp_dir/root/workspaces/existing-dir"

set +e
output="$(WORKSPACE_MANAGER_CONFIG="$tmp_dir/workspaces.yaml" "$REPO_ROOT/bin/workspace" create existing-dir --profile iris 2>&1)"
status=$?
set -e

assert_exit_code "$status" 1
assert_contains "$output" "Path exists but is not a managed workspace"

set +e
output="$(WORKSPACE_MANAGER_CONFIG="$tmp_dir/workspaces.yaml" "$REPO_ROOT/bin/workspace" create ../../escape --profile iris 2>&1)"
status=$?
set -e

assert_exit_code "$status" 1
assert_contains "$output" "Invalid workspace name"
[ ! -e "$tmp_dir/escape" ] || fail "expected create to reject path traversal names"

set +e
output="$(WORKSPACE_MANAGER_CONFIG="$tmp_dir/workspaces.yaml" "$REPO_ROOT/bin/workspace" create ticket-456 --profile iris extra 2>&1)"
status=$?
set -e

assert_exit_code "$status" 1
assert_contains "$output" "Usage: workspace create <name> --profile <profile>"

cat >"$tmp_dir/duplicate-repos.yaml" <<EOF
base_repo_dir: $tmp_dir/repos
workspace_root: $tmp_dir/root/workspaces
profiles:
  iris:
    - iris-auth
    - iris-auth
EOF

set +e
output="$(WORKSPACE_MANAGER_CONFIG="$tmp_dir/duplicate-repos.yaml" "$REPO_ROOT/bin/workspace" create dup-case --profile iris 2>&1)"
status=$?
set -e

assert_exit_code "$status" 1
assert_contains "$output" "Invalid config: profile [iris] repos must not contain duplicates"
[ ! -e "$tmp_dir/root/workspaces/dup-case" ] || fail "expected create to fail before creating workspace for duplicate repos"
[ ! -e "$tmp_dir/repos/iris-auth/iris-auth" ] || fail "expected duplicate repo config to avoid polluting base repo dir"
