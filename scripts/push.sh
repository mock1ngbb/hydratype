#!/usr/bin/env bash
# ── Pragmatic Law ────────────────────────────────────────────────────────────
# Solving the full problem once is always faster than deferring it.
# This gate exists because catching failures here is strictly cheaper than
# catching them downstream. Never weaken, skip, or defer.
# See: docs/constitutions/pragmatic-law.md
# ─────────────────────────────────────────────────────────────────────────────
# scripts/push.sh -- launcher for tools/push, the one push gateway (installed as ~/.local/bin/push).
# Policy for this repo lives in .push.json; behaviour lives in tools/push. This file stays so the
# hooks, docs and agent contracts that name scripts/push.sh keep working. A missing binary is a refusal.
exec "$HOME/.local/bin/push" --root "$(cd "$(dirname "$0")/.." && pwd)" "$@"
