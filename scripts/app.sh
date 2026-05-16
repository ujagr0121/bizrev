#!/usr/bin/env bash
# App-lifecycle subcommands. Reads task.md front-matter to know how to start
# the dev server for a task, then runs it in the background.

# shellcheck source=lib/common.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

usage() {
  cat <<EOF
Usage: bizrev app <subcommand>

Subcommands:
  up <task-id>      Start the task's dev server (PORT exported from front-matter)
  down <task-id>    Stop it
  status [<id>]     Show running apps (all, or just one)
  url <task-id>     Print the URL (port + optional health path)
  logs <task-id>    Tail the log file
EOF
}

cmd_up() {
  local id; id="$(task_resolve_id "${1:?task id required}")"
  local wt cmd port health pid_file log_file
  wt="$(task_worktree "$id")"
  cmd="$(task_front_matter "$id" app.cmd || true)"
  health="$(task_front_matter "$id" app.health || true)"
  pid_file="$(task_pidfile "$id")"
  log_file="$(task_log "$id")"

  [[ -d "$wt" ]] || die "no worktree at $wt — implement the task first"
  if [[ -z "$cmd" || "$cmd" == "null" ]]; then
    warn "task $id declares no app.cmd; nothing to start"
    return 0
  fi
  if [[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
    log "app for $id already running (pid $(cat "$pid_file"))"
    cmd_url "$id"; return 0
  fi

  port="$(task_allocate_port "$id")"

  log "starting app for $id on port $port"
  log "  cmd: $cmd"
  log "  cwd: $wt"
  log "  log: $log_file"

  # Strip surrounding quotes if present.
  cmd="${cmd%\"}"; cmd="${cmd#\"}"

  (
    cd "$wt"
    export PORT="$port"
    export BIZREV_TASK_ID="$id"
    # shellcheck disable=SC2086
    exec bash -lc "$cmd"
  ) >> "$log_file" 2>&1 &
  echo $! > "$pid_file"
  state_set "$id" app "up:$port"

  # Health-check loop (if declared)
  if [[ -n "$health" && "$health" != "null" ]]; then
    # Substitute $PORT in the health URL.
    local url="${health//\$PORT/$port}"
    url="${url//\$\{PORT\}/$port}"
    log "waiting for health: $url"
    local i
    for ((i = 0; i < 60; i++)); do
      if curl --fail -sS -o /dev/null "$url" 2>/dev/null; then
        ok "app for $id is healthy: $url"
        return 0
      fi
      sleep 1
    done
    warn "health check timed out for $id ($url) — check $log_file"
    return 1
  fi

  ok "app for $id started: http://localhost:$port"
}

cmd_down() {
  local id; id="$(task_resolve_id "${1:?task id required}")"
  local pid_file; pid_file="$(task_pidfile "$id")"
  if [[ ! -f "$pid_file" ]]; then warn "no pid file for $id"; return 0; fi
  local pid; pid="$(cat "$pid_file")"
  if kill -0 "$pid" 2>/dev/null; then
    # SIGTERM the whole process group; dev servers tend to spawn children.
    kill -TERM -- "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
    sleep 1
    if kill -0 "$pid" 2>/dev/null; then
      kill -KILL "$pid" 2>/dev/null || true
    fi
    ok "stopped app for $id (pid $pid)"
  else
    warn "pid $pid for $id was not running"
  fi
  rm -f "$pid_file"
  state_set "$id" app "down"
}

cmd_status() {
  if (( $# > 0 )); then
    local id; id="$(task_resolve_id "$1")"
    _print_status_row "$id"
    return
  fi
  if [[ ! -d "$BIZREV_PIDS_DIR" ]] || [[ -z "$(ls -A "$BIZREV_PIDS_DIR" 2>/dev/null)" ]]; then
    echo "(no apps running)"; return
  fi
  printf '%-30s %-8s %-6s %s\n' TASK STATE PID URL
  for f in "$BIZREV_PIDS_DIR"/*.pid; do
    [[ -e "$f" ]] || continue
    local id_file; id_file="$(basename "$f" .pid)"
    _print_status_row "$id_file"
  done
}

_print_status_row() {
  local id="$1"
  local pid_file port_file pid="-" port="-" state="down"
  pid_file="$(task_pidfile "$id")"
  port_file="$(task_portfile "$id")"
  if [[ -f "$pid_file" ]]; then
    pid="$(cat "$pid_file")"
    if kill -0 "$pid" 2>/dev/null; then state="up"; else state="dead"; fi
  fi
  [[ -f "$port_file" ]] && port="$(cat "$port_file")"
  local url="-"
  [[ "$state" == "up" && "$port" != "-" ]] && url="http://localhost:$port"
  printf '%-30s %-8s %-6s %s\n' "$id" "$state" "$pid" "$url"
}

cmd_url() {
  local id; id="$(task_resolve_id "${1:?task id required}")"
  local port; port="$(cat "$(task_portfile "$id")" 2>/dev/null || true)"
  [[ -z "$port" ]] && die "no port allocated for $id"
  echo "http://localhost:$port"
}

cmd_logs() {
  local id; id="$(task_resolve_id "${1:?task id required}")"
  exec tail -f "$(task_log "$id")"
}

main() {
  local sub="${1:-}"; shift || { usage; exit 2; }
  case "$sub" in
    up)     cmd_up     "$@" ;;
    down)   cmd_down   "$@" ;;
    status) cmd_status "$@" ;;
    url)    cmd_url    "$@" ;;
    logs)   cmd_logs   "$@" ;;
    -h|--help) usage ;;
    *) usage; exit 2 ;;
  esac
}

main "$@"
