#!/usr/bin/env bash
# Review a task: run its acceptance commands, optionally boot the app.
#
# Usage: review.sh <task-id> [--no-app]

# shellcheck source=lib/common.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

APP="$BIZREV_REPO_ROOT/scripts/app.sh"

main() {
  local id boot_app=1
  id="$(task_resolve_id "${1:?task id required}")"; shift || true
  while (( $# > 0 )); do
    case "$1" in
      --no-app) boot_app=0; shift ;;
      *) die "unknown flag: $1" ;;
    esac
  done

  local wt acceptance_md
  wt="$(task_worktree "$id")"
  acceptance_md="$BIZREV_REPO_ROOT/tasks/$id/acceptance.md"

  [[ -d "$wt" ]] || die "no worktree at $wt"
  [[ -f "$acceptance_md" ]] || die "no acceptance.md for $id"

  echo "=== diff against main (paths-stat) ==="
  git -C "$wt" diff --stat main 2>/dev/null || git -C "$wt" diff --stat HEAD~
  echo

  echo "=== acceptance ==="
  local pass=0 fail=0 line cmd
  # Extract command from lines like:  - [ ] description — `the command`
  while IFS= read -r line; do
    cmd="$(printf '%s\n' "$line" | sed -n 's/.*`\(.*\)`.*/\1/p')"
    [[ -z "$cmd" ]] && continue
    printf '  $ %s\n' "$cmd"
    if ( cd "$wt" && bash -lc "$cmd" ) >/dev/null 2>&1; then
      ok "  pass: $cmd"
      pass=$((pass+1))
    else
      err "  FAIL: $cmd"
      fail=$((fail+1))
    fi
  done < <(grep -E '^\s*-\s*\[' "$acceptance_md")

  echo
  echo "  passed: $pass / $((pass+fail))"
  echo

  if (( boot_app )); then
    local cmd
    cmd="$(task_front_matter "$id" app.cmd || true)"
    if [[ -n "$cmd" && "$cmd" != "null" ]]; then
      echo "=== booting app ==="
      "$APP" up "$id" || warn "app failed to come up"
    else
      log "task $id declares no app.cmd; skipping app boot"
    fi
  fi

  (( fail == 0 )) || return 1
  ok "all acceptance commands passed"
}

main "$@"
