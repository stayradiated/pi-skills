# Pi tmux subagent protocol

## State layout

The controller stores state under `.pi/tmux-subagents/` by default:

```text
.pi/tmux-subagents/
├── swarm.env
├── agents/
│   └── <name>/
│       ├── status
│       ├── task.md
│       ├── prompt.md
│       ├── result.md
│       ├── failure.md
│       ├── cwd
│       ├── branch
│       ├── tmux-target
│       ├── started-at
│       └── session/
```

Worktrees are stored separately by default:

```text
~/.pi/agent/tmux-worktrees/<project-hash>/
└── <name>/
```

The state root can be overridden with `PI_TMUX_STATE_DIR`. The worktree root can be overridden with `PI_TMUX_WORKTREES_DIR`. The tmux session name can be overridden with `PI_TMUX_SESSION`. Agent names are normalized to lowercase letters, numbers, hyphens, and underscores, and are limited to 63 characters.

## Status values

- `starting`: state exists but Pi has not begun.
- `running`: the child is actively working or ready for steering.
- `blocked`: the child needs a decision, missing information, or external intervention.
- `done`: a complete handoff has been atomically written to `result.md`.
- `failed`: the child deliberately reported failure or its runner exited unexpectedly.
- `stopped`: the manager stopped the tmux window.
- `exited`: the tmux window disappeared before a terminal status was recorded.

The controller reports `exited` dynamically when a child is marked `starting` or `running` but its tmux window no longer exists.

## Child startup defaults

Children start with `--no-approve --no-extensions --no-skills`. This avoids executing project-local Pi resources and reduces global extension side effects or recursive skill use. Use `--approve-project` and `--inherit-resources` explicitly when trusted work requires them. Context files still load unless `--no-context` is supplied.

The controller stores an exact tmux window ID rather than a window name, so duplicate display names do not misroute capture, steering, or stop operations.

## Child completion contract

Every child prompt includes the following contract:

1. Work only on the assigned task and within the assigned working directory.
2. Keep status at `running` while working.
3. If blocked, write an explanation to `result.md`, then atomically set status to `blocked`.
4. If successful, write `result.md` completely, then atomically set status to `done`.
5. If unsuccessful, write `failure.md` and any useful partial handoff, then atomically set status to `failed`.
6. Remain in the Pi session after reporting so the manager or user can inspect and steer it.

Atomic status update example:

```bash
printf '%s\n' done > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"
```

## Result format

Children should use this structure:

```markdown
# Result

## Outcome
One-paragraph statement of what was accomplished or concluded.

## Evidence
- Important files and line ranges inspected.
- Commands run and their outcomes.
- Relevant assumptions.

## Changes
- Files changed and why, or “None”.
- Branch/commit information when applicable.

## Validation
- Tests, checks, or independent reasoning performed.
- Anything not validated.

## Risks and open questions
- Remaining uncertainty, edge cases, conflicts, or follow-up work.

## Handoff
Exact next step for the manager.
```

## tmux messaging

The controller uses a tmux paste buffer followed by a separate Enter keystroke. This avoids shell interpolation and is more reliable than embedding arbitrary text directly in `send-keys`. Commands are addressed to the exact stored tmux window ID.

A manager should use `send` for meaningful steering, not constant status requests. Durable files are the primary communication channel; tmux is the live control plane.

## Concurrency and isolation

- Durable reporting requires `bash` or `write`. A research-only child with either tool should normally use a worktree to reduce accidental working-tree collisions.
- A Git worktree prevents ordinary Git working-tree collisions, but it is not a security boundary; shell-capable children can still access other filesystem paths.
- The manager is responsible for detecting overlapping edits before integration.
- Worktree creation does not install dependencies or copy ignored build artefacts. Project-specific setup may be needed after `start`.
