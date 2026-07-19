# HydraCore

Platform-agnostic correction core for hydratype (thread T34: build this FIRST; it
compiles identically on iOS 26 and macOS 26 with zero platform-conditional code in
its public surface).

## What's here

| File | Slice | Purpose |
|------|-------|---------|
| `CorrectionSuggestion.swift` | E1-S1 | The `@Generable` guided-generation output type (`primary` + ranked `alternates` + `noChange`) + Sendable `PartialCorrection` streaming snapshot. |
| `AppGroupSmoke.swift` | E0-S1 | Cross-target App Group read/write stamp (keyboard writes, host reads). |
| `AFMCorrector.swift` | E1-S2 | Wraps `LanguageModelSession` for one-shot + streaming correction. Loud on unavailability. |
| `CorrectorError.swift` | E1-S2 | Typed, named error surface — no silent `nil`. |
| `CorrectionMode.swift` / `ModeEngine.swift` | E1-S3 | Field-kind → mode mapping + sticky manual override. UI-free. |
| `CorrectionStore.swift` | E1-S4 | Raw-SQLite3 App-Group store of correction events; append / recentUnsynced / markSynced. |
| `Sources/hydratype-cli` | E1b-S1 | Headless stdin→correction CLI (the fast build-test-observe loop). |
| `Sources/hydracore-check` | — | Framework-free runnable logic gate (see below). |
| `Tests/HydraCoreTests` | — | XCTest suite (Xcode toolchain). |

## Toolchain requirement

Foundation Models' `@Generable`/`@Guide` macros are provided by the
`FoundationModelsMacros` plugin, which ships with **Xcode** (not the bare Command
Line Tools). This project's machine has `xcode-select` pointed at Xcode, so plain
`swift build`/`swift test`/`swift run` resolve the plugin and the AFM path compiles
unconditionally. The package baselines at **iOS/macOS 26** (Foundation Models is
26+), so no availability guards or compile-conditions are needed. On a Command Line
Tools–only or Linux host the package will not build — that is inherent to
Foundation Models, not a bug.

## Verify

```sh
# Build the library + CLI + logic gate (uses the Xcode toolchain's macro plugin):
swift build

# Runnable logic gate — mode engine, store round-trip, loud error paths.
# Exits non-zero on the first failure. Wired into scripts/gate.sh / cicada pre-push.
swift run hydracore-check

# Full XCTest suite:
swift test
# (the model-unavailability test auto-skips on a host where a system model IS available)

# Real on-device AFM correction (host with Apple Intelligence available):
echo "i cant beleive it" | swift run hydratype-cli
# → primary: I can’t believe it.  (live-verified 2026-07-19)
```

## Axioms honored

- **Commodity Intelligence** — no model id hardcoded; binds `SystemLanguageModel.default`.
- **Loud by default** — every failure is a named `CorrectorError`/`StoreError`; an
  unavailable model throws, never degrades silently.
- **Zero Local Secrets** — the core never networks and stores no keys; BYO endpoint
  keys live in Keychain (host app), never in this store.
