# hydratype — Data Model & Privacy Decision Record

**Slice:** E0-S2 · **Date:** 2026-07-19 · **Status:** FROZEN (architect storage against this, once)

This is the authoritative classification of **every field hydratype plans to
store or transmit**, decided BEFORE any storage code (E1-S4 `CorrectionStore`,
E3 shadow/calibration, E6 telemetry) is written. Storage is architected once
against this record.

## Governing constraints & axioms

- **App Store 4.4.1** — keyboard-extension data collection is limited to
  **on-device functionality enhancement**. Any aggregate telemetry must be
  **opt-in** and **differentially noised**. The keyboard extension itself does
  **no network I/O** and functions **without Full Access** (`RequestsOpenAccess=false`).
- **Zero Local Secrets** — BYO endpoint keys never touch the DB or disk. They
  live in the **Keychain**, fetched only at call time. Never logged, never synced.
- **Justice / Accountability** — honest labeling; the nutrition label is a
  checked artifact that matches this model (see `nutrition-label-draft.md`).
- **Loud by default** — write/transmit failures surface a structured log line;
  no silent drop.

## Tier definitions

| Tier | Meaning | Leaves device? | Requires consent? |
|------|---------|----------------|-------------------|
| **local-only** | Stored only in the App Group container (or Keychain) for on-device functionality. Never transmitted. | No | No (implicit; on-device enhancement per 4.4.1) |
| **opt-in-aggregate** | Contributes to telemetry ONLY after explicit opt-in, and ONLY as a **differentially-noised aggregate delta**. Raw field never leaves the device. | Only as noised aggregate | Yes (explicit opt-in) |
| **entitlement-tied** | Exists / is exercised only when a paid entitlement (tip-unlock BYO or managed sub) is active; governs BYO credentials and cloud-assisted call state. | BYO: no (Keychain). Cloud: request text to user's own/managed endpoint at call time. | Yes (purchase + BYO configuration) |

## Cohort tags

Every contributed (opt-in) event carries exactly one cohort tag describing the
inference path that produced it:

- `baseline` — stock correction path (no AFM), from host-app calibration (E3-S2).
- `local_afm` — on-device Foundation Models correction.
- `cloud_assisted` — correction produced via the cloud/BYO endpoint tier (E7).

## The data model

### A. `CorrectionStore` row — local event log (E1-S4)

App Group container `group.com.mock1ngbb.hydratype` → `/corrections.sqlite`.
Written by the extension (or host broker per E-SPIKE-1); read/synced by the host app.

| Field | Source | Tier | Retention | Notes |
|-------|--------|------|-----------|-------|
| `id` (rowid) | extension/host | local-only | rolling cap (e.g. last N rows / 90 days), then evicted | Local primary key; never transmitted. |
| `ts` (timestamp) | extension/host | local-only | with row | Coarsened to a bucket (e.g. day) BEFORE any opt-in aggregation; raw ts never leaves device. |
| `fieldKind` | extension/host | local-only → opt-in-aggregate | with row | Enum `{password,url,email,code,plain}`. Only the coarse category may feed a noised aggregate; credential-field kinds are correction-`off` by default. |
| `before` (original text) | extension/host | **local-only** | with row | Raw user keystrokes. NEVER transmitted, never aggregated, never logged verbatim. On-device functionality only. |
| `suggested` (correction) | extension/host | **local-only** | with row | Model/stock output text. NEVER transmitted. |
| `accepted` (Bool) | extension/host | local-only → opt-in-aggregate | with row | Only the acceptance *rate* (noised, aggregated) may be contributed. |
| `source` enum `{afm,stock,user}` | extension/host | local-only → opt-in-aggregate | with row | Which producer made the shown text; feeds cohort mapping, aggregate only. |
| `inferenceTier` | extension/host | local-only → opt-in-aggregate | with row | Maps to cohort (`baseline`/`local_afm`/`cloud_assisted`); aggregate only. |
| `synced` (Bool/flag) | host | local-only | until evicted | Bookkeeping for `recentUnsynced`/`markSynced`; never itself transmitted. |

### B. `ShadowComparator` triple — silent stock-vs-AFM measurement (E3-S1)

`UITextChecker` runs silently alongside AFM; never blocks the shown path.

| Field | Source | Tier | Retention | Notes |
|-------|--------|------|-----------|-------|
| `stockGuess` | extension/host | **local-only** | with event, rolling cap | `UITextChecker.guesses(...)` output text; raw, never transmitted. Only stock-vs-AFM agreement/delta (noised) may aggregate. |
| `afmSuggestion` | extension/host | **local-only** | with event | Raw AFM text; never transmitted. |
| `userAccepted` | extension/host | local-only → opt-in-aggregate | with event | Which candidate the user took; feeds the noised shadow-delta metric only. |

### C. Cohort tag

