# Workspace Manager CLI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Bash-first CLI that creates and syncs workspace symlinks from centrally managed YAML profiles, with per-workspace `.workspace-profile` metadata.

**Architecture:** The repo stays Bash-first: `bin/workspace` is the only entrypoint, small Bash libraries hold command logic, and one tiny Ruby helper reads YAML so the shell code does not try to parse YAML itself. Central config remains read-only and static; dynamic state lives only in each workspace's `.workspace-profile` file.

**Tech Stack:** Bash, Ruby stdlib `YAML`, standard Unix tools (`ln`, `readlink`, `mkdir`, `rm`), shell-based integration tests.

---

## File Structure

- `bin/workspace` — CLI entrypoint and subcommand dispatch.
- `lib/common.sh` — usage text, logging, fatal error handling, argument helpers.
- `lib/config.sh` — config path resolution and wrappers around the Ruby YAML helper.
- `lib/workspace.sh` — workspace path resolution, `.workspace-profile` read/write, managed-workspace validation.
- `lib/symlink.sh` — create/sync link behavior and doctor checks for managed repos.
- `scripts/config_query.rb` — tiny read-only YAML helper used by Bash.
- `tests/test_helper.sh` — shell assertions shared by all tests.
- `tests/help_test.sh` — smoke test for CLI usage output.
- `tests/list_profiles_test.sh` — config parsing and `list-profiles` behavior.
- `tests/create_workspace_test.sh` — `create` command behavior, metadata file creation, refusal to adopt unknown existing directories.
- `tests/sync_workspace_test.sh` — sync behavior for correct links, wrong links, missing repos, unmanaged extra links.
- `tests/show_doctor_test.sh` — `show` output and `doctor` status reporting.
- `Makefile` — single `test` target to run the shell test suite.
- `README.md` — setup, config file format, command reference, migration notes.
- `examples/workspaces.yaml` — sample config users can copy into `~/.config/workspace-manager/workspaces.yaml`.

## Behavioral Decisions Locked In

- Config file path defaults to `${WORKSPACE_MANAGER_CONFIG:-$HOME/.config/workspace-manager/workspaces.yaml}`.
- `create <name> --profile <profile>` always creates under `workspace_root` from config.
- `sync`, `show`, and `doctor` take an explicit filesystem path.
- `.workspace-profile` is a single-line text file containing only the profile name.
- `sync` never deletes extra unmanaged symlinks in v1.
- Missing repo sources are warnings, not fatal errors.
- `doctor` returns exit code `1` for broken managed state (missing metadata, wrong target, missing managed link, unmanaged non-symlink collision) and `0` when only warnings are present.

### Task 1: Bootstrap the CLI skeleton

**Files:**
- Create: `bin/workspace`
- Create: `lib/common.sh`
- Create: `tests/test_helper.sh`
- Create: `tests/help_test.sh`
- Create: `Makefile`

- [ ] **Step 1: Write the failing help test**

Create `tests/test_helper.sh`:

```bash
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
```

Create `tests/help_test.sh`:

```bash
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
```

Create `Makefile`:

```makefile
.RECIPEPREFIX := >
SHELL := /bin/bash

.PHONY: test
test:
> bash tests/help_test.sh
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
make test
```

Expected: FAIL with `/bin/workspace` missing or not executable.

- [ ] **Step 3: Write the minimal implementation**

Create `lib/common.sh`:

```bash
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
```

Create `bin/workspace`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=lib/common.sh
source "$REPO_ROOT/lib/common.sh"

main() {
  case "${1:-}" in
    ""|help|-h|--help)
      print_usage
      ;;
    *)
      die "Unknown command: ${1}"
      ;;
  esac
}

