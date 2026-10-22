# @stayradiated/pi-skills

A small collection of skills for the [Pi coding agent](https://pi.dev).

## Skills

- [**hone**](skills/hone/SKILL.md) — stress-test a plan, decision, or idea through a focused interview.
- [**pair-review**](skills/pair-review/SKILL.md) — walk through local code changes as an interactive, read-only review.
- [**pair-program**](skills/pair-program/SKILL.md) — human-driven pair programming: the agent navigates in small steps and reviews your edits without taking over.
- [**pi-subagents**](skills/pi-subagents/SKILL.md) — delegate observable Pi subagents through one interface for tmux and Zellij.

## Install

From npm:

```bash
pi install npm:@stayradiated/pi-skills
```

Or directly from GitHub:

```bash
pi install git:github.com/stayradiated/pi-skills
```

Restart Pi or run `/reload`, then invoke a skill with `/skill:<name>`. Pi may also load skills automatically when relevant.

## Development

Install the local checkout and run the tests:

```bash
pi install "$PWD"
npm test
```

Use `npm pack --dry-run` to inspect the files included in the npm package.

The `pi-subagents` skill requires Bash, `flock`, Pi, and tmux or Zellij. It reuses the current multiplexer session; from outside one, create a session and pass `--session NAME`. See its [README](skills/pi-subagents/README.md) for details.

## License

[MIT](LICENSE)
