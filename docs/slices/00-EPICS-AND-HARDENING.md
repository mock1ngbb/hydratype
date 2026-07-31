# hydratype — Epics, fedelm hardening, and axiom lens

Source of truth for scope: `docs/research/2026-07-19-afm-autocorrect-thread.md`
(34-turn design thread). This file turns that thread's **epics** into a map, then
records the **fedelm-validated corrections** that reshape the slices, then states
the **axiom lens** every slice was cut against. The per-slice backlog lives in
`01-SLICES.md`.

## What hydratype is (one paragraph)

An iOS (and macOS) custom keyboard that does **intent/context** autocorrect via
Apple's on-device Foundation Models LLM (AFM, ~3B, iOS/macOS 26) instead of
n-gram/edit-distance. A shared Swift core drives correction + prediction; a
Cloudflare backend (R2/D1/Queues/Workers AI) does out-of-band personalization
(LoRA adapters) and opt-in, differentially-noised public telemetry. Three tiers:
(1) free local-only AFM, (2) tip-unlock bring-your-own-endpoint, (3) $5/mo managed
cloud tier with hard usage caps.

## Epic map

| Epic | Title | Phase (thread T12) | Buildable now? |
|------|-------|--------------------|----------------|
| **E0** | Foundations & legal groundwork (Xcode 2-target project, App Group, privacy label draft) | 0 | ✅ |
| **E1** | Shared correction core (SPM package: AFM session wrapper, `@Generable` structs, cache/graph, sync client) | 1 | ✅ |
| **E1b** | macOS headless CLI test rig + IMKit shell (parallel Phase-1 track; fast debug loop) | 1‖ | ✅ |
| **E2** | iOS keyboard extension: local correction + mode-switching (password/URL/code, prose, selected-text) | 1 | ⚠️ blocked on E-SPIKE-1 |
| **E3** | Shadow comparison (`UITextChecker`) + calibration mode | 2 | ✅ |
| **E4** | Companion host-app dashboard (fully local metrics) | 3 | ✅ |
| **E5** | TestFlight friends-and-family beta | 4 | ✅ (ops) |
| **E6** | Cloudflare opt-in aggregate telemetry (D1, R2→Queues, rollup Worker, public JSON, open-source) | 5 | ✅ |
| **E7** | Workers AI cloud tier + LoRA adapter retrain + metering + BYO-endpoint unlock | 6 | ⚠️ beta-gated |
| **E8** | Monetization (StoreKit 2 tip-unlock + subscription) + App Store submission | 7 | later |
| **E9** | Layout variants (half-qwerty, T9-ish, ortholinear, colemak-dh) w/ witty renames; one-handed/drive-first | feature | later |
| **E10** | Accessibility-first affordances (one-handed everywhere, large targets) | feature | later |
| **E11** | Prediction UX (next-word/phrase, swipe-glide word path, punctuation toggle, scrub-delete) | feature | later |
| **E12** | Secure-field gap closure — **separate AutoFill Credential Provider extension** + contact/wallet autofill | feature | ⚠️ re-scoped |
| **E13** | Universal training sets + self-healing cache/graph sync | feature | R&D |
| **E14** | Feature/marketing page + grassroots launch content | GTM | ✅ (content) |

## fedelm hardening — corrections to the thread's assumptions

The design thread was optimistic in places. These four fedelm consults
(2026-07-19) materially change how slices are written. **Slices must obey the
CORRECTED reality, not the thread.**

### H1 — AFM does NOT reliably run inside the keyboard extension process
Keyboard extensions are held to a ~50-60 MB memory ceiling; a 3B model does not
fit. fedelm: running `LanguageModelSession` **in-process in the extension is
highly improbable**; inference likely must run in the host app / an app-group
process. **Consequence:** E2 is gated behind **E-SPIKE-1** — an empirical test of
whether the extension can call AFM at all, and if not, a host-side inference
broker over the App Group (Darwin notifications + shared file/memory, since
XPC-to-host from a keyboard is not guaranteed). Do NOT assume in-extension AFM.

### H2 — Third-party keyboards are auto-disabled in secure text fields
iOS swaps to the system keyboard in password/secure fields. **A custom keyboard
therefore cannot autofill passwords or SMS OTPs.** The thread's turn 21/22 goal is
real but must be delivered as a **separate AutoFill Credential Provider
extension** (E12), not from the keyboard. The keyboard's only job in secure fields
is to yield gracefully (the OS does this). Contact-address / wallet autofill is
likewise a system-AutoFill concern, not keyboard text injection.

### H3 — AFM LoRA adapters: runtime download works, but break on base-model bumps
fedelm CONFIRMS: adapters can be downloaded at runtime via **Background Assets**
and hot-loaded with `SystemLanguageModel(adapter:)` + `LanguageModelSession(model:)`
(no build-time bundling required). BUT adapter compatibility **breaks whenever
Apple updates the base system model** → every adapter must carry a base-model
version tag, and the app must **guard-check compatibility before loading** and
silently fall back to the un-adapted model on mismatch (axiom: loud + no silent
wrong-state).

### H4 — Workers AI LoRA serving is OPEN BETA, not GA
The thread said "GA now." fedelm: **open beta as of latest evidence, no GA
confirmation.** AI Gateway exact-match caching (`cf-aig-cache-status: HIT/MISS`)
and R2 `object-create` → Queues are confirmed. D1-for-metering is **not**
documented as the metering path — **Workers Analytics Engine** is the documented
custom-metrics surface. **Consequence:** E7 must (a) treat CF-hosted LoRA as
behind a feature flag with the **BYO-endpoint tier as the non-beta-dependent
path**, and (b) use Analytics Engine (or D1 with eyes open) for metering, decided
in a slice, not assumed.

## Axiom lens (every slice was cut against these)

**Bifrost architectural axioms** — Zero Local Secrets (no keys on disk; keyboard
never networks; BYO keys live in Keychain, fetched at use), Pragmatic Law (gate
early — each slice ships with a test/acceptance check), Single-Track Development
(branch → PR → squash → learnings), Commodity Intelligence (models are swappable;
never hardcode a model id), Autonomy in Hostility, Justice/Accountability.

**Erebus Compact axioms**: Loud by default (no empty catch, no silent
`return nil` on error; every fallback logs a structured line), Mechanize-not-md
(ship a check/test, not a note), Defer-nothing (a blocked slice is FILED with its
blocker named, never left in prose), Deficiency→file+fix.

## How a cheap non-thinking agent should consume a slice

Each slice in `01-SLICES.md` is **self-contained**: it names the exact files to
create/edit, embeds the API surface and constraints it needs inline (so no
cross-referencing or judgement is required), lists numbered steps, and gives a
binary **Done-when** acceptance check. If a slice says "SPIKE," the deliverable is
a findings note + a go/no-go, not production code. Work one slice per branch
(`wt/<slice-id>-<ts>`), open a PR, let the cicada pre-push gate run. Never add a
`.github/workflows/*` file — CI/CD is charon-cicada (`.cicada-policy.yml`).
