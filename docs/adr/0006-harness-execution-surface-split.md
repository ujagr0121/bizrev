# 0006 — Split harness execution across web and local surfaces

- **Status:** Accepted
- **Date:** 2026-05-17
- **Deciders:** project maintainer

## Context

The bizrev harness uses two distinct Claude Code surfaces: the Anthropic-managed
cloud (claude.ai/code) and a locally installed Claude Code terminal session. As
the harness commands were assigned to one surface or the other, three hard
constraints emerged:

1. Cloud sessions do not ship the Codex CLI, and the default network allowlist
   does not include the OpenAI API endpoints Codex requires, so `codex exec`
   cannot run there even if the binary were installed.
2. The worktree model (`../bizrev-worktrees/<task-id>` on branch
   `task/<task-id>`) requires a persistent filesystem the user can also `cd`
   into. Cloud containers are ephemeral and isolated from the user's machine.
3. `/review` boots the task's dev server (`task.app.cmd`) and reports a URL the
   user must be able to reach — that only works when the server runs on the
   user's local machine.

The per-command split is already documented in `docs/workflow.md` (section
"Where to run what") and `README.md` (section "Where Claude runs"), but those
are prose guides. This ADR exists so the split has a citable record and future
contributors do not attempt to wire Codex into web sessions.

## Decision

We will formally assign harness commands to execution surfaces: `/plan`, `/adr`,
doc work, and async diff review of pushed branches run on the web; `/implement`,
`/parallel`, and `/review` (dev-server-booting) run locally; `/integrate` works
on either surface.

## Consequences

- Tasks authored on the web are immediately runnable locally because `tasks/` is
  version-controlled — both sides share the same task directory once pushed.
- Contributors must have a local environment with Codex CLI installed and
  `OPENAI_API_KEY` set for the implementer phase; `scripts/bizrev doctor`
  verifies this.
- The round-trip is: design on the web → push → `git pull` locally →
  `/implement` → push task branch → review diff on the web. The web side never
  blocks on a Codex run.
- If cloud sessions gain Codex CLI support and the OpenAI allowlist is relaxed,
  this ADR should be superseded by one that re-enables `/implement` on the web.

## Alternatives considered

- **Codex-everywhere via a self-hosted relay** — a small service the web session
  calls that runs Codex on a private VM. Rejected: adds infrastructure to
  maintain, an auth surface, and a new failure mode for a single-developer
  harness. Revisit if the team grows.
- **Skip Codex; let Claude write production code** — rejected: directly
  contradicts the role boundary in `CLAUDE.md` and ADR 0001. The Claude→Codex
  split exists so design and implementation are reviewable as separate artifacts.
- **Local-only harness** — rejected: the web surface is genuinely useful for
  planning, ADR writing, and async review of pushed branches; removing it would
  slow design iteration without benefit.

## References

- ADR 0001 — Claude designs, Codex implements
- `docs/workflow.md` — "Where to run what" table
- `README.md` — "Where Claude runs"
- Commit `5d8db51` on branch `claude/setup-ai-agent-infrastructure-x2q2Z`
