# hydratype — thin slices

Read `00-EPICS-AND-HARDENING.md` first. Each slice is atomic and self-contained.
Convention per slice: **Goal** (1 sentence) · **Files** · **Context** (inline
API/constraints) · **Steps** · **Done-when** (binary) · **Out of scope** · **Axiom
check**. Estimated size: S = <1h, M = a few hours, L = a day. Sequence respects
dependencies noted in **After:**.

Target platform baseline: iOS 26 / macOS 26, Xcode 26+, Swift 6. Foundation
Models framework (`import FoundationModels`). Never hardcode a model id where a
config constant will do (Commodity Intelligence).

---

## SPIKES (do these first — they gate the risky epics)

### E-SPIKE-1 — Can the keyboard extension call AFM at all? (M)  [gates E2]
**Goal:** Empirically determine whether `LanguageModelSession` can run inside a
keyboard extension process, and if not, prove the host-side inference broker.
**Files:** `spikes/afm-in-extension/README.md` (findings), throwaway Xcode probe.
**Context:** Keyboard extensions have a ~50-60 MB memory jetsam ceiling; AFM is a
~3B model. fedelm judged in-process inference "highly improbable" (H1). App Group
IPC options: shared container file + `CFNotificationCenterGetDarwinNotifyCenter`
(Darwin notifications) to signal the host app; the extension writes a request
blob, the host (with AFM loaded) writes the response blob and posts back. XPC from
a keyboard to its host app is not reliable — do NOT rely on it.
**Steps:** 1) Minimal extension that on first keystroke tries
`SystemLanguageModel.default.availability` then one `LanguageModelSession`
response; log memory (`os_proc_available_memory()`) before/after. 2) If it
jetsams or `availability` is unavailable in-extension, build the Darwin-notify +
App-Group-file broker round-trip and measure latency for a 200-token correction.
**Done-when:** README states one of {IN_EXTENSION_OK, BROKER_REQUIRED} with memory
numbers and, if broker, a measured round-trip latency in ms.
**Out of scope:** actual correction quality, UI. **Axiom:** Loud (log the
jetsam/availability failure explicitly); result FILED here, not deferred.

### E-SPIKE-2 — Workers AI LoRA beta reality check (S)  [gates E7]
**Goal:** Confirm current Workers AI LoRA-serving status + the metering surface
before E7 is designed. **Files:** `spikes/workers-ai-lora/README.md`.
**Context:** fedelm (H4): LoRA serving is open beta; AI Gateway caching + R2→Queues
confirmed; D1-as-meter unconfirmed, Analytics Engine is the documented path.
**Steps:** 1) Via `wrangler` + CF docs, confirm whether LoRA finetune serving is
GA or beta today and which base models accept adapters. 2) Decide metering store:
Analytics Engine vs D1 — record the decision + why. **Done-when:** README records
{GA|BETA}, adapter-capable base model list, and a metering decision.
**Axiom:** Commodity Intelligence (no model lock-in); Pragmatic (decide before build).

---

## E0 — Foundations & legal groundwork

### E0-S1 — Xcode workspace: host app + keyboard extension + App Group (M)
**Goal:** Stand up the two-target project sharing one App Group from day one.
**Files:** `HydraType.xcodeproj` (or SPM+project), `App/`, `KeyboardExtension/`,
entitlements for both targets. **Context:** App Group id
`group.com.mock1ngbb.hydratype`. Keyboard extension needs `NSExtension` →
`IntentsSupported`/`RequestsOpenAccess=false` initially (H-4.4.1: must work
without Full Access). Host app is a normal SwiftUI app. **Steps:** 1) New iOS App
target `HydraType`. 2) Add Custom Keyboard Extension target `HydraTypeKeyboard`.
3) Add App Group capability + entitlement to BOTH; verify both can open the shared
container via `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)`.
4) Commit a smoke test writing/reading a file across targets. **Done-when:** a
unit/UI check reads back a value the other target wrote into the App Group.
**Out of scope:** any correction logic. **Axiom:** Zero Local Secrets (entitlements
only, no keys); Pragmatic (smoke test now).

