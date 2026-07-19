# Apple Foundation Models (AFM) — Developer Reference

> **One-liner:** Apple's on-device LLM framework (`import FoundationModels`, iOS/iPadOS/macOS/visionOS **26.0+**, watchOS 27.0+) gives you a ~3B-param on-device model via `SystemLanguageModel` + `LanguageModelSession`, with type-safe "guided generation" (`@Generable`/`@Guide`) that streams partially-built Swift values. No network, no cost, no API key — but gated behind Apple Intelligence being enabled on eligible hardware.

**Reference date:** 2026-07-19. All signatures below are quoted from Apple's live documentation JSON API on this date (framework version reporting iOS 26.0 introductions, with some symbols back-deployed to 26.4). Where a signature could **not** be confirmed against live Apple docs, it is flagged **`⚠ UNCONFIRMED`** — do not treat those as canonical.

---

## 1. `SystemLanguageModel` — the model handle

`final class SystemLanguageModel`. An on-device Apple Foundation Model for text generation. Introduced iOS/iPadOS/macOS/visionOS/Mac Catalyst **26.0**.

```swift
// Getting the default model
static var `default`: SystemLanguageModel { get }

// A model specialized for a built-in use case (e.g. content tagging)
convenience init(useCase: SystemLanguageModel.UseCase = .general,
                 guardrails: SystemLanguageModel.Guardrails = Guardrails.default)
```

### Availability — check BEFORE every session

```swift
final var availability: SystemLanguageModel.Availability { get }
final var isAvailable: Bool { get }          // convenience Bool

@frozen enum Availability {
    case available
    case unavailable(SystemLanguageModel.Availability.UnavailableReason)
}

enum UnavailableReason {           // confirmed live cases:
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
}
```

Usage:

```swift
let model = SystemLanguageModel.default
switch model.availability {
case .available:
    // safe to create a session
case .unavailable(.deviceNotEligible):
    // hardware doesn't support Apple Intelligence
case .unavailable(.appleIntelligenceNotEnabled):
    // user must turn on Apple Intelligence in Settings
case .unavailable(.modelNotReady):
    // assets still downloading / warming up — retry later
case .unavailable(let other):
    // @frozen enum but UnavailableReason is NOT frozen — keep a default arm
}
```

> **LOUD:** `Availability` is `@frozen`, but `UnavailableReason` is **not** frozen. Always keep a catch-all arm on the reason so new OS point-releases don't break your switch.

### Capability inspection

```swift
@backDeployed(before: iOS 26.4, macOS 26.4, visionOS 26.4)
final var contextSize: Int { get }                       // token budget for the whole transcript
final var supportedLanguages: Set<Locale.Language> { get }
final func supportsLocale(_:) -> Bool
final func tokenCount(for:) -> ...                        // pre-flight token counting
```

---

## 2. `LanguageModelSession` — the conversation

`final class LanguageModelSession`. A stateful session (holds a `Transcript`) that interacts with the model. iOS 26.0+ (watchOS 27.0+).

```swift
// Blank-slate session with static instructions (uses an @InstructionsBuilder)
convenience init(model: SystemLanguageModel = .default,
                 tools: [any Tool] = [],
                 @InstructionsBuilder instructions: () throws -> Instructions) rethrows
```

> **LOUD — signature drift:** the widely-quoted WWDC25 `init(instructions:)` that takes a plain `String` is a convenience over the builder form. The canonical live initializer takes an **`@InstructionsBuilder` closure**, and there is **no `guardrails:` parameter on the session initializer** in the current live docs (guardrails live on `SystemLanguageModel`). Prefer the builder form:

```swift
let session = LanguageModelSession {
    "You are a concise typing-correction assistant."
    "Only fix typos and grammar. Never change meaning."
}
```

### One-shot text response

```swift
@discardableResult
nonisolated(nonsending)
final func respond(to prompt: Prompt,
                   options: GenerationOptions = GenerationOptions())
  async throws -> LanguageModelSession.Response<String>

// Response<Content> is: struct Response<Content> where Content : Generable
// -> read the value from `.content`
let answer = try await session.respond(to: "Fix: teh quick brwon fox").content
```

### One-shot **guided** (structured) response

```swift
@discardableResult
nonisolated(nonsending)
final func respond<Content>(to prompt: Prompt,
                            generating type: Content.Type = Content.self,
                            includeSchemaInPrompt: Bool = true,
                            options: GenerationOptions = GenerationOptions())
  async throws -> LanguageModelSession.Response<Content>
  where Content : Generable
```