main "$@"
```

Run:

```bash
chmod +x bin/workspace tests/help_test.sh tests/test_helper.sh
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
make test
```

Expected: PASS with `tests/help_test.sh` completing without output.

- [ ] **Step 5: Commit**

```bash
git add Makefile bin/workspace lib/common.sh tests/test_helper.sh tests/help_test.sh
git commit -m "chore: bootstrap workspace manager cli"
```

### Task 2: Add YAML-backed profile listing

**Files:**
- Modify: `bin/workspace`
- Create: `lib/config.sh`
- Create: `scripts/config_query.rb`
- Create: `tests/list_profiles_test.sh`
- Modify: `Makefile`
- Create: `examples/workspaces.yaml`

- [ ] **Step 1: Write the failing profile-list test**

Create `tests/list_profiles_test.sh`:

```bash
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
```

Update `Makefile`:

```makefile
.RECIPEPREFIX := >
SHELL := /bin/bash

.PHONY: test
test:
> bash tests/help_test.sh
> bash tests/list_profiles_test.sh
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
make test
```

Expected: FAIL with `Unknown command: list-profiles`.

- [ ] **Step 3: Write the minimal implementation**

Create `scripts/config_query.rb`:

```ruby
#!/usr/bin/env ruby
require 'yaml'

config_path = ARGV.shift or abort 'missing config path'
command = ARGV.shift or abort 'missing command'

config = YAML.load_file(config_path) || {}
profiles = config.fetch('profiles')

case command
when 'list-profiles'
  puts profiles.keys.sort
when 'profile-repos'
  profile = ARGV.shift or abort 'missing profile'
  puts profiles.fetch(profile)
when 'base-repo-dir'
  puts config.fetch('base_repo_dir')
when 'workspace-root'
  puts config.fetch('workspace_root')
else
  abort "unknown command: #{command}"
end
```

Create `lib/config.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

config_path() {
  printf '%s\n' "${WORKSPACE_MANAGER_CONFIG:-$HOME/.config/workspace-manager/workspaces.yaml}"
}

ensure_config_exists() {
  local path
  path="$(config_path)"
  [ -f "$path" ] || die "Config not found: $path"
}

config_query() {
  ensure_config_exists
  ruby "$REPO_ROOT/scripts/config_query.rb" "$(config_path)" "$@"
}

list_profiles() {
  config_query list-profiles
}

profile_exists() {
  local profile="$1"
  config_query profile-repos "$profile" >/dev/null 2>&1
}

profile_repos() {
  config_query profile-repos "$1"
}

base_repo_dir() {
  config_query base-repo-dir
}

workspace_root() {
  config_query workspace-root
}
```

Create `examples/workspaces.yaml`:

```yaml
base_repo_dir: /Users/samwang/code/github.com/softleader
workspace_root: /Users/samwang/tmp/Workspace

profiles:
  iris:
    - iris-admin-ui
    - iris-auth
    - iris-finance
  scins-asi-cie:
    - scins-asi-auth
    - scins-asi-frontend-cie
  transglobe:
    - kapok-auth
    - kapok-auth-ui
```

Update `bin/workspace`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=lib/common.sh
source "$REPO_ROOT/lib/common.sh"
# shellcheck source=lib/config.sh
source "$REPO_ROOT/lib/config.sh"

cmd_list_profiles() {
  list_profiles
}

main() {
  case "${1:-}" in
    ""|help|-h|--help)
      print_usage
      ;;
    list-profiles)
      cmd_list_profiles
      ;;
    *)
      die "Unknown command: ${1}"
      ;;
  esac
}

main "$@"
```

Run:

```bash
chmod +x scripts/config_query.rb tests/list_profiles_test.sh
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
make test
```

Expected: PASS with both shell tests completing without output.

- [ ] **Step 5: Commit**

```bash
git add Makefile bin/workspace lib/config.sh scripts/config_query.rb tests/list_profiles_test.sh examples/workspaces.yaml
git commit -m "feat: add yaml-backed profile loading"
```

### Task 3: Implement `create` and workspace metadata

**Files:**
- Modify: `bin/workspace`
- Create: `lib/workspace.sh`
- Create: `lib/symlink.sh`
- Create: `tests/create_workspace_test.sh`
- Modify: `Makefile`

- [ ] **Step 1: Write the failing create test**

Create `tests/create_workspace_test.sh`:

```bash
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
```

Update `Makefile`:

```makefile
.RECIPEPREFIX := >
SHELL := /bin/bash

.PHONY: test
test:
> bash tests/help_test.sh
> bash tests/list_profiles_test.sh
> bash tests/create_workspace_test.sh
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
make test
```

