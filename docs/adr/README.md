# Architecture Decision Records

A decision belongs here if it took more than a paragraph of discussion to
settle, will surprise a future contributor, or constrains future code.

## Conventions

- Filename: `NNNN-kebab-case-title.md` with a zero-padded sequence number.
- Status lifecycle: `Proposed` → `Accepted` | `Rejected`. Once `Accepted`, an
  ADR is immutable. To change course, write a new ADR with status `Accepted`
  and `Supersedes: NNNN`, and edit the old one's status to
  `Superseded by: MMMM` (the only allowed mutation).
- Keep them short — one screen is the target.
- Use `_template.md` to start.

## Index

| #    | Title                                       | Status   |
|------|---------------------------------------------|----------|
| 0001 | Claude designs, Codex implements            | Accepted |
| 0002 | One task per git worktree                   | Accepted |
| 0003 | Task spec format                            | Accepted |
| 0004 | App lifecycle via dev-server contract       | Accepted |
| 0005 | Parallel execution via shell, not a daemon  | Accepted |
| 0006 | Harness execution surface split             | Accepted |
