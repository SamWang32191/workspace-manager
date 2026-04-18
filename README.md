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
