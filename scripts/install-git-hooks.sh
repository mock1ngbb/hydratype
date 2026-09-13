#!/usr/bin/env bash
# ── Pragmatic Law ────────────────────────────────────────────────────────────
# Solving the full problem once is always faster than deferring it.
# This gate exists because catching failures here is strictly cheaper than
# catching them downstream. Never weaken, skip, or defer.
# ─────────────────────────────────────────────────────────────────────────────
#
# Points git at this repo's TRACKED hooks and re-composes the stygian managed
# block into the newly effective hook.
#
# Run once per clone / worktree:  bash scripts/install-git-hooks.sh
#
# Without this, git reads .git/hooks/ — which is untracked, so a fresh clone has
# no build gate and no cicada Layer 1 while looking identically configured.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

git -C "$ROOT" config core.hooksPath scripts/hooks
echo "[install-git-hooks] core.hooksPath -> scripts/hooks"

# stygian-hooks-install resolves the EFFECTIVE hook (it honours core.hooksPath)
# and is idempotent, so re-running it moves its managed block onto the tracked
# hook instead of leaving it stranded in the now-ignored .git/hooks/pre-push.
if command -v stygian-hooks-install >/dev/null 2>&1; then
  stygian-hooks-install "$ROOT" || {
    echo "[install-git-hooks] WARNING: stygian-hooks-install failed; its managed block" >&2
    echo "[install-git-hooks] is not on the effective hook. The cicada gate below is" >&2
    echo "[install-git-hooks] unaffected and still enforced." >&2
  }
else
  echo "[install-git-hooks] stygian-hooks-install not on PATH — skipping its managed block."
fi

# A legacy .git/hooks/pre-push is now dead weight that READS as configuration.
LEGACY="$(git -C "$ROOT" rev-parse --git-common-dir)/hooks/pre-push"
case "$LEGACY" in /*) ;; *) LEGACY="$ROOT/$LEGACY" ;; esac
if [ -e "$LEGACY" ]; then
  echo "[install-git-hooks] NOTE: $LEGACY still exists but git now IGNORES it."
  echo "[install-git-hooks]       Remove it so nothing appears wired that is not:"
  echo "[install-git-hooks]         rm '$LEGACY'"
fi

echo "[install-git-hooks] done. Effective pre-push: $ROOT/scripts/hooks/pre-push"
