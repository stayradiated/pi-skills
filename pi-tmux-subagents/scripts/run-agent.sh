#!/usr/bin/env bash
set -uo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: run-agent.sh AGENT_DIR command [args...]" >&2
  exit 64
fi

agent_dir=$1
shift
status_file="$agent_dir/status"
failure_file="$agent_dir/failure.md"

set +e
"$@"
rc=$?
set -e

status=""
[[ -f "$status_file" ]] && status=$(<"$status_file")
case "$status" in
  done|failed|blocked|stopped) ;;
  *)
    cat >"$failure_file" <<EOF_FAILURE
# Failure

The Pi child process exited with status $rc before recording a terminal status.
EOF_FAILURE
    printf '%s\n' failed >"$status_file.tmp"
    mv "$status_file.tmp" "$status_file"
    ;;
esac

exit "$rc"
