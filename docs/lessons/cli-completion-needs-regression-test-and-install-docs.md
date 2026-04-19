---
id: cli-completion-needs-regression-test-and-install-docs
date: 2026-04-19
scope: feature
tags: [bash, cli, zsh, completion, tests, docs]
source: bug-fix
confidence: 0.5
related: []
---

# CLI completion needs regression test and install docs

## Context

The workspace manager CLI gained its first zsh completion support after users reported that command entry had no autocomplete help.

## Mistake

The repository had an empty `completions/` directory and no completion-related tests or setup instructions, so the feature was effectively absent and would have been easy to regress silently.

## Lesson

- When adding shell completion to a CLI, ship the completion file, a regression test that asserts the completion surface exists, and documentation for loading the completion into the user's shell.
- Do not treat shell startup configuration as implicitly handled; document the exact `fpath`/initialization steps when installation is manual.

## When to Apply

Apply this when adding or reviewing shell completion support for a repository-managed CLI.
