#!/usr/bin/env bash
# Render every ```dot block in a SKILL.md to SVG. Dependency-free (needs graphviz `dot`).
# Usage: render.sh [path/to/SKILL.md] [out-dir]
#   defaults: SKILL.md next to this script; out-dir a fresh temp dir (path printed at the end).
# Exit non-zero if any block fails to parse, so it doubles as a verify gate.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
md="${1:-$here/SKILL.md}"
out="${2:-$(mktemp -d)}"

command -v dot >/dev/null 2>&1 || { echo "graphviz 'dot' not found (brew install graphviz)"; exit 1; }
[ -f "$md" ] || { echo "no SKILL.md at: $md"; exit 1; }
mkdir -p "$out"

# Split out each fenced dot block. Fence lines must start the line, so inline
# mentions of the fence in prose or the description are ignored.
awk -v out="$out" '
  /^```dot$/       { inblk=1; body=""; next }
  inblk && /^```$/ {
    inblk=0
    name="graph_" (++n)
    if (match(body, /digraph[ \t]+[A-Za-z0-9_]+/)) {
      nm=substr(body, RSTART, RLENGTH); sub(/digraph[ \t]+/, "", nm); name=nm
    }
    path=out "/" name ".dot"; printf "%s", body > path; close(path); print path; next
  }
  inblk            { body=body $0 "\n" }
' "$md" > "$out/.blocks"

count=0; fail=0
while IFS= read -r dotf; do
  count=$((count+1)); svg="${dotf%.dot}.svg"; log="${dotf%.dot}.err"
  if dot -Tsvg "$dotf" -o "$svg" 2>"$log"; then
    echo "ok    $(basename "$svg")"
  else
    fail=$((fail+1)); echo "FAIL  $(basename "$dotf")"; sed 's/^/        /' "$log"
  fi
done < "$out/.blocks"
rm -f "$out/.blocks"

echo "---"
echo "$count block(s), $fail failed  ->  $out"
[ "$fail" -eq 0 ]
