#!/usr/bin/env bash
# check-erebus-sync — mechanized Erebus Compact integrity check (Mechanize-not-md axiom).
# The hydrav11 deck is authored as deck/hydrav11/{index.html,erebus-compact.html} and inlined
# into deck/hydrav11/worker.js at deploy time. Those copies drift silently; this gate fails
# LOUDLY if they diverge, and if the worker does not parse.
#
# Verifies:
#   1. deck/hydrav11/index.html       ==  the landing-page block inlined in worker.js
#   2. deck/hydrav11/erebus-compact.html == the const EREBUS_COMPACT block inlined in worker.js
#   3. node --check worker.js
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DECK="$ROOT/deck/hydrav11"
WORKER="$DECK/worker.js"
INDEX="$DECK/index.html"
COMPACT="$DECK/erebus-compact.html"

fail() { echo "[erebus-sync] FAIL: $1" >&2; exit 1; }

[ -f "$WORKER" ] || fail "worker.js missing: $WORKER"
[ -f "$INDEX" ] || fail "index.html missing: $INDEX"
[ -f "$COMPACT" ] || fail "erebus-compact.html missing: $COMPACT"

echo "[erebus-sync] checking deck copies vs inlined worker.js blocks…"

# Use python3 to extract the exact inlined blocks (robust to template-literal framing).
python3 - "$INDEX" "$COMPACT" "$WORKER" <<'PY'
import re, sys
index_path, compact_path, worker_path = sys.argv[1:4]
w = open(worker_path).read()

def strip_trailing_nl(s):
    return s[:-1] if s.endswith("\n") else s

# Compact block: const EREBUS_COMPACT = `...`;
m = re.search(r'const EREBUS_COMPACT = `(.*?)`;', w, re.S)
if not m:
    print("COMPACT_BLOCK=missing"); sys.exit(2)
compact_embedded = m.group(1)
compact_src = open(compact_path).read()
if compact_embedded != strip_trailing_nl(compact_src):
    print("COMPACT_BLOCK=DRIFT"); sys.exit(3)
print("COMPACT_BLOCK=ok")

# Landing block: everything from the first <!DOCTYPE> up to (but excluding) the
# `const EREBUS_COMPACT` template, taken to its closing </html>.
head = w[: w.find('const EREBUS_COMPACT')]
doctype = head.find('<!DOCTYPE')
if doctype < 0:
    print("LANDING_BLOCK=missing"); sys.exit(4)
html_end = head.rfind('</html>')
if html_end < 0:
    print("LANDING_BLOCK=missing"); sys.exit(4)
landing_embedded = head[doctype:html_end + len('</html>')]
landing_src = open(index_path).read()
if landing_embedded != strip_trailing_nl(landing_src):
    print("LANDING_BLOCK=DRIFT"); sys.exit(5)
print("LANDING_BLOCK=ok")
PY
status=$?
if [ "$status" -ne 0 ]; then
  case "$status" in
    2) fail "worker.js has no EREBUS_COMPACT block" ;;
    3) fail "erebus-compact.html drifted from its inlined worker.js copy — run a sync" ;;
    4) fail "worker.js has no inlined landing page" ;;
    5) fail "index.html drifted from its inlined worker.js copy — run a sync" ;;
    *) fail "erebus sync check exited $status" ;;
  esac
fi

echo "[erebus-sync] node --check worker.js…"
node --check "$WORKER"

echo "[erebus-sync] PASS"
