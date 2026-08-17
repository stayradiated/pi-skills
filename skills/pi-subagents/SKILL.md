---
name: pi-subagents
description: Load this skill whenever the user explicitly mentions a `subagent` or `subagents`, asks to delegate work to a subagent, names the `pi-subagents` skill, or invokes `/skill:pi-subagents`; do not load it based only on task similarity.
compatibility: Requires Bash, Pi, and an active tmux or Zellij session.
---

# Pi subagents

Resolve `scripts/pi-subagents` relative to this file as the absolute path `AGENTS`.

The manager owns decomposition, integration, validation, and the final answer. Each Pi session manages only its direct children; children may start their own children, and all workers share the user's filesystem and permissions.

## Assign and start

Give the child a goal and a checkable completion condition. Include context the child cannot discover itself. Specify write boundaries only when concurrent work could conflict. Include the required handoff: outcome, evidence, changed files, validation, and risks.

Strongly prefer OpenAI Codex GPT-5.6 agents and switch variants per assignment:

- `openai-codex/gpt-5.6-luna` for work that does not require complex decisions, such as lookup, summarization, test execution, and straightforward analysis.
- `openai-codex/gpt-5.6-terra` for any coding or code-modification task; use it as the default implementation agent.
- `openai-codex/gpt-5.6-sol` sparingly, only for difficult architecture, ambiguous trade-offs, or complex reasoning that Luna or Terra is unlikely to resolve.

Do not default every child to Sol. Use the lowest thinking level likely to succeed. If GPT-5.6 is unavailable, use a known compatible model; do not guess model names.

```bash
"$AGENTS" start NAME \
  --model PROVIDER/MODEL \
  --thinking LEVEL -- \
  "GOAL. NON-DISCOVERABLE CONTEXT. CONFLICT WRITE BOUNDARIES. COMPLETION CHECK. HANDOFF."
"$AGENTS" check NAME
```

Use `--cwd DIR` for another existing directory. Outside a multiplexer, pass `--session NAME` for an existing session. `READY=target` means the target exists but no pane is recorded; `READY=ready` means it is addressable. Starts enter the shared project queue and normally return `queued`; the dispatcher changes this to `starting` when capacity is available, then `running` when the child command has started. The state-directory-wide active-leaf limit defaults to 8, is initialized from `PI_SUBAGENT_CONCURRENCY`, and can be inspected or changed with `"$AGENTS" limit [NUMBER]`.

## Continue and steer

```bash
"$AGENTS" check NAME CONTEXT_WINDOW
"$AGENTS" send NAME "CORRECTION WITH EVIDENCE AND ACCEPTANCE CRITERIA"
"$AGENTS" capture NAME 80
```

`send` records a steering generation before injection. While it is incomplete, `check` reports `steering` and `wait` stays pending. Confirm the acknowledgement and revised handoff. Steering is accepted only for an active child; use a fresh child once it is done, blocked, or failed so a completed record cannot bypass the global concurrency limit. At 40% context or more, collect the handoff and use a fresh child.

## Integrate and close

Read the handoff, inspect claimed changes, check scope and conflicts, and validate from the manager session. Treat the handoff as evidence requiring verification.

```bash
"$AGENTS" wait NAME 900
"$AGENTS" close NAME
"$AGENTS" check
```

`close` refuses active children and children that still own agent records, then removes the child's target and state. Collect any result before closing. Finish only when no direct children remain and every handoff is integrated or deliberately rejected.

See [references/PROTOCOL.md](references/PROTOCOL.md) for state and transport semantics, or run `"$AGENTS" help` for the full command surface.
