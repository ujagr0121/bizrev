#!/usr/bin/env bash
# Worktree subcommands. See `bizrev worktree -h`.

# shellcheck source=lib/common.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

usage() {
  cat <<EOF
Usage: bizrev worktree <subcommand> [args]

Subcommands:
  new <task-id> [--base <branch>]   Create a worktree for a task (default base: main)
  rm  <task-id>                     Remove a worktree (refuses if dirty)
  list                              List all task worktrees
  path <task-id>                    Print the absolute path
EOF
}

cmd_new() {
  local id base="main"
  id="$(task_resolve_id "$1")"; shift || true
  while (( $# > 0 )); do
    case "$1" in
      --base) base="$2"; shift 2 ;;
      *) die "unknown flag: $1" ;;
    esac
  done

  local wt; wt="$(task_worktree "$id")"
  local branch; branch="$(task_branch "$id")"

  if [[ -d "$wt" ]]; then
    log "worktree already exists at $wt"
    return 0
  fi

  mkdir -p "$BIZREV_WORKTREE_ROOT"

  # Branch may already exist (e.g. from a prior partial run) — reuse it.
  if git -C "$BIZREV_REPO_ROOT" show-ref --verify --quiet "refs/heads/$branch"; then
    log "reusing existing branch $branch"
    git -C "$BIZREV_REPO_ROOT" worktree add "$wt" "$branch"
  else
    # Determine base: prefer local $base, else origin/$base, else HEAD.
    local base_ref
    if git -C "$BIZREV_REPO_ROOT" show-ref --verify --quiet "refs/heads/$base"; then
      base_ref="$base"
    elif git -C "$BIZREV_REPO_ROOT" show-ref --verify --quiet "refs/remotes/origin/$base"; then
      base_ref="origin/$base"
    else
      warn "no '$base' branch found; branching from HEAD"
      base_ref="HEAD"
    fi
    git -C "$BIZREV_REPO_ROOT" worktree add -b "$branch" "$wt" "$base_ref"
  fi
  state_set "$id" worktree "present"
  ok "worktree ready: $wt (branch $branch)"
}

cmd_rm() {
  local id; id="$(task_resolve_id "$1")"
  local wt; wt="$(task_worktree "$id")"
  if [[ ! -d "$wt" ]]; then warn "no worktree at $wt"; return 0; fi

  if [[ -n "$(git -C "$wt" status --porcelain 2>/dev/null || true)" ]]; then
    die "worktree $wt is dirty — commit or stash before removing"
  fi
  git -C "$BIZREV_REPO_ROOT" worktree remove "$wt"
  task_release_port "$id"
  state_set "$id" worktree "absent"
  ok "removed worktree $wt"
}

cmd_list() {
  if [[ ! -d "$BIZREV_WORKTREE_ROOT" ]]; then echo "(no worktrees)"; return; fi
  git -C "$BIZREV_REPO_ROOT" worktree list | grep -F "$BIZREV_WORKTREE_ROOT/" || echo "(no task worktrees)"
}

cmd_path() {
  task_worktree "$1"
}

main() {
  require_cmd git
  local sub="${1:-}"; shift || { usage; exit 2; }
  case "$sub" in
    new)  cmd_new  "$@" ;;
    rm)   cmd_rm   "$@" ;;
    list) cmd_list "$@" ;;
    path) cmd_path "$@" ;;
    -h|--help) usage ;;
    *) usage; exit 2 ;;
  esac
}

main "$@"