Expected: FAIL with `Unknown command: create`.

- [ ] **Step 3: Write the minimal implementation**

Create `lib/workspace.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

workspace_path_from_name() {
  local name="$1"
  printf '%s/%s\n' "$(workspace_root)" "$name"
}

metadata_file() {
  local workspace_path="$1"
  printf '%s/.workspace-profile\n' "$workspace_path"
}

read_profile_metadata() {
  local workspace_path="$1"
  local file
  file="$(metadata_file "$workspace_path")"
  [ -f "$file" ] || die "Missing workspace metadata: $file"
  tr -d '\n' <"$file"
}

write_profile_metadata() {
  local workspace_path="$1"
  local profile="$2"
  printf '%s\n' "$profile" >"$(metadata_file "$workspace_path")"
}

ensure_new_workspace_dir() {
  local workspace_path="$1"

  if [ -e "$workspace_path" ]; then
    if [ -f "$(metadata_file "$workspace_path")" ]; then
      die "Workspace already exists: $workspace_path. Use sync instead."
    fi
    die "Path exists but is not a managed workspace: $workspace_path"
  fi

  mkdir -p "$workspace_path"
}
```

Create `lib/symlink.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ensure_profile_links() {
  local workspace_path="$1"
  local profile="$2"
  local repo
  local base_dir
  local src
  local dst

  base_dir="$(base_repo_dir)"

  while IFS= read -r repo; do
    [ -n "$repo" ] || continue
    src="$base_dir/$repo"
    dst="$workspace_path/$repo"

    if [ ! -d "$src" ]; then
      warn "Missing repo: $src"
      continue
    fi

    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
      warn "Skipping existing non-symlink: $dst"
      continue
    fi

    ln -s "$src" "$dst"
  done < <(profile_repos "$profile")
}
```

Update `bin/workspace`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=lib/common.sh
source "$REPO_ROOT/lib/common.sh"
# shellcheck source=lib/config.sh
source "$REPO_ROOT/lib/config.sh"
# shellcheck source=lib/workspace.sh
source "$REPO_ROOT/lib/workspace.sh"
# shellcheck source=lib/symlink.sh
source "$REPO_ROOT/lib/symlink.sh"

cmd_list_profiles() {
  list_profiles
}

cmd_create() {
  local name="${1:-}"
  local flag="${2:-}"
  local profile="${3:-}"
  local workspace_path

  [ -n "$name" ] || die "Usage: workspace create <name> --profile <profile>"
  [ "$flag" = "--profile" ] || die "Usage: workspace create <name> --profile <profile>"
  [ -n "$profile" ] || die "Usage: workspace create <name> --profile <profile>"
  profile_exists "$profile" || die "Unknown profile: $profile"

  workspace_path="$(workspace_path_from_name "$name")"
  ensure_new_workspace_dir "$workspace_path"
  write_profile_metadata "$workspace_path" "$profile"
  ensure_profile_links "$workspace_path" "$profile"

  printf 'Created workspace: %s\n' "$workspace_path"
}

main() {
  case "${1:-}" in
    ""|help|-h|--help)
      print_usage
      ;;
    list-profiles)
      cmd_list_profiles
      ;;
    create)
      shift
      cmd_create "$@"
      ;;
    *)
      die "Unknown command: ${1}"
      ;;
  esac
}

main "$@"
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
make test
```

Expected: PASS with `tests/create_workspace_test.sh` completing without output.

- [ ] **Step 5: Commit**

```bash
git add Makefile bin/workspace lib/workspace.sh lib/symlink.sh tests/create_workspace_test.sh
git commit -m "feat: add workspace creation command"
```

### Task 4: Make `sync` safe and idempotent

**Files:**
- Modify: `bin/workspace`
- Modify: `lib/symlink.sh`
- Create: `tests/sync_workspace_test.sh`
- Modify: `Makefile`

- [ ] **Step 1: Write the failing sync test**

Create `tests/sync_workspace_test.sh`:

```bash
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
ln -s "$tmp_dir/repos/iris-auth" "$tmp_dir/workspaces/ticket-123/iris-auth"
ln -s "$tmp_dir/repos/wrong-target" "$tmp_dir/workspaces/ticket-123/iris-admin-ui"
ln -s "$tmp_dir/repos/manual-extra" "$tmp_dir/workspaces/ticket-123/manual-extra"

