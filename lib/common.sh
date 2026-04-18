#!/usr/bin/env bash
set -euo pipefail

print_usage() {
  cat <<'EOF'
Usage:
  workspace list-profiles
  workspace create <name> --profile <profile>
  workspace sync <path>
  workspace show <path>
  workspace doctor <path>
EOF
}

die() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

warn() {
  printf 'Warning: %s\n' "$1" >&2
}
