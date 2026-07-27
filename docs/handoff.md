# hydratype — Handoff Document

**Date:** 2026-07-27  
**Session:** Red-team audit fix-up + deck meta tags + commit  
**Purpose:** New agent can pick up and continue without re-reading every doc.

---

## 1. Project Identity

**What:** hydratype — an iOS/macOS 26 custom keyboard that runs corrections through
Apple's on-device Foundation Models LLM (~3B, `@Generable` guided generation) instead
of n-gram/edit-distance.

**Axioms (non-negotiable):**
- **Zero Local Secrets** — BYO keys live in Keychain, fetched at call time, never on
  disk. Keyboard never networks.
- **Loud-by-default** — typed errors everywhere. No silent `return nil`,
  no `?? .default` without logging.
- **Commodity Intelligence** — never hardcode a model id.
- **Mechanize-not-md** — ship a check/test, not a memo. If it can be automated,
  automate it.
- **Defer-nothing** — blocked = filed with blocker named, not left in prose.
- **Single-Track** — branch → PR → squash → learnings. Never directly merge to
  the main checkout.

**Hard constraints (fedelm-corrected — these override the design thread):**
- AFM inside the keyboard extension is "highly improbable" (H1) — E2 gated on
  E-SPIKE-1.
- iOS swaps to system keyboard in secure fields — use a separate AutoFill Credential
  Provider extension (E12), NOT the keyboard.
- LoRA adapters break on base-model bumps (H3) — compatibility guard required.
- Workers AI LoRA serving is OPEN BETA (H4) — BYO-endpoint is the non-beta-dependent
  path.
- No GitHub Actions ever — charon-cicada only.

**Landing page:** https://deck.mock1ngbb.com/hydrav11

---

## 2. Epic State — What's Built vs Design-Only

### ✅ Built & Landed (committed, passing)

| Slice | Files | Notes |
|-------|-------|-------|
| **E0-S1** Xcode 2-target project | `project.yml`, `App/`, `KeyboardExtension/`, `.entitlements` | App Group wired, `RequestsOpenAccess=false` |
| **E1-S1** `CorrectionSuggestion` | `Sources/.../CorrectionSuggestion.swift` | Public `@Generable` struct, Equatable, Sendable, streaming partials |
| **E1-S2** `CorrectorError` | `Sources/.../CorrectorError.swift` | Typed errors, Equatable, Sendable |
| **E1-S3** `ModeEngine` | `Sources/.../ModeEngine.swift` | Field classification, mode switching, override, reset |
| **E1-S4** `CorrectionStore` | `Sources/.../CorrectionStore.swift` | SQLite local event log. **Now thread-safe, loud enum parsing** |
| **E1-S5** `AFMCorrector` | `Sources/.../AFMCorrector.swift` | Session wrapper. **Never called** — keyboard is stubbed |
| **E1b-S1** macOS CLI test rig | `Sources/hydratype-cli/CLI.swift` | `echo "i cant beleive it" | swift run hydratype-cli` works |
| **E1b-S2** Logic gate | `Sources/hydracore-check/main.swift` | **FIXED** — `scripts/gate.sh` passes |
| **E0-S2** Privacy docs | `docs/privacy/DATA-MODEL.md`, `docs/privacy/nutrition-label-draft.md` | Frozen, tier-classified, matches data model |
| **E5-S1** TestFlight ops doc | `docs/ops/testflight.md` | Procedure ready, blocker named |
| **E14-S1** Marketing deck | `deck/hydrav11/index.html`, `worker.js`, `wrangler.toml`, `og-image.png` | **LIVE at deck.mock1ngbb.com/hydrav11** — doc links fixed, og:image + canonical |
| Tests | 10 XCTests | 0 failures, 1 skip (AFM availability — model IS available, skip is correct) |

### 📋 Design-Only (not a line of code)

| Epic | What's needed | Why blocked |
|------|---------------|-------------|
| **E-SPIKE-1** | Run `Probe.swift` on Apple Silicon device | **THE blocker** — needs hardware with iOS 26 |
| **E-SPIKE-2** | Check Workers AI LoRA GA status | Beta-gated |
| **E2** | Full keyboard layout + correction wiring | Gates: E-SPIKE-1. Current: 4 buttons |
| **E3-S1** | `ShadowComparator.swift` | Not written |
| **E3-S2** | `App/Calibration/` | No calibration UI |
| **E4-S1** | `App/Dashboard/` | No dashboard UI |
| **E6** (4 slices) | `backend/` directory, Workers, R2→Queue→D1, `PrivateAggregator.swift` | Zero backend code |
| **E7** (5 slices) | LoRA retrain, adapter delivery, AI Gateway, metering, BYO | Beta-gated + no code |
| **E8** (3 slices) | StoreKit tip-unlock + subscription + submission | Shipping gated |
| **E9-E13** | Layouts, accessibility, prediction, autofill, training sets | Feature-phase, not scoped |