output="$(WORKSPACE_MANAGER_CONFIG="$tmp_dir/workspaces.yaml" "$REPO_ROOT/bin/workspace" sync "$tmp_dir/workspaces/ticket-123" 2>&1)"

assert_symlink_target "$tmp_dir/workspaces/ticket-123/iris-auth" "$tmp_dir/repos/iris-auth"
assert_symlink_target "$tmp_dir/workspaces/ticket-123/iris-admin-ui" "$tmp_dir/repos/iris-admin-ui"
assert_symlink_target "$tmp_dir/workspaces/ticket-123/manual-extra" "$tmp_dir/repos/manual-extra"
assert_contains "$output" "Warning: Missing repo: $tmp_dir/repos/iris-finance"
```

Update `Makefile`:

```makefile
.RECIPEPREFIX := >
SHELL := /bin/bash

.PHONY: test
test:
> bash tests/help_test.sh
> bash tests/list_profiles_test.sh
> bash tests/create_workspace_test.sh
> bash tests/sync_workspace_test.sh
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
make test
```

Expected: FAIL with `Unknown command: sync` or `ln: ... File exists`.

- [ ] **Step 3: Write the minimal implementation**

Update `lib/symlink.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ensure_profile_links() {
  local workspace_path="$1"
  local profile="$2"
  local repo
  local base_dir
  local src
  local dst
  local current_target

  base_dir="$(base_repo_dir)"

  while IFS= read -r repo; do
    [ -n "$repo" ] || continue
    src="$base_dir/$repo"
    dst="$workspace_path/$repo"

    if [ ! -d "$src" ]; then
      warn "Missing repo: $src"
      continue
    fi

    if [ -L "$dst" ]; then
      current_target="$(readlink "$dst")"
      if [ "$current_target" = "$src" ]; then
        continue
      fi
      rm -f "$dst"
      ln -s "$src" "$dst"
      continue
    fi

    if [ -e "$dst" ]; then
      warn "Skipping existing non-symlink: $dst"
      continue
    fi

    ln -s "$src" "$dst"
  done < <(profile_repos "$profile")
}
```

Update `bin/workspace`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=lib/common.sh
source "$REPO_ROOT/lib/common.sh"
# shellcheck source=lib/config.sh
source "$REPO_ROOT/lib/config.sh"
# shellcheck source=lib/workspace.sh
source "$REPO_ROOT/lib/workspace.sh"
# shellcheck source=lib/symlink.sh
source "$REPO_ROOT/lib/symlink.sh"

cmd_list_profiles() {
  list_profiles
}

cmd_create() {
  local name="${1:-}"
  local flag="${2:-}"
  local profile="${3:-}"
  local workspace_path

  [ -n "$name" ] || die "Usage: workspace create <name> --profile <profile>"
  [ "$flag" = "--profile" ] || die "Usage: workspace create <name> --profile <profile>"
  [ -n "$profile" ] || die "Usage: workspace create <name> --profile <profile>"
  profile_exists "$profile" || die "Unknown profile: $profile"

  workspace_path="$(workspace_path_from_name "$name")"
  ensure_new_workspace_dir "$workspace_path"
  write_profile_metadata "$workspace_path" "$profile"
  ensure_profile_links "$workspace_path" "$profile"

  printf 'Created workspace: %s\n' "$workspace_path"
}

cmd_sync() {
  local workspace_path="${1:-}"
  local profile

  [ -n "$workspace_path" ] || die "Usage: workspace sync <path>"
  profile="$(read_profile_metadata "$workspace_path")"
  profile_exists "$profile" || die "Unknown profile in metadata: $profile"
  ensure_profile_links "$workspace_path" "$profile"

  printf 'Synced workspace: %s\n' "$workspace_path"
}

main() {
  case "${1:-}" in
    ""|help|-h|--help)
      print_usage
      ;;
    list-profiles)
      cmd_list_profiles
      ;;
    create)
      shift
      cmd_create "$@"
      ;;
    sync)
      shift
      cmd_sync "$@"
      ;;
    *)
      die "Unknown command: ${1}"
      ;;
  esac
}

main "$@"
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
make test
```

