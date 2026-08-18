#!/usr/bin/env bash
# Hand the CURRENT Claude Code session off to another cswap account: split a
# new herdr pane, park a waiter there that resumes this session (same session
# ID, no fork) under the target account once the origin claude has exited,
# then queue /exit into the origin pane.
#
# Usage:
#   account-hop.sh -a <account> [-m <model>] [-d <direction>] [-T <timeout-s>]
#                  [-p <origin-pane>] [-P <origin-pid>] [-s <session-id>]
#                  [-c <cwd>] [-X] [-F] [-O]
#
#   -a  Target cswap account (email or list number). Required.
#   -m  Model alias for `claude --model`. Default: none (claude's default).
#   -d  Split direction: right|down|left|up. Default: right.
#   -T  Waiter timeout in seconds. Default: 300.
#   -p  Origin pane id.        Default: $HERDR_PANE_ID.
#   -P  Origin claude pid.     Default: $CLAUDE_PID.
#   -s  Session id to resume.  Default: $CLAUDE_CODE_SESSION_ID.
#   -c  Working dir for resume. Default: $PWD.
#   -X  Do NOT queue /exit into the origin pane (testing / manual exit).
#   -F  Do NOT focus the new pane.
#   -O  Keep the origin pane open after the hop (default: close it once the
#       origin claude has exited).
#
# Prints a summary block on stdout. Progress goes to stderr.
set -euo pipefail

usage() { sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }

ACCOUNT=""
MODEL=""
DIRECTION="right"
TIMEOUT=300
ORIGIN_PANE="${HERDR_PANE_ID:-}"
ORIGIN_PID="${CLAUDE_PID:-}"
SESSION_ID="${CLAUDE_CODE_SESSION_ID:-}"
HOP_CWD="$PWD"
SEND_EXIT=1
FOCUS=1
KEEP_ORIGIN=0
while getopts "a:m:d:T:p:P:s:c:XFOh" opt; do
  case "$opt" in
    a) ACCOUNT="$OPTARG" ;;
    m) MODEL="$OPTARG" ;;
    d) DIRECTION="$OPTARG" ;;
    T) TIMEOUT="$OPTARG" ;;
    p) ORIGIN_PANE="$OPTARG" ;;
    P) ORIGIN_PID="$OPTARG" ;;
    s) SESSION_ID="$OPTARG" ;;
    c) HOP_CWD="$OPTARG" ;;
    X) SEND_EXIT=0 ;;
    F) FOCUS=0 ;;
    O) KEEP_ORIGIN=1 ;;
    *) usage ;;
  esac
done

log() { echo "account-hop: $*" >&2; }
die() { echo "account-hop: $*" >&2; exit 1; }

# 1. Environment checks.
[ "${HERDR_ENV:-}" = "1" ] || die "not inside herdr (HERDR_ENV != 1)"
command -v herdr >/dev/null || die "herdr not on PATH"
CSWAP="$(command -v cswap || true)"
[ -n "$CSWAP" ] || CSWAP="$HOME/.local/bin/cswap"
[ -x "$CSWAP" ] || die "cswap not found (PATH or ~/.local/bin)"

[ -n "$ACCOUNT" ]     || { usage; }
[ -n "$ORIGIN_PANE" ] || die "no origin pane (-p or \$HERDR_PANE_ID)"
[ -n "$ORIGIN_PID" ]  || die "no origin claude pid (-P or \$CLAUDE_PID)"
[ -n "$SESSION_ID" ]  || die "no session id (-s or \$CLAUDE_CODE_SESSION_ID)"

# 2. Resolve the account to exactly one row via the JSON listing. Matching is
#    EXACT on number, email, or alias -- a family name like "bouncer" must
#    fail HERE, because after the split a bad account strands the user with
#    no session.
ACCOUNT="$("$CSWAP" list --json 2>/dev/null | python3 -c '
import sys, json
want = sys.argv[1].strip().lower()
try:
    accounts = json.load(sys.stdin)["accounts"]
except Exception:
    print("account-hop: cswap list --json failed or emitted non-JSON", file=sys.stderr)
    sys.exit(1)
hits = [a for a in accounts
        if want in (str(a.get("number")), a.get("email", "").lower())]
if len(hits) != 1:
    kind = "ambiguous" if hits else "not an exact number/email"
    print(f"account-hop: account {sys.argv[1]!r} {kind}. Accounts:", file=sys.stderr)
    for a in accounts:
        print("  {} {}".format(a.get("number"), a.get("email")), file=sys.stderr)
    sys.exit(1)
