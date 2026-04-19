#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/test_helper.sh
source "$REPO_ROOT/tests/test_helper.sh"

completion_file="$REPO_ROOT/completions/_workspace"
assert_file_exists "$completion_file"

completion_source="$(<"$completion_file")"
assert_contains "$completion_source" "#compdef workspace"
assert_contains "$completion_source" "help"
assert_contains "$completion_source" "list-profiles"
assert_contains "$completion_source" "create"
assert_contains "$completion_source" "sync"
assert_contains "$completion_source" "show"
assert_contains "$completion_source" "doctor"