### E0-S2 — Data-model + privacy decision record BEFORE storage code (S)
**Goal:** Freeze what is local-only vs opt-in-aggregate vs entitlement-tied, so
storage is architected once. **Files:** `docs/privacy/DATA-MODEL.md`,
`docs/privacy/nutrition-label-draft.md`. **Context:** 4.4.1 limits keyboard data
collection to on-device functionality enhancement; aggregate telemetry is opt-in
and differentially noised (thread T9/T10). Three cohorts tag every contributed
event: `baseline`, `local_afm`, `cloud_assisted`. **Steps:** classify each field;
draft the App Privacy Nutrition Label (Usage Data — not linked). **Done-when:**
every planned stored field appears in DATA-MODEL.md with a tier + retention.
**Axiom:** Justice/Accountability; Mechanize (label is a checked artifact).

---

## E1 — Shared correction core (SPM package)

> Per thread T34: build this platform-agnostic core FIRST; it compiles identically
> on iOS 26 and macOS 26 with zero platform-conditional code.

### E1-S1 — SPM package `HydraCore` skeleton + `CorrectionSuggestion` @Generable (S)
**Goal:** Create the shared package and the guided-generation output type.
**Files:** `Packages/HydraCore/Package.swift`,
`Sources/HydraCore/CorrectionSuggestion.swift`. **Context:** Foundation Models
guided generation: annotate a struct with `@Generable` and fields with `@Guide`.
Shape from thread T2: a primary correction + ranked alternates ("you could have
also meant"). Example:
```swift
import FoundationModels
@Generable struct CorrectionSuggestion {
  @Guide(description: "The single best correction of the user's text, preserving intent and tone.")
  var primary: String
  @Guide(description: "Up to 2 alternate meanings the user might have intended, most-likely first.")
  var alternates: [String]
  @Guide(description: "True only if the text was already correct and no change is needed.")
  var noChange: Bool
}
```
**Steps:** 1) `swift package init --type library`. 2) Add the struct. 3) Unit test
that it compiles and encodes. **Done-when:** `swift build` + `swift test` pass on
macOS. **Out of scope:** calling the model. **Axiom:** Commodity Intelligence.

### E1-S2 — `AFMCorrector` session wrapper with streaming (M)  [After E1-S1]
**Goal:** Wrap `LanguageModelSession` to produce `CorrectionSuggestion` with
streamed partials. **Files:** `Sources/HydraCore/AFMCorrector.swift`,
`Tests/HydraCoreTests/AFMCorrectorTests.swift`. **Context:** API:
`let session = LanguageModelSession(instructions: ...)`; guided call
`session.respond(to: prompt, generating: CorrectionSuggestion.self)`; streaming
`session.streamResponse(to:generating:)` yields partially-generated snapshots so
`primary` can render before `alternates` finish (thread T2). Instructions must
state: correct for INTENT/tone over edit-distance; never change text in
no-correction mode; keep slang/profanity if intended. Model availability:
`SystemLanguageModel.default.availability` (handle `.unavailable`). **Steps:**
1) Init session with a tuned instruction string (store instruction text as a
constant). 2) `correct(_ text:) async throws -> CorrectionSuggestion`. 3)
`correctStreaming(_:) -> AsyncStream<CorrectionSuggestion.PartiallyGenerated>`.
4) On `.unavailable`, throw a typed `CorrectorError.modelUnavailable` (LOUD — no
silent nil). **Done-when:** a test on a device/sim with AFM returns a non-empty
`primary` for `"i went to teh stroe"`; unavailability path is unit-tested with a
stub. **Axiom:** Loud; Commodity Intelligence.

