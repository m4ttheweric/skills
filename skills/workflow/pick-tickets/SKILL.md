---
name: pick-tickets
description: "Use when Matt asks to pick, grab, or shortlist tickets from a Linear project to work next, wants a batch of tickets to kick off in parallel workflows, or asks what to work on from the current project."
---

# Pick tickets

Read-only. Never assign, comment on, or change status of any ticket.

Output: a ranked list of 10 tickets, then a batch of 4-6 that can run in parallel.

## 1. Find the project

First match wins:

1. A Linear project URL in the request: pass the whole slug after `/project/` to `get_project` and `list_issues`.
2. A ticket key in the current branch, worktree name, or recent conversation: read that ticket's project.
3. Otherwise ask with a form. Read `~/.claude/state/pick-tickets.json` first (shape below); a missing or unreadable file means no remembered projects. Options, in order:
   - the project remembered for this repo, labelled `(Recommended)`
   - else the global last-used project, labelled `(Recommended)`
   - other projects in `recent`
   - the remaining projects from `list_projects` (pass a small `fields` set: id, name, slug, updatedAt; the full response is huge), sorted by `updatedAt` newest first yourself

After any project is chosen, from a URL, a ticket key, or the form, write it back before fetching tickets.

State file, keyed by `git remote get-url origin` (stable across worktrees; use the working directory path if there is no remote):

```json
{
  "lastUsed": {"name": "ClaimView 3 - FNOL + Statements", "slug": "claimview-3-fnol-statements-4d1eaaf5908d"},
  "repos": {"git@gitlab.com:assured/hogwarts.git": {"name": "...", "slug": "..."}},
  "recent": [{"name": "...", "slug": "..."}]
}
```

Set `lastUsed` and this repo's entry to the chosen project, move it to the front of `recent`, keep `recent` at 5, and create `~/.claude/state/` if needed.

Use `linear-work` (Assured workspace). Use `linear-matt` only if Matt names a mattstack project.

## 2. Fetch candidates

Two `list_issues` calls on the project, `limit: 100`, `assignee: "me"` and `assignee: null`. Follow pagination if either returns a full page.

Keep status Todo. Treat Triage and Backlog as stretch picks and say so in the row. Drop every other status (Intake, Clarify, On Hold, In Progress, Code Review, Ready for Release, Done, Canceled, Duplicate). Drop parent tickets: a ticket is a parent when any listed ticket has it as `parentId`.

## 3. Read before ranking

Take the top ~15 by priority order Urgent, High, Medium, Low, then none. Fetch each with `get_issue` (parallel calls) and read the full description.

Score each ticket:

- **Ready**: states the symptom or change, and the acceptance criteria or where the fix goes. A ticket with a "decision needed" line, a rule "pending a product call", or only design links and a list of titles is not ready. A side decision that does not change the main fix does not block.
- **Size**: S (one file or component), M (a few files), L (multi-area). Estimates are usually empty, so judge from the description.
- **Area**: the files, components, or feature the fix touches, taken from the description. Name it concretely.
- **Someone else's lane**: the description or comments name an open MR or a colleague actively working on it. Flag it in the row; do not put it in the batch. Descriptions alone miss this, so call `list_comments` for every ticket you are about to put in the batch.

## 4. Rank

Ready tickets first, by priority (Urgent, High, Medium, Low), then small before large within a tier. Not-ready tickets follow, in the same order, each marked "needs decision". A ticket with no priority set ranks below Low, unless it describes a bug seen in production or gives repro steps, in which case it ranks as Medium. Triage and Backlog stretch picks rank by the same rules and carry a "stretch" flag.

## 5. Present

Table of 10: rank, key (linked), title, priority, owner (You / unassigned), size, area, one line on why it is ready.

Below it, the recommended batch of 4-6:

- Lanes: tickets that touch the same area share a lane and run in sequence in one workflow; tickets in different areas get separate lanes. Only ready tickets enter the batch.
- If a ticket depends on another ticket's outcome, name the dependency in its lane.
- Each lane lists its tickets and one reason.
- Say which lane order to start in, and name one spare ticket for a further lane.
- State what you did not verify (code overlap between lanes is read from descriptions, not the repo).

End with a wrap-up form asking which tickets Matt wants to kick off.
