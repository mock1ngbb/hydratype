// E1-S3 acceptance: table test mapping every FieldKind to its expected default, and
// verifying manual override beats the default and is dropped on field reset.

import XCTest
@testable import HydraCore

final class ModeEngineTests: XCTestCase {

    func testDefaultsTable() {
        let expected: [FieldKind: CorrectionMode] = [
            .password: .off,
            .url: .off,
            .email: .off,
            .code: .off,
            .plain: .prose,
        ]
        // Guard: the table must cover every case so a newly-added FieldKind fails loudly.
        XCTAssertEqual(Set(expected.keys), Set(FieldKind.allCases))
        for kind in FieldKind.allCases {
            XCTAssertEqual(CorrectionMode.defaultMode(for: kind), expected[kind])
        }
    }

    func testOverridePrecedence() {
        let engine = ModeEngine(fieldKind: .plain)
        XCTAssertEqual(engine.mode, .prose)
        XCTAssertFalse(engine.hasOverride)
        engine.override(.off)
        XCTAssertEqual(engine.mode, .off)
        XCTAssertTrue(engine.hasOverride)
        engine.clearOverride()
        XCTAssertEqual(engine.mode, .prose)
    }

    func testOverrideOnInCredentialField() {
        let engine = ModeEngine(fieldKind: .password)
        XCTAssertEqual(engine.mode, .off)
        engine.override(.prose)
        XCTAssertEqual(engine.mode, .prose)
    }

    func testResetDropsOverride() {
        let engine = ModeEngine(fieldKind: .plain)
        engine.override(.off)
        XCTAssertEqual(engine.mode, .off)
        engine.resetForNewField(kind: .plain)
        XCTAssertFalse(engine.hasOverride)
        XCTAssertEqual(engine.mode, .prose)
    }
}
