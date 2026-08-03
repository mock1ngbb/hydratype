// E1-S6 acceptance: the hybrid routing decision. A single clearly-misspelled word
// resolves on the fast edit-distance path (NO model); multi-word / ambiguous /
// low-confidence / no-match input escalates to the injected AFM stub. The stub
// records whether it was invoked, so these tests never depend on live AFM.

import XCTest
@testable import HydraCore

/// Records how many times `correct(_:)` was called, and returns a canned suggestion.
/// `@unchecked Sendable`: only read/written from the single test task. The `result`
/// closure lets each test shape the canned suggestion (empty primary, low confidence,
/// high confidence, …) to exercise the hybrid's guard paths.
private final class StubCorrector: Correcting, @unchecked Sendable {
    private var _callCount = 0
    var callCount: Int { _callCount }
    private let result: (String) -> CorrectionSuggestion

    init(result: @escaping (String) -> CorrectionSuggestion = { text in CorrectionSuggestion(primary: "afm:" + text, source: .afm) }) {
        self.result = result
    }

    func correct(_ text: String) async throws -> CorrectionSuggestion {
        _callCount += 1
        return result(text)
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

    // ── Deterministic no-correction fallback (malformed / low-confidence model output) ──

    func testEmptyPrimaryFromModelFallsBackToNoChange() async throws {
        let stub = StubCorrector { _ in CorrectionSuggestion(primary: "", source: .afm) }
        let hybrid = hybrid(stub: stub)
        let result = try await hybrid.correct("i went to teh store")
        XCTAssertEqual(result.primary, "i went to teh store", "must return the input unchanged")
        XCTAssertTrue(result.noChange)
        XCTAssertEqual(result.source, .afm)
        XCTAssertEqual(stub.callCount, 1)
    }

    func testLowConfidenceFromModelFallsBackToNoChange() async throws {
        let stub = StubCorrector { text in CorrectionSuggestion(primary: "store", source: .afm, confidence: 0.1) }
        let hybrid = hybrid(stub: stub)
        let result = try await hybrid.correct("i went to teh store")
        XCTAssertEqual(result.primary, "i went to teh store", "must return the input unchanged")
        XCTAssertTrue(result.noChange)
        XCTAssertEqual(result.source, .afm)
        XCTAssertEqual(stub.callCount, 1)
    }

    func testNaNConfidenceFromModelFallsBackToNoChange() async throws {
        // A NaN confidence is not >= the floor, so it collapses to no-correction
        // rather than propagating a guess we cannot trust.
        let stub = StubCorrector { text in CorrectionSuggestion(primary: "store", source: .afm, confidence: .nan) }
        let hybrid = hybrid(stub: stub)
        let result = try await hybrid.correct("i went to teh store")
        XCTAssertEqual(result.primary, "i went to teh store")
        XCTAssertTrue(result.noChange)
        XCTAssertEqual(result.source, .afm)
        XCTAssertEqual(stub.callCount, 1)
    }

    func testConfidenceAtFloorPassesThrough() async throws {
        // Exactly at the threshold is accepted: no-correction only fires strictly below.
        let stub = StubCorrector { text in CorrectionSuggestion(primary: "store", source: .afm, confidence: 0.5) }
        let hybrid = hybrid(stub: stub)
        let result = try await hybrid.correct("i went to teh store")
        XCTAssertEqual(result.primary, "store")
        XCTAssertFalse(result.noChange)
        XCTAssertEqual(result.source, .afm)
        XCTAssertEqual(stub.callCount, 1)
    }

    func testHighConfidenceFromModelPassesThrough() async throws {
        let stub = StubCorrector { text in CorrectionSuggestion(primary: "store", source: .afm, confidence: 0.9) }
        let hybrid = hybrid(stub: stub)
        let result = try await hybrid.correct("i went to teh store")
        XCTAssertEqual(result.primary, "store")
        XCTAssertFalse(result.noChange)
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
