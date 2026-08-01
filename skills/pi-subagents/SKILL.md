---
name: pi-subagents
description: Delegate bounded tasks to observable Pi subagents in tmux or Zellij. Use when research, implementation, testing, or review can run independently or in parallel, when the user asks for a subagent, or when another skill needs delegated work.
compatibility: Requires Bash, Pi, and an active tmux or Zellij session.
---

# Pi subagents

Resolve `scripts/pi-subagents` relative to this file as the absolute path `AGENTS`.

The manager owns decomposition, integration, validation, and the final answer. Each Pi session manages only its **direct children**; a child independently owns any children it starts.

## 1. Scope one assignment

Delegate when a task can proceed independently and delegation is cheaper than doing it directly. Define:

- one bounded outcome;
- the context needed to act;
- an exclusive write scope;
- explicit validation;
- the required handoff: outcome, evidence, changed files, validation, and risks.

Active children have exclusive ownership of their write scopes. Use a fresh child for each assignment.

Choose the cheapest model and lowest thinking level likely to succeed: `off` or `minimal` for deterministic edits, `low` for bounded coding, `medium` for multi-step work, and `high` for difficult reasoning.

**Complete when:** the assignment has one outcome, an unambiguous scope, and checkable acceptance criteria.

## 2. Start and confirm

The helper reuses the tmux or Zellij session containing the manager:

```bash
"$AGENTS" start NAME \
  --model PROVIDER/MODEL \
  --thinking LEVEL -- \
  "OUTCOME. CONTEXT. WRITE SCOPE. VALIDATION. REQUIRED HANDOFF."
"$AGENTS" check NAME
```

Use `--cwd DIR` for another existing directory. For backend overrides or invocation outside a multiplexer, follow [Backend and session selection](references/PROTOCOL.md#backend-and-session-selection).

**Complete when:** `start` reports a backend, session, and target, and `check NAME` confirms the child record and live or completed launch.

## 3. Continue, check, and steer

Resume manager-owned work after launch. A child notifies its direct parent on `done`, `blocked`, or `failed`; durable state remains authoritative.

```bash
"$AGENTS" check NAME CONTEXT_WINDOW
"$AGENTS" send NAME "CORRECTION WITH EVIDENCE AND ACCEPTANCE CRITERIA"
"$AGENTS" capture NAME 80
```

At 40% context or more, collect the current handoff and use a fresh child for further work. When a result is the current dependency and no useful independent work remains, wait with a bounded timeout:

```bash
"$AGENTS" wait NAME 900
```

**Complete when:** the child has a terminal status and a durable result, or its blocker has been identified and acted on.

## 4. Integrate and validate

Read the handoff, inspect every claimed change, check scope and conflicts, and run validation from the manager session. Treat the child result as evidence requiring manager verification.

**Complete when:** every claimed change and validation result has been independently accounted for, and manager-tree validation passes.

## 5. Close every direct child

After handling a terminal child:

```bash
"$AGENTS" close NAME
```

`close` preserves hierarchy ownership by refusing active children and children that still own agent records. For intentional cancellation, use `stop NAME`, inspect the retained state, then `close NAME`.

Before reporting the overall task complete:

```bash
"$AGENTS" check
```

**Complete when:** `check` reports no direct children and every collected handoff has been integrated or deliberately rejected.

See [references/PROTOCOL.md](references/PROTOCOL.md) for state and transport semantics, or run `"$AGENTS" help` for the full command surface.
