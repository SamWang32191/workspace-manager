#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/test_helper.sh
source "$REPO_ROOT/tests/test_helper.sh"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$tmp_dir/workspaces.yaml" <<'EOF'
base_repo_dir: /tmp/repos
workspace_root: /tmp/workspaces
profiles:
  iris:
    - iris-auth
    - iris-admin-ui
  transglobe:
    - kapok-auth
EOF

output="$(WORKSPACE_MANAGER_CONFIG="$tmp_dir/workspaces.yaml" "$REPO_ROOT/bin/workspace" list-profiles)"
expected=$'iris\ntransglobe'

assert_eq "$output" "$expected"
