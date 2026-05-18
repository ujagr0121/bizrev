# Roadmap

Where bizrev stands today and what to do next, in order. This file is a
hand-off document — read it once when picking up the project locally, then
work from `tasks/` and `docs/adr/`.

Source material:
- Product brief: `docs/product/spec.md`
- Target architecture: `docs/architecture/overview.md`
- Existing decisions: `docs/adr/0001`–`0006`

## Current state (as of 2026-05-18)

**Done — harness:**
- Claude→Codex split established (ADR-0001).
- One-task-per-worktree model (ADR-0002, ADR-0005).
- Task spec format + app lifecycle (ADR-0003, ADR-0004).
- Web vs local execution surface split (ADR-0006).
- Slash commands (`/plan`, `/implement`, `/review`, `/integrate`, `/adr`,
  `/parallel`, `/status`) and `scripts/bizrev` harness in place.
- `tasks/_template/` exists; `tasks/` otherwise empty.

**Not started — product:**
- `backend/` and `frontend/` directories do not exist yet.
- No LLM provider chosen, no Supabase schema, no Tavily account wired.
- No `IdeaBrief` Pydantic model, no LangGraph DAG.

`main` and `claude/setup-ai-agent-infrastructure-x2q2Z` are both at
commit `3465aaa`. Future feature work branches off `main` as
`task/<id>` per ADR-0002.

## Phase 0 — Local hand-off (do first)

Before any feature work:

1. `git pull origin main` on your local clone.
2. `./scripts/bizrev doctor` — confirms Codex CLI is on PATH and required
   env vars are set. Fix anything it complains about.
3. Skim `docs/adr/0001`–`0006` in order. They're short.
4. Read `docs/product/spec.md` end-to-end. The Week-1/Week-2 day breakdown
   in §Roadmap is the source for Phase 2 below.
