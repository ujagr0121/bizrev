# 0004 — App lifecycle via dev-server contract

- **Status:** Accepted
- **Date:** 2026-05-16
- **Deciders:** project owner

## Context

Reviewing a real feature usually means clicking around in the running app, not
reading diffs. We want `scripts/bizrev review <id>` to bring the right dev
server up on the right port and report the URL — without each task hand-coding
that orchestration.

## Decision

Every task that produces a runnable surface declares it in `task.md`'s
front-matter under `app:`:

```yaml
app:
  cmd: "make -C backend dev"   # foreground command
  port: 8001                   # port to allocate
  health: "http://localhost:8001/healthz"   # optional health check
```

`scripts/bizrev app up <id>` then:

1. cds into the task's worktree.
2. Reads `app.cmd` / `app.port` from `task.md` front-matter.
3. Exports `PORT=<port>` and any `--env` flags passed.
4. Runs `app.cmd` in the background, captures stdout/stderr to
   `.bizrev/logs/<id>.log`, writes pid to `.bizrev/pids/<id>.pid`.
5. If `app.health` is set, polls it until 200 OK (timeout 60s).
6. Prints `Ready: http://localhost:<port>` or the failure log path.

`scripts/bizrev app down <id>` kills the pid and removes the pid file.
`scripts/bizrev app status` lists everything running.

For multi-process tasks (FastAPI + Next.js), the convention is **one Makefile
target per task** that wires up both. The Makefile lives in the worktree, so
Codex owns it.

## Consequences

- Tasks that don't have a runnable surface (e.g. "add a Pydantic model") set
  `app.cmd: null` and the reviewer skips the app-up step.
- Port collisions are avoided by allocating per task — see ADR-0002 (worktree
  isolation) and `scripts/lib/ports.sh`.
- We can extend later (Docker Compose per task, etc.) by changing only the
  harness; the `app:` contract stays.

## Alternatives considered

- **Hard-coded ports per service.** Rejected — collides as soon as two tasks
  run simultaneously.
- **Process supervisor (Honcho/Procfile).** Rejected for MVP — extra dep for
  no current benefit. The Makefile-per-task convention is enough.

## References

- `scripts/app.sh`
- `tasks/_template/task.md`
