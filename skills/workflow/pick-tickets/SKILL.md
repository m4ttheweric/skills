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
3. Otherwise ask with a form: list the projects from `list_projects` that have tickets assigned to Matt or unassigned, most recently updated first.

Use `linear-work` (Assured workspace). Use `linear-matt` only if Matt names a mattstack project.

## 2. Fetch candidates

Two `list_issues` calls on the project, `limit: 100`, `assignee: "me"` and `assignee: null`. Follow pagination if either returns a full page.

Keep status Todo. Treat Triage and Backlog as stretch picks and say so in the row. Drop every other status (Intake, Clarify, On Hold, In Progress, Code Review, Ready for Release, Done, Canceled, Duplicate). Drop parent tickets: a ticket is a parent when any listed ticket has it as `parentId`.

## 3. Read before ranking

Take the top ~15 by priority order Urgent, High, Medium, Low, then none. Fetch each with `get_issue` (parallel calls) and read the full description.

Score each ticket:

- **Ready**: states the symptom or change, and the acceptance criteria or where the fix goes. A ticket with a "decision needed" line, an open product question, or only design links and a list of titles is not ready.
- **Size**: S (one file or component), M (a few files), L (multi-area). Estimates are usually empty, so judge from the description.
- **Area**: the files, components, or feature the fix touches, taken from the description. Name it concretely.
- **Someone else's lane**: the description or comments name an open MR or a colleague actively working on it. Flag it in the row; do not put it in the batch.

## 4. Rank

Ready tickets first, by priority (Urgent, High, Medium, Low), then small before large within a tier. Not-ready tickets follow, in the same order, each marked "needs decision". A ticket with no priority ranks below Low, unless it describes a bug seen in production or with repro steps, in which case it ranks as Medium.

## 5. Present

Table of 10: rank, key (linked), title, priority, owner (You / unassigned), size, area, one line on why it is ready.

Below it, the recommended batch of 4-6:

- Lanes: tickets that touch the same area share a lane and run in sequence in one workflow; tickets in different areas get separate lanes. Only ready tickets enter the batch.
- If a ticket depends on another ticket's outcome, name the dependency in its lane.
- Each lane lists its tickets and one reason.
- Say which lane order to start in, and name one spare ticket for a further lane.
- State what you did not verify (code overlap between lanes is read from descriptions, not the repo).

End with a wrap-up form asking which tickets Matt wants to kick off.
