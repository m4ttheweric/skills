# skills

Matt Goodwin's personal Claude Code skills. These are the ones wired to his own
machine, domains, and data: they are published for reference, not for drop-in
reuse. Everything here is scoped under the `matt:` prefix.

The general-purpose companion collection lives at
[m4ttstack/skills](https://github.com/m4ttstack/skills) under the `mattstack:`
prefix, and browser skills ship inside
[Fast Browser](https://github.com/m4ttstack/fast-browser).

## Skills

### infra

- **matt:local-app** ... set up a local web app as a persistent macOS service with HTTPS via portless and launchd. Handles port selection, plist creation, portless routing, and health checks. Every aliased app is automatically public at `https://<name>.m4tthew.dev` through a shared wildcard Cloudflare tunnel, gated by a per-app publish toggle.
- **matt:remote-brainstorm** ... expose the superpowers visual brainstorming companion at `https://brainstorm.m4tthew.dev` through the same tunnel pipeline, so a visual brainstorm can be joined away from the machine running it.
- **matt:run-feedback** ... analyze a run against the training plan with per-mile split breakdown, effort classification, and trend context. Generates data-dense feedback stored in the training app.

### orchestration

- **matt:remote-agent** ... launch a Claude Code agent in a fresh herdr pane under a chosen cswap account and model, in a target repo, with `/remote-control` enabled so it can be continued from a phone or claude.ai/code. The single-shot cousin of `mattstack:shepherdr`.

### workflow

- **matt:matts-writing-style** ... voice, concision, and formatting rules for MR descriptions, MR comments, commit messages, and technical writing posted under Matt's name.

## Install

Symlink each skill directory into `~/.claude/skills/`, named with its prefix:

```bash
ln -s ~/Documents/GitHub/matt-skills/skills/infra/local-app ~/.claude/skills/matt:local-app
ln -s ~/Documents/GitHub/matt-skills/skills/infra/remote-brainstorm ~/.claude/skills/matt:remote-brainstorm
ln -s ~/Documents/GitHub/matt-skills/skills/infra/run-feedback ~/.claude/skills/matt:run-feedback
ln -s ~/Documents/GitHub/matt-skills/skills/orchestration/remote-agent ~/.claude/skills/matt:remote-agent
ln -s ~/Documents/GitHub/matt-skills/skills/workflow/matts-writing-style ~/.claude/skills/matt:matts-writing-style
```

The prefix is asserted in two places per skill: the symlink name above and the
`name:` field in that skill's `SKILL.md` frontmatter. They have to agree.

## Dependencies

`matt:remote-agent` needs [herdr](https://github.com/ogulcancelik/herdr) and
[claude-swap](https://github.com/m4ttheweric/claude-swap).
`matt:remote-brainstorm` needs the superpowers brainstorming companion and the
portless pipeline that `matt:local-app` documents.
