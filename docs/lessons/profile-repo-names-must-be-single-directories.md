---
id: profile-repo-names-must-be-single-directories
date: 2026-04-19
scope: project
tags: [bash, cli, config, validation, path-traversal]
source: bug-fix
confidence: 0.5
related: ["[[inspection-commands-must-validate-arity-and-config]]"]
---

# Profile repo names must be single directories

## Context
The workspace CLI builds repo symlink paths from configured profile repo names during `create`, `sync`, and inspection flows.

## Mistake
Config validation only required non-empty strings, so values like `../escape` were accepted and later joined into filesystem paths outside the workspace.

## Lesson
- Validate profile repo names in the shared config query path before any command joins them into filesystem paths.
- Treat repo names as single directory entries only: reject empty values, `.`, `..`, and any name containing `/`.

## When to Apply
Apply this when a CLI or script turns config-provided names into child paths under a managed directory.
