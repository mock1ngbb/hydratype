#!/usr/bin/env bash
# cicada-deploy.sh — Manual "fire" trigger for the charon-cicada pipeline.
# Enqueues a build/verify job via cicd-queue and drains it, so the operator can
# run the cicada gate on demand (not only via the GitHub push webhook).
#
# hydratype is a keyboard app with no CF deploy target; its registered deploy
# target (script platform "hydratype-gate") runs the verification gate. This
# manual path is the counterpart to merge-warden's `POST /v1/run`.
#
# Usage:
#   bash scripts/cicada-deploy.sh [repo] [sha]
#   (defaults: mock1ngbb/hydratype, origin/hee-haw)
#
# Requires: bf PROXY_API_KEY.
set -euo pipefail

REPO="${1:-mock1ngbb/hydratype}"
SHA_INPUT="${2:-HEAD}"
if [ "$SHA_INPUT" = "HEAD" ]; then
  SHA="$(git rev-parse origin/hee-haw 2>/dev/null || git rev-parse HEAD)"
else
  SHA="$SHA_INPUT"
fi
echo "$SHA" | grep -qE '^[a-f0-9]{40}$' || { echo "ERROR: SHA must be 40 hex chars (got: $SHA)"; exit 1; }

PROXY_KEY="$(bf PROXY_API_KEY 2>/dev/null || true)"
[ -n "$PROXY_KEY" ] || { echo "ERROR: PROXY_API_KEY unavailable (bf)"; exit 1; }

echo "🚀 Enqueuing cicada job — repo=$REPO sha=$SHA"
RESULT="$(curl -s -m 30 -X POST "https://cicd-queue.mock1ng.workers.dev/v1/queue/enqueue" \
  -H "Authorization: Bearer $PROXY_KEY" -H "Content-Type: application/json" \
  -d "{\"repo\":\"$REPO\",\"sha\":\"$SHA\",\"ref\":\"refs/heads/hee-haw\",\"deliveryId\":\"cicada-cli-$(date +%s)\",\"pusher\":\"operator\"}")"
JOB_ID="$(echo "$RESULT" | python3 -c "import sys,json;print(json.load(sys.stdin).get('jobId',''))" 2>/dev/null || true)"
if [ -n "$JOB_ID" ]; then
  echo "✅ Job enqueued: $JOB_ID"
else
  echo "❌ Enqueue failed: $RESULT"; exit 1
fi

echo "⚡ Draining queue…"
DRAIN="$(curl -s -m 120 -X POST "https://cicd-queue.mock1ng.workers.dev/v1/queue/drain" \
  -H "Authorization: Bearer $PROXY_KEY" -H "Content-Type: application/json" -d '{"limit":1}')"
echo "$DRAIN" | python3 -c "
import sys,json
d=json.load(sys.stdin)
print('✅ dispatched' if d.get('dispatched') else ('⚠️ accepted, not dispatched: ' + json.dumps(d)[:160]))
" 2>/dev/null || echo "Drain response: $(echo "$DRAIN" | head -c 160)"

echo ""
echo "Check job: curl -s https://cicd-queue.mock1ng.workers.dev/v1/queue/job/$JOB_ID"
