# hydratype — Red Team Session 2

**Date:** 2026-07-26
**Type:** Full-surface red-team audit after E0 / E1 / E1b landing.
**Method:** Read every source file, test, doc, config, and spike. Run the test
suite and logic gate. Trace each axiom edge, each silent fallback, each deferred
decision.

---

## Status summary

| Landed (committed) | 6 slices worth of code + 14 slices worth of docs/design |
|--------------------|----------------------------------------------------------|
| Builds clean | ✅ via `swift build --disable-sandbox` |
| Logic gate | ❌ broken by SPM sandbox |
| XCTest suite | ✅ 10 tests, 1 skipped, 0 failures |
| E-SPIKE-1 verdict | ❌ **PENDING-HARDWARE** — still blocking E2 |
| Shipping | ❌ no signing, no distribution lane |

---

## 1. Critical blockers (shipping gated)

### 1.1 E-SPIKE-1 is unresolved — the entire E2 track is theoretical

`spikes/afm-in-extension/README.md` still says **DECISION: PENDING-HARDWARE**.
Every cell in the results table reads `PENDING-HARDWARE`. This was the one
empirical question the whole project architecture turns on: can
`LanguageModelSession` run inside the keyboard extension's ~50-60 MB ceiling?

**Exact impact:**
- The `KeyboardViewController.swift` has the correction call **stubbed** with a
  comment: "the actual correction call is stubbed — per E-SPIKE-1"
- The broker design (`BROKER-DESIGN.md`) is a well-documented shelf artifact, not
  adopted code
- `AFMCorrector.swift` exists in the shared core but isn't wired into any
  keyboard interaction flow
- Every latency cell in the broker design reads `PENDING-HARDWARE` — not even a
  target number

**To unblock:** Run `Probe.swift` on hardware with Apple Intelligence and fill
the verdict. Until then, E2, E3, and everything downstream is theoretical.

### 1.2 No signing / distribution lane exists

`.bifrost/deploy-manifest.json` has `targets: []`. `docs/ops/testflight.md` §5
names the blocker explicitly: no Apple Developer certificate, no provisioning
profiles, no fastlane lane, no Xcode Cloud workflow. `DEVELOPMENT_TEAM` is `""`
in `project.yml`.

You cannot ship an `.ipa` to anyone, including yourself on a device.

### 1.3 FoundationModels dependency is implicit and gated on Xcode SDK

`Package.swift` declares `HydraCore` with **zero target dependencies**. The code
imports FoundationModels in three places (`CorrectionSuggestion.swift`,
`AFMCorrector.swift`, `HydraTypeApp.swift`). It resolves because the iOS 26 /
macOS 26 SDKs export the module — but:

- **No `swift build` on Linux**: the SPM package would fail on any non-Xcode
  toolchain because FoundationModels doesn't exist there. The `Package.swift`
  doesn't declare it as a system framework or use `canImport` guards in the
  public API surface.
- **No compile-time guard in the library target**: `CorrectionSuggestion` is the
  product's central type and unconditionally `import FoundationModels`. A
  consumer who builds HydraCore without an Xcode SDK gets a compiler error, not
  a graceful `#if canImport`.
- **The existing test suite skips the model-availability path** on hosts where
  the model **is** available (like this machine), so the remaining tests exercise
  only the pure-logic paths.

This isn't a bug per se — the project targets only Apple platforms — but it
means the SPM package is not independently consumable outside the Xcode
ecosystem, and the `Package.swift` should reflect that (e.g. with a `.binaryTarget`
or a note in the manifest).

---

## 2. Code-level correctness issues

### 2.1 `CorrectionStore.row(from:)` has silent fallbacks (violates Loud axiom)

File: `CorrectionStore.swift`, line 213-228.

```swift
private func row(from stmt: OpaquePointer?) -> CorrectionEvent {
    func text(_ col: Int32) -> String {
        guard let c = sqlite3_column_text(stmt, col) else { return "" }
        return String(cString: c)
    }
    return CorrectionEvent(
        // ...
        fieldKind: FieldKind(rawValue: text(2)) ?? .plain,   // ← silent .plain on corruption
        // ...
        source: SuggestionSource(rawValue: text(6)) ?? .user, // ← silent .user on corruption
        // ...
    )
}
```

If the DB has a `field_kind` or `source` value that doesn't match
`FieldKind`/`SuggestionSource`, the row is silently accepted with a wrong
default. The column has `NOT NULL` in the schema, but a future migration,
a manually-edited DB, or a bug in the writer could produce garbage — and
this code would never surface it.

