---
description: Record a design decision as a new ADR under docs/adr/.
argument-hint: <one-line decision>
---

Invoke the `adr-writer` subagent with the following decision:

> $ARGUMENTS

Steps:
1. Allocate the next ADR number.
2. Fill the template (Context, Decision, Consequences, Alternatives).
3. Write `docs/adr/NNNN-slug.md`.
4. Append to `docs/adr/README.md` index.
5. Commit on `main` with `docs(adr): NNNN — <title>`.
6. Report the path and commit SHA.

If the conversation hasn't established enough context for the four sections,
ask the user a single targeted question rather than writing a thin ADR.
