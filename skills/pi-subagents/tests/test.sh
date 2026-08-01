#!/usr/bin/env bash
set -euo pipefail

SKILL_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CLI="$SKILL_DIR/scripts/pi-subagents"
RUNNER="$SKILL_DIR/scripts/run-agent.sh"
TMP=$(mktemp -d)
STATE="$TMP/state"
ARGS_FILE="$TMP/pi-args"
TMUX_SESSION="pi-subagents-test-$$"

cleanup() {
  tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true
  local dir tab
  for dir in "$STATE/managers/test-manager/children"/*; do
    [[ -d "$dir" ]] || continue
    [[ "$(cat "$dir/backend" 2>/dev/null || true)" == zellij ]] || continue
    tab=$(cat "$dir/target" 2>/dev/null || true)
    [[ "$tab" =~ ^[0-9]+$ ]] && zellij --session "${ZELLIJ_SESSION_NAME:-}" action close-tab-by-id "$tab" >/dev/null 2>&1 || true
  done
  rm -rf "$TMP"
}
trap cleanup EXIT

bash -n "$CLI" "$RUNNER"
mkdir -p "$TMP/project" "$TMP/bin"
cat >"$TMP/bin/pi" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" >"$ARGS_FILE"
sleep 30
EOF
chmod +x "$TMP/bin/pi"

run() {
  (cd "$TMP/project" && env \
    -u PI_SUBAGENT_SELF_DIR -u PI_SUBAGENT_PATH -u PI_SUBAGENT_BACKEND \
    PATH="$TMP/bin:$PATH" PI_SESSION_ID=test-manager PI_SUBAGENT_STATE_DIR="$STATE" \
    "$CLI" "$@")
}
expect_status() {
  local expected=$1; shift; set +e; run "$@" >/dev/null 2>&1; local actual=$?; set -e
  [[ $actual -eq $expected ]] || { printf 'expected %s, got %s: %s\n' "$expected" "$actual" "$*" >&2; exit 1; }
}

run doctor >/dev/null
expect_status 1 start missing -- "missing explicit model and thinking"

# Outside a multiplexer requires an existing named session.
expect_status 1 start outside --backend tmux --model test/model --thinking low -- "missing session"
tmux new-session -d -s "$TMUX_SESSION"
env -u TMUX -u TMUX_PANE -u ZELLIJ_SESSION_NAME -u ZELLIJ_PANE_ID \
  -u PI_SUBAGENT_SELF_DIR -u PI_SUBAGENT_PATH -u PI_SUBAGENT_BACKEND \
  PATH="$TMP/bin:$PATH" PI_SESSION_ID=test-manager PI_SUBAGENT_STATE_DIR="$STATE" \
  "$CLI" start tmux-child --backend tmux --session "$TMUX_SESSION" \
  --cwd "$TMP/project" --model test/model --thinking low -- "tmux smoke" >/dev/null
for _ in {1..50}; do [[ -s "$STATE/managers/test-manager/children/tmux-child/pane" ]] && break; sleep 0.1; done
TMUX_DIR="$STATE/managers/test-manager/children/tmux-child"
[[ "$(cat "$TMUX_DIR/backend")" == tmux ]]
[[ "$(cat "$TMUX_DIR/multiplexer-session")" == "$TMUX_SESSION" ]]
[[ "$(run info tmux-child --field status)" == starting ]]
grep -Fx -- '--model' "$ARGS_FILE" >/dev/null
grep -Fx -- '--thinking' "$ARGS_FILE" >/dev/null
! grep -Fx -- '--no-skills' "$ARGS_FILE" >/dev/null
! grep -Fx -- '--no-extensions' "$ARGS_FILE" >/dev/null
! grep -Fx -- '--no-approve' "$ARGS_FILE" >/dev/null
run send tmux-child "--steer" >/dev/null
run capture tmux-child 2 >/dev/null
run stop tmux-child >/dev/null
run close tmux-child >/dev/null

# Current Zellij is reused when available.
if [[ -n "${ZELLIJ_SESSION_NAME:-}" && -n "${ZELLIJ_PANE_ID:-}" ]]; then
  : >"$ARGS_FILE"
  run start zellij-child --cwd "$TMP/project" --model test/model --thinking medium -- "zellij smoke" >/dev/null
  ZELLIJ_DIR="$STATE/managers/test-manager/children/zellij-child"
  for _ in {1..50}; do [[ -s "$ZELLIJ_DIR/pane" ]] && break; sleep 0.1; done
  [[ "$(cat "$ZELLIJ_DIR/backend")" == zellij ]]
  [[ "$(cat "$ZELLIJ_DIR/multiplexer-session")" == "$ZELLIJ_SESSION_NAME" ]]
  run stop zellij-child >/dev/null
  run close zellij-child >/dev/null
fi

# Names and command visibility are scoped to one direct parent.
ROOT_CHILD="$STATE/managers/test-manager/children/parent"
mkdir -p "$ROOT_CHILD/children/nested/session"
printf '%s\n' done >"$ROOT_CHILD/status"
printf '%s\n' tmux >"$ROOT_CHILD/backend"
printf '%s\n' "$TMUX_SESSION" >"$ROOT_CHILD/multiplexer-session"
printf '%s\n' "$TMP/project" >"$ROOT_CHILD/cwd"
printf '%s\n' done >"$ROOT_CHILD/children/nested/status"
expect_status 1 close parent
root_status=$(run status)
grep -F parent <<<"$root_status" >/dev/null
! grep -F nested <<<"$root_status" >/dev/null
nested_status=$(cd "$TMP/project" && env PATH="$TMP/bin:$PATH" PI_SESSION_ID=ignored PI_SUBAGENT_STATE_DIR="$STATE" PI_SUBAGENT_SELF_DIR="$ROOT_CHILD" "$CLI" status)
grep -F nested <<<"$nested_status" >/dev/null
rm -rf "$ROOT_CHILD/children/nested"
run close parent >/dev/null

# wait-all preserves status distinctions.
BASE="$STATE/managers/test-manager/children"
mkdir -p "$BASE/done-agent" "$BASE/blocked-agent"
printf '%s\n' done >"$BASE/done-agent/status"
printf '%s\n' blocked >"$BASE/blocked-agent/status"
printf '%s\n' "$TMP/project" >"$BASE/done-agent/cwd"
printf '%s\n' "$TMP/project" >"$BASE/blocked-agent/cwd"
expect_status 2 wait-all 1
printf '%s\n' done >"$BASE/blocked-agent/status"
expect_status 0 wait-all 1

# Notification transport is selected from the recorded parent backend.
NOTIFY="$TMP/notify"
FAKE="$TMP/fake"
LOG="$TMP/notify.log"
mkdir -p "$NOTIFY" "$FAKE"
printf '%s\n' zellij >"$NOTIFY/backend"
printf '%s\n' zellij >"$NOTIFY/parent-backend"
printf '%s\n' parent-session >"$NOTIFY/parent-session"
printf '%s\n' 42 >"$NOTIFY/parent-target"
printf '%s\n' "$CLI" >"$NOTIFY/manager-cli"
printf '%s\n' starting >"$NOTIFY/status"
cat >"$FAKE/zellij" <<'EOF'
#!/usr/bin/env bash
printf '%q ' "$@" >>"$NOTIFY_LOG"
printf '\n' >>"$NOTIFY_LOG"
EOF
cat >"$FAKE/finish" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' done >"$1.tmp"
mv "$1.tmp" "$1"
EOF
chmod +x "$FAKE/zellij" "$FAKE/finish"
env PATH="$FAKE:$PATH" NOTIFY_LOG="$LOG" "$RUNNER" "$NOTIFY" finish "$NOTIFY/status"
[[ "$(cat "$NOTIFY/notified")" == done ]]
[[ "$(grep -c 'action paste' "$LOG")" -eq 1 ]]

printf 'ok: pi-subagents tests passed\n'
