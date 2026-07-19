// Typed error surface for correction. LOUD by default: every failure path is a
// named, inspectable case — never a silent `nil`/empty return (NORTHSTAR axiom 4).

import Foundation

public enum CorrectorError: Error, Equatable, Sendable, CustomStringConvertible {
    /// `SystemLanguageModel.default.availability` was not `.available`.
    /// Carries the human-readable reason so callers can log it verbatim.
    case modelUnavailable(reason: String)
    /// FoundationModels is not present in this build (e.g. Linux CI, older SDK).
    case foundationModelsUnavailable
    /// The model returned but produced an empty primary correction — treated as a
    /// hard failure, not a usable result.
    case emptyResult
    /// Underlying session/generation error, stringified so it stays Equatable/Sendable.
    case sessionFailure(String)

    public var description: String {
        switch self {
        case .modelUnavailable(let reason):
            return "CorrectorError.modelUnavailable: \(reason)"
        case .foundationModelsUnavailable:
            return "CorrectorError.foundationModelsUnavailable: FoundationModels not importable in this build"
        case .emptyResult:
            return "CorrectorError.emptyResult: model returned an empty primary correction"
        case .sessionFailure(let detail):
            return "CorrectorError.sessionFailure: \(detail)"
        }
    }
}
