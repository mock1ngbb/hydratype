# hydratype — Internal TestFlight lane (E5-S1)

**Date:** 2026-07-19
**Slice:** E5-S1 — Internal TestFlight lane (ops).
**Goal:** Ship the Phase-3 build to **≤ 100 internal testers** with **no beta
review**. Internal testing (App Store Connect team members) does not go through
App Review; external testing does.

> ⛔️ **CI/CD note:** GitHub Actions is FORBIDDEN across this ecosystem. Build/
> sign/ship is Xcode / fastlane / Xcode Cloud only. charon-cicada owns intake and
> policy gating (`.cicada-policy.yml`). Never add a `.github/workflows/*` file.

---

## 1. Targets & bundle identifiers

Two targets share the App Group `group.com.mock1ngbb.hydratype` (see E0-S1). The
extension bundle id **must** be prefixed by the host app bundle id — iOS requires
an app extension's identifier to be `<hostId>.<suffix>`.

| Target | Kind | Bundle identifier |
|--------|------|-------------------|
| `HydraType` | iOS host app (SwiftUI) | `com.mock1ngbb.hydratype` |
| `HydraTypeKeyboard` | Custom keyboard extension | `com.mock1ngbb.hydratype.keyboard` |
| — | App Group (shared, both targets) | `group.com.mock1ngbb.hydratype` |

Both targets are uploaded inside **one** app record / one `.ipa`. TestFlight
distributes the host app; the embedded keyboard extension ships with it.

---

## 2. App Store Connect — internal testing setup (step by step)

1. **Register bundle ids** (Certificates, Identifiers & Profiles):
   - Create App ID `com.mock1ngbb.hydratype` with the App Groups capability
     enabled and assigned to `group.com.mock1ngbb.hydratype`.
   - Create App ID `com.mock1ngbb.hydratype.keyboard` with the same App Group.
2. **Create the app record** in App Store Connect → **Apps → +** → New App:
   - Platform iOS, primary bundle id `com.mock1ngbb.hydratype`, SKU, name.
   - The keyboard extension needs **no** separate app record — it rides inside
     the host `.ipa`.
3. **Upload a build** (one of, no GitHub Actions):
   - Xcode: Product → Archive → Distribute App → App Store Connect → Upload; **or**
   - `fastlane pilot upload` / `xcrun altool`/`notarytool` pipeline; **or**
   - Xcode Cloud workflow that archives + delivers to TestFlight.
   - After processing, the build appears under **TestFlight**. Complete the
     **Export Compliance** answer (no non-exempt encryption ⇒ typically "No").
4. **Internal test group** (no App Review):
   - TestFlight → **Internal Testing → +** to create a group (e.g. `phase-3`).
   - Add testers — they must be **Users** on the team (App Store Connect roles).
     Internal testers cap at **100**.
   - Enable the processed build for the group. Testers get it in the TestFlight
     app immediately — **internal builds skip beta review entirely.**
5. **DO NOT** add an External group for this slice — external testing *does*
   require Beta App Review and defeats the "no review" goal.

---

## 3. 🔁🔁 90-DAY BUILD-EXPIRY REFRESH CADENCE — RECURRING, NOT ONE-TIME 🔁🔁

> ### ⏰ EVERY TestFlight build EXPIRES 90 DAYS after upload. ⏰
> ### This is a **STANDING, REPEATING** obligation — re-upload a fresh build on a
> ### rolling cadence so testers are never locked out. It is NOT a one-time task.

- **Cadence:** upload a replacement build **at least every ~75 days** (buffer
  before the 90-day cliff), and re-enable it for the `phase-3` internal group.
- When a build expires it becomes uninstallable/unlaunchable for testers — the
  only fix is a newer build. Treat a lapsed build as an outage.
- **Defer-nothing:** this reminder is FILED as a recurring cadence here, not left
  as vibes. Wire a recurring reminder (calendar / task-store) keyed to each
  upload's +75-day date; renew the reminder every time you upload.

---

## 4. Guideline 4.4.1 — keyboard must work WITHOUT Full Access

The keyboard extension **must be demonstrably functional without Full Access**
(`RequestsOpenAccess = false` by default; see E0-S1). App Review guideline 4.4.1
requires a keyboard to provide its core function with no network access and no
Full Access granted.

- Core typing + local correction must work with Full Access **off**.
- **Testers / reviewers should explicitly verify:** install, add HydraType in
  Settings → General → Keyboard → Keyboards, and use it **without** toggling
  "Allow Full Access" — typing and on-device correction must still function.
- Any capability that needs Full Access (e.g. host-app broker networking) must be
  additive, never required for the baseline keyboard to type.

---

## 5. ⛔️ BLOCKED / PENDING — cannot actually push a build yet

**BLOCKER: No signing identity, fastlane lane, or Xcode Cloud workflow is wired
yet — `.bifrost/deploy-manifest.json` has an empty `targets: []` and states "No
auto-deploy target until an Xcode-Cloud or fastlane target is wired." Until a
signing/distribution lane exists, this doc is procedure-ready but NO build can be
uploaded.**

Unblock requires (each a follow-up slice/task, not vibes):
- Apple Developer distribution certificate + provisioning profiles for **both**
  bundle ids (App Group entitlement included).
- A distribution lane: fastlane `pilot`/`deliver` **or** an Xcode Cloud workflow
  (NOT GitHub Actions), plus App Store Connect API key stored via `bf` (Zero
  Local Secrets — never committed).
- A `targets[]` entry added to `.bifrost/deploy-manifest.json` describing the
  TestFlight lane once wired.

---

## Axiom check

- **Defer-nothing:** the 90-day expiry is filed as a *recurring cadence* (§3) and
  the missing-lane blocker is named explicitly (§5), not left in prose.
- **Zero Local Secrets:** App Store Connect API key / signing creds fetched via
  `bf` at use time, never committed.
- **Loud:** an expired or lapsed build is treated as an outage, not silently
  tolerated.
- **No GitHub Actions:** distribution is Xcode / fastlane / Xcode Cloud only,
  under charon-cicada gating.
