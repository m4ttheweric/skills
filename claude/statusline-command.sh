#!/bin/bash
# Claude Code status line: shows the active model (abbreviated to its first
# letter), account email, an in-progress superpowers plan's completion (when
# one is found for this workspace), the Fable weekly pool (F, Fable sessions
# only), weekly usage (W) and context usage (C).

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

# Usage values carry cswap's severity ramp (claude-swap tui/theme.py): green
# under 70%, amber from 70%, soft red from 90%, so the statusline and cswap's
# TUI agree on when a pool is "climbing" or "near the limit". Labels stay the
# default color; only the value is colored.
sev_pct() {
  local p
  p=$(printf '%.0f' "$1")
  if [ "$p" -ge 90 ]; then
    printf '\033[38;2;215;95;95m%s%%\033[0m' "$p"
  elif [ "$p" -ge 70 ]; then
    printf '\033[38;2;215;175;95m%s%%\033[0m' "$p"
  else
    printf '\033[38;2;135;175;135m%s%%\033[0m' "$p"
  fi
}
usage=""
[ -n "$fable" ] && usage="${usage}F:$(sev_pct "$fable") "
[ -n "$week" ] && usage="${usage}W:$(sev_pct "$week") "
[ -n "$context" ] && usage="${usage}C:$(sev_pct "$context")"
usage="${usage% }"

# In-progress superpowers implementation. Candidate roots are cwd, then
# worktree, then project root; each signal is searched across all of them in
# that order, so a checkout's docs/superpowers/plans/ never hides a worktree's
# live ledger.
#
# Primary signal: the subagent-driven-development / executing-plans ledger at
# .superpowers/sdd/<plan-basename>/progress.md. Its first line names the plan
# file, and each finished task gets a `Task <N>: complete (...)` line; the
# plan's checkboxes are NOT updated during these runs, so they can't measure
# progress there. Only a ledger touched in the last 7 days counts as ongoing
# (stale ledgers are abandoned or superseded work). The match is anchored at
# line start: free-text ledger notes mention tasks and the word "complete"
# ("Task 6: dispatched (... complete code in brief)") without finishing them.
#
# Finished plans: both skills delete the plan's workspace once the final
# review is clean, so a finished plan is read from rt's shared record
# (`rt progress list --tree <root> --refresh --json`, which records first so a
# finish stored after the workspace delete shows at once), asked only when no live ledger is
# found and <root>/.superpowers/sdd exists. A plan rt calls done shows as done
# for a day. An rt without the verb prints nothing here.
#
# A task is done when its `Task <N>: complete` line exists, or when every
# lettered part the ledger mentions (`Task <N>a:` ...) has a complete line.
#
# Fallback: a plan under docs/superpowers/plans/ (.local-dev/superpowers/plans/
# in repos that keep plans untracked) with SOME boxes checked, for work tracked
# by checkboxes instead of a ledger. Untouched plans (0 checked) stay hidden: a
# written plan is not an ongoing implementation.
plan_seg=""
plan_checked="" plan_total="" plan_name="" plan_done=""
sp_cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
sp_worktree=$(echo "$input" | jq -r '.worktree.path // empty')
sp_project=$(echo "$input" | jq -r '.workspace.project_dir // empty')

# Count of done tasks in a ledger under the lettered rule (same as rt's
# countDoneTasks).
sdd_done_tasks() {
  awk '
    /^Task[ \t]+[0-9]+[a-z]?:/ {
      head = $0; sub(/^Task[ \t]+/, "", head)
      n = head; sub(/[^0-9].*/, "", n)
      letter = substr(head, length(n) + 1, 1)
      if (letter !~ /[a-z]/) letter = ""
      c = ($0 ~ /^Task[ \t]+[0-9]+[a-z]?:[ \t]*complete([^A-Za-z0-9_]|$)/)
      if (letter == "") { if (c) whole[n] = 1; next }
      part[n, letter] = 1
      if (c) pdone[n, letter] = 1
    }
    END {
      for (n in whole) count++
      for (k in part) { split(k, a, SUBSEP); if (!(a[1] in whole)) cand[a[1]] = 1 }
      for (n in cand) {
        ok = 1
        for (k in part) { split(k, a, SUBSEP); if (a[1] == n && !(k in pdone)) ok = 0 }
        if (ok) count++
      }
      print count + 0
    }
  ' "$1"
}

