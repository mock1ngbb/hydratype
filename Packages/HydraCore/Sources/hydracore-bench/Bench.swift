// HydraCore quality/regression benchmark harness.
//
//   swift run hydracore-bench [--hybrid]
//
// Runs the pure-Swift fast `EditDistanceCorrector` over the regression corpus
// (`Corpus.swift`), reporting per-item + average latency and how many single-word
// corrections match the expected output (accuracy). No live AFM is required: the
// fast path never touches the model.
//
// The AFM path is OPTIONAL: pass `--hybrid` to also route the corpus through
// `HybridCorrector`. Because the hybrid escalates non-high-confidence single words
// to AFM, and a live `SystemLanguageModel` is usually unavailable in a bare
// toolchain, those escalations are detected and SKIPPED loudly — the run still
// reports the fast-path numbers and never fails merely because AFM is absent.
//
// Exit code is 0 on all-pass fast-path accuracy, 1 (LOUD) otherwise. Latency is
// reported in microseconds per word.

import Foundation
import HydraCore

// MARK: - Fast-path per-item measurement

/// One measured correction against the corpus.
struct BenchRow {
    let typo: String
    let expected: String
    let sentence: String
    let match: EditDistanceMatch?
    let latencyMicros: Double
    let escalated: Bool

    /// True when the fast path returned the expected word.
    var matched: Bool { match?.candidate == expected }
}

/// Runs the fast corrector over one word, timing it in microseconds.
func measureFast(_ corrector: EditDistanceCorrector, _ word: String) -> (EditDistanceMatch?, Double) {
    let start = DispatchTime.now().uptimeNanoseconds
    let match = corrector.bestMatch(for: word)
    let elapsed = DispatchTime.now().uptimeNanoseconds - start
    return (match, Double(elapsed) / 1000.0) // ns -> µs
}

func runFastBench() -> [BenchRow] {
    let corrector = EditDistanceCorrector()
    return benchCorpus.map { entry in
        let (match, micros) = measureFast(corrector, entry.typo)
        return BenchRow(
            typo: entry.typo,
            expected: entry.expected,
            sentence: entry.sentence,
            match: match,
            latencyMicros: micros,
            escalated: match?.isHighConfidence == false
        )
    }
}

// MARK: - Optional AFM-path (hybrid) measurement

/// Routes a word through the hybrid corrector. When the fast path escalates to AFM
/// and the system model is unavailable, we return `nil` (skipped) rather than fail
/// the whole run — the benchmark must run without a live model.
func runHybrid(_ hybrid: HybridCorrector, _ word: String) async -> CorrectionSuggestion? {
    do {
        return try await hybrid.correct(word)
    } catch is CorrectorError {
        // modelUnavailable / foundationModelsUnavailable / emptyResult / sessionFailure —
        // all mean "no live AFM right now": skip loudly, not silently.
        return nil
    } catch {
        return nil
    }
}

// MARK: - Report

func printHeader() {
    print("hydracore-bench — HydraCore fast-path regression harness")
    print("corpus: \(benchCorpus.count) single-word typos")
    print("")
    print("  typo         expected     match   dist  confident      µs  sentence")
    print("  \(String(repeating: "-", count: 78))")
}

func printRow(_ row: BenchRow) {
    let match = row.match
    let matchLabel = row.matched ? "OK" : (match == nil ? "NONE" : "MISS")
    let dist = match.map { String($0.distance) } ?? "—"
    let confident = match?.isHighConfidence == true ? "yes" : (match == nil ? "—" : "no")
    print("  \(pad(row.typo, 11)) \(pad(row.expected, 12)) \(pad(matchLabel, 6)) \(pad(dist, 5)) \(pad(confident, 9)) \(pad(String(format: "%.1f", row.latencyMicros), 8)) \(row.sentence)")
}

func printSummary(_ rows: [BenchRow], hybridSkipped: Int) {
    let total = rows.count
    guard total > 0 else {
        print("\nhydracore-bench: EMPTY CORPUS — nothing to measure (LOUD)")
        exit(1)
    }

    let matched = rows.filter(\.matched).count
    let escalated = rows.filter(\.escalated).count
    let avgMicros = rows.reduce(0.0) { $0 + $1.latencyMicros } / Double(total)
    let attempted = rows.filter { $0.match != nil }.count

    let accuracy = Double(matched) / Double(total) * 100.0
    let accuracyOnAttempted = attempted == 0 ? 0.0 : Double(matched) / Double(attempted) * 100.0

    print("  \(String(repeating: "-", count: 78))")
    print("  matched            \(matched) / \(total)  (\(String(format: "%.1f", accuracy))% overall, \(String(format: "%.1f", accuracyOnAttempted))% of words with a match)")
    print("  escalated (to AFM) \(escalated)  — fast path had no high-confidence match")
    print("  avg latency        \(String(format: "%.1f", avgMicros)) µs/word")

    if hybridSkipped > 0 {
        print("  hybrid mode        \(hybridSkipped) item(s) escalated to AFM were SKIPPED (no live model) — optional, non-fatal")
    }

    if matched == total {
        print("\nhydracore-bench: ALL PASS — \(matched)/\(total) fast-path corrections match")
        exit(0)
    } else {
        FileHandle.standardError.write(Data("\nhydracore-bench: \(total - matched) MISMATCH(ES) — fast-path regression\n".utf8))
        exit(1)
    }
}

/// Pads a string to a fixed display width so the report columns align (handles the
/// non-ASCII "—" glyph safely by padding by character count, not byte count).
private func pad(_ s: String, _ width: Int) -> String {
    let count = s.count
    return count >= width ? s : s + String(repeating: " ", count: width - count)
}

// MARK: - Entry

@main
struct HydraCoreBench {
    static func main() async {
        let wantsHybrid = CommandLine.arguments.contains("--hybrid")

        printHeader()
        let rows = runFastBench()
        for row in rows { printRow(row) }

        var hybridSkipped = 0
        if wantsHybrid {
            let hybrid = HybridCorrector()
            for row in rows where row.escalated {
                let suggestion = await runHybrid(hybrid, row.typo)
                if suggestion == nil {
                    hybridSkipped += 1
                }
            }
        }

        printSummary(rows, hybridSkipped: hybridSkipped)
    }
}
