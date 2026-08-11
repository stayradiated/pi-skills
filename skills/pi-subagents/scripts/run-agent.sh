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
notification_claims="$agent_dir/notification-claims"
notification_file="$agent_dir/notified"
notification_error_file="$agent_dir/notification-error"

read_state_file() { [[ -f "$1" ]] && cat "$1" || true; }
write_atomic() { local path=$1 value=$2; printf '%s\n' "$value" >"$path.tmp"; mv "$path.tmp" "$path"; }

terminal_generation() {
  local pending completed
  pending=$(read_state_file "$agent_dir/steering-pending")
  completed=$(read_state_file "$agent_dir/steering-completed")
  [[ -z "$pending" || "$pending" == "$completed" ]] || return 1
  printf '%s' "${completed:-base}"
}

notify_parent() {
  local status=$1 backend session pane manager_cli name message buffer generation
  case "$status" in done|blocked|failed) ;; *) return 0 ;; esac
  generation=$(terminal_generation) || return 0
  mkdir -p "$notification_claims"
  mkdir "$notification_claims/$status-$generation" 2>/dev/null || return 0

  backend=$(read_state_file "$agent_dir/parent-backend")
  session=$(read_state_file "$agent_dir/parent-session")
  pane=$(read_state_file "$agent_dir/parent-target")
  manager_cli=$(read_state_file "$agent_dir/manager-cli")
  name=$(basename "$agent_dir")
  if [[ -z "$backend" || -z "$session" || -z "$pane" || -z "$manager_cli" ]]; then
    write_atomic "$notification_error_file" "parent has no multiplexer endpoint"
    return 0
  fi

  printf -v message "[pi-subagents] child %q -> %s (gen %s); handoff %q result %q" \
    "$name" "$status" "$generation" "$manager_cli" "$name"
  case "$backend" in
    tmux)
      buffer="pi-subagent-notify-$RANDOM-$$"
      if printf '%s' "$message" | tmux load-buffer -b "$buffer" - &&
        tmux paste-buffer -b "$buffer" -d -t "$pane" && tmux send-keys -t "$pane" Enter; then
        write_atomic "$notification_file" "$status"; rm -f "$notification_error_file"
      else write_atomic "$notification_error_file" "failed to notify tmux pane $pane in $session"; fi
      ;;
    zellij)
      if zellij --session "$session" action paste --pane-id "$pane" -- "$message" &&
        sleep 0.2 && zellij --session "$session" action send-keys --pane-id "$pane" Enter; then
        write_atomic "$notification_file" "$status"; rm -f "$notification_error_file"
      else write_atomic "$notification_error_file" "failed to notify Zellij pane $pane in $session"; fi
      ;;
    *) write_atomic "$notification_error_file" "unknown parent backend: $backend" ;;
  esac
}

kick_dispatch() {
  local manager_cli
  manager_cli=$(read_state_file "$agent_dir/manager-cli")
  [[ -n "$manager_cli" && -x "$manager_cli" ]] || return 0
  "$manager_cli" _dispatch >/dev/null 2>&1 &
}

watch_status() {
  local status dispatched='' generation key
  while :; do
    status=$(read_state_file "$status_file")
    case "$status" in
      done|blocked|failed)
        notify_parent "$status"
        if generation=$(terminal_generation); then
          key="$status-$generation"
          [[ "$dispatched" == "$key" ]] || { kick_dispatch; dispatched=$key; }
        fi
        ;;
      stopped) kick_dispatch; return ;;
    esac
    sleep 0.2
  done
}

backend=$(read_state_file "$agent_dir/backend")
case "$backend" in
  tmux) [[ -z "${TMUX_PANE:-}" ]] || write_atomic "$agent_dir/pane" "$TMUX_PANE" ;;
  zellij) [[ -z "${ZELLIJ_PANE_ID:-}" ]] || write_atomic "$agent_dir/pane" "$ZELLIJ_PANE_ID" ;;
esac
if [[ "$(read_state_file "$agent_dir/status")" == starting ]]; then
  write_atomic "$agent_dir/status" running
fi

watch_status &
watcher_pid=$!
# Invoked indirectly by the trap below.
# shellcheck disable=SC2329
stop_watcher() { kill "$watcher_pid" 2>/dev/null || true; wait "$watcher_pid" 2>/dev/null || true; }
trap stop_watcher EXIT INT TERM

set +e
"$@"
rc=$?
set -e
status=$(read_state_file "$status_file")
case "$status" in done|failed|blocked|stopped) ;;
  *)
    if [[ ! -s "$result_file" ]]; then
      cat >"$result_file" <<EOF
# Result

Pi exited with status $rc before recording a terminal status.
EOF
    fi
    write_atomic "$status_file" failed
    status=failed
    ;;
esac
notify_parent "$status"
kick_dispatch
exit "$rc"
