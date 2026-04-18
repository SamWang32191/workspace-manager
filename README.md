# workspace-manager

Standalone Bash-first CLI for managing per-ticket workspaces from shared repo profiles.

## Setup

1. Copy the sample config into the default location:

```bash
mkdir -p "$HOME/.config/workspace-manager"
cp examples/workspaces.yaml "$HOME/.config/workspace-manager/workspaces.yaml"
```

2. Edit the copied config so `base_repo_dir`, `workspace_root`, and `profiles` match your local checkout layout.

3. Run a smoke check:

```bash
bin/workspace list-profiles
```

The CLI reads config from `${WORKSPACE_MANAGER_CONFIG:-$HOME/.config/workspace-manager/workspaces.yaml}`.

Override the config path when testing or when keeping multiple configs:

```bash
WORKSPACE_MANAGER_CONFIG=/path/to/workspaces.yaml bin/workspace list-profiles
```

## Config Format

The config file is YAML with three top-level keys:

- `base_repo_dir`: directory that contains the source repositories to link from
- `workspace_root`: directory where `workspace create` makes managed workspaces
- `profiles`: map of profile name to ordered repo list

Example:

```yaml
base_repo_dir: /Users/samwang/code/github.com/softleader
workspace_root: /Users/samwang/tmp/Workspace

profiles:
  iris:
    - iris-admin-ui
    - iris-auth
    - iris-finance
  transglobe:
    - kapok-auth
    - kapok-auth-ui
```

Each managed workspace stores its selected profile in a single-line `.workspace-profile` file.

## Command Reference

### `bin/workspace list-profiles`

Prints available profile names in sorted order.

### `bin/workspace create <name> --profile <profile>`

Creates a new managed workspace under `workspace_root/<name>`, writes `.workspace-profile`, and creates the profile's symlinks.

- Fails if the profile does not exist
- Fails if the target path already exists and is not already a managed workspace
- Warns, but does not fail, when a source repo directory is missing

### `bin/workspace sync <path>`

Reads `.workspace-profile` from the given workspace path and makes managed symlinks match the configured profile.

- Replaces managed symlinks that point at the wrong target
- Leaves extra unmanaged symlinks alone in v1
- Warns, but does not fail, when a source repo directory is missing

### `bin/workspace show <path>`

Prints the workspace path, selected profile, and configured repo list for that workspace.

### `bin/workspace doctor <path>`

Checks the managed symlinks for the selected profile and reports one line per repo:

- `OK` when the symlink points at the expected source repo
- `WARNING` when the source repo directory is missing
- `ERROR` when a managed symlink is missing, points at the wrong target, or is blocked by a non-symlink path

`doctor` exits with status `1` when managed state is broken, and `0` when the result is clean or only contains warnings.

## Migration Notes

- Move profile definitions out of ad-hoc shell snippets and into the shared YAML config.
- Replace manual per-ticket symlink creation with `bin/workspace create <ticket> --profile <profile>`.
- For existing managed workspaces, keep the directory, make sure `.workspace-profile` contains the profile name, then run `bin/workspace sync <path>`.
- If a directory already exists without `.workspace-profile`, the CLI treats it as unmanaged and refuses to adopt it automatically. That refusal is deliberate; silent adoption is how you end up debugging your own shortcuts later.
