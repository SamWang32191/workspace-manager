#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/test_helper.sh
source "$REPO_ROOT/tests/test_helper.sh"

set +e
output="$($REPO_ROOT/bin/workspace 2>&1)"
status=$?
set -e

assert_exit_code "$status" 0
assert_contains "$output" "Usage:"
assert_contains "$output" "workspace list-profiles"
assert_contains "$output" "workspace create <name> --profile <profile>"
