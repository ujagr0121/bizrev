---
description: Show current task state across worktrees and running apps.
allowed-tools: Bash(scripts/bizrev:status), Bash(scripts/bizrev:worktree*), Bash(scripts/bizrev:app:*), Read
---

Run `scripts/bizrev status` and present its output as a table:

- Task id, title, status (ready / in-progress / review / merged / abandoned)
- Worktree state (present / absent, branch, dirty?)
- App state (down / up on port N)
- Last log timestamp

Highlight anything stuck (in-progress with no log activity for >30min) or
inconsistent (status: merged but worktree still present).
