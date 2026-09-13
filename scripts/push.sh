#!/usr/bin/env bash
# ── Pragmatic Law ────────────────────────────────────────────────────────────
# Solving the full problem once is always faster than deferring it.
# This gate exists because catching failures here is strictly cheaper than
# catching them downstream. Never weaken, skip, or defer.
# ─────────────────────────────────────────────────────────────────────────────
#
# The push entrypoint for hydratype.
#
# It is deliberately thin: the gate is scripts/hooks/pre-push, which git runs
# for every push once core.hooksPath points at scripts/hooks (see
# scripts/install-git-hooks.sh). Duplicating the gate here would mean two
# places to keep in step and one of them silently drifting.
#
# What this file DOES add is a check that the gate can run at all. Pushing from
# a clone whose core.hooksPath was never set runs NO hook — that is the exact
# unenforced-and-silent state this repo's Layer 1 work exists to end — so that
# state is refused here rather than discovered later.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

hp="$(git -C "$ROOT" config --get core.hooksPath || true)"
if [ "$hp" != "scripts/hooks" ]; then
  echo "[push] REFUSED: core.hooksPath is '${hp:-unset}', not 'scripts/hooks'." >&2
  echo "[push] The tracked pre-push gate would not run for this push, so nothing" >&2
  echo "[push] would be verified. Fix it once per clone:" >&2
  echo "[push]   bash scripts/install-git-hooks.sh" >&2
  exit 1
fi

if [ ! -x "$ROOT/scripts/hooks/pre-push" ]; then
  echo "[push] REFUSED: $ROOT/scripts/hooks/pre-push is missing or not executable." >&2
  exit 1
fi

exec git -C "$ROOT" push "$@"
