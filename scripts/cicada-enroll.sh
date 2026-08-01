#!/usr/bin/env bash
# cicada-enroll.sh — Mechanized charon-cicada enrollment for hydratype.
# Idempotent: re-runnable. Enrolls this repo into the shared cicada pipeline
# (crypt-core vault-keeper registration + GitHub webhook -> cicd-intake).
#
# Usage:
#   bash scripts/cicada-enroll.sh [owner/repo]
#   (default: mock1ngbb/hydratype)
#
# What it does:
#   1. Checks vault-keeper (crypt-core) registration — enrolls if missing
#   2. Creates .bifrost/deploy-manifest.json if absent
#   3. Blacklists GitHub Actions (.github/workflows/*.yml)
#   4. Configures the GitHub webhook -> cicd-intake (JSON, push + pull_request)
#   5. Verifies
#
# Requires: gh CLI, bf (PROXY_API_KEY + GITHUB_WEBHOOK_SECRET).
# Note: creating/updating a webhook requires repo-admin; if gh (rip-rooter) is
# not admin on the target repo, run this with an admin token (e.g. the owner's
# bifrost-GITHUB_TOKEN) or create the webhook manually in the GitHub UI.
set -euo pipefail

REPO="${1:-mock1ngbb/hydratype}"
if ! echo "$REPO" | grep -qE '^[a-zA-Z0-9_-]+/[a-zA-Z0-9._-]+$'; then
  echo "ERROR: invalid repo format '$REPO' — expected <owner>/<name>"
  exit 2
fi
OWNER="${REPO%/*}"; NAME="${REPO#*/}"

PROXY="$(bf PROXY_API_KEY 2>/dev/null || true)"
WS="$(bf GITHUB_WEBHOOK_SECRET 2>/dev/null || true)"
[ -n "$PROXY" ] || { echo "ERROR: PROXY_API_KEY missing (bf)"; exit 1; }
[ -n "$WS" ] || { echo "ERROR: GITHUB_WEBHOOK_SECRET missing (bf)"; exit 1; }

echo "=== Cicada enrollment: $REPO ==="

# Step 1 — Vault-keeper (crypt-core)
echo "1/5 Vault-keeper…"
EXISTING="$(curl -s -m 10 "https://crypt-core.mock1ng.workers.dev/v1/repos/$OWNER/$NAME" -H "Authorization: Bearer $PROXY")"
if echo "$EXISTING" | grep -q '"enabled":true'; then
  echo "   ✅ Already registered"
else
  curl -s -m 15 -X POST "https://crypt-core.mock1ng.workers.dev/v1/repos" \
    -H "Content-Type: application/json" -H "Authorization: Bearer $PROXY" \
    -d "{\"fullName\":\"$OWNER/$NAME\",\"enabled\":true,\"deployTargets\":[{\"platform\":\"script\",\"target\":\"hydratype-gate\"}]}" > /dev/null
  echo "   ✅ Registered (script gate target)"
fi

# Step 2 — Deploy manifest
echo "2/5 Deploy manifest…"
if gh api "repos/$OWNER/$NAME/contents/.bifrost/deploy-manifest.json" --jq .type 2>/dev/null | grep -q file; then
  echo "   ✅ Exists"
else
  echo "   ⚠️  Missing — create .bifrost/deploy-manifest.json ({\"version\":\"1\",\"owner\":\"$OWNER\",\"repo\":\"$NAME\",\"targets\":[]}) and commit it."
fi

# Step 3 — GitHub Actions blacklist
echo "3/5 GitHub Actions blacklist…"
COUNT="$(gh api "repos/$OWNER/$NAME/contents/.github/workflows" --jq 'length' 2>/dev/null || echo 0)"
if [ "$COUNT" -gt 0 ]; then
  echo "   ⚠️  $COUNT workflow(s) present — remove them; cicada policy forbids GitHub Actions."
else
  echo "   ✅ None found"
fi

# Step 4 — Webhook (push + pull_request -> cicd-intake)
echo "4/5 Webhook…"
GH_TOKEN="$(gh auth token 2>/dev/null || true)"
[ -n "$GH_TOKEN" ] || { echo "ERROR: gh auth unavailable"; exit 1; }
ID="$(gh api "repos/$OWNER/$NAME/hooks" --jq '.[] | select(.config.url | test("cicd-intake")) | .id' 2>/dev/null)"
if [ -n "$ID" ]; then
  curl -s -m 15 -X PATCH "https://api.github.com/repos/$OWNER/$NAME/hooks/$ID" \
    -H "Authorization: Bearer $GH_TOKEN" -H "Content-Type: application/json" \
    -d "{\"config\":{\"url\":\"https://cicd-intake.mock1ng.workers.dev/v1/intake/github-push\",\"content_type\":\"json\",\"secret\":\"$WS\",\"insecure_ssl\":\"0\"},\"active\":true,\"events\":[\"push\",\"pull_request\"]}" > /dev/null
  echo "   ✅ Updated hook $ID (push + pull_request)"
else
  curl -s -m 15 -X POST "https://api.github.com/repos/$OWNER/$NAME/hooks" \
    -H "Authorization: Bearer $GH_TOKEN" -H "Content-Type: application/json" \
    -d "{\"name\":\"web\",\"active\":true,\"events\":[\"push\",\"pull_request\"],\"config\":{\"url\":\"https://cicd-intake.mock1ng.workers.dev/v1/intake/github-push\",\"content_type\":\"json\",\"secret\":\"$WS\",\"insecure_ssl\":\"0\"}}" > /dev/null
  echo "   ✅ Created"
fi

# Step 5 — Verify
echo "5/5 Verify…"
curl -s -m 5 "https://crypt-core.mock1ng.workers.dev/v1/repos/$OWNER/$NAME" -H "Authorization: Bearer $PROXY" | \
  python3 -c "import sys,json;d=json.load(sys.stdin);print(f'   vault-keeper: enabled={d.get(\"enabled\")}')" 2>/dev/null

echo ""
echo "✅ Enrolled $REPO"
echo "   Manual deploy: bash scripts/cicada-deploy.sh"
