# hydratype

Intent- and context-aware autocorrect for iOS and macOS 26. A custom keyboard extension that
runs corrections through Apple's **on-device Foundation Models** LLM (~3B params) instead of the
stock n-gram / edit-distance corrector.

The stock corrector ranks candidates by local n-grams and edit distance; it never reasons about the
*whole message's* intent or tone. hydratype feeds full sentence context into the on-device LLM via a
`@Generable` "did-you-mean" schema, so `shot -> shit` is decided by meaning, not Levenshtein proximity.

- **Reads the room.** It considers the whole sentence, not a sliding window of neighbors.
- **Keeps your voice.** It preserves deliberate slang, dialect, and profanity instead of sanitizing them.
- **Private by construction.** The keyboard does zero networking; only the host app ever talks to a server.
- **Commodity intelligence.** No hardcoded model id; the model is a swappable component, not a religion.

## Architecture

- **Shared Swift core (`Packages/HydraCore`)** drives correction. The keyboard extension and the
  host app both speak to it; one engine, one source of truth.
- **Zero networking in the keyboard.** Correction inference runs on-device, in-process or brokered
  through the host app over a shared App Group.
- **Zero Local Secrets.** BYO endpoint keys live in the Keychain, fetched at call time, never written
  to disk and never hardcoded.
- **Opt-in, differentially-noised telemetry.** The host app computes local deltas, adds calibrated
  noise *before* anything is transmitted, and only the host app uploads. Three cohorts: baseline,
  local_afm, cloud_assisted. Raw keystrokes never leave the device.

## Status

Greenfield. The core correction engine, correction store, mode engine, App Group smoke test, and a
macOS CLI test rig are built and passing. **E-SPIKE-1** (empirically validating on-device AFM inside
the extension) is pending hardware validation; full layout and correction wiring are gated behind
that verdict. It is not yet on the App Store, and it is honest about what that means.

## The Erebus Compact

Built to the **Erebus Compact**, the constitution of the House of Hydra: Zero Local Secrets, Loud by
default, Honest measurement, Commodity Intelligence, Mechanize not md, Defer nothing, Age is not a
gate, Plan is consent, and File it then fix it. Read the full Compact (9 Articles and the
antipatterns the Council forbids) at [`deck.mock1ngbb.com/hydrav11/erebus-compact`](https://deck.mock1ngbb.com/hydrav11/erebus-compact).

## Building

```sh
# Shared core (Xcode toolchain required; @Generable is not in Command Line Tools)
cd Packages/HydraCore && swift build && swift test

# Real on-device correction
echo "i cant beleive it" | swift run hydratype-cli

# Xcode app + keyboard extension (project.yml is the source of truth; .xcodeproj is generated)
scripts/bootstrap-xcode.sh
xcodebuild -project HydraType.xcodeproj -scheme HydraType \
  -destination 'generic/platform=iOS Simulator' -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build
```

## CI/CD

Governed by charon-cicada (`.cicada-policy.yml`); GitHub Actions is structurally forbidden in this
ecosystem. The pre-push gate is the hard gate. See `docs/` for the design slices, reference material,
and architecture notes.
