// E1-S1 acceptance: the shared contract type compiles and holds its shape.
// E1-S2 acceptance (offline half): on a host without an available system model,
// `AFMCorrector.correct` throws a typed CorrectorError — LOUD, never nil/empty.

import XCTest
import FoundationModels
@testable import HydraCore

final class CorrectionSuggestionTests: XCTestCase {

    func testShape() {
        let s = CorrectionSuggestion(primary: "the store", alternates: ["the shore"], noChange: false)
        XCTAssertEqual(s.primary, "the store")
        XCTAssertEqual(s.alternates, ["the shore"])
        XCTAssertFalse(s.noChange)
    }

    func testConfidenceDefaultsToOne() {
        // Omitting confidence treats the suggestion as fully confident (1.0); a model
        // that omits it is never spuriously downgraded to no-correction.
        let s = CorrectionSuggestion(primary: "the")
        XCTAssertEqual(s.confidence, 1.0)
        XCTAssertEqual(CorrectionSuggestion(primary: "the", confidence: 0.4).confidence, 0.4)
    }

    func testErrorDescriptions() {
        XCTAssertTrue(CorrectorError.modelUnavailable(reason: "device busy").description.contains("modelUnavailable"))
        XCTAssertTrue(CorrectorError.foundationModelsUnavailable.description.contains("foundationModelsUnavailable"))
        XCTAssertTrue(CorrectorError.emptyResult.description.contains("emptyResult"))
    }

    // On CI / a Mac without an available system model, correction must fail LOUDLY
    // with a typed CorrectorError (typically .modelUnavailable), never nil/empty.
    // Skipped where a model is actually available (a device/host with Apple Intelligence).
    func testUnavailableModelIsLoud() async throws {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            do {
                _ = try await AFMCorrector().correct("i went to teh stroe")
                XCTFail("expected AFMCorrector to throw when the model is unavailable")
            } catch is CorrectorError {
                // expected — loud, typed failure
            } catch {
                XCTFail("expected CorrectorError, got \(error)")
            }
            return
        }
        throw XCTSkip("system model is available on this host — unavailability path not exercised")
    }
}
