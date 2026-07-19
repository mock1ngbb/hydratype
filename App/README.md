# HydraType Xcode project (E0-S1)

Two targets, generated from [`project.yml`](../project.yml) by **XcodeGen** (the
`.xcodeproj` is a build artifact — gitignored, never hand-edited):

| Target | Type | Bundle id | Role |
|--------|------|-----------|------|
| `HydraType` | iOS app | `com.mock1ngbb.hydratype` | SwiftUI host app (dashboard, calibration, monetization live here per 4.4.1) |
| `HydraTypeKeyboard` | app extension | `com.mock1ngbb.hydratype.keyboard` | custom keyboard; embedded in the host app |

Both share **App Group** `group.com.mock1ngbb.hydratype` (entitlements in `App/` and
`KeyboardExtension/`) and link the local **HydraCore** SPM package built with
`-D HYDRA_AFM`, so the real Foundation Models `@Generable` path compiles.

## Generate & build

```sh
scripts/bootstrap-xcode.sh          # installs XcodeGen if needed, runs xcodegen generate
open HydraType.xcodeproj            # or work in Xcode

# Headless compile-verify (signing off; iOS 26 simulator SDK):
xcodebuild -project HydraType.xcodeproj -scheme HydraType \
  -destination 'generic/platform=iOS Simulator' -sdk iphonesimulator \
  CODE_SIGNING_ALLOWED=NO build
```

## App Group smoke (E0-S1 done-when)

`AppGroupSmoke` (in HydraCore) writes/reads a stamp in the shared container. The
keyboard writes `keyboard@<ts>` on load (see Console, subsystem
`com.mock1ngbb.hydratype`); the host app's **Read keyboard stamp** button reads it
back. Full cross-target round-trip requires enabling the keyboard once in
Settings → General → Keyboards (manual, per iOS). Build + entitlement wiring is
verified headlessly by the `xcodebuild` command above.

## Status

- ✅ Build-verified (both targets, embed, real HYDRA_AFM path) on the iOS 26 sim SDK.
- ⏳ E2 keyboard correction pipeline is stubbed — gated on **E-SPIKE-1** (task
  `cb4b60c1`): in-process AFM vs host broker is undecided until the device probe runs.
