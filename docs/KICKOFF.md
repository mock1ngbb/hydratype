# Hydratype — Session Kickoff

**Prepared:** 2026-08-03 · **Main:** `8739a21` · Live state: [`docs/RESUME.md`](RESUME.md)

**The project:** an iOS/macOS 26 custom keyboard that runs autocorrect through Apple's **on-device
Foundation Models** (`@Generable` guided generation) instead of n-gram/edit-distance. Shared Swift core
(`Packages/HydraCore`), Cloudflare telemetry (opt-in, differentially-noised). Governed by the
**Erebus Compact** constitution (ethos, authenticity, autonomy, privacy, accessibility).

---

## Current state — all merged + live

- **Core:** Hybrid corrector (fast Damerau-Levenshtein + AFM escalation), local **DP telemetry**
  (`DifferentialPrivacy`), benchmark harness (`hydracore-bench`), structured-output hardening.
- **On-device AFM:** **macOS M5 pivot `IN_PROCESS_OK`** — `"i cant beleive it"` → `"I can't believe it."`,
  ~1.6s one-shot, footprint 3.6→13.2 MB (model runs in a separate OS process).
- **CI/CD:** charon-cicada — GitHub webhook → `cicd-intake` → **merge-warden auto-merge**
  (hydratype watched, auto + manual fire proven).
- **wyrd:** fixed + durable (task filing works; R2 backup is the one broken piece — see below).

---

## Immediate next (highest leverage)

1. **E-SPIKE-1 iOS run** — the product gate. Run `spikes/afm-in-extension/Probe.swift` on a
   **physical AFM-enabled iPhone (iOS 26)** to determine `IN_EXTENSION_OK | BROKER_REQUIRED` (the
   ~50–60 MB keyboard-jetsam question). Fill the spike README verdict. Wyrd `deae238a`.
2. **wyrd R2 backup 500** — `bifrost-backups.r2.dev` returns HTTP 500; backups aren't reaching R2.
   Wyrd `064f406a`.
3. **Wire a real deploy lane** (Xcode Cloud / fastlane) → enables a server-side `cicada/build` check
   (merge-warden's `cicada/policy` proof is currently policy-only). Wyrd `669a0f3c`.

---

## How the machine works (read before pushing)

- **Worktrees:** branch from `origin/hee-haw`, work in `wt/<topic>-<ts>`, open a PR. **merge-warden
  auto-squash-merges** CLEAN PRs with a green `cicada/policy`. Never commit to the main checkout;
  self-merge is guarded — the operator carve-out is `CLAUDE_MERGE_APPROVE=<n>`.
- **Gate:** `scripts/gate.sh` (swift build + `hydracore-check` + XCTest + erebus deck-sync). Fail-closed:
  docs-only pushes skip the slow Swift gate; any code change runs the full gate.
- **Tasks:** `wyrd "<title>"` files into the current project's lane. Full open-item ledger + IDs:
  `docs/RESUME.md`.

---

## Verify

```sh
cd Packages/HydraCore && swift build && swift test
echo "i cant beleive it" | swift run hydratype-cli     # real on-device AFM correction
swift run hydracore-bench                               # fast-path benchmark (30/30, ~9ms)
```

Deck (live): `deck.mock1ngbb.com/hydrav11/erebus-compact`.
