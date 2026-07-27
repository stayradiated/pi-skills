# Protocol

State defaults to `.pi/zellij-subagents/agents/<name>/` under the directory where the manager invokes the helper.

Each agent stores:

- `status`: `starting`, `running`, `blocked`, `done`, `failed`, or `stopped`
- `prompt.md`: assignment and child contract
- `result.md`: durable handoff or failure reason
- `cwd`: working location
- `zellij-tab`: stable ID of the child's tab
- `zellij-pane`: ID used for capture and steering
- `session/`: Pi session data

`exited` is reported dynamically when a starting or running child loses its Zellij tab.

The child sets `running` when it begins. Before setting `done`, `blocked`, or `failed`, it writes `result.md` with the outcome, evidence, changes, validation, risks, and next step. Status updates use a temporary file and atomic rename.

`wait` and `wait-all` return:

- `0`: done
- `1`: failed, exited, or stopped
- `2`: blocked
- `124`: timeout

`send` targets the child's pane. Durable files remain the source of truth; screen capture is diagnostic only. The user can always inspect or interact with the child directly in its `agent-NAME` tab.

Children start with project trust, extensions, and skills disabled. Context files still load. Child processes retain the invoking user's filesystem and network access.

Environment override:

- `PI_ZELLIJ_STATE_DIR` — relative paths are resolved from the manager's invocation directory
