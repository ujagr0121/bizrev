# bizrev

新規ビジネスアイデア実現性評価AIエージェントチーム。
A multi-agent system that evaluates business-idea feasibility (market, competitors,
technical risk, monetization, etc.) and supports a Go / Conditional Go / NoGo / Hold
decision by a human reviewer.

This repository currently contains the **development infrastructure** for the
project. Product code lands later, on per-task feature branches managed via git
worktrees.

## Roles

- **Claude (this CLI)** — project management, design, architecture, planning,
  review, decision logging. Claude does not write production code directly.
- **Codex CLI** — the implementer. Claude generates a task spec and invokes
  `codex exec` (via the harness scripts) to do the actual coding.
- **You (human reviewer)** — final Go/NoGo on designs, ADRs, and merged code.

The boundary is deliberate: Claude owns _what and why_, Codex owns _how_, you
own _ship it or not_.

## Repository layout

```
.claude/                 Claude Code config: subagents, slash commands, settings
AGENTS.md                Repo-wide instructions consumed by Codex CLI
CLAUDE.md                Repo-wide instructions consumed by Claude Code
docs/
  product/spec.md        Mirror of the product brief (kept up to date)
  architecture/          System-level design docs
  adr/                   Architecture Decision Records (immutable history)
  workflow.md            How the Claude→Codex pipeline actually runs
scripts/                 Harness: codex invocation, worktrees, app lifecycle
tasks/                   Task specs (one directory per task, becomes Codex's input)
  _template/             Copy this to start a new task
```

## Quick start

Prerequisites on the machine where you actually run implementation:

- `git` ≥ 2.40 (worktree support)
- `node` ≥ 20 and `npm` (for the eventual Next.js frontend)
- `python` ≥ 3.11 and `uv` or `pip` (for the eventual FastAPI backend)
- `codex` (OpenAI Codex CLI) on PATH — see https://github.com/openai/codex
- `claude` (Claude Code CLI) on PATH for the orchestrator

Bootstrap:

```bash
./scripts/bizrev doctor            # verify prerequisites
./scripts/bizrev task new <slug>   # scaffold a new task
./scripts/bizrev implement <id>    # have Codex implement it in a worktree
./scripts/bizrev review <id>       # boot the app and stand by for review
```

See `docs/workflow.md` for the full pipeline and `docs/adr/` for the decisions
that shaped this setup.
