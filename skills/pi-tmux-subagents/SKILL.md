---
name: pi-tmux-subagents
description: Delegates bounded tasks to observable Pi child sessions in tmux with durable results, steering, Git worktrees, deliberate integration, and optional pi-tag-slack check-ins. Use for parallel research, implementation, testing, or review outside Zellij.
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

Monitor and collect the durable handoff. Continue manager-owned work first; only wait when a result is the current dependency:

```bash
"$AGENTS" status
"$AGENTS" wait NAME 900
"$AGENTS" result NAME
```

## Optional Slack check-in

When the manager will be unavailable or has no useful independent work, schedule one **one-time** check-in rather than polling. This creates a durable task that a recovered Pi session can act on; it does not directly control a child.

First choose an explicit UTC time, then schedule an instruction that names the agents and required follow-up:

```bash
check_at="$(date -u -d '+15 minutes' '+%Y-%m-%dT%H:%M:%SZ')"
pi-tag-slack schedule add \
  --title "Review tmux subagents" \
  --at "$check_at" \
  --instructions 'Run /absolute/path/to/pi-tmux-agents status and result NAME. Inspect the child diff, validate it in the manager tree, then stop and clean the child. Report any blocker.'
```

Use a recurring schedule only when the user explicitly asks for repeated follow-up. Include an IANA timezone, and remove it once it is no longer needed:

```bash
pi-tag-slack schedule add --title "Subagent review" \
  --cron '*/15 * * * *' --timezone 'UTC' \
  --instructions 'Inspect active tmux subagents and act on completed results.'
pi-tag-slack schedule remove SCHEDULE_ID
```

Never schedule a check-in as a substitute for integration or leave recurring schedules behind unintentionally.

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
