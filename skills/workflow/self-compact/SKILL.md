---
name: matt:self-compact
description: "Use when Matt asks this session to compact itself or get ready for compaction -- 'prepare yourself for compaction', 'save important context to your ledger and then self compact', 'self compact', 'write your ledger and compact', 'get ready to compact'."
---

# self-compact

"Prepare for compaction", "save to your ledger and self compact" and "self
compact" all ask for the whole job: write the ledger, then compact this
session yourself. The ledger is the note you re-read after compaction; the
compaction summary is lossy, the ledger is not.

## Steps

1. **Read the real state.** `git status --short`, `git log --oneline -5`,
   and the open PR/MR's CI if there is one. The ledger records what these
   show, not what you remember.
2. **Commit only finished work**, under the usual commit rules. Half-done
   edits stay on disk uncommitted: compaction never touches the working
   tree. Name them in the ledger.
3. **Write the ledger** to `<scratchpad>/compaction-ledger.md`, the
   scratchpad directory your system prompt names (`$TMPDIR` when it names
   none). Overwrite any earlier ledger from this session. Its sections, in
   this order:
   - **Goal**: the ask, in Matt's words.
   - **Where**: repo or worktree path, branch, PR/MR, ticket, and the path
     of any ledger the work already keeps (an SDD `progress.md`, a run).
   - **Done**: each finished step with its commit sha.
   - **In progress**: the half-done step, its uncommitted files, what is left.
   - **Next step**: the exact next action.
   - **Matt's decisions**: rulings to keep, never reopen.
   - **Learned**: dead ends, gotchas, known flakes, so you don't redo them.
   - **Waiting on Matt**: open questions, or "none".
4. **Queue the compaction** in your own pane. REQUIRED: rt:herdr-inject
   for the mechanics.

```bash
rt pane send self --text "/compact Keep: <goal>, <branch and PR>, <next step>. Ledger: <ledger path>" --then "Continue: read <ledger path>, run git status, then <next step>"
```

5. **End the turn** with one line: the ledger path and that `/compact` is
   queued. Any further tool call only delays it.

When `rt pane send` answers `not in a herdr pane`, the ledger still
stands: give Matt both lines to type, the `/compact ...` line and then the
`Continue: ...` line, and stop.

## Rationalizations

| Thought | Reality |
|---------|---------|
| "Matt said prepare, not compact, so I'll just offer a line to paste." | Prepare means the whole job. Queue the compaction yourself. |
| "I'll WIP-commit the half-done task so nothing is lost." | The working tree survives compaction. List the files under In progress. |
| "I need to search for what 'ledger' means." | It is the file in step 3. |
| "The compaction summary will keep the details." | It is lossy. The ledger and the Continue line are how you get back. |
