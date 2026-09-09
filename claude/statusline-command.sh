#!/bin/bash
# Claude Code status line: shows the active model (abbreviated to its first
# letter), account email, an in-progress superpowers plan's completion (when
# one is found for this workspace), the Fable weekly pool (F, Fable sessions
# only), weekly usage (W) and context usage (C), then whether this session is
# signed in to rt chat.

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

# In-progress superpowers plan: per ~/.claude/rules/superpowers-docs-location.md
# plans live at docs/superpowers/plans/ by default, or .local-dev/superpowers/plans/
# in assured-dev. A plan's own checkboxes ("- [ ]" / "- [x]") are its ledger; no
# separate progress file exists. Walk cwd -> worktree -> project root so a session
# working inside a worktree still finds that worktree's own plan first. Only the
# most recently modified plan is considered, and only while work remains -- a
# fully checked plan is no longer "ongoing" and drops out of the statusline.
plan_seg=""
sp_cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
sp_worktree=$(echo "$input" | jq -r '.worktree.path // empty')
sp_project=$(echo "$input" | jq -r '.workspace.project_dir // empty')

plans_dir=""
for sp_root in "$sp_cwd" "$sp_worktree" "$sp_project"; do
  [ -n "$sp_root" ] || continue
  for sp_rel in ".local-dev/superpowers/plans" "docs/superpowers/plans"; do
    if [ -d "$sp_root/$sp_rel" ]; then
      plans_dir="$sp_root/$sp_rel"
      break 2
    fi
  done
done

if [ -n "$plans_dir" ]; then
  plan_file=$(ls -t "$plans_dir"/*.md 2>/dev/null | head -1)
  if [ -n "$plan_file" ]; then
    # Prints "<checked> <total> <label>", where label is the nearest markdown
    # heading above the first unchecked task -- the plan's current placement.
    parsed=$(awk '
      /^#+[ \t]/ { h = $0; sub(/^#+[ \t]*/, "", h) }
      /^[ \t]*-[ \t]*\[[ xX]\]/ {
        total++
        if ($0 ~ /\[[xX]\]/) { checked++ }
        else if (!found) { cur = h; found = 1 }
      }
      END { printf "%d %d %s\n", checked+0, total+0, cur }
    ' "$plan_file")
    plan_checked=$(echo "$parsed" | cut -d' ' -f1)
    plan_total=$(echo "$parsed" | cut -d' ' -f2)
    plan_label=$(echo "$parsed" | cut -d' ' -f3-)

    if [ -n "$plan_total" ] && [ "$plan_total" -gt 0 ] && [ "$plan_checked" -lt "$plan_total" ]; then
      plan_filled=$((plan_checked * 10 / plan_total))
      plan_empty=$((10 - plan_filled))
      plan_bar=$(printf '%*s' "$plan_filled" '' | tr ' ' '█')$(printf '%*s' "$plan_empty" '' | tr ' ' '░')
      plan_name=$(basename "$plan_file" .md | sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}-//')
      plan_label=$(echo "$plan_label" | cut -c1-28)
      plan_seg="$plan_name $plan_bar $plan_checked/$plan_total"
      [ -n "$plan_label" ] && plan_seg="$plan_seg $plan_label"
    fi
  fi
fi

segments=("$model" "$email")
[ -n "$plan_seg" ] && segments+=("$plan_seg")
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
