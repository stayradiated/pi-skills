#!/usr/bin/env bash
set -uo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: run-agent.sh AGENT_DIR command [args...]" >&2
  exit 64
fi

agent_dir=$1
shift
status_file="$agent_dir/status"
result_file="$agent_dir/result.md"
pane_file="$agent_dir/zellij-pane"
parent_pane_file="$agent_dir/parent-zellij-pane"
manager_cli_file="$agent_dir/manager-cli"
notification_claims="$agent_dir/notification-claims"
notification_file="$agent_dir/notified"
notification_error_file="$agent_dir/notification-error"

read_state_file() { [[ -f "$1" ]] && cat "$1" || true; }
write_atomic() { local path=$1 value=$2; printf '%s\n' "$value" >"$path.tmp"; mv "$path.tmp" "$path"; }

notify_parent() {
  local status=$1 parent_pane manager_cli name message
  case "$status" in done|blocked|failed) ;; *) return 0 ;; esac

  # The per-status mkdir is the atomic claim: watcher and cleanup may race, and
  # a redirected blocked agent may later need a separate done notification.
  mkdir -p "$notification_claims"
  mkdir "$notification_claims/$status" 2>/dev/null || return 0
  parent_pane=$(read_state_file "$parent_pane_file")
  manager_cli=$(read_state_file "$manager_cli_file")
  name=$(basename "$agent_dir")
  if [[ -z "$parent_pane" || -z "$manager_cli" ]]; then
    rm -f "$notification_file"
    write_atomic "$notification_error_file" "missing parent pane or manager CLI"
    return 0
  fi

  printf -v message "[pi-zellij-subagents] Agent '%s' reached status '%s'. Collect its handoff with: %q result %q" \
    "$name" "$status" "$manager_cli" "$name"
  if zellij action paste --pane-id "$parent_pane" -- "$message" &&
    zellij action send-keys --pane-id "$parent_pane" Enter; then
    write_atomic "$notification_file" "$status"
    rm -f "$notification_error_file"
  else
    rm -f "$notification_file"
    write_atomic "$notification_error_file" "failed to send $status notification to pane $parent_pane"
  fi
}

watch_status() {
  local status
  while :; do
    status=$(read_state_file "$status_file")
    case "$status" in
      done|blocked|failed) notify_parent "$status" ;;
      stopped) return ;;
    esac
    sleep 0.2
  done
}

if [[ -n "${ZELLIJ_PANE_ID:-}" ]]; then
  write_atomic "$pane_file" "$ZELLIJ_PANE_ID"
fi

watch_status &
watcher_pid=$!
stop_watcher() {
  kill "$watcher_pid" 2>/dev/null || true
  wait "$watcher_pid" 2>/dev/null || true
}
trap stop_watcher EXIT INT TERM

set +e
"$@"
rc=$?
set -e

status=$(read_state_file "$status_file")
case "$status" in
  done|failed|blocked|stopped) ;;
  *)
    if [[ ! -s "$result_file" ]]; then
      cat >"$result_file" <<EOF_FAILURE
# Result

Pi exited with status $rc before recording a terminal status.
EOF_FAILURE
    fi
    write_atomic "$status_file" failed
    status=failed
    ;;
esac

# Ensure short-lived or failed children notify before this runner exits.
notify_parent "$status"

exit "$rc"
