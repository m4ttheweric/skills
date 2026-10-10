---
name: matt:github-purge-sensitive-data
description: "Use when data that should not be public reached a GitHub repo and history has been (or must be) rewritten: 'scrub it from GitHub', 'purge the cached commit', 'GitHub still serves the old sha', 'file a support request to remove sensitive data', or a force-push that removed a file but github.com/<owner>/<repo>/commit/<sha> still loads."
---
# GitHub sensitive-data purge request

A history rewrite removes a file from branches and tags, but GitHub keeps
the old commits reachable by sha (pull request refs, cached views) until
GitHub Support dereferences them and runs a garbage collection. This skill
files that support ticket through Fast Browser, with the browser work on a
Haiku browser-driver subagent.

GitHub's own guide is "Removing sensitive data from a repository"
(docs.github.com, authentication > keeping your account and data secure).
Support asks for: owner/repo, the affected pull requests, and the first
changed commits. There is no dedicated form; it is a free-form ticket.

## 1. Before filing

- A leaked credential is rotated or revoked first. Support only acts when
  rotating cannot remove the risk.
- The rewrite is pushed. Check, from a checkout with fresh refs
  (`git fetch origin --prune --tags`):

| Check | Expect |
|-------|--------|
| `git branch -r --contains <sha>` | nothing |
| `git tag --contains <sha>` | nothing |
| `gh api repos/<owner>/<repo>/commits/<sha> --jq .sha` | still the sha (this is what the ticket removes) |

  A branch or tag still listed: rewrite or delete it first.
- No open ticket already covers it: `https://help.github.com/support/tickets`
  lists the account's tickets. One that names the same repo and shas is the
  ticket; add a comment there instead of filing again.
- Collect, as full 40-character shas: the commit that added the data (the
  first changed commit), every old commit built on it that a tag or pull
  request pointed at, the file paths, and the affected pull request numbers
  (any PR whose head was one of those commits, open or closed).

## 2. File the ticket

Fill the brief in [brief.md](brief.md) with the values above and dispatch it
with the Agent tool:

- `subagent_type`: `fast-browser:browser-driver`
- `model`: `haiku`
- `effort`: `medium`
- `prompt`: the filled brief, verbatim

The brief carries the form route, so the subagent does not hunt for a topic.
Never write a secret's value, an employer name or an internal ticket id into
the ticket: shas, paths and PR numbers are enough.

## 3. Confirm

The subagent returns the ticket number and URL. It is filed only when the
ticket page (`help.github.com/ticket/...`) shows the subject and at least one
of the shas. Anything else is not filed: read its report and dispatch again
with what it learned, or finish the last step yourself with the Fast Browser
MCP tools.

## The form, as of 2026-10

| Step | Page | Do |
|------|------|----|
| 1 | `https://support.github.com/contact` (lands on `help.github.com/support/contact`, "Select an account") | pick the repo's owner (the **Organization** entry when two share a name), then **Continue** |
| 2 | product selection | **Repositories** (popular products). There is no "sensitive data" topic |
| 3 | Repositories | radio **Repository features** (never **Deletes**, which is about deleting a repository); Feature type **Branches**; fill **Subject**, **Please describe your repository issue**, and the repository URL field; **Continue** |
| 4 | Solution | wait out "Analyzing your support request…", then **Continue to create a ticket** |
| 5 | Create a ticket | shows only From, CCs and **Type of Issue**. Pick **General question or feature request**, then **Submit** |
| 6 | confirmation | "Your message has been successfully submitted"; **View tickets** lists it, newest first |

Step 5 looks empty, but step 3's answers ride along: they sit in
`sessionStorage` under `contact-next:repositories-form:contact_next[subject]`
and `...[description]`. Check those keys hold the subject and body before
**Submit**; if they are missing, start again from step 1 in the same tab.

## Common mistakes

| Mistake | Instead |
|---------|---------|
| Stopping at step 5 because it has no subject or description field | Check the `sessionStorage` keys, then submit |
| Choosing **Deletes** because it sounds like removal | **Repository features** > **Branches** |
| Filing before every branch and tag is clean | Support assumes only `refs/pull/*` still hold the data |
| Pasting the leaked text to "show" what to remove | Shas and paths only |
| First Fast Browser call fails with `SIDECAR_LOST` | `browser_tabs` list re-attaches; retry once |
