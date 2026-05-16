---
description: Run several Codex tasks in parallel (one worktree each).
argument-hint: <task-id> <task-id> [...]
allowed-tools: Bash(scripts/bizrev:*), Read, Grep
---

Invoke the `codex-delegator` subagent for the following task ids: $ARGUMENTS.

Before kicking off, verify the tasks' `paths:` globs don't overlap — that's a
planner bug and should stop here. If overlap is detected, refuse and tell the
user which task pair conflicts.

Otherwise, run `scripts/bizrev parallel $ARGUMENTS`. Tail the log directory
and report each task's final status (acceptance result, exit code, NOTES).
