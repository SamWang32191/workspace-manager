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

cat >"$tmp_dir/top_level_only.yaml" <<'EOF'
base_repo_dir: /tmp/only-repos
workspace_root: /tmp/only-workspaces
EOF

output="$(ruby "$REPO_ROOT/scripts/config_query.rb" "$tmp_dir/top_level_only.yaml" base-repo-dir)"
assert_eq "$output" "/tmp/only-repos"

output="$(ruby "$REPO_ROOT/scripts/config_query.rb" "$tmp_dir/top_level_only.yaml" workspace-root)"
assert_eq "$output" "/tmp/only-workspaces"

set +e
output="$(WORKSPACE_MANAGER_CONFIG="$tmp_dir/workspaces.yaml" bash -c 'set -euo pipefail
REPO_ROOT="$1"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/config.sh"
profile_exists missing' _ "$REPO_ROOT" 2>&1)"
status=$?
set -e

assert_exit_code "$status" 1
assert_eq "$output" ""

cat >"$tmp_dir/malformed.yaml" <<'EOF'
base_repo_dir: /tmp/repos
profiles:
  iris:
    - broken
  :
EOF

set +e
output="$(WORKSPACE_MANAGER_CONFIG="$tmp_dir/malformed.yaml" bash -c 'set -euo pipefail
REPO_ROOT="$1"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/config.sh"
profile_exists iris' _ "$REPO_ROOT" 2>&1)"
status=$?
set -e

[ "$status" -ne 0 ] || fail "expected profile_exists to fail on malformed YAML"
assert_contains "$output" "Psych::SyntaxError"

cat >"$tmp_dir/invalid_profiles_type.yaml" <<'EOF'
base_repo_dir: /tmp/repos
workspace_root: /tmp/workspaces
profiles:
  - iris
EOF

set +e
output="$(ruby "$REPO_ROOT/scripts/config_query.rb" "$tmp_dir/invalid_profiles_type.yaml" list-profiles 2>&1)"
status=$?
set -e

[ "$status" -ne 0 ] || fail "expected list-profiles to fail on non-mapping profiles"
assert_contains "$output" "Invalid config: profiles must be a mapping"

cat >"$tmp_dir/invalid_profile_repos.yaml" <<'EOF'
base_repo_dir: /tmp/repos
workspace_root: /tmp/workspaces
profiles:
  iris: iris-auth
EOF

set +e
output="$(WORKSPACE_MANAGER_CONFIG="$tmp_dir/invalid_profile_repos.yaml" bash -c 'set -euo pipefail
REPO_ROOT="$1"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/config.sh"
profile_exists iris' _ "$REPO_ROOT" 2>&1)"
status=$?
set -e

[ "$status" -ne 0 ] || fail "expected profile_exists to fail on non-list profile repos"
assert_contains "$output" "Invalid config: profile [iris] repos must be a list"

cat >"$tmp_dir/missing_base_repo_dir.yaml" <<'EOF'
workspace_root: /tmp/workspaces
EOF

set +e
output="$(ruby "$REPO_ROOT/scripts/config_query.rb" "$tmp_dir/missing_base_repo_dir.yaml" base-repo-dir 2>&1)"
status=$?
set -e

[ "$status" -ne 0 ] || fail "expected base-repo-dir to fail when key is missing"
assert_contains "$output" "Invalid config: base_repo_dir must be a string"

cat >"$tmp_dir/invalid_workspace_root_type.yaml" <<'EOF'
base_repo_dir: /tmp/repos
workspace_root:
  nested: nope
EOF

set +e
output="$(ruby "$REPO_ROOT/scripts/config_query.rb" "$tmp_dir/invalid_workspace_root_type.yaml" workspace-root 2>&1)"
status=$?
set -e

[ "$status" -ne 0 ] || fail "expected workspace-root to fail on non-string value"
assert_contains "$output" "Invalid config: workspace_root must be a string"

cat >"$tmp_dir/null_profile_repos.yaml" <<'EOF'
base_repo_dir: /tmp/repos
workspace_root: /tmp/workspaces
profiles:
  iris:
EOF

set +e
output="$(WORKSPACE_MANAGER_CONFIG="$tmp_dir/null_profile_repos.yaml" bash -c 'set -euo pipefail
REPO_ROOT="$1"
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/config.sh"
profile_exists iris' _ "$REPO_ROOT" 2>&1)"
status=$?
set -e

[ "$status" -ne 0 ] || fail "expected profile_exists to fail on null profile repos"
assert_contains "$output" "Invalid config: profile [iris] repos must be a list"
