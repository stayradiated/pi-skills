---
name: pi-zellij-subagents
description: Delegate bounded research, implementation, testing, or review tasks to observable Pi subagents in Zellij while the manager continues independent work.
compatibility: Requires Pi inside an attached Zellij session, with Bash and the zellij CLI available.
---

# Pi Zellij subagents

Delegate independent, bounded work when delegation is cheaper than doing it directly.

Resolve `scripts/pi-zellij-agents` relative to this file as the absolute path `AGENTS`. Each child runs in a visible `agent-NAME` tab in the current Zellij session.

## Guardrails

- Run at most four direct children concurrently. Children may delegate, but must close their own children before returning.
- Give each child one outcome, an exclusive write scope, and explicit validation.
- Always pass `--model` and `--thinking`; never rely on inherited defaults.
- Use a fresh child for each task. Do not repurpose completed children.
- Do not edit files owned by an active child.
- Continue manager work instead of polling or waiting.
- Treat every handoff as unverified. The manager owns integration and final validation.

## Choose model and thinking

Use the cheapest model and lowest thinking level likely to succeed. Prefer cheaper models for narrow, easily validated work; use stronger models as ambiguity, scope, risk, or weak validation increases. Ensure the model can hold the relevant context.

Use `off` or `minimal` for deterministic edits, `low` for bounded coding, `medium` for multi-step implementation or debugging, and `high` for difficult consequential reasoning. Reserve `xhigh` and `max` for exceptional, narrow tasks.

Increase thinking when the model understands the task but needs deeper analysis. Switch models when it lacks capability, context, or tool reliability. If a child struggles, do not repeat the same prompt: narrow the task, add evidence and acceptance criteria, then start a fresh child.

## Start

State the outcome, context, allowed files, validation, and required report:

```bash
"$AGENTS" start NAME \
  --model PROVIDER/MODEL \
  --thinking LEVEL \
  -- "TASK"
```

Use `--cwd DIR` when the child needs another existing directory.

Example:

```bash
"$AGENTS" start auth-tests \
  --model openai-codex/gpt-5.6-terra \
  --thinking medium -- \
  "Add tests only under tests/auth/. Do not modify application code.
Run the relevant tests. Report changed files, results, and risks."
```

Confirm launch, then resume manager work:

```bash
"$AGENTS" check
```

## Check and steer

The helper notifies the manager on `done`, `blocked`, or `failed`; `check` and result files remain authoritative.

```bash
"$AGENTS" check                         # all children
"$AGENTS" check NAME 272000             # status, context %, and result
"$AGENTS" send NAME "CORRECTION"
```

At 40% context or more, stop extending the assignment. Collect the handoff and use a fresh child for further work.

For missing or questionable results:

```bash
"$AGENTS" capture NAME 80
```

Investigate failures, blockers, scope violations, and missing validation. A timeout alone is not failure.

## Wait only when blocked

Wait only when no useful independent work remains and progress needs a specific result:

```bash
"$AGENTS" wait NAME 900
"$AGENTS" check NAME 272000
```

Use bounded timeouts. Avoid sequential waits; use `wait-all` only for a shared dependency barrier.

## Integrate and close

Inspect the handoff and diff, check scope and conflicts, then validate from the manager session. Do not rely on the child's claims alone.

After handling a terminal child:

```bash
"$AGENTS" close NAME
```

`close` refuses active children. To cancel intentionally, run `stop NAME`, then `close NAME`. Before finishing, run `"$AGENTS" check` and leave no children behind.

See [references/PROTOCOL.md](references/PROTOCOL.md) for protocol details or run `"$AGENTS" help` for all commands.