for sp_r in "$sp_cwd" "$sp_worktree" "$sp_project"; do
  [ -n "$sp_r" ] || continue
  ledger=$(ls -t "$sp_r"/.superpowers/sdd/*/progress.md 2>/dev/null | head -1)
  [ -n "$ledger" ] && [ -n "$(find "$ledger" -mtime -7 2>/dev/null)" ] &&
    head -1 "$ledger" | grep -q '^# SDD ledger' || continue
  sdd_plan=$(head -1 "$ledger" | sed 's/.*plan:[[:space:]]*//')
  case "$sdd_plan" in
    /*) : ;;
    *) sdd_plan="$sp_r/$sdd_plan" ;;
  esac
  [ -f "$sdd_plan" ] || continue
  plan_total=$(grep -cE '^##+ Task [0-9]+[:.]' "$sdd_plan")
  plan_checked=$(sdd_done_tasks "$ledger")
  plan_name=$(basename "$sdd_plan" .md | sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}-//')
  break
done

if [ -z "$plan_total" ]; then
  sp_cut=$(( ($(date +%s) - 86400) * 1000 ))
  sp_asked=""
  for sp_r in "$sp_cwd" "$sp_worktree" "$sp_project"; do
    [ -n "$sp_r" ] && [ -d "$sp_r/.superpowers/sdd" ] || continue
    sp_real=$(cd "$sp_r" 2>/dev/null && pwd -P) || continue
    case "$sp_asked" in *"|$sp_real|"*) continue ;; esac
    sp_asked="$sp_asked|$sp_real|"
    done_stem=$(rt progress list --tree "$sp_r" --refresh --json 2>/dev/null |
      jq -r --argjson cut "$sp_cut" '[.plans[]? | select(.state == "done" and (.finishedAt // 0) > $cut)] | sort_by(.finishedAt) | last | .stem // empty' 2>/dev/null)
    if [ -n "$done_stem" ]; then
      plan_name=$(echo "$done_stem" | sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}-//')
      plan_done=1
      break
    fi
  done
fi

if [ -z "$plan_done" ] && { [ -z "$plan_total" ] || [ "$plan_total" -eq 0 ]; }; then
  plans_dir=""
  for sp_r in "$sp_cwd" "$sp_worktree" "$sp_project"; do
    [ -n "$sp_r" ] || continue
    for sp_rel in ".local-dev/superpowers/plans" "docs/superpowers/plans"; do
      if [ -d "$sp_r/$sp_rel" ]; then
        plans_dir="$sp_r/$sp_rel"
        break 2
      fi
    done
  done

  plan_file=$(ls -t "$plans_dir"/*.md 2>/dev/null | head -1)
  if [ -n "$plan_file" ]; then
    parsed=$(awk '
      /^[ \t]*-[ \t]*\[[ xX]\]/ {
        total++
        if ($0 ~ /\[[xX]\]/) { checked++ }
      }
      END { printf "%d %d\n", checked+0, total+0 }
    ' "$plan_file")
    plan_checked=$(echo "$parsed" | cut -d' ' -f1)
    plan_total=$(echo "$parsed" | cut -d' ' -f2)
    plan_name=$(basename "$plan_file" .md | sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}-//')
    # Checkbox mode needs at least one checked box to count as ongoing.
    [ -n "$plan_checked" ] && [ "$plan_checked" -eq 0 ] && plan_total=0
  fi
fi

if [ -n "$plan_done" ] ||
   { [ -n "$plan_total" ] && [ "$plan_total" -gt 0 ] &&
     [ -n "$plan_checked" ] && [ "$plan_checked" -ge "$plan_total" ]; }; then
  plan_seg=$(printf "%s \033[38;5;77m✅\033[0m" "$plan_name")
elif [ -n "$plan_total" ] && [ "$plan_total" -gt 0 ] &&
   [ -n "$plan_checked" ]; then
  plan_filled=$((plan_checked * 10 / plan_total))
  plan_empty=$((10 - plan_filled))
  plan_pct=$((plan_checked * 100 / plan_total))
  if [ "$plan_pct" -lt 34 ]; then
    bar_color='\033[38;5;208m'
  elif [ "$plan_pct" -lt 67 ]; then
    bar_color='\033[38;5;220m'
  else
    bar_color='\033[38;5;77m'
  fi
  plan_seg=$(printf "%s ${bar_color}%s\033[0m%s %s" \
    "$plan_name" \
    "$(printf '%*s' "$plan_filled" '' | tr ' ' '█')" \
    "$(printf '%*s' "$plan_empty" '' | tr ' ' '░')" \
    "$plan_checked/$plan_total")
fi

segments=("$model" "$email")
[ -n "$plan_seg" ] && segments+=("$plan_seg")
[ -n "$usage" ] && segments+=("$usage")

out=""
for seg in "${segments[@]}"; do
  if [ -z "$out" ]; then
    out="$seg"
  else
    out="$out | $seg"
  fi
done
printf '%s\n' "$out"
