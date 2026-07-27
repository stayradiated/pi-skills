#!/usr/bin/env bash
set -euo pipefail

SKILL_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CLI="$SKILL_DIR/scripts/pi-zellij-agents"
TMP=$(mktemp -d)
STATE="$TMP/state"
ARGS_FILE="$TMP/pi-args"

cleanup() {
  local root dir tab
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

# Syntax checks must run even when Zellij integration is unavailable.
bash -n "$CLI" "$SKILL_DIR/scripts/run-agent.sh"

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
run start smoke --cwd "$TMP/project" -- "Perform a smoke test." >/dev/null
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
# A leading dash in a steering message must be treated as content, not an option.
run send smoke "--Test steering" >/dev/null
run capture smoke 5 >/dev/null
run stop smoke >/dev/null
run clean smoke >/dev/null

# Relative state overrides remain manager-relative when the child uses another cwd.
mkdir -p "$TMP/other-project"
run_relative() {
  (cd "$TMP/project" && env PATH="$TMP/bin:$PATH" PI_ZELLIJ_STATE_DIR=relative-state "$CLI" "$@")
}
run_relative start relative --cwd "$TMP/other-project" -- "Test relative state." >/dev/null
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
