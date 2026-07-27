# Protocol

State defaults to `.pi/tmux-subagents/agents/<name>/`; worktrees default to `~/.pi/agent/tmux-worktrees/<project-hash>/<name>/`.

Each agent stores:

- `status`: `starting`, `running`, `blocked`, `done`, `failed`, or `stopped`
- `prompt.md`: assignment and child contract
- `result.md`: durable handoff or failure reason
- `cwd` and `branch`: working location
- `tmux-target`: exact tmux window ID
- `session/`: Pi session data

`exited` is reported dynamically when a starting or running child loses its tmux window.

The child sets `running` when it begins. Before setting `done`, `blocked`, or `failed`, it writes `result.md` with the outcome, evidence, changes, validation, risks, and next step. Status updates use a temporary file and atomic rename.

`wait` and `wait-all` return:

- `0`: done
- `1`: failed, exited, or stopped
- `2`: blocked
- `124`: timeout

`send` pastes steering through a tmux buffer. Durable files remain the source of truth; pane capture is diagnostic only.

Children start with project trust, extensions, and skills disabled. Context files still load. Worktrees reduce Git collisions but are not security boundaries; child processes retain the invoking user's filesystem and network access.

Environment overrides:

- `PI_TMUX_STATE_DIR`
- `PI_TMUX_WORKTREES_DIR`
- `PI_TMUX_SESSION`
