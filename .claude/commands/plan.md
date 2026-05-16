---
description: Break a feature request into Codex-ready tasks under tasks/.
argument-hint: <feature description>
---

Invoke the `planner` subagent with the following feature request:

> $ARGUMENTS

Steps:
1. Read `docs/product/spec.md` and `docs/architecture/overview.md` for context.
2. Decompose into the smallest mergeable tasks.
3. Allocate IDs, scaffold `tasks/<id>/task.md` and `acceptance.md` from
   `tasks/_template/`, and fill in `paths:`, `app:`, `depends_on:`.
4. Commit on `main` with `chore(plan): <feature> — tasks <ids>`.
5. Report a table: id, title, parallel-safe, depends_on.