### ⚠️ Known Blockers (named, filed)

| Blocker | Where filed | What's needed |
|---------|-------------|---------------|
| **E-SPIKE-1 unresolved** | `spikes/afm-in-extension/README.md` | Run Probe.swift on Apple Silicon with iOS 26 |
| **No signing identity** | `project.yml:19` (`DEVELOPMENT_TEAM: ""`), `.bifrost/deploy-manifest.json` (`targets: []`) | Apple Developer cert + fastlane/Xcode Cloud lane |
| **KeychainManager missing** | No file exists | Zero Local Secrets is a doc, not a mechanism |
| **PrivateAggregator missing** | No file exists | DP noise is a doc, not a mechanism |

---

## 3. Deck (hydrav11) — Live at deck.mock1ngbb.com/hydrav11

**Files:** `deck/hydrav11/index.html` (29KB), `worker.js`, `wrangler.toml`, `og-image.png`  
**Worker version:** `66c6151a-b367-4683-b8e1-325d251fe26d`  
**Account zone:** `a62c1c7880b50ac345fc7c2135f6ae84`  
**Routes:** `deck.mock1ngbb.com/hydrav11` and `deck.mock1ngbb.com/hydrav11/*`

### Content (6-layer brand system)

| Layer | What's in the deck |
|-------|-------------------|
| L1: Fixed mythology | House of Hydra seal (SVG crest), "est. 1669", serif typography |
| L2: Per-product chapter | "Article IV of the Charter, as amended 2026" |
| L3: 90% deadpan / 1 wink | Theater sections in Georgia italic. **1 wink**: "Sluagh Swarm" footnote |
| L4: Competence anchor | `#receipts` section — SVG architecture diagram + invariants + privacy |
| L5: Consistency | Same seal, same lineage. Three-question gate: ✅ |
| L6: Engineer in-group | "sprint retrospectives that could have been emails", "compliance department with keycaps" |

### Deck deficiencies — ALL RESOLVED

1. **`og:image`** — ✅ 1200×630 PNG generated via Pillow (dark theme + crest + title).
   Base64-inlined in worker.js; served as `image/png` with 7-day CDN cache.
2. **`canonical` meta tag** — ✅ Added. Points to `https://deck.mock1ngbb.com/hydrav11`.

### Deck fixes applied across sessions

- **Broken doc links** (was `/erebus`/`/`) → replaced with GitHub source + docs links. ✅
- **`og:image` + `canonical`** — both meta tags added; og:image served inline from worker. ✅
- **Deployment** — live at version `66c6151a-b367-4683-b8e1-325d251fe26d`.

---

## 4. Session 3 & 4 Fix Progress

### Red-team bugs from Session 2 — all fixed

| Finding | Status | Notes |
|---------|--------|-------|
| `gate.sh` sandbox failure | **✅ FIXED** | `--disable-sandbox` on `swift build`/`swift test`; direct binary for hydracore-check (avoids `swift run` manifest sandboxing) |
| `row(from:)` silent fallbacks | **✅ FIXED** | `throws StoreError.parse` on unrecognized `FieldKind`/`SuggestionSource` raw values |
| `CorrectionStore` not thread-safe | **✅ FIXED** | `OSAllocatedUnfairLock` + `@unchecked Sendable` conformance |
| `Int32(limit)` silent wrap | **✅ FIXED** | `guard limit <= Int(Int32.max)` before SQL bind |

### Deck enhancements (Session 4)

| Item | Status | Notes |
|------|--------|-------|
| `og:image` social preview | **✅ FIXED** | 1200×630 PNG generated via Python/Pillow; inlined in worker.js; served as `image/png` |
| `canonical` meta tag | **✅ FIXED** | Points to `https://deck.mock1ngbb.com/hydrav11` |
| `.codewhale/` gitignored | **✅ FIXED** | Added to `.gitignore` — runtime state not committed |
| All changes committed | **✅ DONE** | Squash-merged via worktree branch `wt/session3-fixes-*` onto `hee-haw` |

### Known residual issues (intentional, not deferred)

- **`AFMCorrector.swift` is never called** — keyboard is stubbed per E-SPIKE-1.
- **No `.github/workflows/`** — never add one; cicada is the only CI/CD.
- **Xcode project is gitignored** — regenerate from `project.yml` via `bootstrap-xcode.sh`.
- **`swift run` triggers SPM manifest sandboxing** — always use `.build/debug/<binary>` directly.
- **KeychainManager and PrivateAggregator are design-only** — no code exists yet.

