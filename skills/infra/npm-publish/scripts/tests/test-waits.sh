#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail=0

check() {
  if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: expected [$2] got [$3]"; fail=1; fi
}

unlock() {
  NPM_BW_SESSION_FILE="$TMP/session" NPM_BW_WAIT_SECS="$1" bash "$HERE/wait-for-unlock.sh" 2>&1
}

: > "$TMP/session"
check "unlock: empty file times out" TIMEOUT "$(unlock 1)"

printf 'SECRET-SESSION-KEY' > "$TMP/session"
check "unlock: filled file is ready, key never echoed" READY "$(unlock 1)"

: > "$TMP/session"
( sleep 1; printf 'k' > "$TMP/session" ) &
check "unlock: file filled mid-wait" READY "$(unlock 6)"
wait

mkdir "$TMP/bin"
cat > "$TMP/bin/npm" <<'FAKE'
#!/usr/bin/env bash
n=$(( $(cat "$FAKE_NPM_COUNT" 2>/dev/null || echo 0) + 1 ))
echo "$n" > "$FAKE_NPM_COUNT"
echo "$*" >> "$FAKE_NPM_ARGS"
if [ "$n" -ge "$FAKE_NPM_LIVE_AT" ]; then echo "1.4.2"; else echo "npm error code E404" >&2; exit 1; fi
FAKE
chmod +x "$TMP/bin/npm"

registry() {
  rm -f "$TMP/count"
  PATH="$TMP/bin:$PATH" FAKE_NPM_COUNT="$TMP/count" FAKE_NPM_ARGS="$TMP/args" \
    FAKE_NPM_LIVE_AT="$1" NPM_REGISTRY_WAIT_SECS="$2" NPM_REGISTRY_POLL_SECS=1 \
    bash "$HERE/wait-for-registry.sh" @m4ttheweric/glance-cli 1.4.2 2>&1
}

check "registry: live on first poll" LIVE "$(registry 1 3)"
if grep -q -- '--prefer-online' "$TMP/args"; then echo "ok   registry: uses --prefer-online"; else echo "FAIL registry: missing --prefer-online"; fail=1; fi
check "registry: live after lag" LIVE "$(registry 3 5)"
check "registry: lag outlasts the cap" LAG_EXPIRED "$(registry 99 2)"

set +e
bash "$HERE/wait-for-registry.sh" only-one-arg >/dev/null 2>&1
check "registry: wrong arg count exits 2" 2 "$?"
set -e

if grep -vE '^[[:space:]]*#' "$HERE/wait-for-unlock.sh" \
  | grep -nE '\bcat\b|<[[:space:]]*"?\$|\bread\b|(^|[[:space:];|&(])bw[[:space:]]|set -x'; then
  echo "FAIL unlock: script reads the session key, calls bw or traces"; fail=1
else
  echo "ok   unlock: never reads the session key"
fi
if grep -vE '^[[:space:]]*#' "$HERE/wait-for-registry.sh" \
  | grep -nE '(^|[[:space:];|&(])bw[[:space:]]|npm-bw|SESSION'; then
  echo "FAIL registry: script touches bw or the session file"; fail=1
else
  echo "ok   registry: never touches bw"
fi

exit "$fail"