### E1-S3 — Mode engine: no-correct field detection + manual override (M)  [After E1-S1]
**Goal:** Decide correction mode from field traits; expose a manual toggle + a
"correct selection only" mode. **Files:** `Sources/HydraCore/CorrectionMode.swift`,
`Sources/HydraCore/ModeEngine.swift`, tests. **Context:** thread T2/T4/T22.
Modes: `.off` (passwords/URLs/code/email), `.prose`, `.selectionOnly`. Signal
sources (passed in by the platform shell, so core stays UI-free):
`UIKeyboardType` / `UITextContentType` equivalents mapped to an enum
`FieldKind { password, url, email, code, plain }`. Rule: password/url/email/code →
`.off` by default; plain → `.prose`; manual override always wins and is sticky per
field session. **Steps:** 1) `FieldKind` + `func defaultMode(for:) -> CorrectionMode`.
2) `ModeEngine` holding current mode + `override(_:)`. 3) tests for each FieldKind
and for override precedence. **Done-when:** table test maps every FieldKind to the
expected default and override beats default. **Out of scope:** reading real UIKit
traits (that's the shell's job, E2/E1b). **Axiom:** Pragmatic; Zero Local Secrets
(off-by-default in credential fields).

### E1-S4 — Local cache/graph store in App Group (M)  [After E0-S1]
**Goal:** SQLite-or-JSON store of accepted/rejected corrections + personal vocab,
in the shared container. **Files:** `Sources/HydraCore/CorrectionStore.swift`,
tests. **Context:** thread T4: extension logs lightweight rows to the App Group;
host app syncs them out. Row: `{ts, fieldKind, before, suggested, accepted:Bool,
source:enum(afm|stock|user), inferenceTier}`. Use `GRDB` or raw SQLite via
`SQLite3`; keep it dependency-light. Path = App Group container +
`/corrections.sqlite`. **Steps:** 1) schema + migration. 2) `append(_ event)`,
`recentUnsynced(limit:)`, `markSynced(ids:)`. 3) tests with a temp container URL.
**Done-when:** append + read-back + markSynced round-trips in a test.
**Axiom:** Loud (surface write failures); Single-Track.

---

## E1b — macOS test rig (parallel Phase-1 track; superior debug loop)

### E1b-S1 — Headless macOS CLI harness over HydraCore (S)  [After E1-S2]
**Goal:** A command-line tool that pipes stdin text through `AFMCorrector` and
prints the `CorrectionSuggestion` — the fast build-test-observe loop from T34.
**Files:** `Tools/hydratype-cli/main.swift`, `Package.swift` executable target.
**Context:** No sandbox, full debugger + console; run `swift run hydratype-cli`.
**Steps:** read a line, call `correct`, pretty-print primary+alternates+timing.
**Done-when:** `echo "i cant beleive it" | swift run hydratype-cli` prints a
correction with latency ms. **Axiom:** Pragmatic (this is the test rig that
de-risks every later phase).

### E1b-S2 — IMKit shell: `IMKInputController` thin adapter (M)  [After E1b-S1]
**Goal:** A macOS input method that forwards keystrokes to HydraCore and renders
candidates. **Files:** `macOS/HydraTypeIM/` (InputMethodKit app). **Context:** T34
— dumbest possible layer; only translates IMKit events into HydraCore calls,
renders in the candidate window. Register the input method; no App Store needed.
**Steps:** `IMKInputController` subclass → accumulate text → `correctStreaming` →
candidate window. **Done-when:** typing in TextEdit with the IM active shows a
hydratype candidate. **Out of scope:** cloud sync. **Axiom:** Commodity/Single-Track.

---

## E2 — iOS keyboard extension: local correction + modes  [After E-SPIKE-1]

### E2-S1 — Keyboard UI + text pipeline wired to ModeEngine (M)
**Goal:** A working keyboard that types, detects field kind, and applies the
mode engine (correction path stubbed to the broker/AFM per SPIKE-1 outcome).
**Files:** `KeyboardExtension/KeyboardViewController.swift`. **Context:** map
`textDocumentProxy.keyboardType` / `.textContentType` → `FieldKind`; feed
`ModeEngine`. If SPIKE-1 = BROKER_REQUIRED, correction requests go through the
App-Group broker, not in-process AFM. **Done-when:** keyboard types text; in a URL
field it does not correct; in a plain field it requests a correction.
**Axiom:** Loud (log broker timeouts); Zero Local Secrets.