Expected: PASS with `tests/sync_workspace_test.sh` completing without output.

- [ ] **Step 5: Commit**

```bash
git add Makefile bin/workspace lib/symlink.sh tests/sync_workspace_test.sh
git commit -m "feat: add safe workspace sync"
```

### Task 5: Add `show` and `doctor`

**Files:**
- Modify: `bin/workspace`
- Modify: `lib/symlink.sh`
- Create: `tests/show_doctor_test.sh`
- Modify: `Makefile`
- Modify: `README.md`

- [ ] **Step 1: Write the failing show/doctor test**

Create `tests/show_doctor_test.sh`:

```bash
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
```

Update `Makefile`:

```makefile
.RECIPEPREFIX := >
SHELL := /bin/bash

.PHONY: test
test:
> bash tests/help_test.sh
> bash tests/list_profiles_test.sh
> bash tests/create_workspace_test.sh
> bash tests/sync_workspace_test.sh
> bash tests/show_doctor_test.sh
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
make test
```

Expected: FAIL with `Unknown command: show`.

- [ ] **Step 3: Write the minimal implementation**

Update `lib/symlink.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ensure_profile_links() {
  local workspace_path="$1"
  local profile="$2"
  local repo
  local base_dir
  local src
  local dst
  local current_target

  base_dir="$(base_repo_dir)"

  while IFS= read -r repo; do
    [ -n "$repo" ] || continue
    src="$base_dir/$repo"
    dst="$workspace_path/$repo"

    if [ ! -d "$src" ]; then
      warn "Missing repo: $src"
      continue
    fi

    if [ -L "$dst" ]; then
      current_target="$(readlink "$dst")"
      if [ "$current_target" = "$src" ]; then
        continue
      fi
      rm -f "$dst"
      ln -s "$src" "$dst"
      continue
    fi

    if [ -e "$dst" ]; then
      warn "Skipping existing non-symlink: $dst"
      continue
    fi

    ln -s "$src" "$dst"
  done < <(profile_repos "$profile")
}

doctor_profile_links() {
  local workspace_path="$1"
  local profile="$2"
  local repo
  local base_dir
  local src
  local dst
  local current_target
  local had_error=0

  base_dir="$(base_repo_dir)"

  while IFS= read -r repo; do
    [ -n "$repo" ] || continue
    src="$base_dir/$repo"
    dst="$workspace_path/$repo"

    if [ ! -d "$src" ]; then
      printf 'WARNING: missing repo source %s\n' "$src"
      continue
    fi

    if [ -L "$dst" ]; then
      current_target="$(readlink "$dst")"
      if [ "$current_target" = "$src" ]; then
        printf 'OK: %s\n' "$repo"
      else
        printf 'ERROR: wrong symlink target for %s\n' "$repo"
        had_error=1
      fi
      continue
    fi

    if [ -e "$dst" ]; then
      printf 'ERROR: managed path is not a symlink for %s\n' "$repo"
      had_error=1
      continue
    fi

    printf 'ERROR: missing managed link for %s\n' "$repo"
    had_error=1
  done < <(profile_repos "$profile")

  return "$had_error"
}
```

Create `README.md`:

```markdown
# workspace-manager

Standalone Bash-first CLI for managing per-ticket workspaces from shared repo profiles.

## Config

Default config path:

`~/.config/workspace-manager/workspaces.yaml`

Override for testing or custom locations:

```bash
WORKSPACE_MANAGER_CONFIG=/path/to/workspaces.yaml bin/workspace list-profiles
```

## Commands

```bash
bin/workspace list-profiles
bin/workspace create ticket-123 --profile iris
bin/workspace sync /path/to/workspace
bin/workspace show /path/to/workspace
bin/workspace doctor /path/to/workspace
```
```

