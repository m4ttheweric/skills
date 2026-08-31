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

- **matt:remote-brainstorm** ... expose the superpowers visual brainstorming companion at `https://brainstorm.m4tthew.dev` through the same tunnel pipeline, so a visual brainstorm can be joined away from the machine running it.
- **matt:run-feedback** ... analyze a run against the training plan with per-mile split breakdown, effort classification, and trend context. Generates data-dense feedback stored in the training app.

### orchestration

- **matt:remote-agent** ... launch a Claude Code agent in a fresh herdr pane under a chosen cswap account and model, in a target repo, with `/remote-control` enabled so it can be continued from a phone or claude.ai/code. The single-shot cousin of `mattstack:shepherdr`.

### workflow

- **matt:matts-writing-style** ... voice, concision, and formatting rules for MR descriptions, MR comments, commit messages, and technical writing posted under Matt's name.
- **matt:wrap-up** ... go through important details, open decisions, and next steps as a form. Uses the current runtime's question tool, or a numbered chat form if the runtime has none.
- **matt:process-digraphs** ... write a Graphviz `digraph` process flowchart for a SKILL.md. Covers the shape vocabulary (diamond, box, plaintext, octagon, doublecircle), the sentence-as-node-id house style, bounded loops with breakers, and the mandatory `dot` render before it ships.

## Install

Symlink each skill directory into `~/.claude/skills/`, named with its prefix:

```bash
ln -s ~/Documents/GitHub/matt-skills/skills/infra/remote-brainstorm ~/.claude/skills/matt:remote-brainstorm
ln -s ~/Documents/GitHub/matt-skills/skills/infra/run-feedback ~/.claude/skills/matt:run-feedback
ln -s ~/Documents/GitHub/matt-skills/skills/orchestration/remote-agent ~/.claude/skills/matt:remote-agent
ln -s ~/Documents/GitHub/matt-skills/skills/workflow/matts-writing-style ~/.claude/skills/matt:matts-writing-style
ln -s ~/Documents/GitHub/matt-skills/skills/workflow/wrap-up ~/.claude/skills/matt:wrap-up
ln -s ~/Documents/GitHub/matt-skills/skills/workflow/process-digraphs ~/.claude/skills/matt:process-digraphs
```

The prefix is asserted in two places per skill: the symlink name above and the
`name:` field in that skill's `SKILL.md` frontmatter. They have to agree.

## Claude Code config

`claude/` holds the non-skill Claude Code files that are tracked here and
symlinked into `~/.claude/`:

- **statusline-command.sh** ... the status line: model and effort, account
  (via cswap), the Fable weekly pool (F, from cswap's store), weekly usage (W)
  and context (C), and rt chat presence. `settings.json` points at the
  `~/.claude` path, so the symlink is what keeps it live.

```bash
ln -s ~/Documents/GitHub/matt-skills/claude/statusline-command.sh ~/.claude/statusline-command.sh
```

## Dependencies

`matt:remote-agent` needs [herdr](https://github.com/ogulcancelik/herdr) and
[claude-swap](https://github.com/m4ttheweric/claude-swap).
`matt:remote-brainstorm` needs the superpowers brainstorming companion and the
portless / Deck pipeline (documented by the deck repo's `deck:add-app` skill).
