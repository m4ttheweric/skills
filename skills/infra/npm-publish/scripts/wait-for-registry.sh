#!/usr/bin/env bash
# Waits out npm's 3 to 5 minute registry lag after a publish. npm's own
# output is discarded so only the result word reaches the caller. Prints
# LIVE or LAG_EXPIRED; exit 0 either way.
#
# Usage: wait-for-registry.sh <name> <version>
# Overridable via env: NPM_REGISTRY_WAIT_SECS (default 360),
# NPM_REGISTRY_POLL_SECS (default 30).
set -uo pipefail

[ $# -eq 2 ] || { echo "usage: wait-for-registry.sh <name> <version>" >&2; exit 2; }
NAME="$1"
VERSION="$2"
WAIT_SECS="${NPM_REGISTRY_WAIT_SECS:-360}"
POLL_SECS="${NPM_REGISTRY_POLL_SECS:-30}"

is_live() {
  [ "$(npm view "$NAME@$VERSION" version --prefer-online 2>/dev/null)" = "$VERSION" ]
}

deadline=$(( $(date +%s) + WAIT_SECS ))
while :; do
  if is_live; then
    echo LIVE
    exit 0
  fi
  [ "$(date +%s)" -ge "$deadline" ] && break
  sleep "$POLL_SECS"
done
echo LAG_EXPIRED
