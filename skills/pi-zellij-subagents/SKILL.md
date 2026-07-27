---
name: pi-zellij-subagents
description: Delegate bounded research, implementation, testing, or review tasks to observable Pi subagents in Zellij while the manager continues independent work.
compatibility: Requires Pi inside an attached Zellij session, with Bash and the zellij CLI available.
---

# Pi Zellij subagents

Use subagents for independent, bounded work when delegation costs less than doing the work directly.

Resolve `scripts/pi-zellij-agents` relative to this file as the absolute path `AGENTS`. Use the current Zellij session. Each child runs in a visible `agent-NAME` tab, and `start` returns the manager to its original tab.

## Rules

- Keep delegation one level deep; children must not spawn agents.
- Run at most four children concurrently.
- Give each child one bounded outcome with explicit validation.
- Assign distinct write scopes. Neither the manager nor another child may edit files assigned to an active child.
- Continue manager-owned work after delegation; do not wait or poll while useful independent work remains.
- Treat every result as an unverified handoff. The manager owns integration, final validation, and cleanup.

## Delegate

Before starting a child, identify its scope and work the manager can do concurrently. Include in the task:

- Expected outcome and relevant context.
- Files or areas it may and must not modify.
- Required validation.
- What its result must report.

```bash
"$AGENTS" start NAME -- "TASK"
```

Use another existing working directory when needed:

```bash
"$AGENTS" start NAME --cwd DIR -- "TASK"
```

Example:

```bash
"$AGENTS" start auth-tests -- \
  "Add authentication tests only under tests/auth/.
Do not modify application code.
Run the relevant tests.
Report changed files, test results, and remaining risks."
```

After starting assignments, confirm they launched, then return to manager-owned work:

```bash
"$AGENTS" status
```

## Collect and steer

The helper notifies the manager when a child reaches `done`, `blocked`, or `failed`. Notifications are advisory; status and result files are authoritative. If no notification has arrived, check status only at a natural work boundary.

```bash
"$AGENTS" status
"$AGENTS" result NAME
```

For missing or questionable results, inspect recent output:

```bash
"$AGENTS" capture NAME 80
```

Send concise correction or unblock information when needed:

```bash
"$AGENTS" send NAME "DECISION OR CORRECTION"
```

Investigate `failed`, `exited`, `stopped`, prolonged `starting`, missing results, scope violations, and absent validation. For `blocked`, inspect the blocker, resolve it if practical, then redirect or stop the child.

When several children are active, collect useful completed work before deciding whether the remainder blocks progress.

## Wait only when blocked

Wait only when the manager has exhausted useful independent work and further progress requires a specific result. Always use a bounded timeout:

```bash
"$AGENTS" wait NAME 900
"$AGENTS" result NAME
```

Do not wait sequentially for every child. Use `wait-all` only when all remaining results form the same dependency barrier. A timeout is not proof of failure; inspect status and output before redirecting or stopping the child.

## Integrate and close

For each accepted handoff:

1. Inspect its findings or diff and confirm scope compliance.
2. Check for conflicts with manager and child work.
3. Run relevant validation from the manager session.
4. Resolve integration issues directly or send a bounded correction.

Do not rely solely on a child's claims about tests or research.

After handling a child, close its tab and remove its state:

```bash
"$AGENTS" stop NAME
"$AGENTS" clean NAME
```

Do not clean before collecting output needed for investigation. Before finishing, run `"$AGENTS" status` and ensure no children remain.

For state and notification semantics, read [references/PROTOCOL.md](references/PROTOCOL.md). For all commands, run:

```bash
"$AGENTS" help
```
