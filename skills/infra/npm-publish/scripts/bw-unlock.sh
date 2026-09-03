#!/usr/bin/env bash
# Pop a Terminal.app window running `bw unlock` so the human only types their
# master password. The unlocked session key is written to SESSION_FILE and is
# never printed back to the agent. Returns as soon as the window is launched;
# the caller polls SESSION_FILE for a non-empty result (bw writes it only on a
# successful unlock).
#
# Overridable via env: NPM_BW_SESSION_FILE.
set -euo pipefail

SESSION_FILE="${NPM_BW_SESSION_FILE:-$HOME/.cache/npm-bw.session}"

# mise shims aren't on a non-login PATH, so resolve bw before handing it to a
# fresh Terminal shell.
BW="$(command -v bw || true)"
[ -z "$BW" ] && BW="$HOME/.local/share/mise/shims/bw"
[ -x "$BW" ] || { echo "bw not found (looked for: $BW)"; exit 3; }

mkdir -p "$(dirname "$SESSION_FILE")"
: > "$SESSION_FILE"
chmod 600 "$SESSION_FILE"

# Terminal's `do script` runs a shell command string; nesting the whole unlock
# inline means fighting three layers of quoting. Write it to a temp launcher and
# run that path instead. The launcher deletes itself once bw returns.
LAUNCHER="$(mktemp "${TMPDIR:-/tmp}/npm-bw-unlock.XXXXXX")"
cat > "$LAUNCHER" <<EOF
#!/usr/bin/env bash
printf '\n  Enter your Bitwarden master password to unlock npm publishing:\n\n'
"$BW" unlock --raw > "$SESSION_FILE" && chmod 600 "$SESSION_FILE" \\
  && printf '\n  >>> Unlocked. You can close this window. <<<\n' \\
  || printf '\n  !!! Unlock failed. Re-run the skill to try again. !!!\n'
rm -f "$LAUNCHER"
EOF
chmod +x "$LAUNCHER"

osascript \
  -e 'tell application "Terminal" to activate' \
  -e "tell application \"Terminal\" to do script \"$LAUNCHER\"" >/dev/null

echo "Terminal window opened. Waiting on the master password..."
