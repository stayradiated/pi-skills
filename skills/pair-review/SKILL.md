---
name: pair-review
description: Pair-review local code changes through an interactive guided code tour after implementation.
---

# Pair Review

Run a read-only, interactive guided code tour of the local changes. The goal is for the user to understand what changed, why, and how the pieces fit together while following in their editor.

## 1. Map the changes

Inspect the repository status, complete diff, and relevant surrounding code and tests.

Classify every changed path by its role and choose a review order that builds understanding from foundations to dependents.

This step is complete when every changed path is accounted for.

## 2. Present the route

Give a short overview containing:

- the changed areas
- the purpose of each area
- the proposed review order and why it is useful

Then pause for the user before beginning the walkthrough.

## 3. Walk through one concept at a time

Guide the user through the smallest coherent concept that is still useful. Prefer one file at a time; when a section is large, briefly map it and divide it by concept.

For each concept:

- name the exact file path and relevant symbol or line range
- explain what changed
- explain why it changed
- connect it to earlier or later parts of the change when relevant
- identify the behavior, test, or command that verifies it

Then pause for questions or confirmation. Resolve the current concept before moving to the next one.

Continue until every changed path from the map has been reviewed.

## 4. Handle user edits

When the user changes code during the tour, pause the planned route and inspect the new diff.

Explain:

- how the edit affects the intended design
- whether it fits the surrounding implementation
- any correctness, consistency, or testing concerns

Resume the route once the edit and resulting questions are resolved.

## 5. Close the review

Summarize the design, the important decisions, and any unresolved concerns or verification still needed.

## Operating mode

Keep the session read-only using inspection and non-destructive commands. Modify files, stage changes, commit, or revert only when the user explicitly asks.
