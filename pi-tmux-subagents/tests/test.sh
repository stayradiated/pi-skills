#!/usr/bin/env bash
set -euo pipefail

SKILL_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CLI="$SKILL_DIR/scripts/pi-tmux-agents"
TMP=$(mktemp -d)
STATE="$TMP/state"
WORKTREES="$TMP/worktrees"
SESSION="pi-tmux-subagents-test-$$"
ARGS_FILE="$TMP/pi-args"

cleanup() {
  tmux kill-session -t "$SESSION" 2>/dev/null || true
  rm -rf "$TMP"
}
trap cleanup EXIT

mkdir -p "$TMP/project" "$TMP/bin"
cat >"$TMP/bin/pi" <<EOF_PI
#!/usr/bin/env bash
printf '%s\n' "\$@" >"$ARGS_FILE"
sleep 30
EOF_PI
chmod +x "$TMP/bin/pi"

run() {
  (cd "$TMP/project" && env \
    PATH="$TMP/bin:$PATH" \
    PI_TMUX_STATE_DIR="$STATE" \
    PI_TMUX_WORKTREES_DIR="$WORKTREES" \
    PI_TMUX_SESSION="$SESSION" \
    "$CLI" "$@")
}

expect_status() {
  local expected=$1
  shift
  set +e
  run "$@" >/dev/null 2>&1
  local actual=$?
  set -e
  [[ $actual -eq $expected ]] || {
    printf 'expected status %s, got %s: %s\n' "$expected" "$actual" "$*" >&2
    exit 1
  }
}

bash -n "$CLI" "$SKILL_DIR/scripts/run-agent.sh"
run init >/dev/null
[[ -d "$STATE/agents" ]]

# Names must never resolve to the agents directory or its parent.
expect_status 1 status .
expect_status 1 status ..
[[ -d "$STATE/agents" ]]

# Failed tmux startup rolls back partially-created agent state.
mkdir -p "$TMP/fail-bin"
cat >"$TMP/fail-bin/tmux" <<'EOF_TMUX'
#!/usr/bin/env bash
exit 1
EOF_TMUX
chmod +x "$TMP/fail-bin/tmux"
set +e
(cd "$TMP/project" && env \
  PATH="$TMP/fail-bin:$TMP/bin:$PATH" \
  PI_TMUX_STATE_DIR="$STATE" \
  PI_TMUX_WORKTREES_DIR="$WORKTREES" \
  PI_TMUX_SESSION="$SESSION" \
  "$CLI" start rollback --cwd "$TMP/project" -- "Trigger startup rollback.") >/dev/null 2>&1
rollback_rc=$?
set -e
[[ $rollback_rc -ne 0 ]]
[[ ! -e "$STATE/agents/rollback" ]]

# A child starts with safe Pi resource defaults and an exact tmux window ID.
run start smoke --cwd "$TMP/project" -- "Perform a smoke test." >/dev/null
for _ in {1..50}; do
  [[ -s "$ARGS_FILE" ]] && break
  sleep 0.1
done
[[ -s "$ARGS_FILE" ]]
target=$(run info smoke --field tmux-target)
[[ "$target" == @* ]]
grep -Fx -- '--no-approve' "$ARGS_FILE" >/dev/null
grep -Fx -- '--no-extensions' "$ARGS_FILE" >/dev/null
grep -Fx -- '--no-skills' "$ARGS_FILE" >/dev/null
run stop smoke >/dev/null
run clean smoke >/dev/null

# wait-all distinguishes blocked and failed batches.
mkdir -p "$STATE/agents/done-agent" "$STATE/agents/blocked-agent"
printf '%s\n' done >"$STATE/agents/done-agent/status"
printf '%s\n' blocked >"$STATE/agents/blocked-agent/status"
expect_status 2 wait-all 1
printf '%s\n' done >"$STATE/agents/blocked-agent/status"
expect_status 0 wait-all 1
mkdir -p "$STATE/agents/failed-agent"
printf '%s\n' failed >"$STATE/agents/failed-agent/status"
expect_status 1 wait-all 1

printf 'ok: pi-tmux-subagents tests passed\n'