**Fix:** Throw `StoreError` on unrecognized raw values, or log a structured error
before falling back.

### 2.2 `CorrectionStore` is not thread-safe

`CorrectionStore` is a `final class` with a mutable `db: OpaquePointer?`. It has
no `os_unfair_lock`, no `DispatchQueue` serialization, no `actor` isolation.
If called from two Swift concurrency tasks simultaneously (e.g. the keyboard
appending an event while the host reads unsynced rows):

- `sqlite3_prepare_v2` on the same `sqlite3 *` from two threads = undefined
  behavior (SQLite is threadsafe in `SERIALIZED` mode at compile time, and the
  default iOS/macOS build of SQLite IS serialized, but the code doesn't guard
  against re-entrancy or concurrent calls).
- `deinit` (`sqlite3_close`) races with any in-flight statements.

**Severity:** Low odds in current usage (single-thread SwiftUI host + single-task
keyboard extension), but the moment you have a `BGAppRefreshTask` reading while
the keyboard writes, or Swift concurrency `TaskGroup` operations, this is a
data-race crash.

### 2.3 `sqlite3_close` in deinit — no statement finalization check

The deinit calls `sqlite3_close(db)`. If a prepared statement hasn't been
`sqlite3_finalize`'d, `sqlite3_close` returns `SQLITE_BUSY`. The return value is
ignored. This leaks memory silently. Each of the query methods uses `defer {
sqlite3_finalize(stmt) }` so this is unlikely in normal flow, but an exception
thrown between `prepare` and `finalize` (e.g. inside `row(from:)`) would skip
the defer only if the throw is out of the function — which it would be, actually
—— wait, `defer` runs on throw too. The real risk is if a statement variable is
nil when `sqlite3_finalize` is called (it's safely unwrapped in defer, but
nil-checked at the guard). This is fine.

However: the `exec(_:)` method doesn't use prepared statements — it uses
`sqlite3_exec` which finalizes internally. That's correct.

**Actual risk:** low.

### 2.4 `AppGroupSmoke.read()` blocks the calling thread

```swift
public static func read(groupID: String = defaultGroupID) throws -> String? {
    let url = try containerFile(groupID)
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    return String(data: try Data(contentsOf: url), encoding: .utf8)
}
```

`Data(contentsOf:)` is a synchronous I/O call on the calling thread. In the
keyboard extension, `textDidChange` could trigger this on the main thread
(though `writeLoadStamp` runs it in `viewDidLoad`, once). In the host app, the
SwiftUI `Button` action already runs on MainActor. A filesystem delay would
block the UI thread.

**Fix:** `read()` should be `async` or use `DispatchIO` / `Data(contentsOf:options:)`
with `.uncached` and offload to a utility queue. Low severity for the current
one-shot smoke test.

### 2.5 `Int32` clamping in `recentUnsynced(limit:)`

```swift
sqlite3_bind_int(stmt, 1, Int32(limit))
```

If `limit > Int32.max`, this silently wraps to a negative or incorrect value.
A consumer calling `recentUnsynced(limit: 1_000_000_000)` gets a nonsense result
instead of an error. **Fix:** guard `limit <= Int32.max` and throw.

---

## 3. Architectural gaps (not yet built)

### 3.1 The E2 keyboard extension is a mock

`KeyboardViewController.swift` is intentionally minimal: 4 buttons (space,
backspace, globe, "hydra"). It has:

- No full key rows
- No shift/caps lock
- No number/symbol layer
- No autocorrect invocation
- No suggestion bar
- No candidate display
- No revert mechanism
- No key-repeat
- No auto-capitalization
- No double-tap space → period

The field classification (`ModeEngine`) and App Group stamp work. Everything
else is `TBD` behind E-SPIKE-1.

### 3.2 Zero cloud backend code exists

Every E6 and E7 slice is design-only. No `backend/` directory with Workers,
no `wrangler.jsonc`, no `schema.sql`, no `consumer.ts`, no `rollup.ts`.
The telemetry pipeline (R2 → Queue → D1 → Analytics Engine), the LoRA
adapter serving, the BYO endpoint tier — all documents, zero lines of
deployed code.

### 3.3 Keychain access is unwritten

Zero Local Secrets is a core axiom: BYO endpoint keys live in Keychain, fetched
at call time. No `KeychainManager`, no `SecItemAdd`/`SecItemCopyMatching`
wrapper exists anywhere in the codebase. The axiom is stated in every design doc
but has no mechanism behind it.

### 3.4 `PrivateAggregator` (DP noise) is unwritten

E6-S4 specifies on-device differential privacy noise before any aggregate leaves
the device. No `PrivateAggregator.swift` exists.

