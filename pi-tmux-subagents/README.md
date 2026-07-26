# pi-tmux-subagents

A Pi skill for delegating bounded work to observable child Pi sessions in tmux.

## Development install

Keep this directory in your source checkout and link it into Pi:

```bash
ln -s "$PWD/pi-tmux-subagents" ~/.pi/agent/skills/pi-tmux-subagents
```

Run `/reload` after changes, then invoke `/skill:pi-tmux-subagents`.

## Requirements

- Bash
- tmux
- Pi available as `pi`
- Git for worktree mode

```bash
./scripts/pi-tmux-agents doctor
./tests/test.sh
```

See `SKILL.md` for the manager workflow and `references/PROTOCOL.md` for state and handoff semantics.
