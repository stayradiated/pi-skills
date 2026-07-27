# pi-zellij-subagents

A Pi skill for spawning observable child Pi sessions as tabs in the current Zellij session. Children notify the manager pane when they finish, block, or fail; durable state files remain the source of truth.

## Development install

From the repository root:

```bash
pi install "$PWD"
```

Run `/reload` after changes, then invoke `/skill:pi-zellij-subagents`.

## Requirements

- Pi must already be running inside an attached Zellij session
- Bash
- Zellij
- Pi available as `pi`

```bash
./scripts/pi-zellij-agents doctor
./tests/test.sh
```

See `SKILL.md` for the manager workflow and `references/PROTOCOL.md` for state and handoff semantics.