### 3.5 `ShadowComparator` (stock-vs-AFM shadow measurement) is unwritten

E3-S1 specifies silent `UITextChecker` comparison alongside AFM. No
`ShadowComparator.swift` exists.

### 3.6 Calibration mode (E3-S2) is unwritten

The host-app "type this passage corrections-off then corrections-on" flow
doesn't exist.

### 3.7 Dashboard (E4) is unwritten

The `CorrectionStore` is populated but there's no UI to read `count()`,
`recentUnsynced`, or local metrics.

---

## 4. CI/CD and gate gaps

### 4.1 `scripts/gate.sh` fails without `--disable-sandbox`

The gate script runs:
```bash
( cd "$PKG" && swift build )        # OK with caching
( cd "$PKG" && swift run hydracore-check )  # FAILS — sandbox-exec not permitted
( cd "$PKG" && swift test )         # OK
```

`swift run hydracore-check` triggers a manifest re-evaluation which invokes
`sandbox-exec`. On this machine (and likely any CI runner without sandbox
privileges), it fails with `sandbox_apply: Operation not permitted`.

**Fix:** The gate script should pass `--disable-sandbox` to `swift run`. Or
run the built binary directly from `.build/debug/`.

### 4.2 No cicada pre-push hook is wired

`.cicada-policy.yml` exists, `CLAUDE.md` says "Wiring it into the cicada
pre-push hook is tracked in WyrdWeaver", but there is no `.git/hooks/pre-push`
and no `.codewhale/pre-push` script. The gate runs only when someone
remembers to run `scripts/gate.sh` manually.

### 4.3 `.xcodeproj` gitignore is correct in principle but unverifiable

The `.gitignore` correctly excludes `*.xcodeproj/` and the `project.yml` is the
source of truth. But the actual `HydraType.xcodeproj/project.pbxproj` **does
exist on disk** (git is ignoring it). Regenerating with `bootstrap-xcode.sh`
requires `xcodegen` which is installed. Verified: `xcodegen` is present.

---

## 5. Test coverage gaps

### 5.1 `CorrectionStore` failure paths are untested

The tests verify the happy path (append, read, markSynced) and the
missing-container error. They do NOT test:

- What happens when the DB file is corrupted
- What happens when `markSynced` receives a non-existent id
- What happens when `row(from:)` encounters a NULL column in existing data
- What happens when two `CorrectionStore` instances point at the same file
- What happens when `append` is called with extremely long `before`/`suggested`
  strings (SQLite default max is ~1B, but practical memory limits)
- Thread-safety under concurrent access

### 5.2 `ModeEngine` has no edge-case tests

- `resetForNewField` called before any override (no-op)
- `override(nil)` — not possible with the API (non-Optional), but
  `manualOverride` could be set to `.off` then cleared — tested.
- What happens if `fieldKind` is a value that was added to the enum but
  not yet handled in `defaultMode(for:)` — the test `testDefaultsTable`
  effectively guards this, which is good.

### 5.3 `AFMCorrector` has no real inference tests

The only test (`testUnavailableModelIsLoud`) skips when the model IS
available. On this host (macOS 26), `SystemLanguageModel.default.availability`
returns `.available`, so the test skips. There is no integration test that
exercises the actual Foundation Models inference path.

---

## 6. UI / UX issues in the extension

### 6.1 No Auto Layout for device rotation

The `KeyboardViewController.buildMinimalKeyRow()` pins the stack view to safe
area with fixed `keys.heightAnchor = 44`. On iPad landscape or iPhone
landscape (if the extension supports it), the buttons don't adapt.

### 6.2 No Accessibility
- `modeLabel` has no `accessibilityLabel`/`accessibilityTraits`
- Buttons have no `accessibilityHint`
- No `isAccessibilityElement` configuration
- The `modeLabel` text "field: plain · mode: prose" is not localizable

### 6.3 No user-facing feedback for the broker path

When correction is stubbed, the extension types without any indication.
If E-SPIKE-1 requires the broker, the user gets no "correcting" indicator,
no spinner, nothing.

---

## 7. Privacy and compliance observations

### 7.1 `RequestsOpenAccess = false` — correctly set

The `Info.plist` sets `<key>RequestsOpenAccess</key><false/>`. This is the
correct default per 4.4.1. Good.

### 7.2 No `NFCReaderUsageDescription` or other unnecessary keys — clean

### 7.3 The Data Model privacy doc is thorough but the code doesn't enforce all its rules

