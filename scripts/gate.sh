#!/usr/bin/env bash
# hydratype local gate — mechanized verification (Mechanize-not-md axiom).
# Builds HydraCore, runs the framework-free logic gate, then the XCTest suite.
# Exits non-zero LOUDLY on any failure so the cicada pre-push hook can block.
# Requires the Xcode toolchain (FoundationModels macros); see Packages/HydraCore/README.md.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKG="$ROOT/Packages/HydraCore"

# Change-scoped gating: when GATE_DIFF_BASE is set (the pre-push hook sets it to
# origin/hee-haw), skip the SLOW swift build+test for docs-only pushes. FAIL-CLOSED:
# we only skip when confident the push is docs-only — a non-empty diff AND every
# changed path is a docs type (.md/.markdown/.txt/.html or under docs/). Any
# code/config/script change, an empty diff (git error), or an unknown extension
# runs the FULL gate. Without GATE_DIFF_BASE (local `scripts/gate.sh`, CI), the
# FULL gate always runs.
SWIFT_RELEVANT=1
if [ -n "${GATE_DIFF_BASE:-}" ]; then
  # Validate GATE_DIFF_BASE is a safe ref before interpolating into git
  # (security: avoid sink-arg injection if the value were ever attacker-controlled).
  case "$GATE_DIFF_BASE" in
    *[!A-Za-z0-9/._-]*)
      echo "[gate] refusing unsafe GATE_DIFF_BASE "$GATE_DIFF_BASE" — running full gate" >&2
      CHANGED=""
      ;;
    *)
      CHANGED="$(git diff --name-only "${GATE_DIFF_BASE}...HEAD" 2>/dev/null || true)"
      ;;
  esac
  # grep -vqE: exit 0 if ANY line is NOT a docs type; ! it => all lines are docs.
  if [ -n "$CHANGED" ] && ! echo "$CHANGED" | grep -vqE '\.(md|markdown|txt|html)$|^docs/'; then
    SWIFT_RELEVANT=0
    echo "[gate] docs-only change vs ${GATE_DIFF_BASE} — skipping swift build/test"
  fi
fi

if [ "$SWIFT_RELEVANT" = "1" ]; then
  echo "[gate] swift build (HydraCore)…"
  ( cd "$PKG" && swift build --disable-sandbox )

  # swift run triggers sandboxed manifest re-evaluation, so run the binary directly.
  echo "[gate] run hydracore-check (logic gate)…"
  ( cd "$PKG" && .build/debug/hydracore-check )

  echo "[gate] swift test (XCTest)…"
  ( cd "$PKG" && swift test --disable-sandbox )
fi

echo "[gate] erebus deck integrity (Compact constitution stays synced)…"
( cd "$ROOT" && ./scripts/check-erebus-sync.sh )

echo "[gate] PASS"
