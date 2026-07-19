# Spike E-SPIKE-2 — Workers AI LoRA serving + metering surface

Date: 2026-07-19
Method: `fedelm` CLI (hosted Search-API + DeepSeek pipeline), 3 targeted queries. No source was fabricated; every claim below traces to a URL in Sources.

## VERDICT

**LoRA serving status = BETA** (open beta — NOT GA)

Cloudflare Workers AI itself is GA, but BYO-LoRA / fine-tune adapter serving is explicitly called out as **open beta** in Cloudflare's own GA announcement and has not been promoted to GA in subsequent updates. Treat LoRA serving as a beta-gated capability that can change shape or pricing without notice.

## Adapter-capable base models

Fedelm returned two overlapping lists. Confidence is MODERATE — the exact current roster is version-dependent and should be re-confirmed against the live docs page before any E7 commitment.

Currently listed as supported (newer set):
- `@cf/meta/llama-guard-3-8b`
- `@cf/qwen/qwen2.5-coder-32b-instruct`
- `@cf/qwen/qwq-32b`

Original beta set:
- `@cf/meta/llama-2-7b-chat-hf-lora`
- `@cf/mistral/mistral-7b-instruct-v0.2-lora`
- `@cf/google/gemma-2b-it-lora`
- `@cf/google/gemma-7b-it-lora`

Additional models are noted as "coming soon." LOUD CAVEAT: because this is open beta, this list is the single least-stable fact in this spike. Do not hard-code it into E7; read it from the live docs at build time.

## Metering decision: Analytics Engine vs D1

**Decision: Workers Analytics Engine (AE).**

Reason: AE is the documented, purpose-built path for high-cardinality, high-volume, append-only per-request usage metering (usage-based billing, token tracking, per-customer metrics). It uses fire-and-forget writes (no `await` in the hot path), time-bucketed SQL aggregation queries, and tolerates the write volume. D1 is a transactional SQLite store optimized for individual-row lookups and application data, not high-throughput time-series aggregation — it is the wrong tool for per-request metering.

AE constraints to design around:
- Max 250 data points per Worker invocation
- Up to 20 blobs + 20 doubles + 1 index per data point
- Blob total <= 16 KB per data point; each index <= 96 bytes
- Queries may sample at high volume (`_sample_interval` column) — account for sampling in billing math, or reconcile against an authoritative counter if exact counts are billing-critical
- 90-day retention on free tier

Practical note: if exact (non-sampled) per-customer counts are ever legally/billing binding, keep a small D1 or Durable Object counter as the authoritative ledger and use AE for analytics — but AE is the primary metering surface.

## AI Gateway caching confirmation

**CONFIRMED.** The `cf-aig-cache-status` response header exists and reports `HIT` / `MISS`. Caching is configured per-gateway (dashboard: AI > AI Gateway > Settings > Cache Responses, or API `cache_ttl`); the gateway-level setting is a default that can be overridden per-request via `cf-aig-cache-ttl` and `cf-aig-cache-key` headers.

## Consequence for E7

The safe, non-beta-dependent E7 path is **BYO-endpoint (bring-your-own inference endpoint)**, fronted by AI Gateway and metered via Analytics Engine.

- BYO-endpoint does NOT depend on Workers AI LoRA open beta, so E7 can be built and shipped today without beta risk.
- The Workers-AI-LoRA path (serving a hydratype adapter directly on `@cf/...` base models) is attractive but **beta-gated** — build it only as an optional/experimental lane behind a flag, never as the sole inference path, until Cloudflare promotes LoRA serving to GA.
- AI Gateway caching (confirmed) and Analytics Engine metering (decided) are both GA and apply to either path, so wire those in now regardless of which inference lane wins.

Recommendation: build E7 on BYO-endpoint + AI Gateway + Analytics Engine. Re-run this spike's LoRA query before any decision to depend on Workers AI LoRA serving.

## Sources

LoRA status / models:
- https://developers.cloudflare.com/workers-ai/features/fine-tunes/loras/
- https://blog.cloudflare.com/workers-ai-ga-huggingface-loras-python-support/
- https://blog.cloudflare.com/fine-tuned-inference-with-loras/
- https://developers.cloudflare.com/workers-ai/features/fine-tunes/public-loras/
- https://blog.cloudflare.com/workers-ai-improvements/

Metering (Analytics Engine vs D1):
- https://developers.cloudflare.com/analytics/analytics-engine/
- https://developers.cloudflare.com/analytics/analytics-engine/limits/
- https://developers.cloudflare.com/analytics/analytics-engine/pricing/
- https://blog.cloudflare.com/analytics-engine-open-beta/
- https://blog.cloudflare.com/making-full-stack-easier-d1-ga-hyperdrive-queues/

AI Gateway caching:
- https://developers.cloudflare.com/ai-gateway/features/caching/
- https://developers.cloudflare.com/ai-gateway/glossary/
- https://developers.cloudflare.com/ai-gateway/changelog/