Update `bin/workspace`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=lib/common.sh
source "$REPO_ROOT/lib/common.sh"
# shellcheck source=lib/config.sh
source "$REPO_ROOT/lib/config.sh"
# shellcheck source=lib/workspace.sh
source "$REPO_ROOT/lib/workspace.sh"
# shellcheck source=lib/symlink.sh
source "$REPO_ROOT/lib/symlink.sh"

cmd_list_profiles() {
  list_profiles
}

cmd_create() {
  local name="${1:-}"
  local flag="${2:-}"
  local profile="${3:-}"
  local workspace_path

  [ -n "$name" ] || die "Usage: workspace create <name> --profile <profile>"
  [ "$flag" = "--profile" ] || die "Usage: workspace create <name> --profile <profile>"
  [ -n "$profile" ] || die "Usage: workspace create <name> --profile <profile>"
  profile_exists "$profile" || die "Unknown profile: $profile"

  workspace_path="$(workspace_path_from_name "$name")"
  ensure_new_workspace_dir "$workspace_path"
  write_profile_metadata "$workspace_path" "$profile"
  ensure_profile_links "$workspace_path" "$profile"

  printf 'Created workspace: %s\n' "$workspace_path"
}

cmd_sync() {
  local workspace_path="${1:-}"
  local profile

  [ -n "$workspace_path" ] || die "Usage: workspace sync <path>"
  profile="$(read_profile_metadata "$workspace_path")"
  profile_exists "$profile" || die "Unknown profile in metadata: $profile"
  ensure_profile_links "$workspace_path" "$profile"

  printf 'Synced workspace: %s\n' "$workspace_path"
}

cmd_show() {
  local workspace_path="${1:-}"
  local profile

  [ -n "$workspace_path" ] || die "Usage: workspace show <path>"
  profile="$(read_profile_metadata "$workspace_path")"
  profile_exists "$profile" || die "Unknown profile in metadata: $profile"

  printf 'Path: %s\n' "$workspace_path"
  printf 'Profile: %s\n' "$profile"
  printf 'Repos:\n'
  while IFS= read -r repo; do
    [ -n "$repo" ] || continue
    printf -- '- %s\n' "$repo"
  done < <(profile_repos "$profile")
}

cmd_doctor() {
  local workspace_path="${1:-}"
  local profile

  [ -n "$workspace_path" ] || die "Usage: workspace doctor <path>"
  profile="$(read_profile_metadata "$workspace_path")"
  profile_exists "$profile" || die "Unknown profile in metadata: $profile"
  doctor_profile_links "$workspace_path" "$profile"
}

main() {
  case "${1:-}" in
    ""|help|-h|--help)
      print_usage
      ;;
    list-profiles)
      cmd_list_profiles
      ;;
    create)
      shift
      cmd_create "$@"
      ;;
    sync)
      shift
      cmd_sync "$@"
      ;;
    show)
      shift
      cmd_show "$@"
      ;;
    doctor)
      shift
      cmd_doctor "$@"
      ;;
    *)
      die "Unknown command: ${1}"
      ;;
  esac
}

main "$@"
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
make test
```

Expected: PASS with all five shell tests completing without output.

- [ ] **Step 5: Commit**

```bash
git add Makefile README.md bin/workspace lib/symlink.sh tests/show_doctor_test.sh
git commit -m "feat: add workspace inspection commands"
```

## Final Verification

- [ ] Run the full suite one more time:

```bash
make test
```

Expected: PASS with all shell tests completing without output.

- [ ] Smoke-test the example config flow locally:

```bash
mkdir -p "$HOME/.config/workspace-manager"
cp examples/workspaces.yaml "$HOME/.config/workspace-manager/workspaces.yaml"
bin/workspace list-profiles
```

Expected: prints the example profile names in sorted order.

- [ ] Manually test a real workspace against your existing repo root:

```bash
bin/workspace create demo-ticket --profile iris
bin/workspace show "/Users/samwang/tmp/Workspace/demo-ticket"
bin/workspace doctor "/Users/samwang/tmp/Workspace/demo-ticket"
```

Expected: `create` produces symlinks and `.workspace-profile`; `show` prints path/profile/repo list; `doctor` prints `OK:` lines plus only warning lines for repos you have not cloned.
