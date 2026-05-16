#!/usr/bin/env bash
# Cross-task dashboard.

# shellcheck source=lib/common.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

main() {
  printf '%-30s %-14s %-9s %-8s %s\n' ID STATUS WORKTREE APP TITLE
  for d in "$BIZREV_REPO_ROOT"/tasks/[0-9][0-9][0-9][0-9]-*; do
    [[ -d "$d" ]] || continue
    local id status title wt_state app_state
    id="$(basename "$d")"
    status="$(task_front_matter "$id" status || echo '?')"
    title="$(task_front_matter "$id" title || echo '?')"
    if [[ -d "$(task_worktree "$id")" ]]; then wt_state="present"; else wt_state="absent"; fi
    if [[ -f "$(task_pidfile "$id")" ]] && kill -0 "$(cat "$(task_pidfile "$id")")" 2>/dev/null; then
      app_state="up:$(cat "$(task_portfile "$id")" 2>/dev/null || echo '?')"
    else
      app_state="down"
    fi
    printf '%-30s %-14s %-9s %-8s %s\n' "$id" "$status" "$wt_state" "$app_state" "$title"
  done
}

main "$@"