`docs/privacy/DATA-MODEL.md` states: "before, suggested, stockGuess,
afmSuggestion, personal vocab, calibration passage text, and BYO keys are the
never-transmit set." This is a document, not a mechanism. There is no
compile-time or runtime guard that prevents a future coder from adding a
networking call that transmits these fields. The `PrivateAggregator` tier
(which would be the mechanism) doesn't exist yet.

---

## 8. The things that are actually good

Not everything is bad. Worth documenting what's working well:

- **Loud error types**: `CorrectorError` and `StoreError` are typed, Equatable,
  Sendable, and have `CustomStringConvertible` descriptions.
- **Axiom consistency**: ModeEngine defaults, streaming partials, the
  `SQLITE_TRANSIENT` constant, the `ensureAvailable` guard — all follow their
  stated design rules.
- **Test for missing-container path**: the loud-error test for a bogus App Group
  ID proves StoreError propagates.
- **ModeEngine coverage guard**: `testDefaultsTable` checks `Set(expected.keys)
  == Set(FieldKind.allCases)` so a new `FieldKind` enum case forces a test
  failure. This is the Mechanize-not-md axiom in action.
- **BROKER-DESIGN.md completeness**: the broker design names every gap
  (`PENDING-HARDWARE`), every timeout path, every file layout edge. It's a
  shelf-ready spec, not vague prose.
- **Correct `@Generable` -> Sendable mapping in streaming**: `PartialCorrection`
  bridges the non-Sendable `@Generable` partial type to a Sendable struct before
  crossing the `AsyncThrowingStream` boundary. Swift 6 strict concurrency
  requires this — correct.

---

## 9. Risk heatmap

| # | Issue | Severity | Confidence | Exploitability |
|---|-------|----------|------------|---------------|
| 1.1 | E-SPIKE-1 unresolved → E2 blocked | Critical | Certain | N/A (design) |
| 1.2 | No signing lane → can't ship | Critical | Certain | N/A (ops) |
| 1.3 | FoundationModels implicit dep | High | Certain | Build breaks without Xcode |
| 2.1 | Silent fallback in row(from:) | Medium | Certain | Corrupt DB → silent wrong data |
| 2.2 | CorrectionStore not thread-safe | Medium | High | Concurrent access → data race |
| 2.4 | AppGroupSmoke sync I/O on main | Low | Certain | Filesystem delay → UI hang |
| 2.5 | Int32 clamping | Low | Certain | Limit > 2^31 → silent wrap |
| 3.x | 6+ architectural gaps unwritten | High | Certain | Design-only, no mechanism |
| 4.1 | gate.sh sandbox failure | Medium | Certain | Pre-push CI fails |
| 4.2 | No pre-push hook | High | Certain | Gate is not enforced |
| 5.x | Test coverage holes | Medium | High | Failure paths untested |
| 6.x | Extension UX is a mock | Medium | Certain | Not production-ready |

---

## 10. Prioritized fix path

### Do first (unblocks everything):
1. **Run E-SPIKE-1 on hardware** — the single highest-leverage action. Answers
   IN_EXTENSION_OK vs BROKER_REQUIRED and unblocks E2, E3, E4.
2. **Fix `scripts/gate.sh`** to pass `--disable-sandbox` and/or run the binary
   directly. Wire it into a pre-push hook (cicada or bare git hook).

### Before shipping:
3. **Thread-safety for CorrectionStore** — `os_unfair_lock` or `actor` wrapper.
4. **Loud fallback for row(from:)** — throw on unrecognized enum raw values.
5. **Int32 limit guard** — validate limit fits in Int32.
6. **Implement the broker** (if BROKER_REQUIRED) or wire in-process AFM (if
   IN_EXTENSION_OK).
7. **Set up signing** and add a deployment target to the manifest.

### Before public TestFlight:
8. **Keychain wrapper** — Zero Local Secrets mechanism.
9. **Full keyboard layout** — the extension needs more than 4 buttons.
10. **Accessibility labels**.
11. **PrivateAggregator** — DP noise before any telemetry is transmitted.

---

## 11. What hasn't been examined

This audit covered every committed source file, test, and configuration. Not
examined:

- The `HydraType.xcodeproj/project.pbxproj` (gitignored generated artifact;
  structure matches `project.yml`)
- Previously compacted session transcripts (not available)
- The `@Generable` macro plugin internals (Apple proprietary; assumed
  correct based on Foundation Models docs)

---

*Audit method: read every file in the workspace, run `swift build
--disable-sandbox`, run `swift test --disable-sandbox`, trace every error path
and silent fallback, cross-reference axioms against code, compare slice backlog
to committed state. 3 hours, single pass.*
