#!/usr/bin/env bash
# Invoke Codex on a single task inside its worktree.
#
# Usage: codex-run.sh <task-id>
#
# Reads tasks/<id>/task.md and acceptance.md, plus AGENTS.md, and feeds them
# to `codex exec --cd <worktree>`. Streams output to .bizrev/logs/<id>.log.

# shellcheck source=lib/common.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

main() {
  local id; id="$(task_resolve_id "${1:?task id required}")"
  local task_md acceptance_md agents_md wt log_file
  task_md="$BIZREV_REPO_ROOT/tasks/$id/task.md"
  acceptance_md="$BIZREV_REPO_ROOT/tasks/$id/acceptance.md"
  agents_md="$BIZREV_REPO_ROOT/AGENTS.md"
  wt="$(task_worktree "$id")"
  log_file="$(task_log "$id")"

  [[ -f "$task_md" ]] || die "no task.md for $id"
  [[ -d "$wt" ]] || die "no worktree at $wt — run 'bizrev worktree new $id' first"
  require_cmd codex

  state_set "$id" status "in-progress"
  task_set_front_matter "$id" status "in-progress" || true

  # Build a single prompt. Codex respects AGENTS.md at the worktree root
  # automatically, but inlining the task brief avoids relying on it picking
  # the right file out of the repo.
  local prompt
  prompt="$(cat <<EOF
You are working on task **${id}** for the bizrev project. Repo-wide rules are
in AGENTS.md at the worktree root — read it first. Your task brief follows.

# tasks/${id}/task.md

$(cat "$task_md")

# tasks/${id}/acceptance.md

$(cat "$acceptance_md" 2>/dev/null || echo '(none specified)')

# Reminders

- Stay inside the paths declared in task.md front-matter.
- Run every acceptance command and confirm exit-zero before declaring done.
- Commit on branch task/${id} with Conventional Commits messages.
- End with a NOTES: section listing anything you guessed at or skipped.
EOF
)"

  log "delegating to codex (task=$id, worktree=$wt)"
  log "log: $log_file"

  {
    printf '\n===== %s — codex exec start =====\n' "$(date -Iseconds)"
    printf 'task: %s\nworktree: %s\n\n' "$id" "$wt"
  } >> "$log_file"

  # `codex exec` is non-interactive. Codex CLI honors AGENTS.md and respects
  # --cd. Flags here are deliberately conservative; users can override via
  # BIZREV_CODEX_FLAGS in their env.
  local rc=0
  codex exec \
    --cd "$wt" \
    ${BIZREV_CODEX_FLAGS:-} \
    "$prompt" 2>&1 | tee -a "$log_file" || rc=$?

  {
    printf '\n===== %s — codex exec end (rc=%s) =====\n' "$(date -Iseconds)" "$rc"
  } >> "$log_file"

  if (( rc == 0 )); then
    state_set "$id" status "review"
    task_set_front_matter "$id" status "review" || true
    ok "codex exec succeeded for $id"
  else
    state_set "$id" status "ready"
    task_set_front_matter "$id" status "ready" || true
    err "codex exec failed for $id (rc=$rc)"
  fi
  return "$rc"
}

main "$@"
