# CLAUDE.md — hydratype

Intent/context-aware autocorrect: an iOS/macOS 26 custom keyboard that runs
corrections through Apple's on-device **Foundation Models** LLM (guided generation
via `@Generable`) instead of n-gram/edit-distance. Shared Swift core (`HydraCore`)
drives correction; a Cloudflare backend does opt-in, differentially-noised telemetry
and (later) cloud personalization.

## Read before coding against a stack (prefix-cached official docs)

Authoritative, official-doc-sourced API references live in **`docs/reference/`** —
consult the relevant one BEFORE writing code for that stack; do not answer from
memory. Index: [`docs/reference/INDEX.md`](docs/reference/INDEX.md). System graphs:
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md). Scope/epics:
[`docs/slices/`](docs/slices/). Spikes + verdicts: [`spikes/`](spikes/).

- Foundation Models → `docs/reference/apple-foundation-models.md`
- Keyboard extension / App Group / IPC → `docs/reference/ios-keyboard-extension.md`
- Workers AI + AI Gateway → `docs/reference/cloudflare-workers-ai.md`
- D1 / R2 / Queues / Analytics Engine → `docs/reference/cloudflare-data-plane.md`
- StoreKit 2 / AutoFill / Keychain → `docs/reference/storekit-autofill-keychain.md`
- IMKit / UITextChecker → `docs/reference/imkit-textchecker.md`

## Hard constraints (fedelm-hardened — obey the corrected reality, not optimism)

- **Foundation Models needs iOS/macOS 26 + the Xcode toolchain** (the `@Generable`
  macro plugin is not in Command Line Tools). HydraCore baselines at 26.
- **A 3B model won't fit the keyboard's ~50-60MB budget** → correction in the
  extension is gated on **E-SPIKE-1** (task `cb4b60c1`); use the host-app broker if
  BROKER_REQUIRED. Never assume in-extension AFM.
- **Secure fields**: iOS swaps to the system keyboard — no password/OTP autofill from
  the keyboard (that's a separate AutoFill Credential Provider extension, E12).
- **Workers AI LoRA serving is OPEN BETA** → E7's shippable path is BYO-endpoint +
  AI Gateway + Analytics Engine (all GA). Metering = Analytics Engine, not D1.
- **Keyboard does zero networking**; the host app uploads. BYO keys live in Keychain,
  fetched at call time (Zero Local Secrets) — never in the DB/on disk.

## Build & verify

```sh
# Shared core (Xcode toolchain required):
cd Packages/HydraCore && swift build && swift run hydracore-check && swift test
scripts/gate.sh                          # build + logic gate + XCTest (cicada pre-push)
echo "i cant beleive it" | swift run hydratype-cli   # real on-device correction

# Xcode app + keyboard (project.yml is source of truth; .xcodeproj is generated):
scripts/bootstrap-xcode.sh               # xcodegen generate
xcodebuild -project HydraType.xcodeproj -scheme HydraType \
  -destination 'generic/platform=iOS Simulator' -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build
```

## How this repo is governed (mechanisms, not reminders)

These are enforced by hooks/gates — this section only documents *where*, so you know
what will fire (the enforcement is not this markdown):

- **CI/CD gate**: charon-cicada (`.cicada-policy.yml`) — pre-push hook; GitHub Actions
  structurally forbidden.
- **Git flow**: trunk `hee-haw`; worktree + `wt/<topic>-<unixtimestamp>` branch shape
  and "no work in main checkout" are enforced by the fleet's block hooks; self-merge
  is blocked by `agent-self-merge-guard`.
- **Verify gate**: `scripts/gate.sh` (build + `hydracore-check` + `swift test`).
  Wiring it into the cicada pre-push hook is tracked in WyrdWeaver (mechanization,
  not a prose rule).
- **Xcode project**: `.xcodeproj` is gitignored and generated from `project.yml`; the
  gitignore is the mechanism that prevents committing a hand-edited project.

## CI/CD authority (delegated)

CI/CD ordering, deploy webhook routing, and pipeline contract semantics defer to the canonical
northstar in the bifrost-bridge constitution:

- `bifrost-bridge/docs/constitutions/cicd/constitution.md` § Article I
- `bifrost-bridge/docs/constitutions/cicd/contract-deploy-lifecycle.md`
- `bifrost-bridge/docs/constitutions/cicd/contract-deploy-manifest.md`

Live path: GitHub push/pull_request → **cicd-intake** worker (`cicada/policy` proof) → **merge-warden**
auto-squash-merges CLEAN PRs with a green `cicada/policy`; **cicd-queue** runs ephemeral Sprite
builds. hydratype is enrolled in crypt-core vault-keeper (script gate target `hydratype-gate`).

- **Auto pick-up + merge**: merge-warden cron (`*/10`), watches `mock1ngbb/hydratype`.
- **Manual fire + merge**: `bash scripts/cicada-deploy.sh` (enqueue+drain) or `POST /v1/run`
  on merge-warden (`PROXY_API_KEY`), plus the in-session `CLAUDE_MERGE_APPROVE=<n>` carve-out.
- **Do not** manually `gh pr merge` from agent context (blocked by `agent-self-merge-guard`).
- **Do not** add `.github/workflows/*` — cicada policy forbids GitHub Actions.

## Constitution — The Erebus Compact

The project's governing constitution. **Values first, then operational laws, then antipatterns.**
Full text: [`deck/hydrav11/erebus-compact.html`](deck/hydrav11/erebus-compact.html) · live at
[`deck.mock1ngbb.com/hydrav11/erebus-compact`](https://deck.mock1ngbb.com/hydrav11/erebus-compact).
New work must stay aligned with these; `scripts/gate.sh` enforces the deck copies stay consistent.

**Values (Articles I–V):**
- **Ethos** — the typer is the first citizen; tools, not traps; simplicity is integrity.
- **Authenticity** — words on screen = words in code; claim no fact we can't prove; keep the typer's voice.
- **Autonomy** — the author owns their text; every setting changeable, model swappable; exit rights are the point.
- **Privacy** — on-device by default; keyboard does zero networking; opt-in differentially-noised telemetry; keys in the Keychain, never on disk.
- **Accessibility** — WCAG is law; the House is open to every hand; accessibility is the trunk, not a branch.

**Operational laws (Articles VI–XIV):** Zero Local Secrets · Loud by default · Honest measurement ·
Commodity Intelligence · Mechanize-not-md · Defer nothing · Age is not a gate · Plan is consent ·
File-then-fix deprecations.

**Forbidden antipatterns:** dark patterns & deceptive marketing (pre-checked consent, confirm-shaming,
unequal opt-out, hidden controls, undisclosed harvest, phantom "anonymous", false urgency, unbribed
numbers, whitewashed claims, sanitizing the typer's voice) and the House's mechanical antipatterns
(silent ledger, hardcoded secrets/model ids, duplicated work, deferring, chasing symptoms).

Design axioms the code is held to (verified by the gate, not by memory): Loud-by-default
(typed errors, no silent nil/empty), Commodity Intelligence (no hardcoded model id),
Mechanize-not-md, Defer-nothing (`wyrd "title"`).
