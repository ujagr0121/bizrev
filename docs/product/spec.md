# Product brief — bizrev

> Source of truth: Google Doc "新規ビジネスアイデア実現性評価AIエージェントチーム 設計検討資料"
> (id `1yqtPUGXNqxSaefkcGjxRYJkXu9Co34-iDF2m0bT8MQI`). This file mirrors the
> doc; when they diverge, the Google Doc wins and this file is re-mirrored.

## 1. Executive summary

Build an "AI agent team" that takes a business idea (unstructured text, a few
sentences to a few hundred characters) and produces a structured Go / Conditional
Go / NoGo / Hold recommendation for the human owner.

Not a "sparring partner" chatbot — a **deterministic workflow** in which LLMs
are workers inside a state machine. Agent-to-agent communication is
**structured JSON** (Pydantic / JSON Schema), and a human-in-the-loop sign-off
gate is built in.

Scope: a personal-build MVP shippable in 1–2 weeks, with an explicit extension
path toward an enterprise version (GitHub Projects integration, RAG over past
NoGo'd ideas, etc.).

### Assumptions

- Initial input: a few sentences to a few hundred characters of free text.
- Backend: Python (FastAPI) for orchestration; talks to the frontend over REST.
- Frontend: Next.js.
- Infra: serverless / PaaS for cost and ops (Vercel, Supabase, Render).

## 2. System overview

The system is a state machine; LLMs are pipeline workers, control flow is
deterministic code.

1. **Input phase** — user enters an idea. A reception agent may ask 1–2
   clarifying questions.
2. **Structuring phase** — reception agent converts the idea to an
   `IdeaBrief` JSON document; this is persisted in the DB.
3. **Investigation phase** — specialist agents read the brief and run their
   own analysis (web search via Tavily, etc.), each emitting a typed JSON
   output. Agents run in parallel where dependencies allow.
4. **Integration & audit phase** — an integration agent aggregates the
   results, then a critical-reviewer agent audits for optimism bias and
   logical leaps.
5. **Decision phase** — user reviews the dashboard and chooses Go /
   Conditional Go / NoGo / Hold.
6. **Action phase** — on Go, the system files initial implementation tasks
   into a project tracker (GitHub Projects V2 later).

## Agent roster (specialists)

(Detailed schemas are TBD in design — see `docs/architecture/overview.md`.)

- Competitor / substitution analysis (includes "is this just ChatGPT?" risk).
- Market sizing & TAM/SAM/SOM sanity check.
- Customer-problem severity (YC "hair on fire" framing).
- Technical feasibility & build-time estimate.
- Monetization / unit economics.
- Regulatory / compliance risk.

Plus:
- **Integration agent** — assembles the report.
- **Critical reviewer** — final audit, deliberately skeptical tone.

## Schema fragment (verbatim from the spec)

One specialist's output schema, illustrating the contract style:

```json
{
  "type": "object",
  "properties": {
    "competitors": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "name": {"type": "string"},
          "url":  {"type": "string"},
          "threat_level":   {"type": "string", "enum": ["High", "Medium", "Low"]},
          "key_difference": {"type": "string"}
        },
        "required": ["name", "url", "threat_level", "key_difference"]
      }
    },
    "chatgpt_replacement_risk": {"type": "boolean"},
    "confidence_score": {"type": "integer", "minimum": 0, "maximum": 100},
    "sources": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "url":            {"type": "string"},
          "accessed_date":  {"type": "string"}
        }
      }
    }
  },
  "required": ["competitors", "chatgpt_replacement_risk", "confidence_score", "sources"]
}
```

## Cost & ops notes

- **Context rebilling.** Naive multi-agent pipelines spend up to ~4.8× a
  single-model run because each agent re-pays for prior context. Mitigations:
  - Pass extracted JSON, not full conversation history ("entity memory").
  - Use Anthropic prompt caching for shared system prompts.
  - Route cheap extraction to GPT-4o-mini; reserve Claude Sonnet for
    integration and review.
- Cap iterations per node in LangGraph (`max_iterations ≈ 3`) so a search
  miss can't trigger an infinite retry loop.

## Failure modes & mitigations

| Failure | Cause | Mitigation |
|---|---|---|
| "Yes-man" output | RLHF reward for pleasing the user | Independent critical reviewer at the end, deliberately strict tone |
| Fabricated market sizes | Hallucination filling for missing search results | Forbid emitting numbers without a source URL in prompts; split extraction from generation |
| API cost runaway | Search returns nothing useful → retry loop | Hard cap iterations per node |
| Unactionable report | Concatenated agent outputs | Integration agent's job is "extract the Go/NoGo axes", not summarize |

## Roadmap (initial 2 weeks)

**Week 1 — backend & core logic**
- Day 1–2: LangGraph environment, Supabase schema, Tavily account.
- Day 3–4: 6 agent prompts + Pydantic output schemas.
- Day 5–6: Sequential DAG in LangGraph; smoke-test with a fixed idea string.
- Day 7: FastAPI endpoints, timeout/error handling.

**Week 2 — frontend & integration**
- Day 8–9: Next.js scaffold, Supabase client.
- Day 10–11: Idea input + progress UI.
- Day 12–13: Report dashboard (Markdown + charts), Go/NoGo buttons writing
  back to the DB.
- Day 14: E2E test, prompt tuning, deploy to Vercel + Render.

## Future extensions (post-MVP)

- GitHub Projects V2 GraphQL integration (auto-file MVP issues on Go).
- Interview-script generation on Conditional Go.
- pgvector-backed RAG over past NoGo'd ideas to surface "same failure
  pattern as idea X" warnings.

## References

- LangGraph docs (state machine + interrupt patterns)
- CrewAI Sequential/Hierarchical (role design patterns)
- OpenAI Structured Outputs guide
- GitHub Projects V2 GraphQL API
- Y Combinator Startup School ("hair on fire problem")
