# pi-subagents

A Pi skill for observable child sessions in either tmux or Zellij through one interface.

## Requirements

- Bash and Pi
- tmux, Zellij, or both
- An active session in the selected backend

The current session is reused automatically. Outside a multiplexer, create a session yourself and pass `--session NAME`.

```bash
./scripts/pi-subagents doctor
./tests/test.sh
```

See `SKILL.md` for the workflow and `references/PROTOCOL.md` for state semantics.