### E2-S2 — Inline "did-you-mean" + one-tap revert UI (M)  [After E2-S1]
**Goal:** Show primary correction inline with a quick accept/revert affordance and
render alternates on demand (T1/T2 UX). **Done-when:** accepting logs an `accepted`
event to `CorrectionStore`; revert restores original within one tap.

---

## E3 — Shadow comparison + calibration

### E3-S1 — `UITextChecker` shadow challenger (M)  [After E1-S4]
**Goal:** Run stock spellcheck silently alongside AFM and log the triple.
**Files:** `Sources/HydraCore/ShadowComparator.swift` (+ tests). **Context:** T11:
`UITextChecker.rangeOfMisspelledWord(in:...)` + `guesses(forWordRange:...)` are
available to extensions, no network, zero user-visible latency (never blocks the
shown path). Per event log `{stockGuess, afmSuggestion, userAccepted}`.
**Done-when:** for a misspelled token, the stored event has all three fields.
**Axiom:** Loud; Justice (honest measurement).

### E3-S2 — Host-app calibration mode (M)
**Goal:** In-host-app flow: user types a fixed passage corrections-off then
corrections-on → true baseline error rate (T10/T11). **Files:** `App/Calibration/`.
**Context:** MUST live in host app (4.4.1). Within-user before/after delta.
**Done-when:** completing calibration writes a `baseline` cohort record.

---

## E4 — Companion dashboard (fully local)

### E4-S1 — Local metrics screen (M)  [After E3-S1]
**Goal:** Host-app screen: corrections made, override/"fighting" rate, shadow
delta vs stock — all from local `CorrectionStore`, no backend (T8/T12 Phase 3).
**Files:** `App/Dashboard/`. **Done-when:** screen renders real counts from a
seeded store; three cohort lines (baseline/local_afm/cloud_assisted) present even
if cloud is empty. **Axiom:** Justice (falsifiable numbers); Loud.

---

## E5 — TestFlight beta (ops slice)

### E5-S1 — Internal TestFlight lane (S)
**Goal:** Ship the Phase-3 build to ≤100 internal testers (no beta review, T8/T12).
**Files:** `docs/ops/testflight.md`. **Context:** builds expire 90 days → note the
refresh cadence. **Done-when:** doc lists bundle ids, App Store Connect steps, and
the 90-day refresh reminder. **Axiom:** Defer-nothing (reminder is filed, not vibes).

---

## E6 — Cloudflare opt-in aggregate telemetry (open-source anchor)

### E6-S1 — D1 schema + R2 bucket + event notification → Queue (M)
**Goal:** Provision the ingest path. **Files:** `backend/wrangler.jsonc`,
`backend/schema.sql`, `.bifrost/deploy-manifest.json` target entry. **Context:**
H4-confirmed: R2 `object-create` → Cloudflare Queue. D1 table `contributions`
(noised deltas, cohort tag). Host app (not the extension — extensions can't do
background networking, T4) uploads noised summary blobs to R2 via
`BGAppRefreshTask`. **Done-when:** writing a test object to R2 lands a queue
message a consumer logs. **Axiom:** Zero Local Secrets (`CF_WORKERS_TOKEN` via
`bf`, never committed); Loud.

### E6-S2 — Consumer Worker: queue → D1 rollup (M)  [After E6-S1]
**Goal:** Consume queue messages, validate noised summaries, upsert daily/weekly
aggregates in D1. **Files:** `backend/src/consumer.ts`. **Done-when:** a queued
summary produces a D1 aggregate row; malformed input is rejected with a logged
structured error (LOUD, no silent drop). **Axiom:** Loud; Pragmatic.

### E6-S3 — Public rollup Worker + JSON stats endpoint (open-sourced) (M)  [After E6-S2]
**Goal:** Cron Worker rolls D1 → small public JSON in KV/R2; live D1 stays private
(T9). **Files:** `backend/src/rollup.ts`, `PUBLIC-METHODOLOGY.md`. **Context:**
publish aggregation + noise methodology alongside numbers — the credibility anchor;
open-source this piece. **Done-when:** public endpoint returns aggregate three-cohort
JSON; methodology doc explains the noise. **Axiom:** Justice/Accountability.

