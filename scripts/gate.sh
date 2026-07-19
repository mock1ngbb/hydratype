#!/usr/bin/env bash
# hydratype local gate — mechanized verification (Mechanize-not-md axiom).
# Runs the HydraCore build + the framework-free logic gate. Exits non-zero LOUDLY on
# any failure so the cicada pre-push hook can block. Does NOT require a full Xcode
# toolchain (the XCTest suite does; see Packages/HydraCore/README.md).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKG="$ROOT/Packages/HydraCore"

echo "[gate] swift build (HydraCore, no HYDRA_AFM)…"
( cd "$PKG" && swift build )

echo "[gate] swift run hydracore-check…"
( cd "$PKG" && swift run hydracore-check )

echo "[gate] PASS"
