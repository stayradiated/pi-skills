# Protocol

State defaults to `<project-root>/.pi/subagents/`, with `PI_SUBAGENT_STATE_DIR` as an override. Root managers are scoped by `PI_SESSION_ID`; nested managers use their own agent record. Names are unique only among a manager's direct children.

Each child stores its status, prompt, result, working directory, model, thinking level, hierarchy, backend, multiplexer session, target IDs, parent endpoint, and Pi session data. Persisted status is one of `queued`, `starting`, `running`, `blocked`, `done`, `failed`, or `stopped`. `start` durably creates a `queued` record and returns; a state-directory-wide dispatcher atomically promotes eligible records to `starting`. The runner records `running` atomically before the child command begins, so `starting` covers launch only. A missing live target is reported dynamically as `exited`; an uncompleted managed steering generation is reported as `steering` so an older terminal status cannot satisfy `wait`.

The dispatcher serializes admission, cancellation, cleanup, and limit changes with an advisory `flock` on the state root, then enforces one global active-leaf limit for the complete `PI_SUBAGENT_STATE_DIR`. Before admission it reconciles `starting` and `running` records whose target is no longer live as failed, so dead panes cannot retain capacity. It is initialized once in `concurrency-limit` from `PI_SUBAGENT_CONCURRENCY` (default 8), and may be changed with `limit NUMBER`. An active `starting`, `running`, or steering record consumes a slot only when it has no active descendant. Consequently, a first nested child transfers its parent branch's slot and can launch at capacity; additional concurrent nested children require another slot. Queued records are considered in ticket order, except that a zero-cost nested record may bypass an ineligible earlier record. Terminal and stopped records release capacity; terminal runner events, starts, stops, waits, and checks kick the dispatcher. `stop` cancels a queued record.

Commands operate only on the invoking manager's direct children. Nested delegation uses the same interface, and hierarchy metadata is informational. A child must close its own direct children before completion; `close` refuses while child records remain.

Both backends implement the same operations:

- launch an interactive Pi child in one tmux window or Zellij tab
- detect liveness
- paste steering into the child pane
- capture its screen
- close its window or tab
- inject one terminal-status notification into its direct parent's pane

Notifications are attempted once per terminal status and managed steering generation. Terminal injection can collide with a draft or dialog, and queued delivery may appear after a manager has already collected or closed the child, so state and result files remain authoritative.

`send` records a steering generation before injecting a wrapped message. It accepts only active children; terminal children must be replaced rather than reactivated outside the global admission path. It uses Pi's follow-up key while the child is active, retries submission without repasting, and confirms either Pi's visible follow-up queue or a durable user message. The helper records `steering-ack` once the message reaches the Pi session; the child is instructed to update its handoff and complete the generation immediately before its next terminal status. Until completion, status is dynamically `steering`, terminal notifications are suppressed, and waits remain pending. This prevents a pre-steering `done` value from being mistaken for completion of the revised assignment. The `queued` response confirms submission, not that the agent has completed the request.

Children use normal Pi skill, extension, and project-trust handling. They retain the invoking user's filesystem and network permissions; multiplexer tabs are not a sandbox.

`wait` and `wait-all` return 0 for done, 1 for failed/exited/stopped, 2 for blocked, and 124 for timeout.

## Backend and session selection

Backend selection precedence is `--backend`, `PI_SUBAGENT_BACKEND`, then the current multiplexer. With both environment markers present, the nearest multiplexer ancestor is preferred.

To force the backend while reusing its current session:

```bash
"$AGENTS" start NAME --backend tmux \
  --model PROVIDER/MODEL --thinking LEVEL -- "TASK"
```

Outside a multiplexer, create the session explicitly and pass its name:

```bash
# tmux
tmux new-session -d -s pi-work
"$AGENTS" start NAME --backend tmux --session pi-work \
  --model PROVIDER/MODEL --thinking LEVEL -- "TASK"

# Zellij
zellij attach --create-background pi-work
"$AGENTS" start NAME --backend zellij --session pi-work \
  --model PROVIDER/MODEL --thinking LEVEL -- "TASK"
```

Without `--backend`, the helper infers a named session only when exactly one installed backend owns an active session with that name. The caller owns session creation, attachment, and deletion; the helper manages only child tabs or windows. `close` deletes the child record, including its result and Pi session trace, after refusing active or hierarchy-owning children; collect required evidence first.
