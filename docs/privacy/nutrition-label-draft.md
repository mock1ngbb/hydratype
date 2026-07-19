# hydratype — App Privacy "Nutrition Label" (DRAFT)

**Slice:** E0-S2 · **Date:** 2026-07-19 · **Status:** DRAFT (finalized in E8-S3 against shipped data model)

Companion to `DATA-MODEL.md`. This is the App Store Connect **App Privacy**
declaration hydratype intends to file. It is a **checked artifact** (Mechanize):
it must remain true to the frozen data model and is re-validated before submission.

## Headline declarations

- **The keyboard extension performs no network I/O of its own.** All raw
  keystrokes, corrections, shadow comparisons, and personal vocabulary stay in
  the on-device App Group container (App Store guideline **4.4.1** — data
  collection limited to on-device functionality enhancement).
- **The keyboard functions fully without Full Access** (`RequestsOpenAccess=false`).
  Granting Full Access is **not** required to type or to get corrections.
- **All off-device telemetry is opt-in and differentially noised.** Only
  aggregate, calibrated-noise deltas leave the device, and only after the user
  explicitly opts in, uploaded by the **host app** (never the extension).
- **Nothing is linked to the user's identity.** No account, no device id, no
  per-event rows, no raw text ever leaves the device.

## Data collected

### Usage Data — **collected only with opt-in · NOT linked to identity · not used for tracking**

| Attribute | Value |
|-----------|-------|
| Data type | Usage Data (product-interaction aggregates: correction acceptance rate, stock-vs-AFM shadow delta, calibration error-rate delta) |
| Collected? | Only if the user opts in (default: off) |
| Linked to identity? | **No** — no user/device identifier is attached |
| Used for tracking? | **No** |
| Purpose | Analytics / App Functionality (published transparency stats) |
| Form transmitted | Differentially-noised aggregate deltas, tagged by cohort (`baseline` / `local_afm` / `cloud_assisted`), coarse period bucket only |
| Uploaded by | Host app (`BGAppRefreshTask` -> R2/Queues/D1). The keyboard extension never networks. |

### Everything else — **Data NOT collected (stays on device)**

The following are processed **on device only** and are **not** "collected" in the
App Privacy sense (never leave the device, never linked to identity):

- Raw keystrokes / original text (`before`).
- Suggested corrections (`suggested`), AFM output, stock `UITextChecker`
  guesses (`stockGuess`, `afmSuggestion`).
- Personal vocabulary (learned words, slang, names).
- Field kind at the raw level and per-event timestamps.
- Calibration passage text.

### Secrets — **never stored on disk, never collected**

- **BYO endpoint API keys** (paid BYO tier) live in the **Keychain**, fetched
  only at call time, never written to the correction database or any file, never
  transmitted to hydratype's backend (**Zero Local Secrets**).

## Cloud / BYO tier note (entitlement-tied)

When a user enables the paid cloud-assisted or BYO-endpoint tier, correction
**requests may be sent to the user's own or the managed endpoint at call time**
to produce a suggestion. This is functional processing initiated by the user's
own configuration, is disclosed at purchase, and is distinct from the opt-in
aggregate telemetry above. Cohort tag `cloud_assisted` marks any aggregate
contribution originating from this path (still opt-in, still noised, still
unlinked).

## Accountability check (Justice)

This label must match `DATA-MODEL.md`. If a future slice adds a stored or
transmitted field, that field is classified in `DATA-MODEL.md` FIRST and this
label is updated in the same change. Finalization: **E8-S3** validates this draft
against the actually-shipped data model and submits with the note that the
extension is fully functional without Full Access.
