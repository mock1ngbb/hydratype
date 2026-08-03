// E1-S1 — the guided-generation output type for intent-aware correction.
//
// Shape from thread T2: a single best correction + ranked alternates
// ("you could have also meant") + a no-change flag. FoundationModels' `@Generable`
// macro drives guided generation; the macro plugin ships with Xcode (see Package.swift).

import FoundationModels

/// Which correction path produced a suggestion. Discriminates the fast edit-distance
/// path from the on-device AFM escalation so callers can shadow-measure honest latency
/// and cost per tier (see `HybridCorrector`). Distinct from `SuggestionSource` (which
/// tags telemetry rows); this is the runtime, per-call discriminator.
@Generable
public enum CorrectionSource: String, Sendable, Equatable, Codable, CaseIterable {
    /// Produced by `EditDistanceCorrector` on the fast single-word path.
    case fastEditDistance
    /// Produced by the AFM escalation (`AFMCorrector` / injected stub).
    case afm
}

@Generable
public struct CorrectionSuggestion: Equatable, Sendable {
    @Guide(description: "The single best correction of the user's text, preserving intent and tone.")
    public var primary: String

    @Guide(description: "Up to 2 alternate meanings the user might have intended, most-likely first.")
    public var alternates: [String]

    @Guide(description: "True only if the text was already correct and no change is needed.")
    public var noChange: Bool

    /// Which path ran. Defaults to `.afm` so existing call sites (and the @Generable
    /// guided-generation constructor) compile unchanged; `HybridCorrector` sets it to
    /// `.fastEditDistance` when it short-circuits without the model. Not produced by
    /// guided generation — it is metadata about how the correction was reached.
    public var source: CorrectionSource

    public init(primary: String, alternates: [String] = [], noChange: Bool = false, source: CorrectionSource = .afm) {
        self.primary = primary
        self.alternates = alternates
        self.noChange = noChange
        self.source = source
    }
}

/// A Sendable snapshot of an in-flight streamed correction. `@Generable`'s own
/// `PartiallyGenerated` type is not Sendable, so streaming maps into this to cross
/// async boundaries safely (Swift 6 strict concurrency). Fields are optional because
/// they fill in progressively — `primary` typically resolves before `alternates`.
public struct PartialCorrection: Equatable, Sendable {
    public var primary: String?
    public var alternates: [String]?
    public var noChange: Bool?

    public init(primary: String? = nil, alternates: [String]? = nil, noChange: Bool? = nil) {
        self.primary = primary
        self.alternates = alternates
        self.noChange = noChange
    }
}
