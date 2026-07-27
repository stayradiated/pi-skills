# pi-tmux-subagents

A Pi skill for delegating bounded work to observable child Pi sessions in tmux.

## Development install

From the repository root, install the local package:

```bash
pi install "$PWD"
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