### Streaming

```swift
// Text stream
final func streamResponse(to prompt: Prompt,
                          options: GenerationOptions = GenerationOptions())
  -> sending LanguageModelSession.ResponseStream<String>

// Guided stream — yields Content.PartiallyGenerated snapshots
final func streamResponse<Content>(to prompt: Prompt,
                                   generating type: Content.Type = Content.self,
                                   includeSchemaInPrompt: Bool = true,
                                   options: GenerationOptions = GenerationOptions())
  -> sending LanguageModelSession.ResponseStream<Content>
  where Content : Generable
```

The stream yields **partial snapshots** (see §3). Each element is `Content.PartiallyGenerated`, an accumulating snapshot — not a token delta. Iterate it and drive UI from each snapshot:

```swift
let stream = session.streamResponse(to: prompt, generating: Suggestion.self)
for try await partial in stream {
    render(partial)              // partial is Suggestion.PartiallyGenerated
}
```

### Guarding against overlap

```swift
final var isResponding: Bool { get }   // true while a response is in flight
```

Do not issue a second `respond`/`streamResponse` while `isResponding` is `true` — a session processes one request at a time.

### `GenerationOptions`

```swift
struct GenerationOptions {
    var temperature: Double?            // confidence/creativity, nil = model default
    var maximumResponseTokens: Int?     // hard cap on output length
    var sampling: GenerationOptions.SamplingMode?     // (also `samplingMode`)
    var toolCallingMode: GenerationOptions.ToolCallingMode?

    init(sampling: SamplingMode? = nil,
         temperature: Double? = nil,
         maximumResponseTokens: Int? = nil)
    // also: init(samplingMode:temperature:maximumResponseTokens:toolCallingMode:)
}
```

```swift
let opts = GenerationOptions(temperature: 0.2, maximumResponseTokens: 60)
```

---

## 3. Guided generation — `@Generable` / `@Guide`

Annotate a `struct`/`enum` with `@Generable`; the framework converts the type to a JSON schema, constrains decoding to that schema, and returns a fully-typed Swift value. `@Guide` adds per-property natural-language descriptions and programmatic constraints.

```swift
@Generable
struct SearchSuggestions {
    @Guide(description: "A list of suggested search terms.", .count(4))
    var searchTerms: [SearchTerm]

    @Generable
    struct SearchTerm {
        var id: GenerationID          // use GenerationID for framework-generated substructures
        @Guide(description: "A two- or three-word search term, like 'Beautiful sunsets'.")
        var searchTerm: String
    }
}
```

Confirmed macro/protocol surface:

```swift
protocol Generable : ConvertibleFromGeneratedContent, ConvertibleToGeneratedContent
associatedtype PartiallyGenerated : ConvertibleFromGeneratedContent = Self
func asPartiallyGenerated() -> Self.PartiallyGenerated

@attached(peer) macro Guide(description: String)
@attached(peer) macro Guide<RegexOutput>(description: String? = nil, _ guides: Regex<RegexOutput>)
// plus constraint forms surfaced in Apple sample code: .count(_), .anyOf([...]), numeric ranges
```

### `PartiallyGenerated` semantics

- Every `@Generable` type gets a compiler-synthesized `PartiallyGenerated` companion where fields are optional / progressively filled.
- Streaming yields these snapshots so you can render a form field-by-field as it materializes.
- `associatedtype PartiallyGenerated ... = Self` — the default is `Self`, but the `@Generable` macro overrides it with the generated partial type.

### ⚠ Build-system gotcha (critical for hydratype CI)

The macros are implemented by the **`FoundationModelsMacros`** compiler plugin, which is **only wired up under Xcode's build system**. Plain **`swift build` / SwiftPM on the command line does not load the macro plugin**, so any file using `@Generable`/`@Guide` fails to compile outside Xcode.

- **`canImport(FoundationModels)` is NOT a reliable gate.** The framework module can be importable in a context where the macro plugin is still unavailable (and vice-versa). Gating macro-using code on `#if canImport(FoundationModels)` will still break `swift build`.
- **Do this instead:** isolate all `@Generable` types behind a custom compilation flag you only set in the Xcode/xcodebuild path (see `HYDRA_AFM` in §5), and keep a hand-written fallback type for the SwiftPM/CI path.

