---
name: matt:npm-publish
description: "Use when publishing a package to npmjs.com from Matt's machine and npm wants a one-time password or a fresh login -- 'npm publish', 'ship a new version to npm', 'publish the package', a recurring 'npm login' loop, or an EOTP / ENEEDAUTH / E401 / 'requires you to be logged in' error on publish. Grabs the npm 2FA code from Bitwarden."
---

# npm publish (Bitwarden OTP)

Publish to npmjs.com without the login/OTP grind. Auth is a long-lived granular
token in `~/.npmrc`; the mandatory 2FA code is pulled from Bitwarden and passed
as `npm publish --otp=`. The human unlocks Bitwarden once per work session (types
their master password into a Terminal window); after that, publishing is
hands-free.

**Why this exists:** npm killed classic/never-expiring tokens (revoked Dec 2025).
`npm login` now hands out a *2-hour* session, which is the "log in all the time"
pain. A granular token lasts up to 90 days and sidesteps that... but 2FA on write
is mandatory, so every `npm publish` still needs an OTP. This skill automates the
OTP half and stretches the login half from 2 hours to 90 days.

## Config (Matt's machine)

| Thing | Value |
|-------|-------|
| Bitwarden item id | `2c8cbfc9-eee7-4210-9e79-af4101431198` (`www.npmjs.com (m4ttheweric)`) |
| Session file | `~/.cache/npm-bw.session` (session key, mode 600) |
| Registry token | `//registry.npmjs.org/:_authToken=` line in `~/.npmrc` |
| npm user | `m4ttheweric` |

If the item id ever changes, find it with (human runs, via `!` prefix):
`bw list items --search npm --session "$(cat ~/.cache/npm-bw.session)" | jq -r '.[] | "\(.id) | \(.name)"'`

## Publish (the common path)

Run in the package directory, with the version already set (this skill does not
bump versions -- use `npm version patch|minor|major` yourself first if needed).

**1. Make sure Bitwarden is unlocked.** Probe it:

```bash
bw get totp 2c8cbfc9-eee7-4210-9e79-af4101431198 \
  --session "$(cat ~/.cache/npm-bw.session)" >/dev/null 2>&1 \
  && echo UNLOCKED || echo LOCKED
```

- `UNLOCKED` -> go to step 2.
- `LOCKED` -> [unlock it](#unlocking-bitwarden), then continue.

**2. Fetch the OTP and publish in one command** so the code cannot age out of its
30-second window between fetch and use:

```bash
npm publish --otp="$(bw get totp 2c8cbfc9-eee7-4210-9e79-af4101431198 \
  --session "$(cat ~/.cache/npm-bw.session)")"
```

Add any normal publish flags on the end (`--tag next`, `--access public`,
`-w <workspace>`, `--provenance`, etc.).

Both `bw get totp *` and `npm publish *` are on the allowlist, so this runs
without a permission prompt.

## Unlocking Bitwarden

Only needed when the probe says `LOCKED` (first publish of a session, or after the
vault re-locks). This pops a real Terminal window so the human types **only** their
master password... the session key never enters the agent's context.

```bash
bash ~/.claude/skills/matt:npm-publish/scripts/bw-unlock.sh
```

Tell the human: *"A Terminal window opened -- type your Bitwarden master password
there."* Then wait for the session to land (it writes only on a successful unlock):

```bash
# background poll; re-invokes the agent when the file is non-empty
until [ -s ~/.cache/npm-bw.session ]; do sleep 1; done; echo READY
```

Re-run the step 1 probe to confirm `UNLOCKED`, then publish.

## One-time setup: the granular token (~every 90 days)

Do this when there is no token, or publish fails auth (see below). It is what
ends the 2-hour `npm login` loop.

1. Open <https://www.npmjs.com/settings/m4ttheweric/tokens> -> **Generate New
   Token** -> **Granular Access Token**.
2. Expiration: **90 days** (the max for write tokens). Packages: your packages (or
   *All*). Permissions: **Read and write**. Leave **2FA enforced** -- do *not*
   check "bypass 2FA" (npm is restricting those, and the OTP flow wants 2FA on).
3. Copy the `npm_...` token and store it:
   ```bash
   npm config set //registry.npmjs.org/:_authToken=npm_PASTE_HERE
   ```
4. Verify: `npm whoami` prints `m4ttheweric`.

No more `npm login`. Re-mint when it expires (npm emails a reminder).

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `E401` / `ENEEDAUTH` / "requires you to be logged in" on publish | Token expired or missing (the 90-day granular token lapsed, or `~/.npmrc` has an old 2-hour session) | Re-run [One-time setup](#one-time-setup-the-granular-token-every-90-days), then publish again |
| `EOTP` / npm still prompts for a one-time password despite `--otp=` | OTP was stale (>30s old) or wrong item | Re-run the single fetch-and-publish command in step 2 (never fetch the OTP in a separate earlier step) |
| `bw` errors "Vault is locked" / "mac failed" | Session expired or file cleared | [Unlock again](#unlocking-bitwarden) |
| No Terminal window appears on unlock | macOS has not granted osascript control of Terminal | Approve it in System Settings -> Privacy & Security -> Automation, or have the human run `bw unlock --raw > ~/.cache/npm-bw.session` themselves via the `!` prefix |
| Classifier blocks a `bw` read | Only `bw get totp *` is allowlisted; broader `bw list items` is not | Have the human run the discovery command (Config section) via the `!` prefix |

## Notes

- The OTP is a transient second factor (expires in 30s, single use); the agent
  seeing it is fine. The master password and the vault session key never reach the
  agent's context -- the password stays in the Terminal, the session key stays in
  the mode-600 file and is only ever read inline as `--session "$(cat ...)"`.
- The session file persists between publishes so one unlock covers a whole work
  session. To lock early: `bw lock` and `rm -f ~/.cache/npm-bw.session`.
