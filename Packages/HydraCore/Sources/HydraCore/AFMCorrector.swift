// E1-S2 — `AFMCorrector`: wraps `LanguageModelSession` to produce a
// `CorrectionSuggestion`, with a streaming variant that yields partial snapshots so
// `primary` can render before `alternates` finish (thread T2).
//
// Commodity Intelligence: the instruction text is a named constant, and no model id
// is hardcoded — we bind to `SystemLanguageModel.default`, which the OS resolves.
//
// Loud by default: unavailability throws `CorrectorError.modelUnavailable` (never a
// silent `nil`). Where FoundationModels can't be imported, every entry point throws
// `CorrectorError.foundationModelsUnavailable` so a mis-targeted build fails loudly
// at the call site instead of silently compiling the feature out.

import Foundation

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

#if HYDRA_AFM
import FoundationModels

@available(iOS 26.0, macOS 26.0, *)
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
        let session = LanguageModelSession(instructions: instructions)
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

    /// Streaming correction: yields partially-generated snapshots so the UI can show
    /// `primary` before `alternates` finish (thread T2). The stream finishes when the
    /// model completes; failures are surfaced by the terminating throw on the
    /// underlying sequence being converted to a logged, finished stream (LOUD: the
    /// error is delivered, never swallowed).
    public func correctStreaming(
        _ text: String
    ) throws -> AsyncThrowingStream<CorrectionSuggestion.PartiallyGenerated, Error> {
        try ensureAvailable()
        let instructions = self.instructions
        return AsyncThrowingStream { continuation in
            let task = Task {
                let session = LanguageModelSession(instructions: instructions)
                do {
                    let stream = session.streamResponse(
                        to: text,
                        generating: CorrectionSuggestion.self
                    )
                    for try await partial in stream {
                        continuation.yield(partial.content)
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

#else

/// Build without `HYDRA_AFM` (CLI/CI/tests). Every entry point throws loudly so a
/// mis-targeted build can never silently ship a no-op corrector.
public struct AFMCorrector: Sendable {
    public init(instructions: String = hydraCorrectionInstructions) {}

    public func correct(_ text: String) async throws -> CorrectionSuggestion {
        throw CorrectorError.foundationModelsUnavailable
    }
}

#endif
