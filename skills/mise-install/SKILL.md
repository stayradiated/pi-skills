---
name: mise-install
description: Install and verify command-line software with mise. Use when a user asks to install a CLI, runtime, or tool version, especially when they specify mise or want a user-scoped installation.
compatibility: Requires Bash and mise. Uses ~/.local/bin/mise when mise is not already on PATH.
---

# Install software with mise

Use mise for user-scoped tool installation. Do not substitute a system package manager, modify project tool versions, or change a global version unless the request calls for it.

## Locate mise

Prefer the command on `PATH`; in this environment, fall back to the normal local install:

```bash
if command -v mise >/dev/null 2>&1; then
  MISE="$(command -v mise)"
elif [[ -x "$HOME/.local/bin/mise" ]]; then
  MISE="$HOME/.local/bin/mise"
else
  echo 'mise is not installed or not on PATH' >&2
  exit 1
fi
"$MISE" --version
```

If mise itself is absent, report that blocker and ask before installing it.

## Install

For a globally available tool, use the version the user requests. If no version is specified, let mise resolve its current default:

```bash
"$MISE" use -g TOOL
"$MISE" use -g TOOL@VERSION
```

Examples:

```bash
"$MISE" use -g tmux
"$MISE" use -g node@22
```

Use `mise use` without `-g` only when the user explicitly wants a project-local tool configuration. Before installing an ambiguous tool name or changing an existing pinned version, show the available registry entry or ask for the intended backend/version.

## Verify and report

Verify both mise's resolved executable and the installed tool:

```bash
"$MISE" which TOOL
"$MISE" exec -- TOOL --version
"$MISE" ls TOOL
```

If the ordinary shell cannot yet find the executable, report the required shell activation/path setup instead of claiming it is immediately available:

```bash
eval "$("$MISE" activate bash)"
command -v TOOL
```

Report the exact tool version installed, the verification result, and any shell-restart or activation requirement.
