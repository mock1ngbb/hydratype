// E1-S6 acceptance: the hybrid routing decision. A single clearly-misspelled word
// resolves on the fast edit-distance path (NO model); multi-word / ambiguous /
// low-confidence / no-match input escalates to the injected AFM stub. The stub
// records whether it was invoked, so these tests never depend on live AFM.

import XCTest
@testable import HydraCore

/// Records how many times `correct(_:)` was called, and returns a canned suggestion.
/// `@unchecked Sendable`: only read/written from the single test task.
private final class StubCorrector: Correcting, @unchecked Sendable {
    private var _callCount = 0
    var callCount: Int { _callCount }

    func correct(_ text: String) async throws -> CorrectionSuggestion {
        _callCount += 1
        return CorrectionSuggestion(primary: "afm:" + text, source: .afm)
    }
}

final class HybridCorrectorTests: XCTestCase {

    /// A hybrid wired to a stub AFM (never touches a live model).
    private func hybrid(edit: EditDistanceCorrector = EditDistanceCorrector(), stub: StubCorrector) -> HybridCorrector {
        HybridCorrector(editCorrector: edit, afmCorrector: stub)
    }

    // ── Fast path: single clearly-misspelled word, no model ──

    func testMisspelledSingleWordTakesFastPath() async throws {
        let stub = StubCorrector()
        let hybrid = hybrid(stub: stub)
        let result = try await hybrid.correct("teh")
        XCTAssertEqual(result.source, .fastEditDistance)
        XCTAssertEqual(result.primary, "the")
        XCTAssertFalse(result.noChange)
        XCTAssertEqual(stub.callCount, 0, "fast path must not invoke AFM")
    }

    func testExactSingleWordFastPathNoChange() async throws {
        let stub = StubCorrector()
        let hybrid = hybrid(stub: stub)
        let result = try await hybrid.correct("hello")
        XCTAssertEqual(result.source, .fastEditDistance)
        XCTAssertEqual(result.primary, "hello")
        XCTAssertTrue(result.noChange)
        XCTAssertEqual(stub.callCount, 0)
    }

    // ── Escalation: multi-word → AFM ──

    func testMultiWordEscalatesToAFM() async throws {
        let stub = StubCorrector()
        let hybrid = hybrid(stub: stub)
        let result = try await hybrid.correct("i went to teh store")
        XCTAssertEqual(result.source, .afm)
        XCTAssertEqual(result.primary, "afm:i went to teh store")
        XCTAssertEqual(stub.callCount, 1)
    }

    // ── Escalation: no dictionary match → AFM ──

    func testNoMatchEscalatesToAFM() async throws {
        let stub = StubCorrector()
        let hybrid = hybrid(stub: stub)
        let result = try await hybrid.correct("qqzzxx")
        XCTAssertEqual(result.source, .afm)
        XCTAssertEqual(stub.callCount, 1)
    }

    // ── Escalation: low-confidence (short word, distance 2) → AFM ──

    func testLowConfidenceShortWordEscalatesToAFM() async throws {
        let stub = StubCorrector()
        let hybrid = hybrid(stub: stub)
        let result = try await hybrid.correct("gda")
        XCTAssertEqual(result.source, .afm)
        XCTAssertEqual(stub.callCount, 1)
    }

    // ── Escalation: empty input → AFM (nothing to fast-correct) ──

    func testEmptyInputEscalatesToAFM() async throws {
        let stub = StubCorrector()
        let hybrid = hybrid(stub: stub)
        let result = try await hybrid.correct("   ")
        XCTAssertEqual(result.source, .afm)
        XCTAssertEqual(stub.callCount, 1)
    }

    // ── Default AFM init compiles (real AFMCorrector) ──

    func testDefaultInitUsesRealAFMCorrector() async throws {
        // Constructing with no args must compile; correctness of the real model is
        // exercised by the CLI / device, not here.
        let hybrid = HybridCorrector()
        // Fast path still works without touching the model:
        let fast = try await hybrid.correct("teh")
        XCTAssertEqual(fast.source, .fastEditDistance)
        XCTAssertEqual(fast.primary, "the")
    }
}
