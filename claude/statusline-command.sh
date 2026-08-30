#!/bin/bash
# Claude Code status line: shows the active model (abbreviated to its first
# letter), account email, the Fable weekly pool (F, Fable sessions only),
# weekly usage (W) and context usage (C), then whether this session is signed
# in to rt chat.

input=$(cat)

model_full=$(echo "$input" | jq -r '.model.display_name // "unknown model"')

# Drop a trailing parenthetical qualifier such as " (1M context)" from the
# model name; keeps the statusline compact. Only a trailing " (...)" is removed.
model_full="${model_full% (*)}"

# Abbreviate the model family to its first letter: "Fable 5" -> "F 5",
# "Sonnet 5" -> "S 5", "Opus 4.8" -> "O 4.8".
model_word1="${model_full%% *}"
model_rest="${model_full#"$model_word1"}"
model="${model_word1:0:1}$model_rest"

# Live reasoning-effort level, shown next to the model. `.effort.level` is only
# present when the current model supports reasoning effort, and it reflects the
# live session value (e.g. after /effort), not the persisted settings.json one.
effort=$(echo "$input" | jq -r '.effort.level // empty')
[ -n "$effort" ] && model="$model [$effort]"

# Account email is not provided in the statusline JSON payload, so read it
# from Claude Code's config `oauthAccount.emailAddress`. This is the field
# Claude Code (and account-switchers like cswap/claude-swap) actually rewrite
# on a login/switch, so it always reflects the live account.
#
# Resolve the config path the same way Claude Code does: (CLAUDE_CONFIG_DIR ||
# $HOME)/.claude.json. This matters for `cswap run`, which launches each
# session with its OWN CLAUDE_CONFIG_DIR (e.g.
# ~/.claude-swap-backup/sessions/<n>-<email>/). The statusline command inherits
# that env var, so per-session accounts resolve correctly instead of all
# sessions showing whatever is in the global ~/.claude.json.
#
# We deliberately do NOT key off `userID`: cswap swaps accounts by splicing
# only `oauthAccount` and leaves `userID` frozen (it even strips `userID` on
# export), so a userID->email map goes stale after a swap. Re-read on every
# invocation (never cache) so switches show immediately.
config_json="${CLAUDE_CONFIG_DIR:-$HOME}/.claude.json"
email=$(jq -r '.oauthAccount.emailAddress // empty' "$config_json" 2>/dev/null)
if [ -z "$email" ]; then
  # Fallback: truncated account id if no email is present.
  email=$(jq -r '.userID // empty' "$config_json" 2>/dev/null)
  email="${email:0:8}"
fi
email_full="$email"

# cswap list --json reads its local store (~110ms, no network fetch), fine to
# call once per render; both the domain collapse and the Fable pool read it.
cswap_json=$(cswap list --json 2>/dev/null)

# Collapse the account email to its shortest DISTINCT part. Group all managed
# accounts (cswap list --json) by domain: a domain unique to one account is
# shown as "@domain"; a domain shared by 2+ accounts falls back to the local
# part (before @) so the accounts stay distinguishable. On any cswap/jq
# failure this defaults to "@domain".
if [ -n "$email" ] && [[ "$email" == *@* ]]; then
  local_part="${email%@*}"
  domain="${email##*@}"
  # Count managed accounts on this domain; always include the current email so
  # an unmanaged/live account still resolves (minimum count of 1).
  same_domain=$(printf '%s' "$cswap_json" | jq -r --arg d "$domain" --arg e "$email" '([.accounts[].email] + [$e]) | unique | map(select(sub("^[^@]*@";"") == $d)) | length' 2>/dev/null)
  if [ -n "$same_domain" ] && [ "$same_domain" -ge 2 ] 2>/dev/null; then
    email="$local_part"
  else
    email="@$domain"
  fi
fi

week=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
context=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# The statusline payload only carries the shared five_hour/seven_day pools.
# Fable draws from its own weekly pool, which Claude Code does not expose in
# the payload; cswap's store has it under usage.scoped (name "Fable"), keyed by
# the account's full email.
fable=""
if [ "$model_word1" = "Fable" ] && [ -n "$cswap_json" ] && [ -n "$email_full" ]; then
  fable=$(printf '%s' "$cswap_json" | jq -r --arg e "$email_full" '.accounts[] | select(.email == $e) | .usage.scoped[]? | select(.name == "Fable") | .pct // empty' 2>/dev/null | head -1)
fi

usage=""
[ -n "$fable" ] && usage="${usage}F:$(printf '%.0f' "$fable")% "
[ -n "$week" ] && usage="${usage}W:$(printf '%.0f' "$week")% "
[ -n "$context" ] && usage="${usage}C:$(printf '%.0f' "$context")%"
usage=$(echo "$usage" | sed 's/ *$//')

# Whether THIS session is signed in to rt chat (the agent group chat), shown
# as the session's chat handle. The rt CLI writes a session file on sign-in
# and deletes it on sign-out, keyed by the statusline payload's own
# session_id; the file's `handle` field is the agent's chat name.
session_id=$(echo "$input" | jq -r '.session_id // empty')
session_file="$HOME/.mattstack/rt/chat/sessions/$session_id.json"
if [ -n "$session_id" ] && [ -f "$session_file" ]; then
  handle=$(jq -r '.handle // empty' "$session_file" 2>/dev/null)
  if [ -n "$handle" ]; then
    chat_str="$handle 🟢"
  else
    chat_str="online 🟢"
  fi
else
  chat_str="offline"
fi

segments=("$model" "$email")
[ -n "$usage" ] && segments+=("$usage")
segments+=("$chat_str")

out=""
for seg in "${segments[@]}"; do
  if [ -z "$out" ]; then
    out=$(printf '\033[2m%s\033[0m' "$seg")
  else
    out=$(printf '%s \033[2m|\033[0m \033[2m%s\033[0m' "$out" "$seg")
  fi
done
printf '%s\n' "$out"
