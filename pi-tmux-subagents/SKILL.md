---
name: pi-tmux-subagents
description: Orchestrates bounded tasks across observable Pi child sessions in tmux, with durable status/result handoffs, steering, optional Git worktrees, and deliberate integration. Use for parallel research, implementation, testing, review, or independent second opinions.
---

# Pi tmux subagents

Delegate bounded work to child Pi sessions in tmux. The manager owns decomposition, integration, verification, and the final answer.

Resolve `scripts/pi-tmux-agents` relative to this loaded `SKILL.md` and store its absolute path as `AGENTS`.

## Rules

1. Give each child one bounded outcome with scope, constraints, evidence, validation, and a done condition.
2. Keep one integrator. Children never merge into the manager branch.
3. Use `--worktree` for any child that can edit or run shell commands. A worktree prevents ordinary working-tree collisions; it is not a security sandbox.
4. Run no more than four children unless the user requests otherwise.
5. Do not permit children to spawn agents unless orchestration is explicitly assigned.
6. Use status and result files as the source of truth. Capture panes only for diagnosis.
7. Review complete diffs and verify claims before integrating.
8. Do not destroy unsummarized work or remove a worktree before its result is handled.

## Start

Run diagnostics once:

```bash
"$AGENTS" doctor
```

Start an implementation child in a dedicated worktree:

```bash
"$AGENTS" start auth-tests --worktree --model sonnet:high -- \
  "Add regression tests for expired refresh tokens. Limit changes to tests and fixtures. Run the narrowest relevant test command. Report changed files, command output, and remaining uncertainty."
```

Start a research child. `bash` lets it write its durable handoff, so isolation is still recommended:

```bash
"$AGENTS" start auth-scout --worktree --tools read,bash,grep,find,ls -- \
  "Map the authentication flow. Do not modify project files. Return key files, data flow, risks, and unanswered questions with evidence."
```

Use complementary assignments rather than repeating one broad prompt.

### Start options

- `--worktree`: create a topic branch and worktree under `~/.pi/agent/tmux-worktrees/`.
- `--cwd DIR`: use an existing directory instead; do not combine with `--worktree`.
- `--model MODEL`, `--provider PROVIDER`, `--thinking LEVEL`: select the child model.
- `--tools LIST`: allowlist Pi tools. Include `bash` or `write` so the child can report status.
- `--no-context`: skip `AGENTS.md` and `CLAUDE.md`.
- `--task-file FILE`: load the task body from a file.
- `--approve-project`: trust project-local Pi resources. Off by default.
- `--inherit-resources`: load discovered extensions and skills. Off by default to reduce side effects and recursive delegation.

Children default to `--no-approve --no-extensions --no-skills`. Enable project trust or inherited resources only when the task needs them and the source is trusted.

## Monitor and steer

```bash
"$AGENTS" status
"$AGENTS" status auth-tests
"$AGENTS" wait auth-tests 900
"$AGENTS" wait-all 1200
"$AGENTS" capture auth-tests 120
"$AGENTS" send auth-tests "Use the existing test factory; do not add another fixture."
```

`wait` and `wait-all` return `0` for done, `2` for blocked, `1` for failed/exited/stopped, and `124` for timeout.

When blocked, read the result and recent capture, make one concrete decision, and send it to the child. Do not busy-loop captures or repeatedly restart without changing the brief or environment.

## Collect and integrate

```bash
"$AGENTS" result auth-tests
"$AGENTS" info auth-tests
agent_dir="$("$AGENTS" info auth-tests --field cwd)"
git -C "$agent_dir" status --short
git -C "$agent_dir" diff --stat
```

Before integration:

1. Read the complete result and diff.
2. Check overlap with other children.
3. Integrate deliberately with a patch, manual edits, or `git cherry-pick`.
4. Run relevant verification in the integrated tree.
5. Record rejected findings when useful.

## Stop and clean

```bash
"$AGENTS" stop auth-tests
"$AGENTS" clean auth-tests                    # retain worktree
"$AGENTS" clean auth-tests --remove-worktree  # remove clean worktree
"$AGENTS" stop-all
"$AGENTS" clean-all                           # retain all worktrees
```

Only clean after results and changes are integrated or intentionally discarded. Git refuses to remove a dirty worktree, preserving unhandled changes.

For state values, file layout, and handoff details, read [references/PROTOCOL.md](references/PROTOCOL.md).
