# MR Writing Style

> Scope: Writing style for GitLab MR descriptions. Apply when drafting or editing an MR description.

When drafting or updating an MR description, follow the house style below. Default to **Template-Preserving** unless the change is a tiny one-liner with a clear screenshot payload.

Cross-rule: never use em dashes (`—`) or en dashes (`–`). See `no-em-dashes.md`. Use ellipses (`...`), parens, or rephrase.

## Length target

Aim for **150-250 words above the checklist**, including the framing paragraph and bullets. Bias short. If the body creeps past 300 words, re-read and cut.

Reference: strong teammate MRs sit around 200 words, and so do the user's own. If your draft is double that, you have padding to remove.

## Structure (default)

```markdown
## <short value-first title for the work>

<one or two short framing sentences. plain english. what this MR does and why.>

### What changed

**<Bold subsection label 1>** (optional path or scope)

- <one-clause bullet>
- <one-clause bullet>

**<Bold subsection label 2>**

- <one-clause bullet>
- <one-clause bullet>

**Also** (optional, for orthogonal changes worth calling out)

- <one-line bullet>
- <one-line bullet>

### Follow-up (optional)

- <one-line bullet pointing at the descope / related ticket>
- <one-line bullet>

---

**Checklist**

- [x] Anything that [should be behind a feature flag](...) is behind a feature flag
  - N/A. <one-line reason> (or list the flag if applicable)
- [x] Appropriate tests have been created or updated
  - <N new tests across <file/suite>; full <scope> suite M/M green.>

---

**Verification Evidence**

_Attach screenshots, screen recordings, links, or any other evidence that you've tested locally and the changes are working_

<one sentence citing a specific case ID + the observable behavior verified.>

- <preview URL 1>
- <preview URL 2>

**Preview Testing**

- [ ] a [preview environment](...) is available for QA testing
```

## Rules for bullets

- **One clause per bullet.** No multi-sentence explanations, no parenthetical paragraphs, no "by design" / "ensures" / "in order to" doc-voice. If you can split a bullet into two, you probably should.
- **Action-first** when starting the bullet: `Adds`, `Fixes`, `Removes`, `Reduces`, `Tightens`, `Extracts`, `Migrates`, `Renames`. Lowercase-fragment form (`adds ...`) is also fine for tiny changes.
- **Reference files/symbols in backticks** (`cartTotals.ts`, `isValidQuantity`). Don't paste code blocks of source.
- **Skip the why** when the diff makes it obvious. Reviewers can read the code. Save the "why" for non-obvious tradeoffs or for the framing paragraph.
- **Nested bullets only when necessary.** Default to flat. Nest only if a sub-point genuinely doesn't fit on the parent line.

## Rules for subsection labels

- Use **bold inline labels** (not `####` headings) under `### What changed`.
- Typical labels: name them after what's grouped, not after structure. `Helpers`, `Wiring`, `GraphQL`, `Also`, `Deleted` are all good. Avoid generic ones like "Code Changes" or "Implementation Details".
- 2-4 subsections is the sweet spot. If you have 1 you don't need them; if you have 5+ the MR is probably too big.
- An optional path or scope hint in parens after the label is helpful: `**Helpers** (`src/cart/.../helpers/`)`.

## Rules for the "Also" / "Follow-up" sections

- **Also**: orthogonal in-MR changes (renames, drive-by fixes, cosmetic patches) that reviewers should know about but aren't the main work. One line each. Don't promote to its own heading.
- **Follow-up**: descopes, related tickets, known limitations the reviewer should be aware of. One line each. Skip the section entirely if there's nothing to say.
- If the **Also** or **Follow-up** sections are growing past 3 bullets each, you have padding. Cut.

## Rules for Verification Evidence

- One sentence with a **specific case ID** and the observable behavior verified. Generic statements ("manually tested locally") are insufficient.
- A screenshot or Loom is great when available. Skip prose if you have an image.
- **No Jest output dumps.** "27 new tests; full cart suite 319/319 green" is plenty.
- Preview URLs go in a flat bullet list. Use markdown link form (`[url](url)`) so they render clickable in GitLab.

## Don't

- Don't use em dashes (`—`) or en dashes (`–`). See `no-em-dashes.md`.
- Don't restate the ticket AC verbatim. Link the ticket via the title (`ABC-1483: ...`).
- Don't write framing paragraphs longer than 2 sentences.
- Don't add multi-sentence bullets with parenthetical paragraphs.
- Don't add a "Drive-by polish (call out for review)" theatrical heading. Just put it under `**Also**`.
- Don't leave TODO/placeholder sections.
- Don't include giant code fences of diff or test logs.
- Don't mix the two styles (Template-Preserving and Minimal). Pick one.

## Anti-patterns I have fallen into

- Leading with a verbose "Renders one section per order type under the checkout panel, slotted between Shipping and Payment. Titles match the legacy app's `getSectionLayout.ts`..." style sentence. Cut to: "Adds a section per order type under Checkout, sourced from the orders API. Titles match the legacy app's `getSectionLayout.ts`."
- Compound bullets like: "Adds `foo.ts` which does X. The static maps are keyed by Y and the resolver does Z (general-first / other-second order, dedupe by title with module-key union, GIFT_CARD excluded)." Cut to: "`foo.ts`: map plus resolver."
- "Drive-by polish (call out for review)" subsection with three paragraphs of justification. Cut to a single bullet under `**Also**`.
- Adding cookie-cutter "follow-up" sub-bullets that just rephrase what's already in linked tickets. If ABC-1915 covers a follow-up, the bullet is `ABC-1915 covers X surfaced during verification.` One line.
- Multi-paragraph Verification Evidence prose. One sentence with the case ID, then the URLs.

## Minimal style

Only when the change is trivially small and a screenshot carries the explanation. Strip the template entirely:

```markdown
- <lowercase sentence fragment describing the change>
- <optional second bullet>

![image](/uploads/.../image.png){width=... height=...}
```
