---
id: inspection-commands-must-validate-arity-and-config
date: 2026-04-19
scope: feature
tags:
  - bash
  - cli
  - validation
  - config
  - tests
source: bug-fix
confidence: 0.5
related: []
---

# Inspection commands must validate arity and config

## Context

Task 5 added `show` and `doctor` inspection commands to the Bash CLI.

## Mistake

The first implementation accepted extra positional arguments and let `doctor` continue into link inspection even when `base_repo_dir` from config did not exist.

## Lesson

For Bash CLI subcommands, require the exact expected argument count and run shared config path validation before command-specific work when the command depends on configured directories.

## When to Apply

Apply this when adding or reviewing CLI commands that read workspace metadata and then inspect filesystem state derived from repo config.
