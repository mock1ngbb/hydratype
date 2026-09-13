#!/usr/bin/env bash
# ── Pragmatic Law ────────────────────────────────────────────────────────────
# Solving the full problem once is always faster than deferring it.
# This gate exists because catching failures here is strictly cheaper than
# catching them downstream. Never weaken, skip, or defer.
# See: docs/constitutions/pragmatic-law.md
# ─────────────────────────────────────────────────────────────────────────────
#
# cicada-policy LAYER 1 BOOTSTRAP — the fail-CLOSED resolver for the enforcer.
#
# THIS FILE IS THE VENDORABLE HALF OF LAYER 1. Copy it into any cicada repo and
# call it from that repo's live pre-push chain. It is deliberately small and
# stable: it resolves the enforcer, proves the resolved file is really the
# enforcer, and runs it. All policy lives in the enforcer
# (scripts/hooks/cicada-policy-pre-push.sh), which exists in ONE place.
#
# WHY THIS SHAPE (the alternative was measured, 2026-09-13):
# The previous distribution model was "chain to a machine-local copy at
# $HOME/.local/share/cicada-policy/pre-push-hook.sh" written verbatim into five
# repos as:
#
#     POLICY_HOOK="$HOME/.local/share/cicada-policy/pre-push-hook.sh"
#     if [ -x "$POLICY_HOOK" ]; then exec "$POLICY_HOOK" "$@"; fi
#     exit 0
#
# The trailing `exit 0` is the defect: where the central copy is absent — a
# fresh clone, a new machine, CI, or an operator who cleaned ~/.local/share —
# Layer 1 enforces NOTHING and says nothing while doing it. An absent gate and
# a passing gate are indistinguishable to the pusher, which is the exact
# failure class this repo keeps re-learning.
#
# Rejected alternative: vendor the whole 400-line enforcer into all 32 repos.
# That trades one silent absence for 32 silent divergences, and the divergence
# is not hypothetical — rift-runes already carries an inlined fork whose body
# differs from the central copy. A policy that means something different in
# every repo is not a policy. So: ONE enforcer body, N tracked bootstraps. The
# volatile half is centralized; the stable half is what gets copied.
#
# FAIL CLOSED, AND DISTINGUISH THE STATES. Absent, present-but-not-the-enforcer,
# and present-but-gutted are three different repairs, so they get three
# different messages. None of them is "exit 0".
#
# A MARKER PROVES IDENTITY, NOT INTEGRITY. The enforcer's own header says so.
# A `cat >/dev/null; exit 0` stub that keeps CICADA_POLICY_HOOK_ID would satisfy
# a grep and enforce nothing, so this bootstrap also applies a body-shape floor:
# minimum size, every clause name, and a real scanner definition.
#
# Env:
#   CICADA_POLICY_ENFORCER      explicit path to the enforcer (highest priority)
#   CICADA_POLICY_HOME          central install dir (default ~/.local/share/cicada-policy)
#   CICADA_ENFORCER_MIN_BYTES   body-shape floor (default 4096)
#
# There is NO bypass for a missing enforcer. The repair is one command and it is
# printed. The enforcer keeps its own audited per-repo bypass
# (CLAUDE_CICADA_POLICY_APPROVE) for policy violations; that is a different
# question from "is the gate running at all", and conflating them would let a
# broken install masquerade as an approved exception.
set -uo pipefail

TAG="[cicada-bootstrap]"
CICADA_POLICY_HOME="${CICADA_POLICY_HOME:-$HOME/.local/share/cicada-policy}"
CICADA_ENFORCER_MIN_BYTES="${CICADA_ENFORCER_MIN_BYTES:-4096}"

