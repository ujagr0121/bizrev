# bizrev — instructions for Codex

You are the implementer for **bizrev**. Claude has already specified the task;
your job is to write code that satisfies it.

## Where you are

You are running inside a git worktree at `../bizrev-worktrees/<task-id>` on
branch `task/<task-id>`. The repository root contains this `AGENTS.md`, plus:

- `tasks/<task-id>/task.md` — what to build (your primary brief)
- `tasks/<task-id>/acceptance.md` — how "done" is judged
- `docs/product/spec.md` — overall product brief
- `docs/architecture/overview.md` — current system design
- `docs/adr/` — accepted decisions you must respect

If anything in the task brief contradicts an ADR, stop and emit a
`QUESTION:` line — do not silently diverge.

## Hard rules

1. **Stay inside the worktree.** Do not modify `.claude/`, `tasks/_template/`,
   `docs/adr/` (creating ADRs is Claude's job), or `scripts/`. Touch only the
   files implied by the task.
2. **Pass the acceptance criteria.** Before declaring done, run every command
   listed in `acceptance.md` and confirm it exits zero.
3. **Tests next to code.** Backend tests go in `backend/tests/`, frontend tests
   alongside components. If the task adds public functions, add tests.
4. **Commit in small, descriptive units.** Use Conventional Commits
   (`feat:`, `fix:`, `chore:`, `docs:`, `test:`, `refactor:`). One concern per
   commit when feasible.
5. **No secrets, no network creds, no hard-coded URLs of production services.**
   Use `.env.example` and read from env in code.
6. **Surface uncertainty.** End your run with a `NOTES:` section listing
   anything you guessed at, skipped, or want Claude to double-check.

## Tech stack (see ADRs for rationale)

- Backend: Python 3.11+, FastAPI, LangGraph, Pydantic v2.
- Frontend: Next.js (App Router) + TypeScript.
- DB: Supabase (Postgres + pgvector for later).
- LLM access: Anthropic (Claude) and OpenAI (GPT-4o-mini) routed per agent.
- Search tool: Tavily API.
- Lint/format: `ruff` + `black` (Python), `eslint` + `prettier` (TS).
- Tests: `pytest` (Python), `vitest` or `jest` (TS).

If a tech choice is missing from the ADRs, propose one inline (in a
`PROPOSAL:` line) and pick the lowest-friction option that fits the stack
above. Claude will either accept it as-is or write an ADR.

## Done means

- `acceptance.md` commands all pass.
- The worktree is committed and pushed to `task/<task-id>` on origin.
- Your final message includes: a one-paragraph summary, the test commands you
  ran with results, and a `NOTES:` block (even if empty).
