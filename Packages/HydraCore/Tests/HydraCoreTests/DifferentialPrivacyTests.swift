// E6-S3 — verify the local differential-privacy noise mechanism:
//   • noise is applied (noised aggregates differ from raw, flagged `isNoised`)
//   • the mean is approximately unbiased (E[Laplace] = 0)
//   • sensitivity + epsilon are respected statistically (scale = ε/sensitivity,
//     empirical std ≈ √2 · scale)
//   • determinism via a seeded generator
//
// The pure-DP distributional tests draw many samples from one seeded RNG and
// check aggregate statistics with tolerance; the store tests exercise the
// opt-in wiring end-to-end against a temp SQLite DB.

import Foundation
import XCTest
@testable import HydraCore

final class DifferentialPrivacyTests: XCTestCase {

    // MARK: - Parameter validation (Loud by default)

    func testNonPositiveEpsilonThrows() {
        XCTAssertThrowsError(try DifferentialPrivacy(epsilon: 0, sensitivity: 1)) { error in
            XCTAssertEqual(error as? DifferentialPrivacyError, .nonPositiveEpsilon(0))
        }
        XCTAssertThrowsError(try DifferentialPrivacy(epsilon: -1, sensitivity: 1)) { error in
            XCTAssertEqual(error as? DifferentialPrivacyError, .nonPositiveEpsilon(-1))
        }
    }

    func testNegativeSensitivityThrows() {
        XCTAssertThrowsError(try DifferentialPrivacy(epsilon: 1, sensitivity: -0.5)) { error in
            XCTAssertEqual(error as? DifferentialPrivacyError, .negativeSensitivity(-0.5))
        }
    }

    func testValidParametersAndDocumentedConstants() throws {
        let dp = try DifferentialPrivacy(epsilon: 1, sensitivity: 1)
        XCTAssertEqual(dp.scale, 1.0, accuracy: 1e-12)
        // Documented privacy claim: pure ε-DP, δ = 0.
        XCTAssertEqual(DifferentialPrivacy.delta, 0.0)
        XCTAssertGreaterThan(DifferentialPrivacy.defaultEpsilon, 0)
    }

    // MARK: - Determinism via seed

    func testDeterminismViaSeed() throws {
        let dp = try DifferentialPrivacy(epsilon: 1, sensitivity: 1)
        let a = samples(dp, count: 1000, seed: 42)
        let b = samples(dp, count: 1000, seed: 42)
        let c = samples(dp, count: 1000, seed: 43)
        XCTAssertEqual(a, b, "same seed must reproduce identical noise")
        XCTAssertNotEqual(a, c, "different seed must (overwhelmingly) differ")
    }

    func testSeededNoiseIsReproducibleInStore() throws {
        let dp = try DifferentialPrivacy(epsilon: 1, sensitivity: 1)
        let (store, url) = try tempStore()
        defer { try? FileManager.default.removeItem(at: url) }
        try store.append(CorrectionEvent(
            fieldKind: .plain, before: "a", suggested: "b",
            accepted: true, source: .afm, inferenceTier: "baseline"
        ))
        let first = try store.cohortAggregates(dp: dp, seed: 123)
        let second = try store.cohortAggregates(dp: dp, seed: 123)
        XCTAssertEqual(first, second, "same seed ⇒ identical noised aggregate")
    }

    // MARK: - Statistical properties

    func testMeanApproximatelyUnbiased() throws {
        let dp = try DifferentialPrivacy(epsilon: 1, sensitivity: 1) // scale 1
        let n = 200_000
        let noise = samples(dp, count: n, seed: 7)
        let mean = noise.reduce(0, +) / Double(n)
        // E[Laplace(0,1)] = 0; 3σ of the sample mean ≈ 3·√(2/n) ≈ 0.0095.
        XCTAssertEqual(mean, 0.0, accuracy: 0.03, "sample mean should be ≈ 0 (unbiased)")
    }

