# shellcheck shell=bash
# Shared utilities for the bizrev harness. Source this from every script.

set -euo pipefail

# Resolve repo root from any caller.
BIZREV_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BIZREV_WORKTREE_ROOT="${BIZREV_WORKTREE_ROOT:-$(cd "$BIZREV_REPO_ROOT/.." && pwd)/bizrev-worktrees}"
BIZREV_STATE_DIR="$BIZREV_REPO_ROOT/.bizrev"
BIZREV_LOGS_DIR="$BIZREV_STATE_DIR/logs"
BIZREV_PIDS_DIR="$BIZREV_STATE_DIR/pids"
BIZREV_PORTS_DIR="$BIZREV_STATE_DIR/ports"
BIZREV_STATE_FILE="$BIZREV_STATE_DIR/state.json"

mkdir -p "$BIZREV_LOGS_DIR" "$BIZREV_PIDS_DIR" "$BIZREV_PORTS_DIR"

# ---- output helpers ---------------------------------------------------------

if [[ -t 1 ]]; then
  _C_RESET=$'\033[0m'; _C_DIM=$'\033[2m'
  _C_RED=$'\033[31m'; _C_GREEN=$'\033[32m'; _C_YELLOW=$'\033[33m'; _C_BLUE=$'\033[34m'
else
  _C_RESET=''; _C_DIM=''; _C_RED=''; _C_GREEN=''; _C_YELLOW=''; _C_BLUE=''
fi

log()  { printf '%s[bizrev]%s %s\n' "$_C_BLUE"  "$_C_RESET" "$*" >&2; }
ok()   { printf '%s[bizrev]%s %s\n' "$_C_GREEN" "$_C_RESET" "$*" >&2; }
warn() { printf '%s[bizrev]%s %s\n' "$_C_YELLOW" "$_C_RESET" "$*" >&2; }
err()  { printf '%s[bizrev]%s %s\n' "$_C_RED"   "$_C_RESET" "$*" >&2; }
die()  { err "$@"; exit 1; }

# ---- task helpers -----------------------------------------------------------

