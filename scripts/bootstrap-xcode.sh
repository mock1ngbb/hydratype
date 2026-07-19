#!/usr/bin/env bash
# Generate HydraType.xcodeproj from project.yml (the source of truth). Idempotent.
# Run after cloning/pulling, or after editing project.yml. LOUD on missing tooling.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "[bootstrap] xcodegen not found — installing via Homebrew…" >&2
    if ! command -v brew >/dev/null 2>&1; then
        echo "[bootstrap] FATAL: neither xcodegen nor brew is available. Install XcodeGen: https://github.com/yonaskolb/XcodeGen" >&2
        exit 1
    fi
    brew install xcodegen
fi

echo "[bootstrap] xcodegen generate…"
xcodegen generate

echo "[bootstrap] done. Open HydraType.xcodeproj in Xcode (targets: HydraType, HydraTypeKeyboard)."
echo "[bootstrap] Compile-verify headlessly:"
echo "  xcodebuild -project HydraType.xcodeproj -scheme HydraType \\"
echo "    -destination 'generic/platform=iOS Simulator' -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build"
