#!/usr/bin/env bash
# Run codex-run.sh on several tasks concurrently.
#
# Usage: parallel.sh <task-id> <task-id> [...]
#
# Each task gets its own worktree (created if missing) and runs in the
# background. We wait for all to finish, then summarize.

# shellcheck source=lib/common.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

CODEX_RUN="$BIZREV_REPO_ROOT/scripts/codex-run.sh"
WT="$BIZREV_REPO_ROOT/scripts/worktree.sh"

usage() {
  echo "Usage: bizrev parallel <task-id> <task-id> [...]"
}

# Detect path-glob collisions across tasks before launching. A collision means
# two tasks declare overlapping `paths:` — that's a planner error and should
# block parallel execution.
check_path_collisions() {
  local ids=("$@") i j paths_i paths_j
  for ((i = 0; i < ${#ids[@]}; i++)); do
    paths_i="$(task_front_matter "${ids[$i]}" paths || true)"
    for ((j = i + 1; j < ${#ids[@]}; j++)); do
      paths_j="$(task_front_matter "${ids[$j]}" paths || true)"
      # Cheap heuristic: tokenize and look for any shared top-level segment.
      # Full glob-overlap is intentionally not solved here — the planner
      # should already have made this safe.
      while read -r p1; do
        [[ -z "$p1" ]] && continue
        local prefix1="${p1%%/*}"
        while read -r p2; do
          [[ -z "$p2" ]] && continue
          local prefix2="${p2%%/*}"
          if [[ "$prefix1" == "$prefix2" && "$prefix1" != "" ]]; then
            warn "path-prefix collision between ${ids[$i]} and ${ids[$j]}: '$prefix1'"
            warn "  -> running anyway; the reviewer should double-check the diff"
          fi
        done <<< "$(grep -E '^\s+- ' <(printf '%s\n' "$paths_j") | sed 's/^\s*- //')"
      done <<< "$(grep -E '^\s+- ' <(printf '%s\n' "$paths_i") | sed 's/^\s*- //')"
    done
  done
}

main() {
  (( $# > 0 )) || { usage; exit 2; }
  require_cmd codex
  require_cmd git

  local ids=()
  for arg in "$@"; do ids+=("$(task_resolve_id "$arg")"); done

  check_path_collisions "${ids[@]}"

  # Ensure each worktree exists before forking — that operation isn't
  # parallel-safe (it writes to the shared git dir).
  for id in "${ids[@]}"; do
    "$WT" new "$id"
  done

  local pids=()
  for id in "${ids[@]}"; do
    log "spawning codex for $id"
    "$CODEX_RUN" "$id" >> "$(task_log "$id")" 2>&1 &
    local child_pid=$!
    pids+=("$child_pid")
    echo "$child_pid" > "$(task_pidfile "$id")"
  done

  log "spawned ${#pids[@]} tasks; tailing logs from $BIZREV_LOGS_DIR"

  local rc=0
  for i in "${!pids[@]}"; do
    local id="${ids[$i]}"
    if wait "${pids[$i]}"; then
      ok "$id finished"
    else
      err "$id failed (see $(task_log "$id"))"
      rc=1
    fi
    rm -f "$(task_pidfile "$id")"
  done

  echo
  echo "=== parallel run summary ==="
  for id in "${ids[@]}"; do
    printf '  %-30s  status=%s\n' "$id" "$(state_get "$id" status || echo '?')"
  done
  return "$rc"
}

main "$@"
