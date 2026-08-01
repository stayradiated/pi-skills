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
if command -v tmux >/dev/null 2>&1; then
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
for forbidden in --no-skills --no-extensions --no-approve; do
  if grep -Fx -- "$forbidden" "$ARGS_FILE" >/dev/null; then
    printf 'unexpected Pi argument: %s\n' "$forbidden" >&2
    exit 1
  fi
done

# Pre-injection failures and concurrent sends cannot publish a steering generation.
mv "$TMUX_DIR/pane" "$TMUX_DIR/pane.saved"
expect_status 1 send tmux-child "missing pane"
[[ ! -e "$TMUX_DIR/steering-pending" ]]
mv "$TMUX_DIR/pane.saved" "$TMUX_DIR/pane"
mkdir "$TMUX_DIR/send-lock"
expect_status 1 send tmux-child "concurrent send"
[[ ! -e "$TMUX_DIR/steering-pending" ]]
rmdir "$TMUX_DIR/send-lock"

(
  for _ in {1..50}; do
    if [[ -s "$TMUX_DIR/steering-pending" ]]; then
      recorded_generation=$(cat "$TMUX_DIR/steering-pending")
      printf '{"message":{"role":"user","content":"steering %s"}}\n' "$recorded_generation" >"$TMUX_DIR/session/steering.jsonl"
      exit 0
    fi
    sleep 0.1
  done
  exit 1
) &
recorder_pid=$!
send_output=$(run send tmux-child "--steer")
wait "$recorder_pid"
grep -F 'agent completion pending' <<<"$send_output" >/dev/null
[[ "$(run info tmux-child --field status)" == steering ]]
generation=$(cat "$TMUX_DIR/steering-pending")
[[ "$(cat "$TMUX_DIR/steering-ack")" == "$generation" ]]
printf '%s\n' running >"$TMUX_DIR/status"
[[ "$(run info tmux-child --field status)" == steering ]]
printf '%s\n' "$generation" >"$TMUX_DIR/steering-completed"
printf '%s\n' 'done' >"$TMUX_DIR/status"
[[ "$(run info tmux-child --field status)" == 'done' ]]
run capture tmux-child 2 >/dev/null
close_output=$(run close tmux-child)
grep -F 'closed tmux-child' <<<"$close_output" >/dev/null
if grep -F 'stopped tmux-child' <<<"$close_output" >/dev/null; then
  printf 'terminal close was reported as stopped\n' >&2
  exit 1
fi
else
  printf 'skip: tmux transport tests (tmux is not installed)\n'
fi

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
printf '%s\n' 'done' >"$ROOT_CHILD/status"
printf '%s\n' tmux >"$ROOT_CHILD/backend"
printf '%s\n' "$TMUX_SESSION" >"$ROOT_CHILD/multiplexer-session"
printf '%s\n' "$TMP/project" >"$ROOT_CHILD/cwd"
printf '%s\n' 'done' >"$ROOT_CHILD/children/nested/status"
expect_status 1 close parent
root_status=$(run status)
grep -F parent <<<"$root_status" >/dev/null
if grep -F nested <<<"$root_status" >/dev/null; then
  printf 'nested child leaked into root status\n' >&2
  exit 1
fi
nested_status=$(cd "$TMP/project" && env PATH="$TMP/bin:$PATH" PI_SESSION_ID=ignored PI_SUBAGENT_STATE_DIR="$STATE" PI_SUBAGENT_SELF_DIR="$ROOT_CHILD" "$CLI" status)
grep -F nested <<<"$nested_status" >/dev/null
rm -rf "$ROOT_CHILD/children/nested"
run close parent >/dev/null

# Context selects the newest session and parses usage rather than similarly named cost fields.
BASE="$STATE/managers/test-manager/children"
CONTEXT="$BASE/context-agent"
mkdir -p "$CONTEXT/session"
printf '%s\n' 'done' >"$CONTEXT/status"
printf '%s\n' "$TMP/project" >"$CONTEXT/cwd"
printf '%s\n' '{"usage":{"input":900,"output":1,"cacheRead":0,"cost":{"input":0.1}}}' >"$CONTEXT/session/old.jsonl"
printf '%s\n' \
  '{"usage":{"input":100,"output":5,"cacheRead":50,"cost":{"input":0.0001,"cacheRead":0}}}' \
  '{"usage":{"input":0,"output":0,"cacheRead":0,"cost":{"input":0,"cacheRead":0}}}' >"$CONTEXT/session/new.jsonl"
touch -t 202001010000 "$CONTEXT/session/old.jsonl"
touch -t 202101010000 "$CONTEXT/session/new.jsonl"
context_output=$(run context context-agent 1000)
grep -F 'estimated context: 150 tokens' <<<"$context_output" >/dev/null
grep -F '(15% used)' <<<"$context_output" >/dev/null
rm -rf "$CONTEXT"

# wait-all preserves status distinctions and treats steering as nonterminal.
mkdir -p "$BASE/done-agent" "$BASE/blocked-agent"
printf '%s\n' 'done' >"$BASE/done-agent/status"
printf '%s\n' 'blocked' >"$BASE/blocked-agent/status"
printf '%s\n' "$TMP/project" >"$BASE/done-agent/cwd"
printf '%s\n' "$TMP/project" >"$BASE/blocked-agent/cwd"
expect_status 2 wait-all 1
if command -v tmux >/dev/null 2>&1; then
  steering_target=$(tmux new-window -d -P -F '#{pane_id}|#{window_id}' -t "=$TMUX_SESSION:" "sleep 30")
  IFS='|' read -r steering_pane steering_container <<<"$steering_target"
  printf '%s\n' tmux >"$BASE/done-agent/backend"
  printf '%s\n' "$TMUX_SESSION" >"$BASE/done-agent/multiplexer-session"
  printf '%s\n' "$steering_pane" >"$BASE/done-agent/target"
  printf '%s\n' "$steering_container" >"$BASE/done-agent/container"
  printf '%s\n' pending >"$BASE/done-agent/steering-pending"
  expect_status 124 wait-all 1
  printf '%s\n' pending >"$BASE/done-agent/steering-completed"
fi
printf '%s\n' 'done' >"$BASE/blocked-agent/status"
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
printf '%s\n' 'done' >"$1.tmp"
mv "$1.tmp" "$1"
EOF
chmod +x "$FAKE/zellij" "$FAKE/finish"
env PATH="$FAKE:$PATH" NOTIFY_LOG="$LOG" "$RUNNER" "$NOTIFY" finish "$NOTIFY/status"
[[ "$(cat "$NOTIFY/notified")" == 'done' ]]
[[ "$(grep -c 'action paste' "$LOG")" -eq 1 ]]

printf 'ok: pi-subagents tests passed\n'
