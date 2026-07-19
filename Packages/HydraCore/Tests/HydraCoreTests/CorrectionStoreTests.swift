// E1-S4 acceptance: append + read-back + markSynced round-trips against a temp DB.

import Foundation
import XCTest
@testable import HydraCore

final class CorrectionStoreTests: XCTestCase {

    private func tempStore() throws -> (CorrectionStore, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("hydratype-test-\(UUID().uuidString).sqlite")
        return (try CorrectionStore(url: url), url)
    }

    func testRoundTrip() throws {
        let (store, url) = try tempStore()
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertEqual(try store.count(), 0)

        let id1 = try store.append(CorrectionEvent(
            fieldKind: .plain, before: "teh stroe", suggested: "the store",
            accepted: true, source: .afm, inferenceTier: "local_afm"
        ))
        let id2 = try store.append(CorrectionEvent(
            fieldKind: .plain, before: "cant", suggested: "can't",
            accepted: false, source: .stock, inferenceTier: "baseline"
        ))
        XCTAssertNotEqual(id1, id2)
        XCTAssertEqual(try store.count(), 2)

        let unsynced = try store.recentUnsynced(limit: 10)
        XCTAssertEqual(unsynced.count, 2)
        // Oldest first (upload order).
        XCTAssertEqual(unsynced.first?.before, "teh stroe")
        XCTAssertEqual(unsynced.first?.accepted, true)
        XCTAssertEqual(unsynced.first?.source, .afm)

        try store.markSynced(ids: [id1])
        let stillUnsynced = try store.recentUnsynced(limit: 10)
        XCTAssertEqual(stillUnsynced.count, 1)
        XCTAssertEqual(stillUnsynced.first?.id, id2)
    }

    func testMarkSyncedEmpty() throws {
        let (store, url) = try tempStore()
        defer { try? FileManager.default.removeItem(at: url) }
        try store.markSynced(ids: [])
        XCTAssertEqual(try store.count(), 0)
    }

    func testMissingContainerIsLoud() {
        XCTAssertThrowsError(try CorrectionStore(appGroupID: "group.does.not.exist.hydratype.test")) { error in
            XCTAssertTrue(error is StoreError)
        }
    }
}
