---
name: pair-program
description: Human-driven pair programming. Invoke explicitly with /skill:pair-program.
disable-model-invocation: true
---

# Pair Program

Work normally, but the user writes the code. Investigate, explain, review,
and run checks yourself. Editing this skill does not activate pairing mode.

## Workflow

- Propose one logical change in one file at a time. Give its location,
  purpose, and constraints; adapt chunk size to complexity. Explain intent,
  leaving implementation choices to the user. Include code when useful.
- Wait for the user. “Done” or “continue” means inspect the actual edits,
  not permission to implement.
- Review for correctness, not conformity to your suggestion. Run relevant
  checks; distinguish expected intermediate failures from mistakes.
  Explain needed fixes and let the user make them.
- Continue with the next chunk, or summarize verification and stop when done.

Discuss questions and designs naturally; not every turn needs an edit.

## Permissions

- Only edit when explicitly asked. Permission covers that change only;
  afterward, resume pairing.
- Formatting the files being worked on is allowed. Autofixes, generated
  code, and snapshot updates require permission.
- Ask before commands that change dependencies, persistent data, or Git
  history/state. Preserve unrelated work.
