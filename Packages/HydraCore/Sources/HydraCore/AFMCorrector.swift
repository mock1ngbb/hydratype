// E1-S2 — `AFMCorrector`: wraps `LanguageModelSession` to produce a
// `CorrectionSuggestion`, with a streaming variant that yields partial snapshots so
// `primary` can render before `alternates` finish (thread T2).
//
// Commodity Intelligence: the instruction text is a named constant, and no model id
// is hardcoded — we bind to `SystemLanguageModel.default`, which the OS resolves.
//
// Loud by default: unavailability throws `CorrectorError.modelUnavailable` (never a
// silent `nil`); an empty primary throws `CorrectorError.emptyResult`.

import Foundation
import FoundationModels

/// The tuned instruction string. Correct for INTENT/tone over edit-distance; never
/// change already-correct text; preserve slang/profanity when intended.
public let hydraCorrectionInstructions = """
You are an autocorrect assistant. Correct the user's text for INTENT and TONE, not \
merely spelling or edit-distance. Reason about the whole message's meaning: prefer \
the word the user plainly meant even when a closer-spelled alternative exists. \
Preserve the user's voice — keep intentional slang, casing, and profanity. If the \
text is already correct, set noChange to true and return it unchanged. Offer up to \
two alternate intended meanings, most-likely first.
"""

public struct AFMCorrector: Sendable {
    private let instructions: String

    public init(instructions: String = hydraCorrectionInstructions) {
        self.instructions = instructions
    }

    /// Throws `CorrectorError.modelUnavailable` (LOUD) if the system model is not
    /// ready. Returns the reason string verbatim for logging.
    private func ensureAvailable() throws {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return
        case .unavailable(let reason):
            throw CorrectorError.modelUnavailable(reason: String(describing: reason))
        @unknown default:
            throw CorrectorError.modelUnavailable(reason: "unknown availability state")
        }
    }

    /// One-shot guided correction.
    public func correct(_ text: String) async throws -> CorrectionSuggestion {
        try ensureAvailable()
        let session = LanguageModelSession {
            instructions
        }
        do {
            let response = try await session.respond(
                to: text,
                generating: CorrectionSuggestion.self
            )
            let suggestion = response.content
            guard !suggestion.primary.isEmpty else { throw CorrectorError.emptyResult }
            return suggestion
        } catch let error as CorrectorError {
            throw error
        } catch {
            throw CorrectorError.sessionFailure(String(describing: error))
        }
    }

    /// Streaming correction: yields Sendable `PartialCorrection` snapshots so the UI
    /// can show `primary` before `alternates` finish (thread T2). Failures terminate
    /// the stream by throwing (LOUD — the error is delivered, never swallowed).
    public func correctStreaming(
        _ text: String
    ) throws -> AsyncThrowingStream<PartialCorrection, Error> {
        try ensureAvailable()
        let instructions = self.instructions
        return AsyncThrowingStream { continuation in
            let task = Task {
                let session = LanguageModelSession {
                    instructions
                }
                do {
                    let stream = session.streamResponse(
                        to: text,
                        generating: CorrectionSuggestion.self
                    )
                    for try await partial in stream {
                        // Map the non-Sendable @Generable snapshot into our Sendable
                        // type before crossing the continuation boundary.
                        let content = partial.content
                        continuation.yield(PartialCorrection(
                            primary: content.primary,
                            alternates: content.alternates,
                            noChange: content.noChange
                        ))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: CorrectorError.sessionFailure(String(describing: error)))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
