# hydratype stack reference — index

Authoritative, official-doc-sourced API references for every stack hydratype uses.
Each doc: a cheat-sheet + a mermaid graph + a cited Sources list. Pulled 2026-07-19.
Consult the relevant doc BEFORE writing code against that stack — do not answer from
memory. System-level graphs: [`../ARCHITECTURE.md`](../ARCHITECTURE.md).

| Reference | Covers | Used by |
|-----------|--------|---------|
| [apple-foundation-models.md](apple-foundation-models.md) | `SystemLanguageModel`, `LanguageModelSession`, `@Generable`/`@Guide`, streaming, adapters, availability | E1 HydraCore, E7 adapters |
| [ios-keyboard-extension.md](ios-keyboard-extension.md) | `UIInputViewController`, `textDocumentProxy`, Full Access, memory ceiling, App Groups, Darwin notify, secure fields, 4.4.1 | E0, E2, E-SPIKE-1 |
| [cloudflare-workers-ai.md](cloudflare-workers-ai.md) | Workers AI binding, LoRA (BETA), AI Gateway caching, BYO endpoint | E7 |
| [cloudflare-data-plane.md](cloudflare-data-plane.md) | D1, R2 event notifications, Queues + DLQ, Analytics Engine, Workflows, wrangler.jsonc | E6, E7 |
| [storekit-autofill-keychain.md](storekit-autofill-keychain.md) | StoreKit 2 purchases/entitlements, AutoFill Credential Provider, Keychain | E8, E12 |
| [imkit-textchecker.md](imkit-textchecker.md) | InputMethodKit (`IMKInputController`), `UITextChecker`/`NSSpellChecker` | E1b, E3 |

## Key cross-cutting facts (from the spikes + fedelm)

- **Foundation Models is iOS/macOS 26+; the `@Generable` macro plugin ships with Xcode**, not Command Line Tools. HydraCore baselines at 26 and compiles unconditionally under the Xcode toolchain. See [[foundationmodels-generable-needs-xcode]].
- **A 3B model cannot run in the keyboard's ~50-60MB budget** → E2 is gated on E-SPIKE-1 (in-proc vs host broker). Data crosses the App Group file; Darwin notify is a name-only wake-up.
- **Secure fields (H2)**: iOS swaps to the system keyboard — password/OTP autofill needs a separate AutoFill Credential Provider extension, not the keyboard.
- **Workers AI LoRA serving is OPEN BETA** (not GA) → build E7 on the GA BYO-endpoint + AI Gateway + Analytics Engine path.
- **Metering = Analytics Engine, not D1**; correct for `_sample_interval` in queries. Queues need a DLQ or exhausted messages are dropped silently.
