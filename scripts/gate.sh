#!/usr/bin/env bash
# hydratype local gate — mechanized verification (Mechanize-not-md axiom).
# Builds HydraCore, runs the framework-free logic gate, then the XCTest suite.
# Exits non-zero LOUDLY on any failure so the cicada pre-push hook can block.
# Requires the Xcode toolchain (FoundationModels macros); see Packages/HydraCore/README.md.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKG="$ROOT/Packages/HydraCore"

echo "[gate] swift build (HydraCore)…"
( cd "$PKG" && swift build --disable-sandbox )

# swift run triggers sandboxed manifest re-evaluation, so run the binary directly.
echo "[gate] run hydracore-check (logic gate)…"
( cd "$PKG" && .build/debug/hydracore-check )

echo "[gate] swift test (XCTest)…"
( cd "$PKG" && swift test --disable-sandbox )

echo "[gate] PASS"