5. Decide on the secrets you need available locally:
   `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `TAVILY_API_KEY`,
   `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`. Stash them in your shell
   profile or `.env` (gitignored).

## Phase 1 — Decisions to make before code (web or local)

These are blocking for Week-1 implementation. Each becomes an ADR
(`/adr <slug>`). Author on the web if convenient — they're pure design.

| # | Decision | Why blocking |
|---|---|---|
| 1 | **LLM provider + model pinning** per role (extraction vs integration vs review). Spec hints GPT-4o-mini + Claude Sonnet, but pin exact IDs. | Every agent prompt and the cost model depend on this. |
| 2 | **LangGraph vs CrewAI vs hand-rolled DAG.** Spec leans LangGraph; confirm and pin a version. | Affects backend skeleton, task decomposition. |
| 3 | **Persistence: Supabase schema v0.** Tables: `ideas`, `idea_briefs`, `runs`, `reports`, `votes`. Decide foreign-key shape and which fields are JSONB. | Day 1–2 of Week-1 builds against this. |
| 4 | **Auth model for MVP.** Single-user (env-based) vs Supabase Auth from day one. Spec says single-user is fine for MVP. | Affects FastAPI middleware and Next.js wiring. |
| 5 | **Deployment target for FastAPI.** Render vs Fly.io vs Vercel Functions. | Affects `infra/` and the dev/prod parity story. |
| 6 | **Tavily call budget per idea.** Hard cap (e.g. 12 searches × 6 specialists). | Cost guardrail; informs the iteration-cap implementation. |

Decisions 1–4 are hard blockers for Phase 2. 5–6 can be punted into
Week-1 if needed, but cheaper to settle up front.

## Phase 2 — Week 1: backend & core logic

Tracks the spec's Day 1–7 breakdown. Each row becomes a task directory
under `tasks/`, planned via `/plan` and implemented via
`/implement <id>` from local Claude Code.

| Task id (proposed) | Scope | Acceptance shape | Parallel-safe with |
|---|---|---|---|
| `0001-backend-scaffold` | `backend/` skeleton: FastAPI app, pyproject, lint/test config, health endpoint | `pytest` exits 0; `uvicorn` starts; `/health` returns 200 | — |
| `0002-supabase-schema-v0` | SQL migrations for `ideas`, `idea_briefs`, `runs`, `reports`, `votes` per Phase-1 decision #3 | Migration applies clean against a fresh Supabase project; round-trip insert/select test | `0001` |
| `0003-idea-brief-schema` | `IdeaBrief` Pydantic model + JSON Schema export | `IdeaBrief.model_validate` passes on sample inputs; schema export matches fixture | `0001` |
| `0004-langgraph-skeleton` | LangGraph DAG with stub nodes (R → P* → I → V); fixed iteration cap | Smoke-test runs end-to-end with mock LLMs in <5s | `0003` |
| `0005-reception-agent` | Real reception agent: text → `IdeaBrief` via chosen LLM | Given 3 fixture ideas, produces valid `IdeaBrief` objects | `0004` |
| `0006-specialist-competitor` | First specialist: competitor analysis, full Tavily wiring | Output matches schema in spec §Schema fragment; `sources` non-empty | `0005` |
| `0007-specialist-{market,problem,tech,monetization,regulatory}` | The other five specialists. **Parallelizable** — split as 5 tasks if cycle budget allows | Each emits its typed schema; iteration cap respected | each other |
| `0008-integration-and-review` | Integration agent + critical reviewer | On a fixture run, produces a Go/Conditional/NoGo recommendation + a written critique | depends on 0006/0007 |
| `0009-fastapi-endpoints` | `POST /ideas`, `GET /ideas/{id}`, `POST /ideas/{id}/vote`, `GET /ideas/{id}/report` | OpenAPI doc generated; integration tests against a local Supabase pass | depends on 0008 |

Tasks 0006 + 0007 are the planner's main parallel-fan-out opportunity —
six specialists touching different files (`backend/app/agents/<name>/`).
Use `/parallel` once the upstream tasks (0001–0005) are merged.

## Phase 3 — Week 2: frontend & integration

Defer detailed task breakdown until Week 1 lands and the API shape is
real. Outline per spec §Roadmap Week 2:

- `0010-frontend-scaffold` — Next.js (App Router), Supabase client, auth wiring matching Phase-1 decision #4.
- `0011-idea-input-and-progress-ui` — submit form + LangGraph progress polling/SSE.
- `0012-report-dashboard` — data-driven renderer over per-agent JSON Schemas (per `docs/architecture/overview.md` §Data contracts), Markdown + charts, Go/NoGo buttons.
- `0013-e2e-and-deploy` — Playwright happy-path, Vercel + Render (or whichever Phase-1 decision #5 picks) deploys, prompt tuning pass.

## Phase 4 — Post-MVP (tracked, not scheduled)

From spec §Future extensions. Each gets its own roadmap entry when
prioritized:

- GitHub Projects V2 GraphQL integration (auto-file MVP issues on Go).
- Interview-script generation on Conditional Go.
- pgvector RAG over past NoGo'd ideas — "same failure pattern as idea X".

## Open questions to revisit

- **Prompt-cache hit measurement.** ADR for how we verify the cacheable
  prefix is actually hit (spec §Cost & ops notes). Likely a small
  observability task in Week 1.
- **`runs` table fan-out.** Spec wants `(idea_id, agent, attempt)`
  keying. If parallel specialists write concurrently, confirm Supabase
  PG handles the write rate; otherwise queue via LangGraph's state.
- **Failure-mode taxonomy in the DB.** Spec §Failure modes lists four;
  pick a small enum and store it on each `runs` row so the dashboard
  can surface them.
- **Critical reviewer's tone calibration.** Needs a fixture set of
  "obviously-bad" ideas to confirm the reviewer doesn't rubber-stamp.
  Build that fixture set as part of `0008`.

## How to use this roadmap

- **Web (this side):** good for refining Phase 1 ADRs and adjusting the
  Phase-2 task list before kicking off `/plan`. Push changes to `main`
  so local picks them up.
- **Local Claude Code:** owns Phase 2 onward — `/plan` to materialize
  Phase-2 task directories, `/implement <id>` per row, `/review <id>`,
  `/integrate <id>`. See `docs/workflow.md` and ADR-0006 for the split.

When this roadmap and reality diverge (a task changes scope, a
decision flips), update this file in the same commit that introduces
the change. Roadmap drift is a leading indicator of plan rot.
