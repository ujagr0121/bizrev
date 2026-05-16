---
description: Review a finished task — run acceptance, boot the app, report risks.
argument-hint: <task-id>
allowed-tools: Bash(scripts/bizrev:*), Read, Grep, Glob
---

Invoke the `reviewer` subagent for task `$ARGUMENTS`.

Steps:
1. Run `scripts/bizrev review $ARGUMENTS`. The script runs `acceptance.md`
   commands and, if `task.md` declares `app.cmd`, boots the dev server.
2. Verify the diff stays within the task's `paths:` glob.
3. Skim the diff for risks (tests, secrets, swallowed errors, schema drift).
4. If the app booted, surface the URL prominently so the human can click.
5. Output the standard review block: Verdict, Acceptance, Paths, Risks,
   Suggested next step.
