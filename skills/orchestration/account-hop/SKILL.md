---
name: matt:account-hop
description: "Use when the user wants the CURRENT Claude Code session continued under a different cswap account -- 'hop accounts', 'account-hop', 'resume this in my other account', 'move this session to account N', 'continue this as <account>', or when the active account is running out of rate limit mid-task. Only works from a herdr-managed pane."
---

# account-hop

Hand this very session to another cswap account: split a pane right, park
a waiter there, exit this claude, and the waiter resumes the SAME session
id (no fork) under the target account with shared history. You are the
origin claude, running this from inside the session being hopped, in a
herdr pane.

`<skill>` is this skill's directory (the folder holding this file).

## The flow

Follow this graph. A move it does not show is a question for Matt through
AskUserQuestion, never a judgment call.

```dot
digraph account_hop {
    rankdir=TB;

    "Trigger: Matt asks to continue this session under another cswap account" [shape=ellipse];
    "printenv HERDR_ENV HERDR_PANE_ID CLAUDE_PID CLAUDE_CODE_SESSION_ID" [shape=plaintext];
    "All four herdr variables set?" [shape=diamond];
    "test -x ~/.local/bin/cswap" [shape=plaintext];
    "cswap installed?" [shape=diamond];
    "Not hopped: name what is missing" [shape=doublecircle];
    "Pick the model alias this session runs as" [shape=box];
    "Did Matt name exactly one account?" [shape=diamond];
    "STOP: a partial name is not a target; list the pool with pick-account.py" [shape=octagon style=filled fillcolor=red fontcolor=white];
    "python3 \"$(ls -d ~/.claude/plugins/cache/mattstack/mattstack/*/attachments/cswap-accounts/scripts/pick-account.py | sort -V | tail -1)\" --headroom --pool 1,2,3,4 --model <alias>" [shape=plaintext];
    "pick-account.py printed headroom lines?" [shape=diamond];
    "AskUserQuestion {questions: [which account to hop to]}" [shape=plaintext];
    "Account answer?" [shape=diamond];
    "bash <skill>/scripts/account-hop.sh -a <email> -m <alias>" [shape=plaintext];
    "account-hop.sh result?" [shape=diamond];
    "Account refusals = 2?" [shape=diamond];
    "STOP: a refused hop goes to AskUserQuestion, never a hand-built resume" [shape=octagon style=filled fillcolor=red fontcolor=white];
    "Hop gate asked = 2?" [shape=diamond];
    "AskUserQuestion {questions: [account-hop.sh refused the hop]}" [shape=plaintext];
    "Hop answer?" [shape=diamond];
    "STOP: a failed picker goes to AskUserQuestion, never a hand-built account list" [shape=octagon style=filled fillcolor=red fontcolor=white];
    "Picker gate asked = 2?" [shape=diamond];
    "AskUserQuestion {questions: [the account picker failed]}" [shape=plaintext];
    "Picker answer?" [shape=diamond];
    "STOP: end the turn after the handoff line" [shape=octagon style=filled fillcolor=red fontcolor=white];
    "Write the one-line handoff" [shape=box];
    "Not hopped: Matt stays on this account" [shape=doublecircle];
    "Held: not hopped" [shape=doublecircle];
    "Handed back: Matt hops by hand" [shape=doublecircle];
    "Hopped: end the turn with no further tool calls" [shape=doublecircle style=filled fillcolor=lightgreen];

    "Trigger: Matt asks to continue this session under another cswap account" -> "printenv HERDR_ENV HERDR_PANE_ID CLAUDE_PID CLAUDE_CODE_SESSION_ID";
    "printenv HERDR_ENV HERDR_PANE_ID CLAUDE_PID CLAUDE_CODE_SESSION_ID" -> "All four herdr variables set?";
    "All four herdr variables set?" -> "test -x ~/.local/bin/cswap" [label="yes"];
    "All four herdr variables set?" -> "Not hopped: name what is missing" [label="no"];
    "test -x ~/.local/bin/cswap" -> "cswap installed?";
    "cswap installed?" -> "Pick the model alias this session runs as" [label="yes"];
    "cswap installed?" -> "Not hopped: name what is missing" [label="no"];
    "Pick the model alias this session runs as" -> "Did Matt name exactly one account?";
    "Did Matt name exactly one account?" -> "bash <skill>/scripts/account-hop.sh -a <email> -m <alias>" [label="yes: a unique email or list number"];
    "Did Matt name exactly one account?" -> "python3 \"$(ls -d ~/.claude/plugins/cache/mattstack/mattstack/*/attachments/cswap-accounts/scripts/pick-account.py | sort -V | tail -1)\" --headroom --pool 1,2,3,4 --model <alias>" [label="no, or a partial or family name"];
    "Did Matt name exactly one account?" -> "STOP: a partial name is not a target; list the pool with pick-account.py" [label="tempted to guess the account from a partial name"];
    "STOP: a partial name is not a target; list the pool with pick-account.py" -> "python3 \"$(ls -d ~/.claude/plugins/cache/mattstack/mattstack/*/attachments/cswap-accounts/scripts/pick-account.py | sort -V | tail -1)\" --headroom --pool 1,2,3,4 --model <alias>";
    "python3 \"$(ls -d ~/.claude/plugins/cache/mattstack/mattstack/*/attachments/cswap-accounts/scripts/pick-account.py | sort -V | tail -1)\" --headroom --pool 1,2,3,4 --model <alias>" -> "pick-account.py printed headroom lines?";
    "pick-account.py printed headroom lines?" -> "AskUserQuestion {questions: [which account to hop to]}" [label="yes"];
    "pick-account.py printed headroom lines?" -> "Picker gate asked = 2?" [label="no: missing or errored"];
    "pick-account.py printed headroom lines?" -> "STOP: a failed picker goes to AskUserQuestion, never a hand-built account list" [label="tempted to build the list from cswap yourself"];
    "STOP: a failed picker goes to AskUserQuestion, never a hand-built account list" -> "Picker gate asked = 2?";
    "AskUserQuestion {questions: [which account to hop to]}" -> "Account answer?";
    "Account answer?" -> "bash <skill>/scripts/account-hop.sh -a <email> -m <alias>" [label="an account"];
    "Account answer?" -> "Not hopped: Matt stays on this account" [label="stay on this account"];
    "Picker gate asked = 2?" -> "AskUserQuestion {questions: [the account picker failed]}" [label="no"];
    "Picker gate asked = 2?" -> "Handed back: Matt hops by hand" [label="yes: budget spent"];
    "AskUserQuestion {questions: [the account picker failed]}" -> "Picker answer?";
    "Picker answer?" -> "bash <skill>/scripts/account-hop.sh -a <email> -m <alias>" [label="take: Matt names the account"];
    "Picker answer?" -> "python3 \"$(ls -d ~/.claude/plugins/cache/mattstack/mattstack/*/attachments/cswap-accounts/scripts/pick-account.py | sort -V | tail -1)\" --headroom --pool 1,2,3,4 --model <alias>" [label="iterate: rerun the picker"];
    "Picker answer?" -> "Held: not hopped" [label="hold"];
    "Picker answer?" -> "Handed back: Matt hops by hand" [label="hand back"];

    "bash <skill>/scripts/account-hop.sh -a <email> -m <alias>" -> "account-hop.sh result?";
    "account-hop.sh result?" -> "Write the one-line handoff" [label="ok: summary printed, exit_queued: yes"];
    "account-hop.sh result?" -> "Account refusals = 2?" [label="refused the account: dead auth or no unique match"];
    "account-hop.sh result?" -> "Hop gate asked = 2?" [label="any other refusal"];
    "account-hop.sh result?" -> "STOP: a refused hop goes to AskUserQuestion, never a hand-built resume" [label="tempted to run the resume by hand"];
    "account-hop.sh result?" -> "STOP: end the turn after the handoff line" [label="tempted to finish other work first"];
    "STOP: end the turn after the handoff line" -> "Write the one-line handoff";
    "Account refusals = 2?" -> "python3 \"$(ls -d ~/.claude/plugins/cache/mattstack/mattstack/*/attachments/cswap-accounts/scripts/pick-account.py | sort -V | tail -1)\" --headroom --pool 1,2,3,4 --model <alias>" [label="no: re-offer healthy accounts"];
    "Account refusals = 2?" -> "Hop gate asked = 2?" [label="yes: budget spent"];
    "STOP: a refused hop goes to AskUserQuestion, never a hand-built resume" -> "Hop gate asked = 2?";
    "Hop gate asked = 2?" -> "AskUserQuestion {questions: [account-hop.sh refused the hop]}" [label="no"];
    "Hop gate asked = 2?" -> "Handed back: Matt hops by hand" [label="yes: budget spent"];
    "AskUserQuestion {questions: [account-hop.sh refused the hop]}" -> "Hop answer?";
    "Hop answer?" -> "bash <skill>/scripts/account-hop.sh -a <email> -m <alias>" [label="take: the flag or account Matt names"];
    "Hop answer?" -> "python3 \"$(ls -d ~/.claude/plugins/cache/mattstack/mattstack/*/attachments/cswap-accounts/scripts/pick-account.py | sort -V | tail -1)\" --headroom --pool 1,2,3,4 --model <alias>" [label="iterate: re-pick from fresh headroom"];
    "Hop answer?" -> "Held: not hopped" [label="hold"];
    "Hop answer?" -> "Handed back: Matt hops by hand" [label="hand back"];
    "Write the one-line handoff" -> "Hopped: end the turn with no further tool calls";
}
```