---

## 4. Adapters (custom fine-tuned weights)

**⚠ LOUD — API NOT CONFIRMED IN CURRENT LIVE DOCS (2026-07-19).**
The runtime adapter API demonstrated at WWDC25 — `SystemLanguageModel(adapter:)` with a `SystemLanguageModel.Adapter` type, paired with `LanguageModelSession(model:)` — **could not be found in the live Apple documentation on this date.** Every probed slug (`.../systemlanguagemodel/adapter`, `.../systemlanguagemodel/init(adapter:)`, framework-root `Adapter` symbol) returns **HTTP 404**, and the `SystemLanguageModel` page's initializer list shows only `init(useCase:guardrails:)`. Treat the code below as **WWDC25-era shape, unverified against shipping docs** — confirm in Xcode against the SDK you build with before relying on it.

```swift
// ⚠ UNCONFIRMED — WWDC25 shape only
let adapter = try SystemLanguageModel.Adapter(name: "hydratype-corrector")
let model   = SystemLanguageModel(adapter: adapter)
let session = LanguageModelSession(model: model) { "…instructions…" }
```

What IS well-established about adapters (from Apple's Adapter Training Toolkit and WWDC guidance):

- Adapters are **rank-restricted LoRA-style weights (~tens–hundreds of MB, ~160 MB range)**. They are far too large to bundle in the app binary.
- Ship/update them at runtime via **Background Assets** (`BackgroundAssets` framework) so the download happens out-of-process and can be refreshed independently of app updates.
- **Adapters are locked to a specific base-model version.** When Apple ships a new base model in an OS update, an old adapter **stops loading** and must be **retrained** against the new base. You MUST:
  1. Guard-check that the adapter is compatible with the currently-installed base model before creating a session.
  2. **Fall back** to `SystemLanguageModel.default` (or a built-in use-case model) when the adapter is incompatible or not yet downloaded — never hard-fail the feature.
- Because of this treadmill, prefer `@Generable` guided generation on the **base** model for anything you can express with schema + instructions; reserve adapters for behavior the base model genuinely can't reach.

---

## 5. Gotchas / hydratype-specific

### `HYDRA_AFM` compile gate
Because the `@Generable` macro plugin only exists under Xcode (§3), define a Swift active-compilation-condition **`HYDRA_AFM`** that is set **only** in the Xcode/`xcodebuild` build settings (`SWIFT_ACTIVE_COMPILATION_CONDITIONS`), never in the SwiftPM manifest used by CI:

```swift
#if HYDRA_AFM
@Generable struct Correction { @Guide(description: "corrected text") var text: String }
#else
struct Correction: Codable { var text: String }   // hand-written fallback, swift-build-safe
#endif
```
Do **not** substitute `#if canImport(FoundationModels)` — it does not imply the macro plugin is present and will still break `swift build`.

### Memory / on-device constraints
- The model shares the device's unified memory; loading a session has a non-trivial memory + warm-up cost. Create sessions lazily, reuse one session per conversation, and release it under memory pressure.
- Respect `contextSize` (§1): the **entire transcript + the `@Generable` JSON schema** counts against the window. Large `@Generable` types can throw a context-exceeded error — trim schemas, drop redundant `@Guide` descriptions where property names are self-explanatory (Apple's own guidance), and keep instructions short.
- Always pre-check `availability` and degrade gracefully (`deviceNotEligible` / `appleIntelligenceNotEnabled` / `modelNotReady`) — a large fraction of installed devices will report unavailable.

### Latency characteristics
- First response pays a **cold warm-up** (model/adapter load). Subsequent turns in the same session are much faster.
- **Always stream** for user-facing typing correction: `streamResponse` yields `PartiallyGenerated` snapshots so the UI updates within the first tokens instead of blocking on the full completion. Use `isResponding` to prevent overlapping requests as keystrokes arrive (debounce, then check `isResponding`).
- Keep `maximumResponseTokens` tight (corrections are short) to bound worst-case latency.

### Tool calling
- The framework supports tool calling: `protocol Tool<Arguments, Output> : Sendable` with required members `call(arguments:)`, `name`, `description`, `parameters`, `includesSchemaInInstructions`, and associated `Arguments`/`Output`. Pass tools via the session initializer's `tools: [any Tool]` parameter, and steer invocation with `GenerationOptions.toolCallingMode`. For hydratype's correction path this is likely unnecessary — pure guided generation is simpler and cheaper.

---

## 6. Correction call flow

```mermaid
flowchart TD
    A[User keystrokes / text buffer] --> B{SystemLanguageModel.default\n.availability == .available?}
    B -- unavailable(reason) --> Z[Fallback path\nnon-AFM corrector / disable feature]
    B -- available --> C{HYDRA_AFM set\n& macro plugin present?}
    C -- no --> Z
    C -- yes --> D[LanguageModelSession\ninstructions builder]
    D --> E{isResponding?}
    E -- yes --> E2[debounce / skip] --> D
    E -- no --> F["streamResponse(to:generating: Correction.self,\noptions: temp=0.2, maxTokens≈60)"]
    F --> G[[Guided generation\n@Generable Correction + @Guide constraints\nschema-constrained decode]]
    G --> H[/for await partial in stream/\nCorrection.PartiallyGenerated]
    H --> I[Render suggestion incrementally in UI]
    H --> H
    I --> J[Final Correction value -> apply / offer accept]
```

---

## 7. Sources

Primary — Apple Developer Documentation (fetched 2026-07-19 via the docs JSON API; signatures quoted verbatim):

- Framework root: https://developer.apple.com/documentation/foundationmodels
- `SystemLanguageModel`: https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel
- `SystemLanguageModel.Availability` (enum): https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability-swift.enum
- `Availability.UnavailableReason`: https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability-swift.enum/unavailablereason
- `SystemLanguageModel.default`: https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/default
- `contextSize`: https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/contextsize
- `LanguageModelSession`: https://developer.apple.com/documentation/foundationmodels/languagemodelsession
- `init(model:tools:instructions:)`: https://developer.apple.com/documentation/foundationmodels/languagemodelsession/init(model:tools:instructions:)
- `respond(to:options:)`: https://developer.apple.com/documentation/foundationmodels/languagemodelsession/respond(to:options:)
- `respond(to:generating:includeSchemaInPrompt:options:)`: https://developer.apple.com/documentation/foundationmodels/languagemodelsession/respond(to:generating:includeschemainprompt:options:)
- `streamResponse(to:options:)`: https://developer.apple.com/documentation/foundationmodels/languagemodelsession/streamresponse(to:options:)
- `streamResponse(to:generating:includeSchemaInPrompt:options:)`: https://developer.apple.com/documentation/foundationmodels/languagemodelsession/streamresponse(to:generating:includeschemainprompt:options:)
- `isResponding`: https://developer.apple.com/documentation/foundationmodels/languagemodelsession/isresponding
- `GenerationOptions`: https://developer.apple.com/documentation/foundationmodels/generationoptions
- `Generable` (protocol + `@Generable` overview + `PartiallyGenerated`): https://developer.apple.com/documentation/foundationmodels/generable
- `Generable.PartiallyGenerated`: https://developer.apple.com/documentation/foundationmodels/generable/partiallygenerated
- `Guide(description:)` macro: https://developer.apple.com/documentation/foundationmodels/guide(description:)
- Guided-generation guide: https://developer.apple.com/documentation/foundationmodels/generating-swift-data-structures-with-guided-generation
- `Tool` protocol: https://developer.apple.com/documentation/foundationmodels/tool
- Runtime performance guide: https://developer.apple.com/documentation/foundationmodels/analyzing-the-runtime-performance-of-your-foundation-models-app
- WWDC25 session 286 "Deep dive into the Foundation Models framework": https://developer.apple.com/videos/play/wwdc2025/286/

Secondary / corroborating (adapters, macro-plugin build behavior, sizes — used only where primary docs were silent, flagged UNCONFIRMED above):

- fedelm research run (Perplexity Search + DeepSeek), 2026-07-19 — 15 sources incl. createwithswift.com "Exploring the Foundation Models framework" and dev.to Foundation Models walkthrough.
- Adapter compatibility / Background Assets guidance: Apple Foundation Models Adapter Training Toolkit + WWDC25 adapter session (verify against the SDK you ship with).

> **Confidence note:** §1–§3 and §5 latency/tooling surface are quoted from live Apple docs and are high-confidence. §4 (adapter runtime API) is **low-confidence / unverified** — the `SystemLanguageModel(adapter:)` symbol was absent from live docs on 2026-07-19. Re-verify in Xcode before implementing the adapter path.
