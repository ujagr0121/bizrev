# tasks/

Each subdirectory is one **task** — a unit of work small enough for a single
Codex invocation, large enough to merge as a coherent diff.

- `tasks/<id>/task.md` — the brief (front-matter + Markdown)
- `tasks/<id>/acceptance.md` — executable checks
- `tasks/_template/` — copy this to scaffold a new task (or just use
  `scripts/bizrev task new <slug>`)

See `docs/adr/0003-task-spec-format.md` for the format spec, and
`docs/workflow.md` for the full plan → implement → review → integrate loop.

## Status lifecycle

```
ready ──► in-progress ──► review ──► merged
              │                 │
              └─► abandoned ◄───┘
```

The harness updates `status:` in front-matter as a task moves through the
pipeline. Don't hand-edit `status:` unless recovering from a broken run.