### E6-S4 — Differential-privacy noise at the edge (M)  [After E6-S1]
**Goal:** Device computes local deltas and adds calibrated noise before transmit,
so raw events never leave the device (T9). **Files:**
`Sources/HydraCore/PrivateAggregator.swift`. **Done-when:** unit test shows summed
noised deltas approximate true aggregate within tolerance; no raw event field is
present in the transmit payload. **Axiom:** Zero Local Secrets; Justice.

---

## E7 — Workers AI cloud tier + adapter retrain  [beta-gated, After E-SPIKE-2]

Slices (design after SPIKE-2 records GA/beta + metering decision):
- **E7-S1** LoRA retrain job triggered off R2 checkpoint events (durable/Workflow);
  writes new adapter to R2 tagged with base-model version (H3).
- **E7-S2** AFM adapter delivery: host-app Background Assets download + compatibility
  guard (reject on base-model mismatch, silent fallback to un-adapted — LOUD log).
- **E7-S3** AI Gateway in front of Workers AI for exact-match caching (`cf-aig-cache-status`).
- **E7-S4** Metering store (Analytics Engine per H4) + hard cap → silent fallback to
  local-only at cap (T6). No surprise billing.
- **E7-S5** BYO-endpoint unlock: user supplies own R2/D1/OpenAI-compatible keys,
  stored in Keychain, used only at call time (Zero Local Secrets). This is the
  non-beta-dependent path and should ship before CF-hosted LoRA if beta blocks.

## E8 — Monetization + submission (host-app only, 4.4.1)
- **E8-S1** StoreKit 2 non-consumable tip-unlock (≥ $1) → permanently enables BYO tier.
- **E8-S2** StoreKit 2 auto-renewable subscription for the $5/mo managed tier.
- **E8-S3** Nutrition label finalize vs shipped data model; submit with note that the
  extension is fully functional without Full Access.

## E9 — Layout variants (witty renames; one-handed / drive-first, T15-T18, T28)
- E9-S1 Layout engine abstraction (keymap as data). E9-S2 half-qwerty variant.
  E9-S3 T9-style variant. E9-S4 ortholinear. E9-S5 colemak-dh. All must be usable
  one-handed (T18/T28 — driving is a first-class case, not a separate "mode").
  Renames avoid trademarked names (BlackBerry/T9) per T16.

## E10 — Accessibility-first (T19)
- One-handed reachability for every mode; large hit targets; VoiceOver labels;
  high-contrast candidate rendering. Not an afterthought — cut as its own slices.

## E11 — Prediction UX (T23-T26)
- E11-S1 next-word/phrase prediction row (tap = next word, double-tap = whole
  phrase). E11-S2 swipe-glide word-path selection with fast undo (swipe R→L).
- E11-S3 punctuation toggle: none / learned / proper (keeps slang like "lol").
- E11-S4 scrub-delete: swipe on backspace to delete-by-word with forward "un-delete."

## E12 — Secure-field gap closure  [re-scoped per H2]
- E12-S1 **Separate AutoFill Credential Provider extension** target for password
  autofill (works WITH Bitwarden as the provider — NOT the keyboard, which iOS
  disables in secure fields). E12-S2 contact-address / wallet autofill via system
  AutoFill. Keyboard's job: yield cleanly in secure fields (OS default).

## E13 — Universal training sets + self-healing sync (T20, R&D)
- Aggregate anonymized telemetry → publish several "universal" fine-tuned
  cache/graphs; companion app silently heals a user to the closest-matching set by
  typing style/language/slang. Depends on E6 telemetry volume; spike first.

## E14 — Feature/marketing page (T29, T13-T14)
- E14-S1 One feature page: each feature = technical/philosophical reason + a "why
  you care" TL;DR framed as "the compensation you didn't know you had." Content
  deliverable for friends + resume; not app code.