---

## 5. Git State

```
b101bf1 fix(red-team): gate sandbox, thread-safe store, loud parsing, deck meta tags (#5)
0fe8bb4 fix(deck): inline og-image.png in worker, add image route (#5 follow)
3aede21 docs: official stack references, architecture graphs, CLAUDE.md prefix-cache (#4)
14ee32f feat(E0-S1): Xcode two-target project + live-verified AFM path (#3)
5f28096 docs: privacy data-model, spikes, TestFlight ops, marketing page (#2)
f5830c9 feat(HydraCore): shared correction core — E1-S1..S4 + E1b-S1 + logic gate (#1)
51ae22e docs: epics + fedelm-hardened thin-slice backlog
48add1a scaffold hydratype: cicada policy, deploy manifest, research thread
```

**Branch:** `hee-haw` (trunk), ahead of `origin/hee-haw` by 2 commits.  
**Push blocked:** `origin` push is authorized only after `scripts/gate.sh` passes.
**Working tree:** Clean.

### Worktree cleanup
- Worktree `codex/agent-css-rewrite-682783f2` at
  `../.codewhale-worktrees/hydratype/codex-agent-css-rewrite-682783f2` is stale
  (same tree as hee-haw) — safe to delete.
- Temp branch `wt/session3-fixes-*` was squash-merged and deleted.

---

## 6. Quick-start for next agent

### Run the gate
```sh
bash scripts/gate.sh
```

### Real correction test (CLI)
```sh
cd Packages/HydraCore
echo "i cant beleive it" | .build/debug/hydratype-cli
```

### Regenerate Xcode project
```sh
bash scripts/bootstrap-xcode.sh
```

### Deploy deck
```sh
cd deck/hydrav11 && npx wrangler deploy
```

### Key files to read first
| File | What it is |
|------|-----------|
| `docs/slices/00-EPICS-AND-HARDENING.md` | Epic map + fedelm corrections (read this first) |
| `docs/slices/01-SLICES.md` | Per-slice backlog (all 322 lines) |
| `docs/ARCHITECTURE.md` | 6 system graphs |
| `docs/privacy/DATA-MODEL.md` | Frozen data model (every field classified) |
| `docs/reference/INDEX.md` | Index of per-stack official-doc references |
| `deck/hydrav11/index.html` | Live marketing deck |
| `.cicada-policy.yml` | CI/CD policy (no GitHub Actions) |
| `.bifrost/deploy-manifest.json` | Deploy target manifest |
| `docs/session-2.md` | Full red-team audit findings (context for the fixes applied) |

### Red flags for the next agent
- **Do NOT** assume in-extension AFM (H1). E-SPIKE-1 verdict is pending hardware.
- **Do NOT** add `.github/workflows/*` files. Cicada police will refuse the push.
- **Do NOT** merge to main directly — use worktree branch → PR → squash.
- **Never** hardcode a model id (Commodity Intelligence axiom).
- **Pre-push hook IS wired** — it enforces cicada policy. Run `scripts/gate.sh` before pushing.
- **`swift run` triggers manifest sandboxing** and fails on this machine. Use `.build/debug/<binary>` directly instead. `swift build --disable-sandbox` works. `swift test --disable-sandbox` works.
- **Xcode project is gitignored** — regenerate from `project.yml` via `bootstrap-xcode.sh`.
- **`.codewhale/` is in `.gitignore`** — CodeWhale runtime state excluded from version control.
- **Worktree branches** were used for Session 3/4 commits — squash-merged and deleted. Use the same pattern for future work.

### Changes applied this session (Session 4)
| File | What changed |
|------|-------------|
| `scripts/gate.sh` | `--disable-sandbox` on build/test; direct binary for hydracore-check (avoids `swift run` manifest sandbox) |
| `CorrectionStore.swift` | `OSAllocatedUnfairLock` thread-safety; `@unchecked Sendable`; loud `StoreError.parse` on enum deserialization; `Int32(limit)` overflow guard |
| `deck/hydrav11/index.html` | Footer links: broken `/erebus`/`/` → GitHub source + docs; added `og:image` + `canonical` meta tags |
| `deck/hydrav11/og-image.png` | **NEW** — 1200×630 social preview image (dark theme, crest, title) generated via Pillow |
| `deck/hydrav11/worker.js` | Base64-inlined og-image.png; added fetch handler route for `/og-image.png` with `image/png` content-type |
| `.gitignore` | Added `.codewhale/` — exclude CodeWhale runtime state |
| `docs/handoff.md` | This file — updated for next session |
| `docs/session-1.md`, `docs/session-2.md` | Committed session history (previously untracked) |
