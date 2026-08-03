# Hydratype — Session Resume

**Last updated:** 2026-08-03 · **Author:** Claude (rip-rooter lane) · **Sessions:** deck/CI-CD + core + red-team

> **⚠️ Why this file matters right now:** the **wyrd write-relay is down** (`wyrd-capture` →
> "created but not readable on V2 within poll budget (write-relay never drained)" since 2026-08-03),
> so **new WyrdWeaver tasks are not being confirmed**. Until the relay recovers, THIS document is the
> authoritative record of what's unfinished. Re-file items to wyrd once the relay is back.

---

## Done (no action needed)

**Session 1 (deck / CI-CD / governance):**
- Erebus Compact → values-led constitution; deck redeployed live.
- hydratype enrolled in charon-cicada: crypt-core vault-keeper, GitHub webhook → cicd-intake,
  merge-warden `WATCHED_REPOS`. Auto + manual merge proven.
- Build gate (pre-push `gate.sh` → cicada-policy); deck-sync check mechanized.
- **bifrost-bridge PR #5919 merged** (merge-warden watch hydratype on bifrost-bridge main).
- **Main checkout reconciled** (reset to origin; the divergent red-team/deck line was superseded).

**Session 2 (core / macOS pivot / loom):**
- **macOS M5 pivot:** on-device AFM **IN_PROCESS_OK** — `hydratype-cli` ran a real correction
  (`"i cant beleive it"` → `"I can't believe it."`, latency ~1.6s, footprint 3.6→13.2 MB).
- **Hybrid corrector** (fast Damerau-Levenshtein + AFM escalation) — PR #10.
- **Structured-output hardening** (confidence + deterministic no-correction fallback) — PR #11.
- **Benchmark harness** (`hydracore-bench`, 30-entry corpus) — PR #12.
- **DP telemetry** (`DifferentialPrivacy` — local Laplace, sensitivity + ε) — PR #13.
- All the above auto-merged by merge-warden; main at `ee3192b`.

---

## Unfinished — pick up here, in order

### 1. E-SPIKE-1 — iOS jetsam verdict (the #1 product gate)
- **Wyrd:** `hydratype` → `53da1d19`
- **What:** macOS M5 pivot **proved the model is viable** (IN_PROCESS_OK) but does NOT answer the
  iOS question. The keyboard extension's **~50–60 MB jetsam ceiling** (`IN_EXTENSION_OK` vs
  `BROKER_REQUIRED`) still needs `Probe.swift` run on a **physical AFM-enabled iPhone (iOS 26)**.
- **Resume:** run the hardened `Probe.swift` (canonical `LanguageModelSession { }` form) on a real
  iPhone; fill the spike README verdict table.

### 2. Wire a real deploy lane (Xcode Cloud / fastlane)
- **Wyrd:** `hydratype` → `669a0f3c`
- **What:** deploy-manifest uses a `script` gate placeholder; merge-warden's `cicada/policy` proof is
  policy-only (a broken build could auto-merge). Local pre-push gate is the only build mitigation.
- **Resume:** wire Xcode Cloud / fastlane → enables a server-side `cicada/build` check.

### 3. Verify merge-warden stays in sync after auto-deploy
- **Wyrd:** (unfiled — relay down)
- **What:** the deployed `WATCHED_REPOS` once drifted to 4-repo (lost hydratype); fixed via the
  **pinned** `npm run deploy` (`wrangler@4.100.0`). The auto-pipeline redeploys on pushes — monitor
  for recurrence; keep the deploy method canonical.
- **Resume:** on any bifrost-bridge deploy, confirm merge-warden still watches `mock1ngbb/hydratype`.

### 4. Investigate the wyrd write-relay outage
- **Wyrd:** (unfiled — this is the outage itself)
- **What:** `wyrd-capture` can't confirm V2 reads ("write-relay never drained") since 2026-08-03.
  Task filing is unreliable; the resume md is the fallback record.
- **Resume:** check the wyrd V2 write-relay / capture pipeline; re-file the items below once it's back.

### 5. Make the pre-push build-gate durable
- **Wyrd:** `hydratype` → `d44bc980`
- **What:** the composite `.git/hooks/pre-push` (gate.sh → cicada-policy) is machine-local and can be
  re-symlinked by `install-cicada-policy-hook.sh`. Not committed.
- **Resume:** commit an installer script (pattern: `vestas-warpath/scripts/install-writing-rules-hook.sh`).

### 6. Fix the flaky `EditDistanceCorrectorTests.testFastUnderBudget`
- **Wyrd:** (unfiled — relay down)
- **What:** a 10 ms debug wall-clock budget assertion flakes under load / incremental builds
  (verified pre-existing — fails on the clean base too). Not caused by recent work.
- **Resume:** warm-up, a generous bound, or assert relative not absolute.

### 7. Loom-workflow interop: worktree gh-guard friction
- **Wyrd:** (unfiled — relay down)
- **What:** 2/3 loom agents hit the worktree-isolation guard blocking `gh pr create`/`gh` from the
  agent worktree shell and worked around it (REST API / wrapper script).
- **Resume:** document a sanctioned path for loom agents to open PRs from isolated worktrees.

### 8. Verify rip-rooter admin on hydratype
- **Wyrd:** `hydratype` → `5869866a`
- **What:** `PUT /collaborators/rip-rooter` returned 204 but role still reads `write`; the webhook
  works (owner token), but the bot admin status is unresolved.

### 9. Reconcile crypt-core `manifestPath`
- **Wyrd:** `hydratype` → `8bf741b3`
- **What:** vault-keeper registration defaulted `manifestPath` to `.bifrost/deploy.yaml`, but the
  actual manifest is `.bifrost/deploy-manifest.json`. Low impact; reconcile the registration.

---

## How to resume (fast path)

1. **E-SPIKE-1 iOS run** — get a physical AFM iPhone, run `Probe.swift`, fill the verdict. This is the
   real product gate.
2. **Fix the wyrd write-relay** so task tracking is trustworthy again.
3. **Wire the deploy lane / server-side build gate** to make the merge gate prove the build.

Deck (live): `deck.mock1ngbb.com/hydrav11/erebus-compact` · Erebus Compact governance wired into
`CLAUDE.md` + `scripts/gate.sh`. Core: `Packages/HydraCore` (hybrid corrector, DP telemetry, bench).
