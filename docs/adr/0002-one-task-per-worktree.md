# 0002 — One task per git worktree

- **Status:** Accepted
- **Date:** 2026-05-16
- **Deciders:** project owner

## Context

We want to run multiple Codex implementations in parallel (e.g. the
competitor-agent and the market-sizing-agent at the same time). They must not
collide in the working tree, and we still want one canonical repository on
disk.

Options for isolation:
1. Multiple full clones of the repo.
2. Long-running feature branches in a single working tree (serial only).
3. Git worktrees, one per task.
4. Container-per-task with a bind-mounted clone.

## Decision

We use **git worktrees, one per task**, created and managed by the harness:

- Worktrees live at `../bizrev-worktrees/<task-id>/`, outside the main repo.
- Each worktree is on branch `task/<task-id>`, branched from `main`
  (or from a designated integration branch).
- The harness owns creation (`scripts/bizrev worktree new <id>`) and cleanup
  (`scripts/bizrev worktree rm <id>`); humans don't run raw `git worktree`.
- Concurrent tasks must touch disjoint file paths — the planner enforces this
  when splitting work.

## Consequences

- Disk usage stays low: shared `.git` directory across all worktrees.
- A Codex run cannot accidentally clobber another's edits.
- App lifecycle (ADR-0004) cleanly maps to "one app per worktree, one port."
- Merging is normal `git merge`/PR flow; no special tooling needed.
- We accept the limitation that submodules are awkward in worktrees — we
  don't plan to use submodules.

## Alternatives considered

- **Multiple clones.** Rejected — wastes disk, drifts on `git config`.
- **Serial single-branch.** Rejected — kills the parallel-execution goal.
- **Container per task.** Rejected — adds an order of magnitude of setup
  complexity for a personal-build MVP. We may revisit when we want hermetic
  CI for tasks.

## References

- `scripts/worktree.sh`
- https://git-scm.com/docs/git-worktree
