# HydraCore

Platform-agnostic correction core for hydratype (thread T34: build this FIRST; it
compiles identically on iOS 26 and macOS 26 with zero platform-conditional code in
its public surface).

## What's here

| File | Slice | Purpose |
|------|-------|---------|
| `CorrectionSuggestion.swift` | E1-S1 | The guided-generation output type (`primary` + ranked `alternates` + `noChange`). `@Generable` under `HYDRA_AFM`, plain mirror otherwise. |
| `AFMCorrector.swift` | E1-S2 | Wraps `LanguageModelSession` for one-shot + streaming correction. Loud on unavailability. |
| `CorrectorError.swift` | E1-S2 | Typed, named error surface — no silent `nil`. |
| `CorrectionMode.swift` / `ModeEngine.swift` | E1-S3 | Field-kind → mode mapping + sticky manual override. UI-free. |
| `CorrectionStore.swift` | E1-S4 | Raw-SQLite3 App-Group store of correction events; append / recentUnsynced / markSynced. |
| `Sources/hydratype-cli` | E1b-S1 | Headless stdin→correction CLI (the fast build-test-observe loop). Needs `HYDRA_AFM`. |
| `Sources/hydracore-check` | — | Framework-free runnable logic gate (see below). |
| `Tests/HydraCoreTests` | — | XCTest suite (needs a full Xcode toolchain). |

## The `HYDRA_AFM` compilation gate

Apple's Foundation Models `@Generable`/`@Guide` macros are provided by the
closed-source `FoundationModelsMacros` plugin, which is **only loaded by Xcode's
build — not by a plain `swift build` from the CLI** (and `canImport(FoundationModels)`
returns true even where the macro plugin is absent, so it can't be the gate).

So the AFM path is gated behind the `HYDRA_AFM` compilation condition:

- **Without `HYDRA_AFM`** (CLI, CI, this repo's local gate): the plain
  `CorrectionSuggestion` mirror compiles; `AFMCorrector` throws
  `CorrectorError.foundationModelsUnavailable` **loudly** — it never silently no-ops.
- **With `HYDRA_AFM`** (the Xcode app + keyboard targets, built against the
  macOS/iOS 26 SDK): the real `@Generable` type and guided-generation calls compile.

Xcode targets must set `SWIFT_ACTIVE_COMPILATION_CONDITIONS` to include `HYDRA_AFM`
(or pass `-D HYDRA_AFM`). Filed follow-up: task `21aabb92` (E0-S1 Xcode project).

## Verify

```sh
# Builds the library + CLI + logic gate (skips FoundationModels; no Xcode needed):
swift build

# Runnable logic gate — verifies mode engine, store round-trip, loud error paths.
# Exits non-zero on the first failure. Wired as the cicada pre-push gate.
swift run hydracore-check

# Full XCTest suite — needs a licensed full Xcode toolchain:
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
# (blocked in this env until `sudo xcodebuild -license accept`; task dba80f7f)

# Real AFM correction on macOS 26 hardware:
swift build -Xswiftc -DHYDRA_AFM && echo "i cant beleive it" | swift run hydratype-cli
```

## Axioms honored

- **Commodity Intelligence** — no model id hardcoded; binds `SystemLanguageModel.default`.
- **Loud by default** — every failure is a named `CorrectorError`/`StoreError`; the
  no-AFM build throws, never degrades silently.
- **Zero Local Secrets** — the core never networks and stores no keys; BYO endpoint
  keys live in Keychain (host app), never in this store.
