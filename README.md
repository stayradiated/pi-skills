# @stayradiated/pi-skills

A small collection of skills for the [Pi coding agent](https://pi.dev).

## Skills

- **hone** — stress-test a plan, decision, or idea through a focused interview.
- **pair-review** — walk through local code changes as an interactive, read-only review.
- **pi-zellij-subagents** — spawn observable Pi subagents as tabs in the current Zellij session.

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

The `pi-zellij-subagents` skill requires Pi to already be running inside Zellij, plus Bash and the Zellij CLI.

## License

[MIT](LICENSE)
