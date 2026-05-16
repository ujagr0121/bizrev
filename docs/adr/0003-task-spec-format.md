# 0003 — Task spec format

- **Status:** Accepted
- **Date:** 2026-05-16
- **Deciders:** project owner

## Context

Codex needs a self-contained brief. The brief is also what humans audit when a
task goes sideways. It must be writable in minutes by Claude, parseable by the
harness (to extract metadata), and complete enough to implement against without
chat backchannel.

## Decision

A task is a directory `tasks/<task-id>/` containing:

- `task.md` (**required**) — the brief. Front-matter YAML for machine fields,
  Markdown body for the human brief. Schema:

  ```yaml
  ---
  id: 0007-competitor-agent
  title: Implement the competitor-analysis specialist
  status: ready          # ready | in-progress | review | merged | abandoned
  depends_on: [0001-ideabrief-schema]
  paths:                 # files this task is allowed to touch
    - backend/app/agents/competitor/**
    - backend/tests/agents/test_competitor*.py
  app:
    cmd: null            # or e.g. "make -C backend dev"
    port: null           # or 8001
    health: null         # or "http://localhost:8001/health"
  ---
  ```

  Body sections:
  - **Why** — link to spec/ADR, one paragraph of motivation.
  - **What** — concrete deliverables (files, functions, endpoints).
  - **Notes** — known gotchas, links to relevant code in other worktrees.

- `acceptance.md` (**required**) — a checklist of executable commands.
  Each item is `- [ ] description — \`shell command\``. The reviewer pastes
  these into the worktree and confirms they all pass.

- `codex.log` (auto, gitignored inside the task dir is fine) — appended by
  the harness on each `codex exec` run.

`task-id` is `NNNN-kebab-slug` where NNNN is a zero-padded sequence. The
harness allocates the next number on `task new`.

## Consequences

- `paths:` is enforceable — the reviewer can `git diff --name-only` against
  it and reject a task that touches outside its lane. This is what makes
  parallel work safe.
- Tasks are reviewable as a unit even months later, because everything
  needed to understand them is in the directory.
- We accept the verbosity. A 5-line `task.md` is fine for trivial tasks —
  the format scales down as well as up.

## Alternatives considered

- **GitHub Issues only.** Rejected — works for tracking, but pulls humans
  into a non-git surface for what should be a code-adjacent artifact.
- **Inline in PR description.** Rejected — loses pre-implementation review,
  and you can't depend on a PR description before the PR exists.

## References

- `tasks/_template/`
- `scripts/bizrev task new`
