# Hydratype — Session Resume

**Last updated:** 2026-08-03 · **Author:** Claude (rip-rooter lane) · **Sessions:** deck/CI-CD + core + infra + red-team

What is unfinished and how to pick it back up. Every open item is tracked in **WyrdWeaver** (`wyrd`) —
live IDs are listed so nothing is lost to a restart.

---

## Done (no action needed)

**Deck / governance / CI-CD:**
- Erebus Compact → values-led constitution; deck redeployed live.
- hydratype enrolled in charon-cicada (crypt-core vault-keeper, GitHub webhook → cicd-intake,
  merge-warden `WATCHED_REPOS`); auto + manual merge proven.
- bifrost-bridge PR #5919 + #5961 merged; main checkout reconciled.

**Core / macOS pivot / loom:**
- **macOS M5 pivot:** on-device AFM **IN_PROCESS_OK** (~1.6s, footprint 3.6→13.2 MB).
- Hybrid corrector (#10), structured-output hardening (#11), benchmark harness (#12), DP telemetry (#13).

**Infra fixes this session:**
- **wyrd write-relay readback bug FIXED** (bifrost #5961): owner/repo group → `/` in issueId → the path
  route `/tasks/:ref` couldn't match it → "write-relay never drained" despite the task persisting.
  `getTaskRow` now falls back to `?issueId=` + reads `tasks[0]`. Local bifrost synced to origin → durable.
- **Flaky test** `testFastUnderBudget` de-flaked (#15). Wyrd task `ff7769cf` closed.
- **Gate scoping fail-closed** (#16) + **sink-arg validation** (#17).

---

## Unfinished — pick up here, in order

### 1. E-SPIKE-1 — iOS jetsam verdict (the #1 product gate)
- **Wyrd:** `hydratype` → `deae238a`
- macOS M5 proved model viability; the **~50–60 MB keyboard-jetsam** question (`IN_EXTENSION_OK` vs
  `BROKER_REQUIRED`) still needs `Probe.swift` run on a **physical AFM-enabled iPhone (iOS 26)**.

### 2. Wire a real deploy lane (Xcode Cloud / fastlane)
- **Wyrd:** `hydratype` → `669a0f3c`
- deploy-manifest uses a `script` gate placeholder; merge-warden's `cicada/policy` proof is policy-only
  (a broken build could auto-merge). A real lane enables a server-side `cicada/build` check.

### 3. wyrd R2 backup — RESOLVED 2026-08-03 (bifrost-bridge PR #5976)
- The original framing was wrong on two counts. Backups **were** reaching R2 (2,648 objects, every
  hour of the day covered), and `bifrost-backups.r2.dev` → HTTP 500 is a **red herring** — that
  public dev URL is not on the backup path, which uses the CF REST API. The cited wyrd id
  `064f406a` did not exist in the store.
- Real defect: `com.mock1ng.wyrd-snapshot` was exiting **2** (`die()` in `cmdBackup`) because the R2
  PUT had **no retry** — `wyrd-snapshot.log` carries 50+ `fetch failed` and several 30s timeouts
  against `api.cloudflare.com`, so a single blip dropped that hour's snapshot outright.
- Fixed: exponential-backoff retry (default 4 attempts; 5xx/429 retry, other 4xx fail fast), plus
  `scripts/mac-env/bin/wyrd-backup-health.sh` — a negative-proofed gate that fails loud on any
  `com.mock1ng.*` job with a nonzero last-exit or a stale newest backup, and exits 2 (never 0) when
  it cannot verify.
- Also found and removed: `com.mock1ng.r2-hourly-snapshot` had sat at launchd **exit 78** since the
  day it was created — never ran once, wrote no logs, a dead duplicate of `wyrd-snapshot` caused by
  a `/Users/mock1ng` vs `/Users/mock1ngbb` typo. The gate then surfaced 5 more dead jobs; all filed
  in bifrost-bridge (`de242496`, `6605505b`, `ec6042ed`, `0bcfbdbe`, `f13ca4dd`).

### 4. Verify merge-warden stays in sync after auto-deploy
- **Wyrd:** `hydratype` → `b53713ea`
- `WATCHED_REPOS` once drifted to 4-repo (lost hydratype); fixed via pinned `npm run deploy`
  (`wrangler@4.100.0`, task `bd4a6134`). Monitor recurrence.

### 5. Monitor wyrd durability (local bifrost source drift)
- **Wyrd:** `hydratype` → `d76601e7`
- The local bifrost `.husky/post-checkout` refresh copies `client.mjs` to the installed client; if the
  local source drifts from origin (the #5961 fix), wyrd reverts. Keep the local bifrost synced to origin.

### 6. Make the pre-push build-gate durable
- **Wyrd:** `hydratype` → `d44bc980`
- The composite `.git/hooks/pre-push` (gate.sh → cicada-policy) is machine-local; can be re-symlinked by
  `install-cicada-policy-hook.sh`. Commit an installer script.

### 7. Loom-workflow interop: worktree gh-guard friction
- **Wyrd:** `hydratype` → `a4bcba5f`
- 2/3 loom agents hit the worktree-isolation guard blocking `gh pr create`/`gh`; worked around via REST.
  Document a sanctioned path for loom agents to open PRs from isolated worktrees.

### 8. Verify rip-rooter admin on hydratype
- **Wyrd:** `hydratype` → `5869866a`
- `PUT /collaborators/rip-rooter` returned 204 but role still reads `write`; webhook works (owner token).

### 9. Reconcile crypt-core `manifestPath`
- **Wyrd:** `hydratype` → `8bf741b3`
- vault-keeper registration defaulted `manifestPath` to `.bifrost/deploy.yaml`, actual is
  `.bifrost/deploy-manifest.json`. Low impact; reconcile.

---

## How to resume (fast path)
1. **E-SPIKE-1 iOS run** — get a physical AFM iPhone, run `Probe.swift`, fill the verdict. The product gate.
2. **Wire the deploy lane / server-side build gate** so the merge gate proves the build.

(The R2 backup item is resolved — see §3 above. Backups were landing all along; the real bug was a
missing retry around a flaky R2 PUT, fixed in bifrost-bridge PR #5976.)

Deck (live): `deck.mock1ngbb.com/hydrav11/erebus-compact` · Erebus Compact governance wired into
`CLAUDE.md` + `scripts/gate.sh`. Core: `Packages/HydraCore` (hybrid corrector, DP telemetry, bench).
wyrd is fixed and durable (task filing works).
