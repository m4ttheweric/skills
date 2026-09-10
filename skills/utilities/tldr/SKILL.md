---
name: matt:tldr
description: "Use when the user says 'tldr' or 'tl;dr' after a response, or asks to shorten, simplify, or redo the prior answer in plain language."
---

# tldr

Redo the previous turn's response only. Don't re-run tool calls, re-derive
new information, or answer a different question -- restate the same answer,
shorter and plainer.

## Rewrite rules

- **Cut the weeds.** Drop caveats, hedging, and detail that wouldn't change
  what the user does next.
- **Plain language.** No jargon, no unexplained acronyms, no internal
  tool/file names unless the user needs them to act.
- **Keep the conclusion.** tldr trims words, it doesn't change the answer or
  soften a recommendation into a menu of options.
- **Short.** A few sentences or a tight list -- not a restructured essay.
