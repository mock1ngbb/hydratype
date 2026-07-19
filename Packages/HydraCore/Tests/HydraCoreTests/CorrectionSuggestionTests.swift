// E1-S1 acceptance: the shared contract type compiles and holds its shape.
// E1-S2 acceptance (offline half): the unavailability path is LOUD — in a build
// without HYDRA_AFM, `AFMCorrector.correct` throws, never returns nil/empty.

import XCTest
@testable import HydraCore

final class CorrectionSuggestionTests: XCTestCase {

    func testShape() {
        let s = CorrectionSuggestion(primary: "the store", alternates: ["the shore"], noChange: false)
        XCTAssertEqual(s.primary, "the store")
        XCTAssertEqual(s.alternates, ["the shore"])
        XCTAssertFalse(s.noChange)
    }

    func testErrorDescriptions() {
        XCTAssertTrue(CorrectorError.modelUnavailable(reason: "device busy").description.contains("modelUnavailable"))
        XCTAssertTrue(CorrectorError.foundationModelsUnavailable.description.contains("foundationModelsUnavailable"))
        XCTAssertTrue(CorrectorError.emptyResult.description.contains("emptyResult"))
    }

    #if !HYDRA_AFM
    func testAbsentModelIsLoud() async {
        do {
            _ = try await AFMCorrector().correct("i went to teh stroe")
            XCTFail("expected AFMCorrector to throw in a non-HYDRA_AFM build")
        } catch let error as CorrectorError {
            XCTAssertEqual(error, .foundationModelsUnavailable)
        } catch {
            XCTFail("expected CorrectorError, got \(error)")
        }
    }
    #endif
}
