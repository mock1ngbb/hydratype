// E1-S1 — the guided-generation output type for intent-aware correction.
//
// Shape from thread T2: a single best correction + ranked alternates
// ("you could have also meant") + a no-change flag.
//
// FoundationModels' `@Generable` macro drives guided generation on iOS/macOS 26.
// The macro plugin (`FoundationModelsMacros`) is only present in Xcode's build, NOT
// in a plain `swift build` from the CLI — so we gate the guided variant behind the
// `HYDRA_AFM` compilation condition, which the Xcode app/keyboard targets pass via
// `-D HYDRA_AFM`. Command-line `swift build`/`swift test` compile the byte-identical
// plain value type below, so the rest of HydraCore — mode engine, store, shadow
// comparison — and its logic tests run everywhere. The AFM call site in
// `AFMCorrector` is gated the same way; this type is the shared contract. LOUD, not
// silent: a build without `HYDRA_AFM` fails at the corrector's throw, never no-ops.

#if HYDRA_AFM
import FoundationModels

@available(iOS 26.0, macOS 26.0, *)
@Generable
public struct CorrectionSuggestion: Equatable, Sendable {
    @Guide(description: "The single best correction of the user's text, preserving intent and tone.")
    public var primary: String

    @Guide(description: "Up to 2 alternate meanings the user might have intended, most-likely first.")
    public var alternates: [String]

    @Guide(description: "True only if the text was already correct and no change is needed.")
    public var noChange: Bool

    public init(primary: String, alternates: [String] = [], noChange: Bool = false) {
        self.primary = primary
        self.alternates = alternates
        self.noChange = noChange
    }
}

#else

/// Plain mirror compiled when `HYDRA_AFM` is not set (CLI builds, CI, tests). Field
/// set is kept identical to the `@Generable` variant so downstream code is
/// source-compatible. Guided generation is not available here — `AFMCorrector`
/// throws `CorrectorError.foundationModelsUnavailable` loudly rather than degrading.
public struct CorrectionSuggestion: Equatable, Sendable, Codable {
    public var primary: String
    public var alternates: [String]
    public var noChange: Bool

    public init(primary: String, alternates: [String] = [], noChange: Bool = false) {
        self.primary = primary
        self.alternates = alternates
        self.noChange = noChange
    }
}

#endif
