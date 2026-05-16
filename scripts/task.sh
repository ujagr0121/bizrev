#!/usr/bin/env bash
# Task-management subcommands: scaffold, list, show.

# shellcheck source=lib/common.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

usage() {
  cat <<EOF
Usage: bizrev task <subcommand>

Subcommands:
  new <slug>       Scaffold tasks/<NNNN-slug>/ from the template
  list             List all tasks with their status
  show <id>        Print the task brief
EOF
}

next_id() {
  local last
  last=$(find "$BIZREV_REPO_ROOT/tasks" -maxdepth 1 -mindepth 1 -type d -name '[0-9][0-9][0-9][0-9]-*' \
         -printf '%f\n' | sort | tail -1 || true)
  if [[ -z "$last" ]]; then
    printf '0001'
  else
    printf '%04d' $((10#${last%%-*} + 1))
  fi
}

cmd_new() {
  local slug="${1:?slug required}"
  [[ "$slug" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "slug must be kebab-case (a-z0-9-)"
  local nnnn; nnnn="$(next_id)"
  local id="$nnnn-$slug"
  local dir="$BIZREV_REPO_ROOT/tasks/$id"
  [[ -d "$dir" ]] && die "task $id already exists"
  mkdir -p "$dir"
  # Copy template, substitute id and title-from-slug.
  local title
  title="$(echo "$slug" | tr '-' ' ' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1')"
  sed -e "s/^id: NNNN-slug/id: $id/" \
      -e "s/^title: One-line description in imperative mood/title: $title/" \
      "$BIZREV_REPO_ROOT/tasks/_template/task.md" > "$dir/task.md"
  cp "$BIZREV_REPO_ROOT/tasks/_template/acceptance.md" "$dir/acceptance.md"
  ok "scaffolded $dir"
  echo "$id"
}

cmd_list() {
  printf '%-30s %-14s %s\n' ID STATUS TITLE
  for d in "$BIZREV_REPO_ROOT"/tasks/[0-9][0-9][0-9][0-9]-*; do
    [[ -d "$d" ]] || continue
    local id; id="$(basename "$d")"
    local status title
    status="$(task_front_matter "$id" status || echo '?')"
    title="$(task_front_matter "$id" title || echo '?')"
    printf '%-30s %-14s %s\n' "$id" "$status" "$title"
  done
}

cmd_show() {
  local id; id="$(task_resolve_id "${1:?task id required}")"
  cat "$BIZREV_REPO_ROOT/tasks/$id/task.md"
  echo
  echo "--- acceptance ---"
  cat "$BIZREV_REPO_ROOT/tasks/$id/acceptance.md"
}

main() {
  local sub="${1:-}"; shift || { usage; exit 2; }
  case "$sub" in
    new)  cmd_new  "$@" ;;
    list) cmd_list "$@" ;;
    show) cmd_show "$@" ;;
    -h|--help) usage ;;
    *) usage; exit 2 ;;
  esac
}

main "$@"
