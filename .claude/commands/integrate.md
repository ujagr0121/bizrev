---
description: Merge a reviewed task branch into main and tear down its worktree.
argument-hint: <task-id>
allowed-tools: Bash(scripts/bizrev:*), Bash(git:*), Read, Grep
---

Invoke the `integrator` subagent for task `$ARGUMENTS`.

Refuse if the most recent review for this task isn't `ready-to-merge`. Then:

1. Fast-forward `main`.
2. `git merge --squash task/$ARGUMENTS` and commit with the task title.
3. Push `main` (retry per project push protocol).
4. Bump `tasks/$ARGUMENTS/task.md` `status: merged`.
5. `scripts/bizrev app down $ARGUMENTS && scripts/bizrev worktree rm $ARGUMENTS`.
6. Report SHA + cleanup state.
