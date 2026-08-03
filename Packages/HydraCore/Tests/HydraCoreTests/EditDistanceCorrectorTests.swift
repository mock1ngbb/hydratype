// E1-S6 acceptance: the pure-Swift fast path corrector.
// Damerau-Levenshtein over the built-in dictionary: common single-word typos resolve
// deterministically; gibberish / too-distant words yield `nil` (escalate). Everything
// here is offline — no model, no network, deterministic.

import XCTest
@testable import HydraCore

final class EditDistanceCorrectorTests: XCTestCase {

    private var corrector: EditDistanceCorrector { EditDistanceCorrector() }

    // ── Transposition (Damerau) is a single edit ──

    func testTehToThe() {
        let match = corrector.bestMatch(for: "teh")
        XCTAssertEqual(match?.candidate, "the")
        XCTAssertEqual(match?.distance, 1)
        XCTAssertEqual(match?.isHighConfidence, true)
    }

    func testStroeToStore() {
        let match = corrector.bestMatch(for: "stroe")
        XCTAssertEqual(match?.candidate, "store")
        XCTAssertEqual(match?.distance, 1)
        XCTAssertEqual(match?.isHighConfidence, true)
    }

    func testRecieveToReceive() {
        let match = corrector.bestMatch(for: "recieve")
        XCTAssertEqual(match?.candidate, "receive")
        XCTAssertEqual(match?.distance, 1)
        XCTAssertEqual(match?.isHighConfidence, true)
    }

    func testBeliveToBelieve() {
        let match = corrector.bestMatch(for: "belive")
        XCTAssertEqual(match?.candidate, "believe")
        XCTAssertEqual(match?.distance, 1)
        XCTAssertEqual(match?.isHighConfidence, true)
    }

    // ── Exact match / no-change ──

    func testExactMatchDistanceZero() {
        let match = corrector.bestMatch(for: "hello")
        XCTAssertEqual(match?.candidate, "hello")
        XCTAssertEqual(match?.distance, 0)
    }

    // ── No good match → nil (escalate) ──

    func testGibberishReturnsNil() {
        XCTAssertNil(corrector.bestMatch(for: "qqzzxx"))
    }

    func testEmptyReturnsNil() {
        XCTAssertNil(corrector.bestMatch(for: ""))
        XCTAssertNil(corrector.bestMatch(for: "   "))
    }

    // ── Confidence threshold: distance 2 is confident only for longer words ──

    func testDistance2LongWordIsConfident() {
        // "commodate" → "accommodate" is a 2-edit miss on a 9-char word → trustworthy.
        let match = corrector.bestMatch(for: "commodate")
        XCTAssertEqual(match?.candidate, "accommodate")
        XCTAssertEqual(match?.distance, 2)
        XCTAssertEqual(match?.isHighConfidence, true)
    }

    func testDistance2ShortWordIsNotConfident() {
        // A 2-edit miss on a 3-char word is usually a different word → not confident.
        let match = corrector.bestMatch(for: "gda")
        XCTAssertEqual(match?.distance, 2)
        XCTAssertEqual(match?.isHighConfidence, false)
    }

    // ── Determinism + case-insensitivity ──

    func testCaseInsensitive() {
        XCTAssertEqual(corrector.bestMatch(for: "TEH")?.candidate, "the")
        XCTAssertEqual(corrector.bestMatch(for: "Teh")?.candidate, "the")
    }

    func testDeterministicAcrossRuns() {
        let a = corrector.bestMatch(for: "teh")
        let b = corrector.bestMatch(for: "teh")
        XCTAssertEqual(a, b)
    }

    func testFastUnderBudget() {
        // The <10ms budget is per correction. Time 200 runs and assert the average
        // is comfortably under it (it is ~sub-ms in release; debug is still fast).
        let start = Date()
        let runs = 200
        for _ in 0..<runs {
            _ = corrector.bestMatch(for: "recieve")
        }
        let perCorrectionMs = Date().timeIntervalSince(start) * 1000 / Double(runs)
        XCTAssertLessThan(perCorrectionMs, 10.0, "avg \(perCorrectionMs) ms/correction — exceeds 10ms budget")
    }
}
