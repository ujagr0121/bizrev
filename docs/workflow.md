# Development workflow

How a feature actually gets built end-to-end. Skim once, then keep open while
running the harness for the first time.

## TL;DR

```
idea ──► Claude /plan ──► tasks/<id>/ ──► /implement ──► worktree+Codex
                                                  │
                                                  ▼
                                       /review (boots app)
                                                  │
                                  ┌────── Go ─────┴───── NoGo ──────┐
                                  ▼                                  ▼
                            /integrate                          rework task
```

## 1. Plan

```
You:     "Add the competitor-analysis specialist."
Claude:  /plan competitor-analysis
```

The `planner` subagent decomposes the request into one or more task
directories under `tasks/`. Each gets a numeric id (`NNNN-slug`), a brief, an
acceptance checklist, and `paths:` declaring which files it owns. The plan
itself ends with a one-line summary committed on the main branch:

```
chore(plan): add tasks 0007–0009 (competitor agent)
```

If two tasks are independent (`paths:` don't overlap), the plan flags them as
parallel-safe.

## 2. Implement

```
Claude:  /implement 0007-competitor-agent
```

This calls `scripts/bizrev implement 0007-competitor-agent`, which:

1. Ensures a worktree at `../bizrev-worktrees/0007-competitor-agent/` exists
   on branch `task/0007-competitor-agent`, branched from `main`.
2. Builds the Codex prompt from `tasks/0007-competitor-agent/task.md`,
   `acceptance.md`, the repo `AGENTS.md`, and the listed `depends_on` task
   summaries.
3. Runs `codex exec --cd <worktree> <prompt>`, streaming output to
   `.bizrev/logs/0007-competitor-agent.log`.
4. On exit, commits any unstaged Codex changes with `chore(codex): wip` so
   nothing is lost, then prints next-step hints.

For parallel work:

```
Claude:  /parallel 0007 0008 0009
```

Equivalent to three `/implement` runs but spawned concurrently.

## 3. Review

```
You:     "Ready to review 0007?"
Claude:  /review 0007-competitor-agent
```

The `reviewer` subagent:

1. Runs `scripts/bizrev review 0007-competitor-agent`, which:
   a. Runs the acceptance commands from `acceptance.md`.
   b. If `app.cmd` is set, boots the dev server via `scripts/bizrev app up`.
   c. Prints the URL and waits.
2. Summarizes the diff against `main` with focus on `paths:` adherence,
   tests added, risks, and any `NOTES:` block Codex emitted.
3. Hands back to you with: green checks, the app URL, and the questions
   needing your judgment.

If the diff strays outside `paths:`, the review fails fast — that's a planner
bug, not a Codex bug.

## 4. Integrate

```
You:     "Merge it."
Claude:  /integrate 0007-competitor-agent
```

The `integrator` subagent fast-forwards or merges `task/0007-competitor-agent`
into `main` (squash by default), pushes, and tears down the worktree and the
running app. The task directory stays in git history; `tasks/<id>/task.md`'s
`status` is bumped to `merged`.

## 5. Capture decisions

If anything during plan/implement/review surfaced a non-obvious decision:

```
Claude:  /adr "route GPT-4o-mini for competitor extraction, Sonnet for review"
```

The `adr-writer` agent creates the next-numbered ADR with status `Accepted`
and links it from the task and (if relevant) `docs/architecture/overview.md`.

## Day-to-day commands

```bash
scripts/bizrev doctor              # prerequisites check
scripts/bizrev task new <slug>     # scaffold tasks/<NNNN-slug>/
scripts/bizrev implement <id>      # delegate to Codex in a worktree
scripts/bizrev parallel <id> ...   # several at once
scripts/bizrev review <id>         # run acceptance + boot app
scripts/bizrev app up <id>         # just the app
scripts/bizrev app down <id>
scripts/bizrev app status
scripts/bizrev worktree list
scripts/bizrev worktree rm <id>
scripts/bizrev status              # cross-task dashboard
```

Inside Claude Code, prefer the slash commands (`/plan`, `/implement`, ...) —
they wire in the right subagent and contextual prompts.

## What lives where

- `tasks/<id>/` — the brief. Versioned.
- `../bizrev-worktrees/<id>/` — the working tree. Not versioned in this repo
  (it's a separate working copy of the same `.git`).
- `.bizrev/` — runtime state (pids, logs, port assignments). Gitignored.
- `docs/adr/` — decisions. Immutable history.