Counts never reset within one hop. Each gate's `asked = 2?` counter sits in
front of the gate because take loops back as well as iterate; a guard STOP
enters its gate through that counter too.

The two precondition checks read the environment herdr sets in every
claude pane and the cswap install; when either is missing, say which and
stop. "Set" means `HERDR_ENV` is exactly `1` and the other three
variables are non-empty; `HERDR_ENV=0` counts as not set.

### Pick the model alias this session runs as

Map the model you are running as right now to its CLI alias: fable, opus,
sonnet or haiku. A model Matt names wins. Always pass `-m`: without it the
resumed session silently runs on claude's default model.

## Did Matt name exactly one account?

A unique email or a list number is a name: skip the picker and hop. A
partial or family name ("bouncer", "my other account") is not, even when
you think you know which one he means: list the pool and ask, showing at
least the matching accounts.

## The account question

The picker's newest copy lives in the mattstack plugin cache; the graph's
call resolves it by version sort in the same command. One AskUserQuestion,
single choice: name the current account in the question sentence ("You
are on <email> now.") and leave it out of the options, so at most 3
accounts plus a last option **Stay on this account** ("I don't hop; this
session keeps going here.") stay under AskUserQuestion's 4-option cap.
Each account option carries its headroom line verbatim as the
description, with the healthiest non-current account first and
recommended. Never offer or recommend an account whose `cswap list
--json` row has `usageStatus` `relogin_required`, `no_credentials` or
`api_key`: a dead account fails only after this session has exited,
stranding Matt. Labels are 2 to 6 words (the email alone fits).

## The hop call

`bash <skill>/scripts/account-hop.sh -a <email> -m <alias>`

`-a` takes the email; when Matt named only a list number, pass that
number as given (the script resolves both numbers and emails, but
numbers can renumber, so prefer the email when it is known). Pane, pid
and session id come from the environment; the cwd is the shell's `$PWD`,
so add `-c <dir>` when the working directory has drifted from the session's
project dir. `-h` lists the rest (direction, timeout, no-exit, no-focus,
keep-origin-pane). The script resolves the account to exactly one row,
refuses a dead one ("is unusable (usageStatus=...)") or an unmatched one
("ambiguous" or "not an exact number/email"): those are account refusals.
Anything else it refuses (not inside herdr, origin pid not alive, cswap
list failed) is another refusal. On success it splits right, starts the
waiter and queues `/exit` into this pane; its summary ends with
`exit_queued: yes`.

### Write the one-line handoff

Write one short line: "resuming this session as <account> in the pane to
the right; exiting". Mention the folder-trust dialog only when hopping in
an unusual directory (the target profile may never have trusted it; Matt
answers it in the new pane). Then end the turn with no further tool calls
and no unfinished work picked back up: the queued `/exit` submits only
when the turn ends, and the waiter resumes only after this process dies.

## Gates

**The account picker failed.** Quote the error.

| Answer | Label | Description |
|--------|-------|-------------|
| take | I'll name the account | Your note names the account; I hop to it. |
| iterate | Rerun the picker | I run the account picker again. |
| hold | Hold the hop | I stop here; this session stays on this account. |
| hand back | I'll hop by hand | I stop and leave the hop to you. |

**account-hop.sh refused the hop.** Quote the refusal.

| Answer | Label | Description |
|--------|-------|-------------|
| take | Use my account or flag | I rerun the hop with the account or flag in your note. |
| iterate | Re-pick from fresh headroom | I rerun the picker and ask which account again. |
| hold | Hold the hop | I stop here; this session stays on this account. |
| hand back | I'll hop by hand | I stop; the waiter prints the manual resume command if one started. |

## Gotchas

- cswap forwards everything after the first `--` to the claude binary:
  `cswap run <acct> --share-history -- --resume <id> --model <m>`. Never a
  literal `claude` token after the `--`. The script builds this; never
  build it by hand.
- `--share-history` is mandatory: cswap re-syncs sharing every launch, and
  without it the target profile's history unlinks and `--resume` cannot
  see this transcript.
- No `--fork-session`: a same-id resume is safe because the waiter waits
  for the origin pid to die first.
- If the queued `/exit` is lost (a startup-greeting-style race), Matt
  exits by hand; the waiter still catches it, and after its timeout
  (default 300s) it prints the manual resume command.
- The resumed pane runs under the target account's plugin cache, so
  missing-plugin symptoms there are expected; do not chase them.
- Once the origin claude has exited, the waiter closes the origin pane;
  `-O` keeps it open instead. On waiter timeout the pane is left open
  either way.

## Rationalizations

| Thought | Reality |
|---------|---------|
| "'bouncer' obviously means claude@bouncer.mx." | A partial name is not a target. List the pool and ask. |
| "Matt said whatever it takes, so I'll build the resume command myself." | A refused hop goes to the hop gate; only `account-hop.sh` hops. |
| "The picker is missing, so I'll read `cswap list --json` and rank them myself." | A failed picker goes to the picker gate. |
| "I'll just commit these edits before I stop." | After the summary, one handoff line and the turn ends. The work continues in the resumed pane. |
| "`-m` is optional." | Omitting it resumes on the default model. |
| "the correct move is to restore the tool (via the already-established `/reload-plugins` path) rather than improvise around it." | The picker gate ("the account picker failed") asks Matt; restoring the tool on your own is not on the graph. |