| Field | Source | Tier | Retention | Notes |
|-------|--------|------|-----------|-------|
| `cohort` (`baseline`/`local_afm`/`cloud_assisted`) | host | opt-in-aggregate | attached to each contributed delta | Not identity; a bucket label on aggregate contributions. Present on-device for local dashboard (E4) even without opt-in. |

### D. Personal vocabulary

| Field | Source | Tier | Retention | Notes |
|-------|--------|------|-----------|-------|
| `vocab` entries (learned words, slang, names) | extension/host | **local-only** | until user clears / app uninstall | On-device functionality enhancement (keep-slang-if-intended). NEVER transmitted — high re-identification risk. Lives in App Group store. |

### E. BYO endpoint credentials (E7-S5, entitlement-tied)

| Field | Source | Tier | Retention | Notes |
|-------|--------|------|-----------|-------|
| BYO endpoint API key(s) (R2/D1/OpenAI-compatible) | host | **entitlement-tied** | Keychain only, until user removes | **Zero Local Secrets**: NEVER in the DB, NEVER on disk, NEVER in `CorrectionStore`, NEVER logged. Stored in **Keychain**, fetched at call time only. Not synced to backend. |
| BYO endpoint URL / config (non-secret) | host | entitlement-tied | app defaults / local config | Non-secret; may live in local config, still never transmitted to hydratype's backend. |

### F. Calibration baseline records (E3-S2, host app)

Calibration MUST live in the host app (4.4.1), not the extension.

| Field | Source | Tier | Retention | Notes |
|-------|--------|------|-----------|-------|
| calibration passage text | host | **local-only** | discarded after delta computed | Fixed known passage; used only to compute within-user error rate. |
| baseline error rate (corrections-off) | host | local-only → opt-in-aggregate | with baseline record | Within-user before value; feeds `baseline` cohort as a noised aggregate only. |
| post-correction error rate (corrections-on) | host | local-only → opt-in-aggregate | with baseline record | Within-user after value; the before/after **delta** is the only thing that (noised) may contribute. |
| `baseline` cohort record | host | opt-in-aggregate | until superseded | The written artifact of E3-S2 done-when. |

### G. Noised aggregate deltas transmitted to backend (E6, host app only)

The extension CANNOT network (T4). The host app, on `BGAppRefreshTask`, uploads
**noised summary blobs** to R2 → Queue → D1. Raw event fields (A/B `before`,
`suggested`, `stockGuess`, `afmSuggestion`) are NEVER present in the payload
(E6-S4 `PrivateAggregator` guarantees this).

| Field | Source | Tier | Retention | Notes |
|-------|--------|------|-----------|-------|
| noised delta metric(s) (acceptance rate, shadow delta, error-rate delta) | backend (from host upload) | **opt-in-aggregate** | D1 rollup; raw blob dropped after rollup | Calibrated DP noise added **on device** before transmit. Not linked to identity. |
| `cohort` tag on the contribution | backend | opt-in-aggregate | with aggregate row | `baseline`/`local_afm`/`cloud_assisted` only. |
| coarse period bucket (day/week) | backend | opt-in-aggregate | with aggregate row | No fine timestamps, no per-event rows, no device/user id. |
| public rollup JSON (three-cohort aggregate) | backend | opt-in-aggregate (published) | public KV/R2 | Open-sourced with noise methodology (E6-S3, `PUBLIC-METHODOLOGY.md`). |

### H. Entitlement / purchase state (E8, host app)

| Field | Source | Tier | Retention | Notes |
|-------|--------|------|-----------|-------|
| tip-unlock / subscription entitlement flag | host (StoreKit 2) | entitlement-tied | managed by StoreKit / local | Gates BYO + cloud tiers. Not contributed to telemetry; not linked to typing data. |

## Done-when self-check

Every planned stored field has a **tier + retention**. Confirmed:

- [x] `CorrectionStore` row — all of `{id, ts, fieldKind, before, suggested, accepted, source, inferenceTier, synced}` classified (A).
- [x] `ShadowComparator` triple — `{stockGuess, afmSuggestion, userAccepted}` classified (B).
- [x] Cohort tag classified (C).
- [x] Personal vocab classified as local-only (D).
- [x] BYO endpoint keys classified entitlement-tied, **Keychain only, never DB/disk** (E).
- [x] Calibration baseline records classified (F).
- [x] Noised aggregate deltas + public rollup classified opt-in-aggregate, raw fields absent from payload (G).
- [x] Entitlement/purchase state classified (H).
- [x] No stored field carries raw text (`before`/`suggested`/`stockGuess`/`afmSuggestion`/vocab/calibration text) off-device.
- [x] Nutrition label draft (`nutrition-label-draft.md`) matches this model.

**Invariant for storage code:** `before`, `suggested`, `stockGuess`,
`afmSuggestion`, personal vocab, calibration passage text, and BYO keys are the
**never-transmit set**. Only noised aggregates of `accepted`/`source`/
`inferenceTier`/`fieldKind`(coarse)/error-rate deltas, tagged by cohort, may
leave the device — and only after explicit opt-in.
