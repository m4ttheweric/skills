# MR Writing Style

> Scope: Writing style for GitLab MR descriptions. Apply when drafting or editing an MR description.

The repo's own MR template is the structure of every MR description. This
file covers what goes into it: which boxes to tick, and how the prose reads.

Cross-rule: never use em dashes (`—`) or en dashes (`–`). See `no-em-dashes.md`. Use ellipses (`...`), parens, or rephrase.

## The template is the skeleton

Before drafting, read the repo's MR template: `.gitlab/merge_request_templates/Default.md`
on GitLab, `.github/pull_request_template.md` on GitHub, or the one the
repo's AGENTS.md names. Start from a copy of it and fill it in:

- Every heading, `---` divider, italic helper line, link, checkbox and
  trailing note stays where the template put it, in the template's order.
- Your content replaces only the empty placeholders: a bare `-` bullet, or
  the blank space under a heading's helper line.
- A repo with no template gets the fallback at the bottom of this file.

## Checklist boxes are attestations

A ticked box is a claim you did the thing. Tick exactly these, and leave
every other box unticked for the developer:

| Box | Tick it when |
|---|---|
| "should be behind a feature flag" | Always, when the change adds no flag: nothing needed gating. When it adds one, tick it once the new behavior sits behind that flag. |
| "all values of the feature flag have been tested" (the child box) | Always, when the change adds no flag: with one code path, the verification evidence covers every value. When it adds one, tick it only if your evidence shows every value. |
| "appropriate tests have been created or updated" | You wrote or updated tests. Add one sub-bullet: the count and the suite result (`12 new tests; full cart suite 319/319 green`). |
| Preview environment, and every preview e2e option | Never yours to tick. Leave them all unticked, including "not run because": only the developer can attest a preview was tested and how its e2es ran. |

## Length target

Aim for **150-250 words above the checklist**, including the framing paragraph and bullets. Bias short. If the body creeps past 300 words, re-read and cut.

Reference: strong teammate MRs sit around 200 words, and so do the user's own. If your draft is double that, you have padding to remove.

## Filling the What section

Under the template's helper line: one or two framing sentences (what this
MR does and why, plain english), then bullets. Group bullets under bold
labels when there is more than one area of change:

```markdown
## What

_List high-level changes included in this work and why they were necessary_

Adds a refund reason picker so support can tag why an order was refunded. Reasons feed the weekly refunds report.

**Picker** (`src/orders/refunds/`)

- Adds `RefundReasonSelect` with the five reasons from the report spec
- Requires a reason before `RefundDialog` submits

**Also**

- Renames `refundNote` to `refundComment` in the dialog state

**Follow-up**

- ABC-1915 covers backfilling reasons on past refunds
```

## Rules for bullets

- **One clause per bullet.** No multi-sentence explanations, no parenthetical paragraphs, no "by design" / "ensures" / "in order to" doc-voice. If you can split a bullet into two, you probably should.
- **Action-first** when starting the bullet: `Adds`, `Fixes`, `Removes`, `Reduces`, `Tightens`, `Extracts`, `Migrates`, `Renames`. Lowercase-fragment form (`adds ...`) is also fine for tiny changes.
- **Reference files/symbols in backticks** (`cartTotals.ts`, `isValidQuantity`). Don't paste code blocks of source.
- **Skip the why** when the diff makes it obvious. Reviewers can read the code. Save the "why" for non-obvious tradeoffs or for the framing paragraph.
- **Nested bullets only when necessary.** Default to flat. Nest only if a sub-point genuinely doesn't fit on the parent line.

## Rules for subsection labels

- Use **bold inline labels** (not `####` headings) inside the What section.
- Typical labels: name them after what's grouped, not after structure. `Helpers`, `Wiring`, `GraphQL`, `Also`, `Deleted` are all good. Avoid generic ones like "Code Changes" or "Implementation Details".
- 2-4 subsections is the sweet spot. If you have 1 you don't need them; if you have 5+ the MR is probably too big.
- An optional path or scope hint in parens after the label is helpful: `**Helpers** (`src/cart/.../helpers/`)`.

## Rules for the "Also" / "Follow-up" labels

- **Also**: orthogonal in-MR changes (renames, drive-by fixes, cosmetic patches) that reviewers should know about but aren't the main work. One line each.
- **Follow-up**: descopes, related tickets, known limitations the reviewer should be aware of. One line each. Skip the label entirely if there's nothing to say.
- Both are the last labels in the What section, never sections of their own. Past 3 bullets each, you have padding. Cut.

## Rules for Verification Evidence

Under the template's helper line:

- One sentence with a **specific case ID** and the observable behavior verified. Generic statements ("manually tested locally") are insufficient.
- Then the evidence: the uploaded image or video embed, a Loom, or preview URLs as a flat list of markdown links (`[url](url)`) so they render clickable.
- **No test output dumps.** Test counts live on the tests checkbox.

## Don't

- Don't use em dashes (`—`) or en dashes (`–`). See `no-em-dashes.md`.
- Don't restate the ticket AC verbatim. Link the ticket via the title (`ABC-1483: ...`).
- Don't write framing paragraphs longer than 2 sentences.
- Don't add multi-sentence bullets with parenthetical paragraphs.
- Don't add a "Drive-by polish (call out for review)" theatrical heading. Just put it under `**Also**`.
- Don't include giant code fences of diff or test logs.

## Anti-patterns I have fallen into

- Leading with a verbose "Renders one section per order type under the checkout panel, slotted between Shipping and Payment. Titles match the legacy app's `getSectionLayout.ts`..." style sentence. Cut to: "Adds a section per order type under Checkout, sourced from the orders API. Titles match the legacy app's `getSectionLayout.ts`."
- Compound bullets like: "Adds `foo.ts` which does X. The static maps are keyed by Y and the resolver does Z (general-first / other-second order, dedupe by title with module-key union, GIFT_CARD excluded)." Cut to: "`foo.ts`: map plus resolver."
- "Drive-by polish (call out for review)" subsection with three paragraphs of justification. Cut to a single bullet under `**Also**`.
- Adding cookie-cutter "follow-up" sub-bullets that just rephrase what's already in linked tickets. If ABC-1915 covers a follow-up, the bullet is `ABC-1915 covers X surfaced during verification.` One line.
- Multi-paragraph Verification Evidence prose. One sentence with the case ID, then the URLs.

## Fallback: a repo with no MR template

Only when the repo has no template at all:

```markdown
<one or two framing sentences: what this MR does and why>

### What changed

**<Bold label>**

- <one-clause bullet>

### Verification

<one sentence with a specific case ID and the observed behavior, then the evidence>
```

No checklist here: there is nothing for you to attest.
