#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/test_helper.sh
source "$REPO_ROOT/tests/test_helper.sh"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/repos/iris-auth" "$tmp_dir/repos/iris-admin-ui" "$tmp_dir/repos/wrong-target" "$tmp_dir/workspaces/ticket-123"

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
ln -s "$tmp_dir/repos/iris-auth" "$tmp_dir/workspaces/ticket-123/iris-auth"
ln -s "$tmp_dir/repos/wrong-target" "$tmp_dir/workspaces/ticket-123/iris-admin-ui"

show_output="$(WORKSPACE_MANAGER_CONFIG="$tmp_dir/workspaces.yaml" "$REPO_ROOT/bin/workspace" show "$tmp_dir/workspaces/ticket-123")"
assert_contains "$show_output" "Path: $tmp_dir/workspaces/ticket-123"
assert_contains "$show_output" "Profile: iris"
assert_contains "$show_output" "- iris-auth"
assert_contains "$show_output" "- iris-admin-ui"

set +e
doctor_output="$(WORKSPACE_MANAGER_CONFIG="$tmp_dir/workspaces.yaml" "$REPO_ROOT/bin/workspace" doctor "$tmp_dir/workspaces/ticket-123" 2>&1)"
doctor_status=$?
set -e

assert_exit_code "$doctor_status" 1
assert_contains "$doctor_output" "OK: iris-auth"
assert_contains "$doctor_output" "ERROR: wrong symlink target for iris-admin-ui"
assert_contains "$doctor_output" "WARNING: missing repo source $tmp_dir/repos/iris-finance"
