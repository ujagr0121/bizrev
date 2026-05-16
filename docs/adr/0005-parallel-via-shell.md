# 0005 — Parallel execution via shell, not a daemon

- **Status:** Accepted
- **Date:** 2026-05-16
- **Deciders:** project owner

## Context

The harness needs to run several `codex exec` tasks at once. Options:

1. A long-running coordinator daemon (Python service, queue, workers).
2. A shell-level approach: each task is a backgrounded subprocess managed by
   files under `.bizrev/`.
3. A workflow engine (Temporal, Prefect).

We're a single-developer build at MVP. We need parallelism, not durability or
distributed scheduling.

## Decision

Parallel execution is implemented in shell. `scripts/bizrev parallel <ids...>`
forks one `codex exec` per task id (each in its own worktree) and waits for
all of them. State is captured in plain files:

- `.bizrev/pids/<id>.pid` — running pid.
- `.bizrev/logs/<id>.log` — combined stdout/stderr.
- `.bizrev/state.json` — last known status per task (updated atomically with
  `flock`).

There is no daemon; there is no socket. Killing a `bizrev parallel` invocation
SIGTERMs the children.

## Consequences

- Trivial to operate: `ps`, `tail -f`, `kill`.
- Crash-recoverable: state lives on disk; a new `bizrev status` reads the
  same files.
- We accept that we can't survive a host reboot mid-run — tasks would need
  to be re-kicked. That's fine for personal-scale work.
- If we ever need multi-host scheduling, we replace `scripts/parallel.sh`
  with a real queue and leave the rest of the harness alone.

## Alternatives considered

- **Daemon.** Rejected — too much surface area for current needs.
- **Workflow engine.** Rejected — same reason; revisit if we go SaaS.

## References

- `scripts/parallel.sh`
- `scripts/lib/common.sh`
