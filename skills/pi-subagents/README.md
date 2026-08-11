# pi-subagents

A Pi skill for observable child sessions in either tmux or Zellij through one interface.

## Requirements

- Bash, `flock`, and Pi
- tmux, Zellij, or both
- An active session in the selected backend

The current session is reused automatically. Outside a multiplexer, create a session yourself and pass `--session NAME`.

Starts are queued and dispatched under one state-directory-wide active-leaf limit (default 8). Set `PI_SUBAGENT_CONCURRENCY` before first use of a state directory, or use `./scripts/pi-subagents limit NUMBER` to change its persisted limit.

```bash
./scripts/pi-subagents doctor
./tests/test.sh
```

See `SKILL.md` for the workflow and `references/PROTOCOL.md` for state semantics.
