---
name: matt:account-hop
description: "Use when the user wants the CURRENT Claude Code session continued under a different cswap account -- 'hop accounts', 'account-hop', 'resume this in my other account', 'move this session to account N', 'continue this as <account>', or when the active account is running out of rate limit mid-task. Only works from a herdr-managed pane."
---

# account-hop

Hand this very session off to another cswap account: split a pane right,
park a waiter there, exit this claude, and the waiter resumes the SAME
session id (no fork) under the target account with shared history. You
are the origin claude -- you run this from inside the session being
hopped.

## preconditions

`HERDR_ENV=1`, `HERDR_PANE_ID`, `CLAUDE_PID`, and
`CLAUDE_CODE_SESSION_ID` must all be set (they are, in any herdr claude
pane), and `cswap` must exist (`~/.local/bin/cswap`). Any missing: stop
and say which.

## pick the account and model

Model: always pass `-m` with the model you are running as right now
(map yourself to the CLI alias: fable / opus / sonnet / haiku), unless
the user names a different model. Omitting `-m` silently resumes on
claude's default model.

If the user named exactly one account (a unique email or list number),
skip the picker and the question and use it -- the script still refuses
accounts with dead auth; if it does, tell the user and offer the
healthy accounts instead. A partial or family name ("bouncer", "my
other account") is NOT a named target: still ask, listing at least the
matching accounts. Otherwise, build the choice with the cswap account
pool picker:

```bash
python3 ~/.claude/skills/mattstack:cswap-accounts/scripts/pick-account.py \
  --headroom --pool 1,2,3,4 --model <alias>
```

Ask ONE AskUserQuestion (single choice) listing each account with its
headroom line verbatim, marking the current account "(current)".
Recommend the healthiest non-current account. Never offer or recommend
an account whose `cswap list --json` row has `usageStatus` of
`relogin_required`, `no_credentials`, or `api_key`: a dead account
fails only AFTER this session has exited, stranding the user (the
script also refuses these).

## hop

```bash
"$SKILL_DIR/scripts/account-hop.sh" -a <account> -m <alias>
```

`$SKILL_DIR` is this skill's directory (the folder containing this
file). Pass `-a` as the account email (list numbers work but can
renumber). Origin pane, pid, and session id come from the environment;
cwd is the shell's `$PWD`, so pass `-c <dir>` if your working directory
has drifted from the session's project dir. The script resolves the
account to exactly one row (else it fails), refuses to run if the
origin pid is not alive, splits right (focused), starts the waiter, and
queues `/exit` into THIS pane. Once the origin claude exits, the waiter
closes the origin pane and resumes. Run `-h` for flags (direction,
timeout, no-exit, no-focus, keep-origin-pane).

Then write ONE short handoff line ("resuming this session as <account>
in the pane to the right -- exiting") and END YOUR TURN immediately. No
further tool calls: the queued `/exit` submits when your turn ends, and
the waiter resumes only after this process dies.

## gotchas

- cswap forwards everything after the first `--` directly to the claude
  binary: `cswap run <acct> --share-history -- --resume <id> --model <m>`.
  Never insert a literal `claude` token after the `--`.
- `--share-history` is mandatory. cswap re-syncs sharing every launch;
  without it the target profile's history unlinks and `--resume` cannot
  see this session's transcript.
- No `--fork-session`: same-id resume is safe precisely because the
  waiter waits for the origin pid to die first.
- If the queued `/exit` gets lost (startup-greeting-style race), the
  user exits manually; the waiter still catches it, and after the
  timeout (default 300s) it prints the manual resume command instead.
- The resumed pane runs under the target account's plugin cache, so
  missing-plugin symptoms there are expected -- do not chase them.
- If the target account's profile has never trusted the project folder,
  the resumed claude blocks on the folder-trust dialog; the user answers
  it in the new pane and the session continues. Mention this in the
  handoff line only when hopping in an unusual directory.
