#!/usr/bin/env bash
set -euo pipefail

SKILL_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CLI="$SKILL_DIR/scripts/pi-zellij-agents"
RUNNER="$SKILL_DIR/scripts/run-agent.sh"
TMP=$(mktemp -d)
STATE="$TMP/state"
ARGS_FILE="$TMP/pi-args"

sink_pane=''
cleanup() {
  local root dir tab
  [[ -z "$sink_pane" ]] || zellij action close-pane --pane-id "$sink_pane" >/dev/null 2>&1 || true
  for root in "$STATE" "$TMP/project/relative-state"; do
    [[ -d "$root/agents" ]] || continue
    for dir in "$root/agents"/*; do
      [[ -d "$dir" ]] || continue
      tab=$(cat "$dir/zellij-tab" 2>/dev/null || true)
      [[ "$tab" =~ ^[0-9]+$ ]] && zellij action close-tab-by-id "$tab" >/dev/null 2>&1 || true
    done
  done
  rm -rf "$TMP"
}
trap cleanup EXIT

# Syntax and notification tests must run even when Zellij integration is unavailable.
bash -n "$CLI" "$RUNNER"

# A terminal child status sends exactly one fixed completion message to its parent pane.
NOTIFY_AGENT="$TMP/notify-agent"
NOTIFY_BIN="$TMP/notify-bin"
NOTIFY_LOG="$TMP/notify.log"
mkdir -p "$NOTIFY_AGENT" "$NOTIFY_BIN"
printf '%s\n' starting >"$NOTIFY_AGENT/status"
printf '%s\n' parent-pane-42 >"$NOTIFY_AGENT/parent-zellij-pane"
printf '%s\n' "$CLI" >"$NOTIFY_AGENT/manager-cli"
cat >"$NOTIFY_BIN/zellij" <<'EOF_ZELLIJ'
#!/usr/bin/env bash
printf '%q ' "$@" >>"$NOTIFY_LOG"
printf '\n' >>"$NOTIFY_LOG"
EOF_ZELLIJ
cat >"$NOTIFY_BIN/finish-child" <<'EOF_CHILD'
#!/usr/bin/env bash
printf '%s\n' done >"$1.tmp"
mv "$1.tmp" "$1"
EOF_CHILD
chmod +x "$NOTIFY_BIN/zellij" "$NOTIFY_BIN/finish-child"
env PATH="$NOTIFY_BIN:$PATH" NOTIFY_LOG="$NOTIFY_LOG" \
  "$RUNNER" "$NOTIFY_AGENT" finish-child "$NOTIFY_AGENT/status"
[[ "$(cat "$NOTIFY_AGENT/notified")" == done ]]
[[ ! -e "$NOTIFY_AGENT/notification-error" ]]
[[ "$(grep -c '^action paste ' "$NOTIFY_LOG")" -eq 1 ]]
[[ "$(grep -c '^action send-keys ' "$NOTIFY_LOG")" -eq 1 ]]
grep -F -- "--pane-id parent-pane-42" "$NOTIFY_LOG" >/dev/null
grep -F -- "Agent\\ \'notify-agent\'\\ reached\\ status\\ \'done\'" "$NOTIFY_LOG" >/dev/null
grep -F -- "result\\ notify-agent" "$NOTIFY_LOG" >/dev/null

[[ -n "${ZELLIJ_SESSION_NAME:-}" && -n "${ZELLIJ_PANE_ID:-}" ]] || {
  printf 'skip: pi-zellij-subagents integration test requires Zellij\n'
  exit 0
}

mkdir -p "$TMP/project" "$TMP/bin"
cat >"$TMP/bin/pi" <<EOF_PI
#!/usr/bin/env bash
printf '%s\n' "\$@" >"$ARGS_FILE"
sleep 30
EOF_PI
chmod +x "$TMP/bin/pi"

run() {
  (cd "$TMP/project" && env PATH="$TMP/bin:$PATH" PI_ZELLIJ_STATE_DIR="$STATE" "$CLI" "$@")
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

run doctor >/dev/null

# Exercise actual Zellij delivery against a disposable sink pane, never the Pi pane running tests.
REAL_NOTIFY_AGENT="$TMP/real-notify-agent"
REAL_NOTIFY_RECEIVED="$TMP/real-notify-received"
mkdir -p "$REAL_NOTIFY_AGENT"
printf '%s\n' starting >"$REAL_NOTIFY_AGENT/status"
printf '%s\n' "$CLI" >"$REAL_NOTIFY_AGENT/manager-cli"
sink_pane=$(zellij action new-pane --name notification-sink -- bash -c \
  'IFS= read -r line; printf "%s\n" "$line" >"$1"; sleep 30' _ "$REAL_NOTIFY_RECEIVED")
zellij action focus-pane-id "$ZELLIJ_PANE_ID"
printf '%s\n' "$sink_pane" >"$REAL_NOTIFY_AGENT/parent-zellij-pane"
"$RUNNER" "$REAL_NOTIFY_AGENT" "$NOTIFY_BIN/finish-child" "$REAL_NOTIFY_AGENT/status"
for _ in {1..50}; do
  [[ -s "$REAL_NOTIFY_RECEIVED" ]] && break
  sleep 0.1
done
[[ "$(cat "$REAL_NOTIFY_AGENT/notified")" == done ]]
grep -F -- "[pi-zellij-subagents] Agent 'real-notify-agent' reached status 'done'." \
  "$REAL_NOTIFY_RECEIVED" >/dev/null
zellij action close-pane --pane-id "$sink_pane" >/dev/null
sink_pane=''

mkdir -p "$STATE/agents"

# Missing Pi fails before creating partial agent state.
mkdir -p "$TMP/no-pi-bin"
ln -s "$(command -v bash)" "$TMP/no-pi-bin/bash"
ln -s "$(command -v dirname)" "$TMP/no-pi-bin/dirname"
set +e
(cd "$TMP/project" && env PATH="$TMP/no-pi-bin" PI_ZELLIJ_STATE_DIR="$STATE" \
  "$CLI" start no-pi -- "Must not start") >/dev/null 2>&1
no_pi_rc=$?
set -e
[[ $no_pi_rc -ne 0 ]]
[[ ! -e "$STATE/agents/no-pi" ]]

# Names must never resolve to the agents directory or its parent.
expect_status 1 status .
expect_status 1 status ..

# Start opens a tab in this session and launches Pi with safe resource defaults.
expect_status 1 start missing-options -- "Must specify model and thinking."
run start smoke --cwd "$TMP/project" --model test/model --thinking low -- "Perform a smoke test." >/dev/null
for _ in {1..50}; do
  [[ -s "$ARGS_FILE" && -s "$STATE/agents/smoke/zellij-pane" ]] && break
  sleep 0.1
done
[[ -s "$ARGS_FILE" ]]
tab=$(run info smoke --field zellij-tab)
pane=$(run info smoke --field zellij-pane)
[[ "$tab" =~ ^[0-9]+$ ]]
[[ "$pane" =~ ^[0-9]+$ ]]
[[ "$(run info smoke --field status)" == starting ]]
grep -Fx -- '--no-approve' "$ARGS_FILE" >/dev/null
grep -Fx -- '--no-extensions' "$ARGS_FILE" >/dev/null
grep -Fx -- '--no-skills' "$ARGS_FILE" >/dev/null
grep -Fx -- '--model' "$ARGS_FILE" >/dev/null
grep -Fx -- 'test/model' "$ARGS_FILE" >/dev/null
grep -Fx -- '--thinking' "$ARGS_FILE" >/dev/null
grep -Fx -- 'low' "$ARGS_FILE" >/dev/null
[[ "$(run info smoke --field model)" == test/model ]]
[[ "$(run info smoke --field thinking)" == low ]]
# A leading dash in a steering message must be treated as content, not an option.
run check smoke >/dev/null
expect_status 1 close smoke
run send smoke "--Test steering" >/dev/null
run capture smoke 5 >/dev/null
run stop smoke >/dev/null
run clean smoke >/dev/null

# Relative state overrides remain manager-relative when the child uses another cwd.
mkdir -p "$TMP/other-project"
run_relative() {
  (cd "$TMP/project" && env PATH="$TMP/bin:$PATH" PI_ZELLIJ_STATE_DIR=relative-state "$CLI" "$@")
}
run_relative start relative --cwd "$TMP/other-project" --model test/model --thinking medium -- "Test relative state." >/dev/null
for _ in {1..50}; do
  [[ -s "$TMP/project/relative-state/agents/relative/zellij-pane" ]] && break
  sleep 0.1
done
[[ -s "$TMP/project/relative-state/agents/relative/zellij-pane" ]]
[[ "$(run_relative info relative --field status)" == starting ]]
run_relative stop relative >/dev/null
run_relative clean relative >/dev/null

# start refuses to operate without an attached Zellij environment.
set +e
(cd "$TMP/project" && env -u ZELLIJ_SESSION_NAME -u ZELLIJ_PANE_ID \
  PATH="$TMP/bin:$PATH" PI_ZELLIJ_STATE_DIR="$STATE" \
  "$CLI" start outside -- "Must not start") >/dev/null 2>&1
outside_rc=$?
set -e
[[ $outside_rc -ne 0 ]]

# Context reports the latest request's input plus cache-read tokens and warns at 40%.
mkdir -p "$STATE/agents/context-agent/session"
printf '%s\n' '{"usage":{"input":300,"cacheRead":200}}' >"$STATE/agents/context-agent/session/test.jsonl"
printf '%s\n' running >"$STATE/agents/context-agent/status"
context_output=$(run context context-agent 1000)
grep -F -- 'estimated context: 500 tokens (input 300 + cache read 200)' <<<"$context_output" >/dev/null
grep -F -- 'context window:    1000 tokens (50% used)' <<<"$context_output" >/dev/null
grep -F -- 'recommendation: start a fresh child' <<<"$context_output" >/dev/null
printf '%s\n' done >"$STATE/agents/context-agent/status"
check_output=$(run check context-agent 1000)
grep -F -- 'context-agent' <<<"$check_output" >/dev/null
grep -F -- '50% used' <<<"$check_output" >/dev/null
run close context-agent >/dev/null
[[ ! -e "$STATE/agents/context-agent" ]]

# wait-all distinguishes blocked and failed batches without requiring live tabs.
mkdir -p "$STATE/agents/done-agent" "$STATE/agents/blocked-agent"
printf '%s\n' done >"$STATE/agents/done-agent/status"
printf '%s\n' blocked >"$STATE/agents/blocked-agent/status"
expect_status 2 wait-all 1
printf '%s\n' done >"$STATE/agents/blocked-agent/status"
expect_status 0 wait-all 1

# Malformed state must not be mistaken for successful completion.
mkdir -p "$STATE/agents/invalid-agent"
printf '%s\n' complete >"$STATE/agents/invalid-agent/status"
[[ "$(run info invalid-agent --field status)" == unknown ]]
printf '%s\n' done >"$STATE/agents/invalid-agent/status"

mkdir -p "$STATE/agents/failed-agent"
printf '%s\n' failed >"$STATE/agents/failed-agent/status"
expect_status 1 wait-all 1

printf 'ok: pi-zellij-subagents tests passed\n'
