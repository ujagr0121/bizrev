---
description: Delegate a task to Codex in its own worktree.
argument-hint: <task-id>
allowed-tools: Bash(scripts/bizrev:*), Read, Grep, Glob
---

Invoke the `codex-delegator` subagent for task `$ARGUMENTS`.

Steps:
1. Verify `tasks/$ARGUMENTS/task.md` exists and `status: ready`.
2. Run `scripts/bizrev implement $ARGUMENTS`.
3. When Codex exits, run `scripts/bizrev review $ARGUMENTS --no-app` to
   capture acceptance results without booting the app.
4. Report exit code, files touched, Codex's NOTES block, and acceptance
   pass/fail.