acct = hits[0]
# A dead account fails only AFTER the origin claude has exited, stranding the
# user with no session -- refuse permanently-broken auth up front.
status = acct.get("usageStatus", "ok")
if status in ("relogin_required", "no_credentials", "api_key"):
    print("account-hop: account {} is unusable (usageStatus={}); "
          "refusing to hop".format(acct["email"], status), file=sys.stderr)
    sys.exit(1)
if status != "ok":
    print("account-hop: warning: {} usageStatus={}; proceeding".format(
        acct["email"], status), file=sys.stderr)
print(acct["email"])
' "$ACCOUNT")" || exit 1

# 3. The origin pid must be alive NOW. A stale pid would release the waiter
#    immediately -- two claudes on one session file, the exact hazard the
#    waiter exists to prevent.
kill -0 "$ORIGIN_PID" 2>/dev/null \
  || die "origin pid $ORIGIN_PID is not alive; refusing to hop (check \$CLAUDE_PID / -P)"
log "account -> $ACCOUNT  session -> $SESSION_ID  pid -> $ORIGIN_PID"

# 4. Split the origin pane. The new pane takes focus by default: the user is
#    moving there.
FOCUS_ARGS=""
[ "$FOCUS" = "0" ] && FOCUS_ARGS="--no-focus"
PANE="$(herdr pane split "$ORIGIN_PANE" --direction "$DIRECTION" $FOCUS_ARGS \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["result"]["pane"]["pane_id"])')"
log "split pane $PANE ($DIRECTION)"

# 5. Write the waiter and start it in the new pane. It resumes only after the
#    origin claude process is gone, so two claudes never share the session
#    file. --share-history is not optional: without it cswap unlinks the
#    profile's history and --resume cannot see this session's transcript.
MODEL_ARGS=""
[ -n "$MODEL" ] && MODEL_ARGS="--model '$MODEL'"
# Close the origin pane once its claude is gone -- by then it is a bare shell.
# Only on the success path: on timeout the user may still be working there.
CLOSE_LINE="herdr pane close '$ORIGIN_PANE' >/dev/null 2>&1 || true"
[ "$KEEP_ORIGIN" = "1" ] && CLOSE_LINE=": origin pane kept open (-O)"
WAITER_DIR="$HOME/.cache/account-hop"
mkdir -p "$WAITER_DIR"
WAITER="$WAITER_DIR/waiter-$SESSION_ID.sh"
cat > "$WAITER" <<EOF
#!/usr/bin/env bash
cd '$HOP_CWD' 2>/dev/null || cd "\$HOME"
RESUME="'$CSWAP' run '$ACCOUNT' --share-history -- --resume '$SESSION_ID' $MODEL_ARGS"
echo "account-hop: waiting for origin claude (pid $ORIGIN_PID) to exit..."
i=0
while kill -0 '$ORIGIN_PID' 2>/dev/null; do
  sleep 1; i=\$((i+1))
  if [ "\$i" -ge '$TIMEOUT' ]; then
    echo "account-hop: origin claude still alive after ${TIMEOUT}s."
    echo "account-hop: exit it yourself, then run:"
    echo "  \$RESUME"
    exit 1
  fi
done
echo "account-hop: origin exited -- resuming as $ACCOUNT"
$CLOSE_LINE
rm -f -- "\$0"
eval exec "\$RESUME"
EOF
chmod +x "$WAITER"
herdr pane run "$PANE" "bash '$WAITER'" >/dev/null
log "waiter running in $PANE"

# 6. Queue /exit into the origin pane. While claude is mid-turn it sits in the
#    input buffer and submits when the turn ends; if it gets lost, a manual
#    exit still releases the waiter.
if [ "$SEND_EXIT" = "1" ]; then
  herdr pane send-text "$ORIGIN_PANE" "/exit" >/dev/null
  herdr pane send-keys "$ORIGIN_PANE" Enter >/dev/null
  log "queued /exit into $ORIGIN_PANE"
fi

echo "pane: $PANE"
echo "account: $ACCOUNT"
echo "model: ${MODEL:-default}"
echo "session: $SESSION_ID"
echo "exit_queued: $([ "$SEND_EXIT" = "1" ] && echo yes || echo no)"
echo "origin_close: $([ "$KEEP_ORIGIN" = "0" ] && echo yes || echo no)"