# Clause names the enforcer must be able to emit. Absence of any one of these
# means the resolved file cannot refuse the thing it claims to refuse.
CICADA_REQUIRED_CLAUSES=(
  github_actions_forbidden
  lfs_backend_not_lfs_bridge
  policy_file_missing
  manifest_missing
)

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# Returns 0 when "$1" is a sound enforcer. On rejection prints the REASON to
# stdout (not stderr) so the caller can attribute it to the candidate path.
cicada_enforcer_reject_reason() {
  local f="$1" size

  [ -n "$f" ]  || { echo "unset"; return 1; }
  [ -e "$f" ]  || { echo "ABSENT"; return 1; }
  [ -r "$f" ]  || { echo "NOT READABLE (permission drift — the file is there)"; return 1; }

  grep -q 'CICADA_POLICY_HOOK_ID="cicada-policy-hook.v1"' "$f" 2>/dev/null || {
    echo "NOT THE ENFORCER (identity marker cicada-policy-hook.v1 absent)"; return 1; }

  size="$(wc -c < "$f" 2>/dev/null | tr -d ' ')"
  if [ -z "$size" ] || [ "$size" -lt "$CICADA_ENFORCER_MIN_BYTES" ]; then
    echo "GUTTED (${size:-0}b < ${CICADA_ENFORCER_MIN_BYTES}b floor — marker kept, body removed)"
    return 1
  fi

  local clause
  for clause in "${CICADA_REQUIRED_CLAUSES[@]}"; do
    grep -q "$clause" "$f" 2>/dev/null || {
      echo "INCOMPLETE (cannot emit clause '$clause')"; return 1; }
  done

  grep -qE '^[[:space:]]*scan_github_actions[[:space:]]*\(\)' "$f" 2>/dev/null || {
    echo "NO SCANNER (scan_github_actions is not defined — clause names present as text only)"
    return 1; }

  return 0
}

# ── resolve, in priority order ──────────────────────────────────────────────
# 1. explicit override   — tests and one-off installs
# 2. in-repo source      — bifrost-bridge itself, and any repo that vendors the
#                          enforcer; a tracked copy always beats a machine-local
#                          one, because a tracked copy survives a fresh clone
# 3. central install     — the shared copy every other repo uses today
CICADA_CANDIDATES=()
[ -n "${CICADA_POLICY_ENFORCER:-}" ] && CICADA_CANDIDATES+=("$CICADA_POLICY_ENFORCER")
CICADA_CANDIDATES+=("$REPO_ROOT/scripts/hooks/cicada-policy-pre-push.sh")
CICADA_CANDIDATES+=("$CICADA_POLICY_HOME/pre-push-hook.sh")

ENFORCER=""
REJECTIONS=()
for cand in "${CICADA_CANDIDATES[@]}"; do
  if reason="$(cicada_enforcer_reject_reason "$cand")"; then
    ENFORCER="$cand"
    break
  fi
  REJECTIONS+=("$cand :: $reason")
done

if [ -z "$ENFORCER" ]; then
  {
    echo ""
    echo "$TAG push REFUSED: the cicada Layer 1 enforcer could not be resolved."
    echo "$TAG Repo: $REPO_ROOT"
    echo "$TAG"
    echo "$TAG Layer 1 refuses pushes carrying .github/workflows, a non-lfs-bridge LFS"
    echo "$TAG backend, or a missing .cicada-policy.yml / .bifrost/deploy-manifest.json."
    echo "$TAG NONE of that was checked for this push. Rather than let an unenforced"
    echo "$TAG push read exactly like an enforced one, this refuses."
    echo "$TAG"
    echo "$TAG Candidates tried, in order:"
    for r in "${REJECTIONS[@]}"; do
      echo "$TAG   - $r"
    done
    echo "$TAG"
    echo "$TAG Repair (idempotent, from a bifrost-bridge checkout):"
    echo "$TAG   bash scripts/install-cicada-policy-hook.sh <this-repo> --apply"
    echo "$TAG"
    echo "$TAG Do NOT 'fix' this by restoring the old \`exit 0\` fallthrough. That is"
    echo "$TAG the defect, not the workaround."
    echo ""
  } >&2
  exit 1
fi

# ── run it ──────────────────────────────────────────────────────────────────
# STDIN IS BUFFERED AND HANDED ON, NOT DRAINED. git feeds the hook
# `<local-ref> <local-sha> <remote-ref> <remote-sha>` lines; the enforcer reads
# them. A drained stdin is not an empty ref list, it is a gate iterating zero
# refs and passing vacuously.
_cicada_stdin_buf="$(mktemp 2>/dev/null || true)"
if [ -n "$_cicada_stdin_buf" ] && [ -f "$_cicada_stdin_buf" ]; then
  trap 'rm -f "$_cicada_stdin_buf"' EXIT
  cat > "$_cicada_stdin_buf"
  bash "$ENFORCER" "$@" < "$_cicada_stdin_buf"
  exit $?
fi

# mktemp failed. Run the enforcer on the live stdin rather than skipping it:
# a scan with an unbuffered ref list still checks the whole tree, whereas
# skipping checks nothing.
echo "$TAG WARN: mktemp failed; running the enforcer on unbuffered stdin." >&2
bash "$ENFORCER" "$@"
exit $?