# Resolve a task id (full "NNNN-slug" or just "NNNN") to its canonical form.
task_resolve_id() {
  local needle="$1"
  local matches
  if [[ "$needle" =~ ^[0-9]{4}-.+ ]] && [[ -d "$BIZREV_REPO_ROOT/tasks/$needle" ]]; then
    printf '%s' "$needle"; return 0
  fi
  if [[ "$needle" =~ ^[0-9]{4}$ ]]; then
    mapfile -t matches < <(find "$BIZREV_REPO_ROOT/tasks" -maxdepth 1 -mindepth 1 -type d -name "${needle}-*" -printf '%f\n')
    if (( ${#matches[@]} == 1 )); then printf '%s' "${matches[0]}"; return 0; fi
    if (( ${#matches[@]} > 1 )); then die "ambiguous id '$needle' matches: ${matches[*]}"; fi
  fi
  die "unknown task id: $needle"
}

task_dir()         { printf '%s/tasks/%s' "$BIZREV_REPO_ROOT" "$(task_resolve_id "$1")"; }
task_worktree()    { printf '%s/%s' "$BIZREV_WORKTREE_ROOT" "$(task_resolve_id "$1")"; }
task_branch()      { printf 'task/%s' "$(task_resolve_id "$1")"; }
task_log()         { printf '%s/%s.log' "$BIZREV_LOGS_DIR" "$(task_resolve_id "$1")"; }
task_pidfile()     { printf '%s/%s.pid' "$BIZREV_PIDS_DIR" "$(task_resolve_id "$1")"; }
task_portfile()    { printf '%s/%s.port' "$BIZREV_PORTS_DIR" "$(task_resolve_id "$1")"; }

# Extract a value from task.md YAML front-matter. Top-level keys only and
# nested keys with dotted lookup (one level deep). Returns empty if missing.
# Implemented in pure POSIX awk so it works under mawk too.
task_front_matter() {
  local id key task_md
  id="$(task_resolve_id "$1")"; key="$2"
  task_md="$BIZREV_REPO_ROOT/tasks/$id/task.md"
  [[ -f "$task_md" ]] || die "no task.md at $task_md"
  awk -v key="$key" '
    function clean(s) {
      sub(/[[:space:]]+$/, "", s)
      # strip a single matching pair of surrounding double or single quotes
      if (length(s) >= 2) {
        first = substr(s, 1, 1); last = substr(s, length(s), 1)
        if ((first == "\"" && last == "\"") || (first == "'\''" && last == "'\''")) {
          s = substr(s, 2, length(s) - 2)
        }
      }
      return s
    }
    BEGIN { in_fm=0; parent="" }
    /^---[[:space:]]*$/ {
      if (!in_fm) { in_fm=1; next }
      else        { exit }
    }
    in_fm {
      # top-level "key: value" (no leading space)
      if ($0 ~ /^[A-Za-z_][A-Za-z0-9_]*:/) {
        idx = index($0, ":")
        k = substr($0, 1, idx-1)
        v = substr($0, idx+1)
        sub(/^[[:space:]]+/, "", v)
        parent = k
        if (k == key) { print clean(v); exit }
      }
      # nested "  subkey: value"
      else if ($0 ~ /^[[:space:]]+[A-Za-z_][A-Za-z0-9_]*:/) {
        line = $0
        sub(/^[[:space:]]+/, "", line)
        idx = index(line, ":")
        k = substr(line, 1, idx-1)
        v = substr(line, idx+1)
        sub(/^[[:space:]]+/, "", v)
        compound = parent "." k
        if (compound == key) { print clean(v); exit }
      }
    }
  ' "$task_md"
}

# Set a top-level front-matter scalar value.
task_set_front_matter() {
  local id key val task_md tmp
  id="$(task_resolve_id "$1")"; key="$2"; val="$3"
  task_md="$BIZREV_REPO_ROOT/tasks/$id/task.md"
  tmp="$(mktemp)"
  awk -v key="$key" -v val="$val" '
    BEGIN { in_fm=0; replaced=0 }
    /^---[[:space:]]*$/ { in_fm = !in_fm; print; next }
    in_fm && match($0, "^" key ":") { print key ": " val; replaced=1; next }
    { print }
  ' "$task_md" > "$tmp" && mv "$tmp" "$task_md"
}

# ---- port allocation --------------------------------------------------------

# Allocate a port for a task. If task.md declares one, honor it; otherwise
# pick from BIZREV_PORT_BASE upward, skipping ports already taken.
BIZREV_PORT_BASE="${BIZREV_PORT_BASE:-8100}"

task_allocate_port() {
  local id explicit port_file p
  id="$(task_resolve_id "$1")"
  port_file="$(task_portfile "$id")"
  if [[ -f "$port_file" ]]; then cat "$port_file"; return 0; fi
  explicit="$(task_front_matter "$id" app.port 2>/dev/null || true)"
  if [[ -n "$explicit" && "$explicit" != "null" ]]; then
    printf '%s' "$explicit" > "$port_file"
    cat "$port_file"; return 0
  fi
  for ((p = BIZREV_PORT_BASE; p < BIZREV_PORT_BASE + 100; p++)); do
    # skip ports we've already handed out
    if ! grep -lFx "$p" "$BIZREV_PORTS_DIR"/*.port >/dev/null 2>&1; then
      # skip ports the OS already has open
      if ! (exec 3<>/dev/tcp/127.0.0.1/"$p") 2>/dev/null; then
        printf '%s' "$p" > "$port_file"
        cat "$port_file"; return 0
      else
        exec 3<&- 3>&-
      fi
    fi
  done
  die "could not allocate a port for $id in range $BIZREV_PORT_BASE-$((BIZREV_PORT_BASE+99))"
}

task_release_port() { rm -f "$(task_portfile "$1")"; }

# ---- state.json helpers (best-effort, file-locked) --------------------------

state_init_if_missing() {
  [[ -f "$BIZREV_STATE_FILE" ]] || printf '{"tasks":{}}\n' > "$BIZREV_STATE_FILE"
}

state_set() {
  local id key val
  id="$(task_resolve_id "$1")"; key="$2"; val="$3"
  state_init_if_missing
  ( flock 9
    local tmp; tmp="$(mktemp)"
    jq --arg id "$id" --arg k "$key" --arg v "$val" \
       '.tasks[$id] = ((.tasks[$id] // {}) + {($k): $v, "updated": now | todate})' \
       "$BIZREV_STATE_FILE" > "$tmp" && mv "$tmp" "$BIZREV_STATE_FILE"
  ) 9>"$BIZREV_STATE_FILE.lock"
}

state_get() {
  local id key
  id="$(task_resolve_id "$1")"; key="$2"
  state_init_if_missing
  jq -r --arg id "$id" --arg k "$key" '.tasks[$id][$k] // empty' "$BIZREV_STATE_FILE"
}

# ---- preflight --------------------------------------------------------------

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}
