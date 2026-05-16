#!/usr/bin/env bash
# Preflight check: are all the dependencies the harness needs available?

# shellcheck source=lib/common.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

check_ok=0
check_fail=0
check() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    printf '  %s✓%s %s\n' "$_C_GREEN" "$_C_RESET" "$name"
    check_ok=$((check_ok+1))
  else
    printf '  %s✗%s %s\n' "$_C_RED" "$_C_RESET" "$name"
    check_fail=$((check_fail+1))
  fi
}

echo "=== required ==="
check "git ≥ 2.40"          bash -c "git --version | awk '{print \$3}' | awk -F. '{exit (\$1>2 || (\$1==2 && \$2>=40)) ? 0 : 1}'"
check "jq"                  command -v jq
check "bash ≥ 4 (assoc arrays, mapfile)"  bash -c 'test ${BASH_VERSINFO[0]} -ge 4'

echo
echo "=== implementer ==="
check "codex (Codex CLI)"   command -v codex

echo
echo "=== runtime (recommended) ==="
check "node ≥ 20"           bash -c "node --version | sed s/v// | awk -F. '{exit \$1>=20 ? 0 : 1}'"
check "python ≥ 3.11"       bash -c "python3 --version | awk '{print \$2}' | awk -F. '{exit (\$1>3 || (\$1==3 && \$2>=11)) ? 0 : 1}'"
check "curl"                command -v curl
check "make"                command -v make

echo
echo "=== state ==="
check "repo writable"       test -w "$BIZREV_REPO_ROOT"
check "state dir writable"  test -w "$BIZREV_STATE_DIR"

echo
echo "summary: $check_ok ok, $check_fail missing"
exit "$check_fail"
