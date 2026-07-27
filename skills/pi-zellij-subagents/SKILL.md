---
name: pi-zellij-subagents
description: Delegate bounded research, implementation, testing, or review tasks to observable Pi subagents in Zellij while the manager continues independent work.
compatibility: Requires Pi inside an attached Zellij session, with Bash and the zellij CLI available.
---

# Pi Zellij subagents

Use observable Pi subagents when work can be split into independent, bounded assignments.

Resolve `scripts/pi-zellij-agents` relative to this file as the absolute path `AGENTS`. Use the current Zellij session. Each subagent runs in a visible `agent-NAME` tab, and the manager returns to its original tab after starting an agent.

## Operating model

Delegation is asynchronous:

1. Start bounded assignments.
2. Continue independent manager work.
3. Check agents at natural work boundaries.
4. Collect completed results as they become useful.
5. Wait only when a specific result blocks further progress.

Starting an agent is not a reason to wait. Agent completion is not itself a dependency barrier.

## Constraints

* Keep delegation one level deep; subagents must not create subagents.
* Run at most four subagents concurrently.
* Give each agent one bounded outcome with explicit validation criteria.
* Assign distinct write scopes. Agents must not edit the same files concurrently.
* The manager must not edit files assigned to an active agent.
* Do not delegate when coordination costs more than doing the work directly.
* Treat every result as an unverified handoff.
* The manager owns integration, final validation, and cleanup.

## Plan and delegate

Before starting agents, identify:

* Independent assignments for subagents.
* Work the manager can perform while they run.
* Specific dependency barriers that may eventually require a result.

For each assignment, specify:

* A short, unique name.
* Exact scope and expected outcome.
* Files or areas it may and must not modify.
* Required validation.
* What the result must report.

Start an assignment:

```bash
"$AGENTS" start NAME -- "TASK"
```

Use another existing directory when necessary:

```bash
"$AGENTS" start NAME --cwd DIR -- "TASK"
```

Tasks must be self-contained. Include relevant context, constraints, expected output, and validation criteria.

```bash
"$AGENTS" start auth-tests -- \
  "Add authentication tests only under tests/auth/.
Do not modify application code.
Run the relevant test command.
Report changed files, test results, and remaining risks."
```

After starting assignments, confirm their tabs and investigate any startup failure:

```bash
"$AGENTS" status
```

Then return to manager-owned work. Do not call `wait` merely because agents are running.

## Work asynchronously

While agents run, continue any work that does not touch their assigned files or depend on their results. Examples include:

* Inspecting shared context or unaffected code.
* Preparing integration points.
* Defining final validation commands.
* Resolving unrelated design decisions.
* Checking repository state.
* Verifying agents that finish early.

At a natural work boundary, check status once:

```bash
"$AGENTS" status
```

Do not repeatedly poll, idle, or block while useful independent work remains.

For a completed agent, collect its handoff:

```bash
"$AGENTS" result NAME
```

When an agent needs investigation or correction, inspect its result and recent output:

```bash
"$AGENTS" result NAME
"$AGENTS" capture NAME 80
```

Send concise direction only when needed:

```bash
"$AGENTS" send NAME "DECISION OR CORRECTION"
```

Investigate `failed`, `exited`, `stopped`, or prolonged `starting` states. For `blocked`, inspect the reported blocker, resolve it if practical, then redirect or stop the agent. Also investigate missing results, out-of-scope work, and absent validation evidence.

When several agents are active, collect and reconcile finished work before considering whether to block on the remainder.

## Wait only at a dependency barrier

A blocking wait is allowed only when all of these are true:

* The manager has exhausted useful independent work.
* Further progress requires a particular agent result.
* The wait has a bounded timeout.

```bash
"$AGENTS" wait NAME 900
```

Do not wait sequentially for every agent. Do not use `wait-all` unless all remaining agents jointly form the same dependency barrier.

After a wait returns, inspect status and collect the result:

```bash
"$AGENTS" status
"$AGENTS" result NAME
```

A timeout is not proof of failure. Inspect the agent before redirecting or stopping it.

## Verify and integrate

For every result the manager accepts:

1. Inspect the reported changes or findings.
2. Confirm the agent stayed within scope.
3. Check for conflicts with manager or agent work.
4. Run relevant validation from the manager session.
5. Resolve integration issues directly or send a bounded correction.
6. Retain concrete validation evidence for the final response.

Do not rely solely on an agent's claim that tests passed. Inspect implementation diffs, and verify important research or review claims against their sources.

## Close handled agents

After collecting and handling an agent's result, close its tab and remove its stored state:

```bash
"$AGENTS" stop NAME
"$AGENTS" clean NAME
```

Do not clean an agent before collecting output needed for investigation.

After all accepted work is integrated, verify cleanup:

```bash
"$AGENTS" status
```

All child tabs must be closed, no agents may remain active, required results must be collected, failures must be investigated, and status must report no agents.

For state semantics and stored files, consult [references/PROTOCOL.md](references/PROTOCOL.md). For the complete command reference, run:

```bash
"$AGENTS" help
```
