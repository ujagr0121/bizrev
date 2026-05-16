---
id: NNNN-slug
title: One-line description in imperative mood
status: ready
depends_on: []
paths:
  - path/glob/this/task/owns/**
app:
  cmd: null
  port: null
  health: null
---

## Why

Link the spec section or ADR motivating this work, then one short paragraph
on the user-facing or system-level value. If you can't justify it in three
sentences, the task is probably too big or premature.

## What

Bullet list of concrete deliverables. Be specific:

- A file or function name when you can.
- An endpoint and its request/response shape when it's an API.
- A schema name and its JSON shape when it's a data contract.
- A UI element and what state it reads/writes when it's frontend.

## Notes

- Anything Codex needs to know that isn't in the spec/ADRs.
- Pointers to similar code already in the repo.
- Known gotchas (rate limits, schema quirks, etc.).
