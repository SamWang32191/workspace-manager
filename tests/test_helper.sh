#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  [ "$actual" = "$expected" ] || fail "expected [$expected], got [$actual]"
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  case "$haystack" in
    *"$needle"*) ;;
    *) fail "expected output to contain [$needle], got [$haystack]" ;;
  esac
}

assert_exit_code() {
  local actual="$1"
  local expected="$2"
  [ "$actual" -eq "$expected" ] || fail "expected exit code [$expected], got [$actual]"
}

assert_file_exists() {
  [ -e "$1" ] || fail "expected path to exist: $1"
}

assert_symlink_target() {
  local path="$1"
  local expected="$2"
  [ -L "$path" ] || fail "expected symlink: $path"
  local actual
  actual="$(readlink "$path")"
  [ "$actual" = "$expected" ] || fail "expected [$path] -> [$expected], got [$actual]"
}
