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

set +e
"$@"
rc=$?
set -e

status=""
[[ -f "$status_file" ]] && status=$(<"$status_file")
case "$status" in
  done|failed|blocked|stopped) ;;
  *)
    if [[ ! -s "$result_file" ]]; then
      cat >"$result_file" <<EOF_FAILURE
# Result

Pi exited with status $rc before recording a terminal status.
EOF_FAILURE
    fi
    printf '%s\n' failed >"$status_file.tmp"
    mv "$status_file.tmp" "$status_file"
    ;;
esac

exit "$rc"
