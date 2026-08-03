// E6-S3 — local differential-privacy noise for opt-in telemetry aggregation.
//
// Privacy claim (docs/privacy/DATA-MODEL.md §C/§G, nutrition-label-draft.md):
// only noised aggregate deltas leave the device, calibrated to a declared
// sensitivity and epsilon. This file is the on-device mechanism that makes that
// claim provable: Laplace noise (pure ε-DP, δ = 0) added to a count/sum before
// it leaves the device.
//
// Loud by default: a non-positive epsilon or negative sensitivity throws a typed
// `DifferentialPrivacyError` rather than silently returning an uncalibrated or
// noiseless value (NORTHSTAR axiom 4).

import Foundation

/// Typed error for differential-privacy parameter validation (Loud-by-default).
public enum DifferentialPrivacyError: Error, CustomStringConvertible, Equatable, Sendable {
    /// `epsilon` must be strictly positive (it is the privacy budget).
    case nonPositiveEpsilon(Double)
    /// `sensitivity` must be non-negative.
    case negativeSensitivity(Double)

    public var description: String {
        switch self {
        case .nonPositiveEpsilon(let e):
            return "DifferentialPrivacyError.nonPositiveEpsilon(\(e)): epsilon must be > 0 (privacy budget)."
        case .negativeSensitivity(let s):
            return "DifferentialPrivacyError.negativeSensitivity(\(s)): sensitivity must be >= 0."
        }
    }
}

/// The Laplace mechanism for local DP noise on aggregate counts/sums.
///
/// Privacy guarantee — pure ε-differential privacy with **δ = 0**:
/// removing a single record can change a count by at most `sensitivity` (1 for a
/// count, the per-record max for a sum), so adding Laplace noise with scale
/// `b = sensitivity / ε` yields ε-DP. No approximate-DP δ budget is consumed
/// because this is the pure (not `(ε, δ)`) mechanism; `delta` is documented as 0
/// so the privacy claim is explicit rather than implied.
///
/// The mechanism is unbiased: `E[noise] = 0`, so large aggregates approximate
/// the true count while each individual contribution is protected.
public struct DifferentialPrivacy: Sendable, Equatable {
    /// Privacy budget (privacy loss). Smaller is more private; must be `> 0`.
    public let epsilon: Double
    /// How much a single record's removal can change the aggregate (1 for a
    /// count, the per-record max for a sum); must be `>= 0`.
    public let sensitivity: Double

    /// Declared, documented default budget for correction-event counts.
    public static let defaultEpsilon: Double = 1.0
    /// Pure ε-DP; the Laplace mechanism has exactly δ = 0.
    public static let delta: Double = 0.0

    /// Laplace scale `b = sensitivity / epsilon`.
    public var scale: Double { sensitivity / epsilon }

    /// - Parameters:
    ///   - epsilon: privacy budget, must be `> 0`.
    ///   - sensitivity: change bound on the aggregate, must be `>= 0`.
    public init(epsilon: Double, sensitivity: Double) throws {
        guard epsilon > 0 else {
            throw DifferentialPrivacyError.nonPositiveEpsilon(epsilon)
        }
        guard sensitivity >= 0 else {
            throw DifferentialPrivacyError.negativeSensitivity(sensitivity)
        }
        self.epsilon = epsilon
        self.sensitivity = sensitivity
    }

    /// Draw one sample from `Laplace(0, scale)` using `rng` (inverse-CDF).
    ///
    /// Unbiased: `E[X] = 0`. Variance `2 * scale²`. The consumer supplies the
    /// RNG so reproducibility (via a seeded generator) is the caller's choice.
    public func sample(using rng: inout any RandomNumberGenerator) -> Double {
        let u = uniformUnit(in: &rng)
        if u <= 0.5 {
            return scale * log(2 * u)
        } else {
            return -scale * log(2 * (1 - u))
        }
    }

    /// Apply Laplace noise to a count/sum aggregate before it leaves the device.
    public func noised(_ value: Double, using rng: inout any RandomNumberGenerator) -> Double {
        value + sample(using: &rng)
    }

    /// Uniform on `(0, 1)` exclusive of 0 and 1, so `log` inputs stay finite.
    private func uniformUnit(in rng: inout RandomNumberGenerator) -> Double {
        // 53 random bits → [0, 1); map 0 to the smallest positive representable
        // value so the inverse-CDF never sees `log(0)`.
        let u = Double(rng.next() >> 11) * (1.0 / 0x1.0p53)
        return u > 0 ? u : .leastNonzeroMagnitude
    }
}

/// A deterministic, seeded `RandomNumberGenerator` (SplitMix64) so DP noise is
/// reproducible for tests and reproducible A/B re-runs. NOT for cryptographic
/// use — it only needs to be fast and seed-reproducible.
public struct SplitMix64: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
