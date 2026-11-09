#!/usr/bin/env bash
# verify.sh — hydratype landing verifier: the erebus deck sync check, then the
# Swift gate (scripts/gate.sh: HydraCore build, hydracore-check, XCTest), which needs full Xcode.
#
# trunkq (bifrost-bridge tools/trunkq) runs this in the candidate checkout as
#   bash scripts/verify.sh --base <trunk-sha>
# Exit 0 pass, 1 fail (a check failed), 2 could-not-run (a tool is missing or
# setup failed; never a pass). Steps run in order and stop at the first red.
# The last stdout line is always
#   VERIFY {"verdict":"pass|fail|could-not-run","base":..,"head":..,"steps":[{"name":..,"rc":..}]}
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE

# The Swift gate needs FULL Xcode (HydraCore uses FoundationModels macros); the Command
# Line Tools ship an xcodebuild that only errors. No Xcode means nothing Swift was
# verified: the 'xcode' setup step makes that could-not-run (2), never a pass.

BASE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --base) BASE="${2:-}"; shift 2 ;;
    *) echo "verify.sh: unknown argument $1" >&2; echo 'VERIFY {"verdict":"could-not-run","steps":[]}'; exit 2 ;;
  esac
done
HEAD_SHA="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
STEPS=""

finish() {  # <verdict> <exit>
  printf 'VERIFY {"verdict":"%s","base":"%s","head":"%s","steps":[%s]}\n' "$1" "$BASE" "$HEAD_SHA" "${STEPS#,}"
  exit "$2"
}

# step <setup|check> <name> <comma-separated tools> <command>
step() {
  local kind="$1" name="$2" tools="$3" cmd="$4" t rc
  for t in ${tools//,/ }; do
    if ! command -v "$t" >/dev/null 2>&1; then
      echo "verify.sh: $name: required tool '$t' is not on PATH; nothing was verified." >&2
      STEPS="$STEPS,{\"name\":\"$name\",\"rc\":127}"
      finish could-not-run 2
    fi
  done
  echo "== $name" >&2
  bash -c "$cmd"
  rc=$?
  STEPS="$STEPS,{\"name\":\"$name\",\"rc\":$rc}"
  if [ "$rc" -ne 0 ]; then
    if [ "$kind" = setup ]; then
      echo "verify.sh: setup step $name failed (rc=$rc); nothing was verified." >&2
      finish could-not-run 2
    fi
    echo "verify.sh: $name FAILED (rc=$rc)." >&2
    finish fail 1
  fi
}


step check 'erebus-sync' 'node' 'bash scripts/check-erebus-sync.sh'
step setup 'xcode' 'xcodebuild' 'xcodebuild -version'
step check 'swift-gate' 'swift' 'bash scripts/gate.sh'

finish pass 0
