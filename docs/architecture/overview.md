# Architecture overview

> Status: **draft**. Updated as ADRs are accepted. When in doubt, ADRs win.

## Top-level layout (target)

```
backend/                  FastAPI app, LangGraph workflows, agent prompts
  app/
    api/                  HTTP routes
    graph/                LangGraph nodes & edges
    agents/               Per-specialist prompts + Pydantic schemas
    db/                   Supabase client, migrations
    tools/                Tavily wrapper, etc.
  tests/
  pyproject.toml

frontend/                 Next.js (App Router) UI
  app/
  components/
  lib/
  package.json

infra/                    Deploy config (Vercel + Render envs, Supabase SQL)

docs/                     Specs, architecture, ADRs (this directory)
```

The directory tree above is **the target**, not what's on disk yet. The first
implementation tasks build it incrementally — see `tasks/`.

## Runtime shape

```
┌────────────┐    REST     ┌──────────────────────────┐
│  Next.js   │ ──────────► │  FastAPI                 │
│  (Vercel)  │ ◄────────── │  /ideas, /reports, /vote │
└────────────┘   JSON      │                          │
                           │  ┌────────────────────┐  │
                           │  │  LangGraph DAG     │  │
                           │  │  ┌──┐ ┌──┐ ┌──┐    │  │
                           │  │  │R │→│P*│→│I │→│V││  │
                           │  │  └──┘ └──┘ └──┘    │  │
                           │  └────────────────────┘  │
                           │       │       │          │
                           │   Tavily   Anthropic /   │
                           │             OpenAI       │
                           └──────────────────────────┘
                                    │
                                    ▼
                              Supabase (Postgres)
```

- R: reception (idea → IdeaBrief).
- P*: parallel specialists (competition, market, problem severity,
  tech feasibility, monetization, regulatory).
- I: integration + critical review.
- V: vote (Human-in-the-loop interrupt; user clicks Go/Conditional/NoGo/Hold).

## Data contracts

Every agent has a Pydantic model in `backend/app/agents/<name>/schema.py`.
Models are exported as JSON Schema and shipped to the frontend's report
renderer so the UI is data-driven (no per-agent hand-coded views).

The reception agent's output (`IdeaBrief`) is the join point — every
specialist consumes it. Treat its schema as a stable contract; changes go
through an ADR.

## Cross-cutting concerns

- **Prompt caching.** System prompts share a cacheable prefix; per-agent
  variation is appended. Verified via Anthropic's cache hit-rate logs.
- **Cost routing.** Cheap extraction → GPT-4o-mini. Integration and
  critical review → Claude Sonnet (latest). See ADR-0004 (to be written
  when we pick exact model IDs).
- **Iteration caps.** Every LangGraph node has `max_iterations = 3`. A
  specialist that can't converge emits a low-confidence result rather than
  looping.
- **Observability.** Every agent run writes to a `runs` table keyed by
  `(idea_id, agent, attempt)` with inputs, outputs, token counts, and
  latency. The dashboard surfaces this as a per-idea audit trail.

## Open questions tracked elsewhere

- Exact LLM models and version pinning → future ADR.
- Auth (single-user MVP vs. multi-tenant) → future ADR.
- Deployment target for FastAPI (Render vs. Fly.io vs. Lambda) → future ADR.
