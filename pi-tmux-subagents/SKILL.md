---
name: pi-tmux-subagents
description: Delegates bounded tasks to observable Pi child sessions in tmux with durable results, steering, Git worktrees, and deliberate integration. Use for parallel research, implementation, testing, or review.
---

# Pi tmux subagents

Resolve `scripts/pi-tmux-agents` relative to this file as `AGENTS`.

The manager owns task decomposition, review, integration, verification, and the final answer. Give each child one bounded outcome with clear scope and validation. Use no more than four children unless asked, and do not allow recursive delegation.

## Run

Use a worktree for children that can edit or run shell commands:

```bash
"$AGENTS" start NAME --worktree -- "TASK"
```

For a specific existing directory, use `--cwd DIR` instead.

Monitor and collect the durable handoff:

```bash
"$AGENTS" status
"$AGENTS" wait NAME 900
"$AGENTS" result NAME
```

If blocked, inspect and steer:

```bash
"$AGENTS" capture NAME 80
"$AGENTS" send NAME "DECISION OR CORRECTION"
```

For worktree children, inspect the full diff before integrating:

```bash
child_dir="$("$AGENTS" info NAME --field cwd)"
git -C "$child_dir" status --short
git -C "$child_dir" diff
```

A child result is not proof. Integrate deliberately and validate in the manager tree.

After handling all work:

```bash
"$AGENTS" stop NAME
"$AGENTS" clean NAME                    # retain worktree
"$AGENTS" clean NAME --remove-worktree  # remove clean worktree
```

Never remove a worktree with unhandled changes. Use `"$AGENTS" help` for other commands and [references/PROTOCOL.md](references/PROTOCOL.md) for status semantics.
