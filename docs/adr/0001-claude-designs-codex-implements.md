# 0001 — Claude designs, Codex implements

- **Status:** Accepted
- **Date:** 2026-05-16
- **Deciders:** project owner

## Context

We need a workflow that uses two complementary AI tools without them stepping
on each other:

- Claude Code is strong at design, multi-file reasoning, and reviewing tradeoffs.
- Codex CLI is strong at carrying out a well-specified implementation task.

Letting either tool do "all of it" hurts: Claude is expensive for bulk
implementation and slower to converge on long edit sequences; Codex left to
its own devices on an under-specified brief tends to invent scope.

## Decision

We split responsibilities by role, enforced by both `CLAUDE.md` and
`AGENTS.md`:

- **Claude** owns: requirements clarification, architecture, task breakdown,
  acceptance criteria, code review, ADR authoring, and orchestration of the
  Codex calls via `scripts/bizrev`.
- **Codex** owns: writing application code in a worktree, running tests
  locally, and committing on the task branch.
- The human owns: final Go/NoGo on designs, ADRs, and PRs.

Claude must not edit files under `backend/`, `frontend/`, or `infra/` directly
(except to bootstrap an empty skeleton when explicitly asked). Codex must not
edit files under `.claude/`, `docs/adr/`, `scripts/`, or `tasks/_template/`.

## Consequences

- Every implementation lives behind a Codex invocation, giving us a clean
  log of "what was Codex asked to do, on what input, and what did it produce."
- The task spec format becomes load-bearing (see ADR-0003) because it is
  Codex's entire briefing.
- Code review is genuinely independent — Claude reviews work it didn't write.
- We accept some friction on tiny edits (a one-line typo fix goes through the
  same pipeline). The harness keeps that overhead low; we prefer consistency
  to a fast path that erodes over time.

## Alternatives considered

- **Single tool end-to-end.** Rejected — loses the design/implement separation
  and the audit trail.
- **Claude implements, Codex reviews.** Rejected — Codex's review output is
  less useful than Claude's, and Claude is more expensive per implementation
  token.

## References

- `CLAUDE.md`, `AGENTS.md`
- `scripts/bizrev` (`implement` subcommand)
