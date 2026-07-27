// E1-S2/E1-S5 acceptance: AFMCorrector error paths, streaming shape, and the
// PartialCorrection Sendable bridge.
//
// The actual AFM correction path runs only when the system model is available
// (and is exercised by the CLI + E2 integration tests on device). Here we test
// everything that does NOT need a live model: typed errors, stream construction,
// the Sendable snapshot type, and the unavailability path (skipped when model
// IS present — same as CorrectionSuggestionTests).

import XCTest
import FoundationModels
@testable import HydraCore

final class AFMCorrectorTests: XCTestCase {

    // ── PartialCorrection: shape, Equatable, Sendable ──

    func testPartialCorrectionShape() {
        let empty = PartialCorrection()
        XCTAssertNil(empty.primary)
        XCTAssertNil(empty.alternates)
        XCTAssertNil(empty.noChange)

        let full = PartialCorrection(
            primary: "the store",
            alternates: ["the shore"],
            noChange: false
        )
        XCTAssertEqual(full.primary, "the store")
        XCTAssertEqual(full.alternates, ["the shore"])
        XCTAssertEqual(full.noChange, false)

        let partial = PartialCorrection(primary: "hello")
        XCTAssertEqual(partial.primary, "hello")
        XCTAssertNil(partial.alternates)
        XCTAssertNil(partial.noChange)
    }

    func testPartialCorrectionEquatable() {
        let a = PartialCorrection(primary: "x", alternates: ["y"])
        let b = PartialCorrection(primary: "x", alternates: ["y"])
        let c = PartialCorrection(primary: "x", alternates: ["z"])
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // ── CorrectorError surface (complements testErrorDescriptions) ──

    func testAllErrorCasesEquatable() {
        let errors: [CorrectorError] = [
            .modelUnavailable(reason: "test"),
            .foundationModelsUnavailable,
            .emptyResult,
            .sessionFailure("timeout"),
        ]
        // Every error is Equatable and Sendable — if this compiles, Sendable is satisfied.
        XCTAssertEqual(errors[0], errors[0])
        XCTAssertNotEqual(errors[0], errors[1])
        XCTAssertNotEqual(errors[1], errors[2])
        XCTAssertNotEqual(errors[2], errors[3])
    }

    // ── Unavailability path (same pattern as CorrectionSuggestionTests) ──

    func testCorrectionThrowsOnUnavailableModel() async throws {
        let model = SystemLanguageModel.default
        guard case .unavailable = model.availability else {
            throw XCTSkip("system model is available on this host — unavailability path not exercised")
        }
        do {
            _ = try await AFMCorrector().correct("test")
            XCTFail("expected AFMCorrector to throw when the model is unavailable")
        } catch is CorrectorError {
            // expected — loud, typed failure
        } catch {
            XCTFail("expected CorrectorError, got \(error)")
        }
    }

    // ── correctStreaming throws if model unavailable ──

    func testStreamingThrowsOnUnavailableModel() throws {
        let model = SystemLanguageModel.default
        guard case .unavailable = model.availability else {
            throw XCTSkip("system model is available on this host — streaming unavailability path not exercised")
        }
        XCTAssertThrowsError(try AFMCorrector().correctStreaming("test")) { error in
            XCTAssertTrue(error is CorrectorError)
        }
    }

    // ── Correct instruction constant is non-empty ──

    func testInstructionConstantIsNonEmpty() {
        XCTAssertFalse(hydraCorrectionInstructions.isEmpty)
        XCTAssertTrue(hydraCorrectionInstructions.contains("intent"))
        XCTAssertTrue(hydraCorrectionInstructions.localizedCaseInsensitiveContains("tone"))
        XCTAssertTrue(hydraCorrectionInstructions.localizedCaseInsensitiveContains("profanity"))
    }
}
