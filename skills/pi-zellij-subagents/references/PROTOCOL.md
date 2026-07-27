# Protocol

State defaults to `.pi/zellij-subagents/agents/<name>/` under the directory where the manager invokes the helper.

Each agent stores:

- `status`: `starting`, `running`, `blocked`, `done`, `failed`, or `stopped`
- `prompt.md`: assignment and child contract
- `result.md`: durable handoff or failure reason
- `cwd`: working location
- `zellij-tab`: stable ID of the child's tab
- `zellij-pane`: ID used for capture and steering
- `parent-zellij-pane`: manager pane ID used for terminal-status notification
- `manager-cli`: absolute helper path included in the notification
- `notified`: terminal status successfully sent to the manager, when present
- `notification-claims/`: per-status atomic single-sender claim directories
- `notification-error`: notification delivery failure, when present
- `session/`: Pi session data

`exited` is reported dynamically when a starting or running child loses its Zellij tab.

The child sets `running` when it begins. Before setting `done`, `blocked`, or `failed`, it writes `result.md` with the outcome, evidence, changes, validation, risks, and next step. Status updates use a temporary file and atomic rename.

`wait` and `wait-all` return:

- `0`: done
- `1`: failed, exited, or stopped
- `2`: blocked
- `124`: timeout

`send` targets the child's pane. On `done`, `blocked`, or `failed`, the runner pastes a fixed message into `parent-zellij-pane` and sends Enter. In an active Pi run this becomes queued steering after the current tool-call batch. Each status is attempted once and the latest delivery outcome is recorded in `notified` or `notification-error`; status and result files remain the source of truth. Because notification uses terminal input injection, it can collide with a user draft or active dialog. Screen capture is diagnostic only. The user can always inspect or interact with the child directly in its `agent-NAME` tab.

Children start with project trust, extensions, and skills disabled. Context files still load. Child processes retain the invoking user's filesystem and network access.

Environment override:

- `PI_ZELLIJ_STATE_DIR` — relative paths are resolved from the manager's invocation directory
