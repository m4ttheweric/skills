#!/usr/bin/env bash
# Waits for bw-unlock.sh's Terminal window to write the session file. Only
# tests that the file is non-empty: the vault session key inside it must
# never reach this script's output. Prints READY or TIMEOUT; exit 0 either way.
#
# Overridable via env: NPM_BW_SESSION_FILE, NPM_BW_WAIT_SECS (default 300).
set -uo pipefail

SESSION_FILE="${NPM_BW_SESSION_FILE:-$HOME/.cache/npm-bw.session}"
WAIT_SECS="${NPM_BW_WAIT_SECS:-300}"

deadline=$(( $(date +%s) + WAIT_SECS ))
while [ "$(date +%s)" -lt "$deadline" ]; do
  if [ -s "$SESSION_FILE" ]; then
    echo READY
    exit 0
  fi
  sleep 2
done
if [ -s "$SESSION_FILE" ]; then echo READY; else echo TIMEOUT; fi
