// E1-S6 — `HybridCorrector`: routes single-word corrections through the fast
// edit-distance path and escalates everything else to on-device AFM.
//
// Deterministic escalation decision (documented):
//   fast path (NO model) ⟺ the trimmed input is a SINGLE word AND
//   `EditDistanceCorrector.bestMatch` returns a HIGH-CONFIDENCE match
//   (distance <= 1; or distance == 2 for words of length >= 5).
//   Otherwise — multi-word text, a short word with only a distance-2 candidate,
//   an ambiguous/no-match, or empty input — we escalate to AFM.
//
// The AFM dependency is injected as an `any Correcting` (default: the real
// `AFMCorrector`) so tests substitute a stub and never depend on a live model.
// The returned `CorrectionSuggestion.source` discriminates which path ran.

/// Abstraction over "produce a correction", injectable for tests. The real
/// implementation is `AFMCorrector`; tests inject a stub that records invocation.
public protocol Correcting: Sendable {
    func correct(_ text: String) async throws -> CorrectionSuggestion
}

extension AFMCorrector: Correcting {}

/// Routes single-word corrections to the fast edit-distance path, escalating
/// multi-word / low-confidence / ambiguous input to AFM.
public struct HybridCorrector: Sendable {
    /// Floor for the model's `confidence` (0...1) below which we refuse to apply a
    /// guess. Below this we deterministically return the input unchanged with
    /// `noChange = true` rather than risk a bad correction. Values at or above this
    /// threshold pass through.
    public static let minConfidenceForCorrection: Double = 0.5
    private let edit: EditDistanceCorrector
    private let afm: any Correcting

    /// - Parameters:
    ///   - editCorrector: the fast-path corrector (defaults to the built-in one).
    ///   - afmCorrector: the escalation target (defaults to the real `AFMCorrector`;
    ///     tests inject a stub so the hybrid is unit-testable offline).
    public init(
        editCorrector: EditDistanceCorrector = EditDistanceCorrector(),
        afmCorrector: any Correcting = AFMCorrector()
    ) {
        self.edit = editCorrector
        self.afm = afmCorrector
    }

    /// Corrects `text`. Single-word high-confidence edits never touch the model;
    /// everything else escalates to AFM. `source` on the result reports the path.
    ///
    /// If the escalation path returns an empty `primary` or a `confidence` below
    /// `minConfidenceForCorrection`, we deterministically return `text` unchanged with
    /// `noChange = true` instead of a bad guess — and we never throw on this case.
    public func correct(_ text: String) async throws -> CorrectionSuggestion {
        if let fast = fastPathSuggestion(for: text) {
            return fast
        }
        var suggestion = try await afm.correct(text)
        suggestion.source = .afm
        return noCorrectionIfNeeded(suggestion, for: text)
    }

    /// Guards the escalation result. An empty primary, or a confidence below the
    /// floor (a `NaN`/negative/low value counts as below the floor), collapses to the
    /// input unchanged with `noChange = true`. Never throws. This is the deterministic
    /// fallback that keeps a malformed model output from becoming a bad correction.
    private func noCorrectionIfNeeded(_ suggestion: CorrectionSuggestion, for text: String) -> CorrectionSuggestion {
        // `confidence >= floor` is false for NaN, so a NaN (or otherwise out-of-range)
        // confidence also collapses to no-correction — the safe direction.
        guard !suggestion.primary.isEmpty,
              suggestion.confidence >= Self.minConfidenceForCorrection else {
            return CorrectionSuggestion(
                primary: text,
                noChange: true,
                source: .afm
            )
        }
        return suggestion
    }

    /// The fast-path suggestion for a single word, or `nil` to escalate.
    private func fastPathSuggestion(for text: String) -> CorrectionSuggestion? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Only a bare single word (no whitespace) is eligible for the fast path.
        guard !trimmed.isEmpty, !trimmed.contains(where: \.isWhitespace) else { return nil }

        guard let match = edit.bestMatch(for: trimmed), match.isHighConfidence else {
            return nil
        }

        // An exact dictionary match is already-correct text: report noChange.
        let noChange = match.distance == 0
        return CorrectionSuggestion(
            primary: match.candidate,
            noChange: noChange,
            source: .fastEditDistance
        )
    }
}
