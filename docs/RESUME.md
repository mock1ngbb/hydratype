# Hydratype — Session Resume

**Date:** 2026-08-02 · **Author:** Claude (rip-rooter lane) · **Session type:** deck/CI-CD + red-team closeout

What is unfinished after this session and how to pick it back up. Every item is tracked in
**WyrdWeaver** (`wyrd`) — live IDs are listed so nothing is lost to a restart.

---

## Done this session (no action needed)

- **Erebus Compact** reworked into a values-led constitution (Ethos, Authenticity, Autonomy, Privacy,
  Accessibility) → merged (PR #5), deck redeployed live.
- **Wired hydratype into charon-cicada**: crypt-core enrollment, GitHub webhook → cicd-intake
  (`push`+`pull_request`), merge-warden `WATCHED_REPOS`. **Auto + manual merge proven** (PR #6
  auto-merged via `POST /v1/run`).
- **Build gate**: composite pre-push hook (`scripts/gate.sh` → cicada-policy hook); deck-sync check
  mechanized into `scripts/gate.sh` (`check-erebus-sync.sh`).
- **Worktree cleanup**: removed merged `wt-cicada-onboard` + `wt/hydrav11-theme`.

---

## Unfinished — pick up here, in order

### 1. Land bifrost-bridge PR #5919
- **Wyrd:** `bifrost-bridge` → `e6e2be2a` (operator/chore)
- **What:** merge-warden change (watch `mock1ngbb/hydratype` + `[triggers]` config fix + new
  `build-stamp.ts`) is **deployed** (Version `10d6a73c`) but the code is **not on bifrost-bridge `main`**.
- **Resume:** operator merge → `CLAUDE_MERGE_APPROVE=5919 gh pr merge 5919 --squash` (self-merge guard applies).

### 2. Reconcile the main checkout divergence
- **Wyrd:** `hydratype` → `759a63af` (operator/chore)
- **What:** `/Users/mock1ngbb/AntiGH/hydratype` is stale at `8427694`, has a **local-only commit
  (`fix(red-team) #6`) not on origin**, and is missing current files (e.g. `scripts/check-erebus-sync.sh`).
- **Resume:** confirm the red-team commit is superseded, then `git fetch && git reset --hard origin/hee-haw`.

### 3. E-SPIKE-1 — validate on-device AFM in the keyboard extension
- **Wyrd:** `hydratype` → `53da1d19` (refiled; CLAUDE.md's `cb4b60c1` was absent from wyrd)
- **What:** the **main product gating task**. Empirically validate Apple Foundation Models
  (`@Generable`) inside the ~50–60 MB keyboard extension; use the host-app broker if
  `BROKER_REQUIRED`. Hardware validation pending.
- **Resume:** this is the real product work once the CI/deck cleanup above is closed.

### 4. Wire a real deploy lane (Xcode Cloud / fastlane)
- **Wyrd:** `hydratype` → `669a0f3c`
- **What:** deploy-manifest uses a `script` gate placeholder (`hydratype-gate`). Because there's no
  server-side Swift build lane, merge-warden's `cicada/policy` proof is **policy-only** — a broken
  build could auto-merge. The local pre-push gate is the only build mitigation today.
- **Resume:** wire Xcode Cloud / fastlane → enables a server-side `cicada/build` check.

### 5. Make the pre-push build-gate durable
- **Wyrd:** `hydratype` → `d44bc980`
- **What:** the composite `.git/hooks/pre-push` (gate.sh → cicada-policy) is machine-local and can be
  re-symlinked by `install-cicada-policy-hook.sh`. Not committed to the repo.
- **Resume:** commit an installer script (pattern: `vestas-warpath/scripts/install-writing-rules-hook.sh`).

### 6. Verify rip-rooter admin on hydratype
- **Wyrd:** `hydratype` → `5869866a`
- **What:** `PUT /collaborators/rip-rooter` returned 204 but role still reads `write`. The webhook
  works (created via owner token `bifrost-GITHUB_TOKEN`), but the bot's admin status is unresolved.

### 7. Reconcile crypt-core `manifestPath`
- **Wyrd:** `hydratype` → `8bf741b3`
- **What:** vault-keeper registration defaulted `manifestPath` to `.bifrost/deploy.yaml`, but
  hydratype's actual manifest is `.bifrost/deploy-manifest.json`. Low impact (no real deploy), but
  reconcile the registration so the paths agree.

---

## How to resume (fast path)

1. **Merge PR #5919** (bifrost-bridge) — operator action.
2. **Reconcile main checkout** — `git reset --hard origin/hee-haw` after confirming the red-team commit.
3. **Start E-SPIKE-1** — the product work. Deck + CI/CD are done and live.

Deck (live): `deck.mock1ngbb.com/hydrav11/erebus-compact` · Erebus Compact governance is wired into
`CLAUDE.md` (auto-loads every session) and `scripts/gate.sh`.
