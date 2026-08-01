# @stayradiated/pi-skills

A small collection of skills for the [Pi coding agent](https://pi.dev).

## Skills

- **hone** — stress-test a plan, decision, or idea through a focused interview.
- **pair-review** — walk through local code changes as an interactive, read-only review.
- **pi-subagents** — delegate observable Pi subagents through one interface for tmux and Zellij.
- **mise-install** — install and verify user-scoped command-line software with mise.

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

The `pi-subagents` skill requires Bash, Pi, and an active tmux or Zellij session. The `mise-install` skill requires mise.

## License

[MIT](LICENSE)
