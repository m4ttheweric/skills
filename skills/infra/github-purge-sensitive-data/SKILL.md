---
name: matt:github-purge-sensitive-data
description: "Use when data that should not be public reached a GitHub repo and history has been (or must be) rewritten: 'scrub it from GitHub', 'purge the cached commit', 'GitHub still serves the old sha', 'file a support request to remove sensitive data', or a force-push that removed a file but github.com/<owner>/<repo>/commit/<sha> still loads."
---
# GitHub sensitive-data purge request

A history rewrite removes data from branches and tags, but GitHub keeps the
old commits reachable by sha (pull request refs, cached views) until GitHub
Support dereferences them and runs a garbage collection. This skill files
that free-form support ticket through a Haiku Fast Browser subagent.

## 1. Before filing

- A leaked credential is rotated or revoked first; Support acts only when
  rotating cannot remove the risk.
- The rewrite is pushed. From a checkout with fresh refs
  (`git fetch origin --prune --tags`):

| Check | Expect |
|-------|--------|
| `git branch -r --contains <sha>` | nothing (else rewrite or delete it first) |
| `git tag --contains <sha>` | nothing (else re-point the tag first) |
| `gh api repos/<owner>/<repo>/commits/<sha> --jq .sha` | still the sha: what the ticket removes |

- No open ticket already covers it: `https://help.github.com/support/tickets`.
  If one names the same repo and shas, comment there instead.
- Collect full 40-character shas (the commit that added the data, and every
  old commit built on it that a tag or pull request pointed at), the file
  paths, and the affected pull request numbers, open or closed.

## 2. File the ticket

Fill [brief.md](brief.md) and dispatch it with the Agent tool:

- `subagent_type`: `fast-browser:browser-driver`
- `model`: `haiku`
- `effort`: `medium`
- `prompt`: the filled brief, verbatim

The brief carries the whole form route. The ticket names shas, paths and PR
numbers only: never a secret's value, an employer name or an internal
ticket id.

## 3. Confirm

It is filed only when the ticket page (`help.github.com/ticket/...`) shows
the subject and a sha. A returned question gets its answer through
SendMessage to the same agent. Anything else unfinished: dispatch again with
what its report learned, or finish the last steps yourself with the Fast
Browser MCP tools, following brief.md's steps.

## Common mistakes

| Mistake | Instead |
|---------|---------|
| Treating the last form page as empty (it shows no subject or body) | brief.md step 5: the answers sit in `sessionStorage`; check, then submit |
| Filing before every branch and tag is clean | Support assumes only `refs/pull/*` still hold the data |
| Pasting the leaked text to "show" what to remove | Shas and paths only |
