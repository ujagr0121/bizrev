# Acceptance checklist

Every item must be a runnable command. The reviewer runs each one and confirms
exit-zero.

- [ ] Unit tests pass — `cd backend && pytest tests/path/to/new_test.py`
- [ ] Linter clean — `cd backend && ruff check .`
- [ ] Types check — `cd backend && mypy app/` (if applicable)
- [ ] Frontend builds — `cd frontend && npm run build` (if applicable)
- [ ] Endpoint responds — `curl --fail -sS http://localhost:8000/healthz`
      (if the task brings up an app)
- [ ] No new TODO / FIXME without an issue link — `! grep -rn 'TODO\|FIXME' <paths>`

Add or remove items to match the task. If you can't write at least one
testable command, the task isn't ready — escalate to the planner.