    func testVarianceRespectsSensitivityAndEpsilon() throws {
        // scale = sensitivity/epsilon; Var[Laplace(0,b)] = 2b²; std = √2·b.
        let dp = try DifferentialPrivacy(epsilon: 0.5, sensitivity: 1) // scale 2, std ≈ 2.828
        let expectedStd = (2.0).squareRoot() * dp.scale
        let n = 200_000
        let noise = samples(dp, count: n, seed: 99)
        let mean = noise.reduce(0, +) / Double(n)
        let variance = noise.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) } / Double(n)
        let std = variance.squareRoot()
        XCTAssertEqual(
            std, expectedStd, accuracy: expectedStd * 0.05,
            "empirical stddev should approximate √2·scale = √2·sensitivity/epsilon"
        )
    }

    func testSmallerEpsilonGivesLargerNoise() throws {
        // More privacy (smaller ε) ⇒ wider Laplace ⇒ larger expected |noise|.
        let loud = try DifferentialPrivacy(epsilon: 0.1, sensitivity: 1) // scale 10
        let tight = try DifferentialPrivacy(epsilon: 10, sensitivity: 1) // scale 0.1
        let n = 10_000
        func meanAbs(_ s: [Double]) -> Double {
            s.reduce(0) { $0 + abs($1) } / Double(s.count)
        }
        XCTAssertGreaterThan(
            meanAbs(samples(loud, count: n, seed: 1)),
            meanAbs(samples(tight, count: n, seed: 1)),
            "smaller epsilon must produce larger-magnitude noise"
        )
    }

    // MARK: - Store wiring (opt-in aggregate path)

    func testNoiseAppliedToStoreAggregate() throws {
        let dp = try DifferentialPrivacy(epsilon: 1, sensitivity: 1)
        let (store, url) = try tempStore()
        defer { try? FileManager.default.removeItem(at: url) }
        for _ in 0..<5 {
            try store.append(CorrectionEvent(
                fieldKind: .plain, before: "a", suggested: "b",
                accepted: true, source: .stock, inferenceTier: "local_afm"
            ))
        }
        let raw = try store.cohortAggregates(dp: nil, seed: 0)
        let noised = try store.cohortAggregates(dp: dp, seed: 123)
        let rawAgg = try XCTUnwrap(raw.first { $0.cohort == "local_afm" })
        let noisedAgg = try XCTUnwrap(noised.first { $0.cohort == "local_afm" })

        XCTAssertFalse(rawAgg.isNoised, "opt-in off ⇒ raw, local-dashboard-only")
        XCTAssertTrue(noisedAgg.isNoised, "opt-in on ⇒ noised, transmit-safe")
        XCTAssertEqual(rawAgg.count, 5.0)
        XCTAssertNotEqual(noisedAgg.count, 5.0, "noised count should differ from raw")
        XCTAssertNotEqual(noisedAgg.acceptedCount, 5.0, "noised accepted count should differ from raw")
    }

    func testNoisedCountMeanUnbiasedInStore() throws {
        let dp = try DifferentialPrivacy(epsilon: 1, sensitivity: 1)
        let (store, url) = try tempStore()
        defer { try? FileManager.default.removeItem(at: url) }
        for _ in 0..<3 {
            try store.append(CorrectionEvent(
                fieldKind: .plain, before: "x", suggested: "y",
                accepted: true, source: .afm, inferenceTier: "baseline"
            ))
        }
        let trials = 400
        let rawCount = 3.0
        var total = 0.0
        var checkedNoised = false
        for i in 0..<trials {
            let aggs = try store.cohortAggregates(dp: dp, seed: UInt64(i))
            let agg = try XCTUnwrap(aggs.first { $0.cohort == "baseline" })
            checkedNoised = checkedNoised || agg.isNoised
            total += agg.count
        }
        XCTAssertTrue(checkedNoised)
        let mean = total / Double(trials)
        // E[noised count] = raw count = 3; SE of the mean ≈ √2/√trials ≈ 0.071.
        XCTAssertEqual(mean, rawCount, accuracy: 0.25,
                       "mean of noised counts should approximate the raw count (unbiased)")
    }

    func testEmptyStoreYieldsEmptyAggregates() throws {
        let dp = try DifferentialPrivacy(epsilon: 1, sensitivity: 1)
        let (store, url) = try tempStore()
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(try store.cohortAggregates(dp: nil, seed: 0), [])
        XCTAssertEqual(try store.cohortAggregates(dp: dp, seed: 0), [])
    }

    // MARK: - Helpers

    private func samples(_ dp: DifferentialPrivacy, count: Int, seed: UInt64) -> [Double] {
        var rng: any RandomNumberGenerator = SplitMix64(seed: seed)
        var out: [Double] = []
        out.reserveCapacity(count)
        for _ in 0..<count {
            out.append(dp.sample(using: &rng))
        }
        return out
    }

    private func tempStore() throws -> (CorrectionStore, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("hydratype-dp-test-\(UUID().uuidString).sqlite")
        return (try CorrectionStore(url: url), url)
    }
}
