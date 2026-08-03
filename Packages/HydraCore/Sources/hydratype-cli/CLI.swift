// E1b-S1 — headless macOS CLI harness over HydraCore. The fast build-test-observe
// loop from thread T34: pipe stdin text through `HybridCorrector` (fast edit-distance
// path for single words, AFM escalation otherwise), pretty-print the
// `CorrectionSuggestion` with latency, footprint, and which source ran.
// No sandbox, full debugger + console.
//
//   echo "i cant beleive it" | swift run hydratype-cli
//
// Loud by default: an unavailable model prints the typed error and exits non-zero —
// never a silent empty print.

import Foundation
import Darwin
import HydraCore

/// macOS memory metric — resident footprint (bytes) via mach task_info. NOTE:
/// os_proc_available_memory() is API_UNAVAILABLE on macOS (iOS-only), so the M5
/// pivot uses resident footprint to show the model's working-set growth across a
/// correction (there is no ~50–60 MB keyboard ceiling on macOS anyway).
@inline(__always)
private func residentFootprintMB() -> Double {
    var info = mach_task_basic_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info_data_t>.size / MemoryLayout<integer_t>.size)
    let kr = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }
    guard kr == KERN_SUCCESS else { return -1 }
    return Double(info.resident_size) / (1024.0 * 1024.0)
}

@main
struct HydraTypeCLI {
    static func main() async {
        FileHandle.standardError.write(Data("hydratype-cli — reading lines from stdin (Ctrl-D to end)\n".utf8))

        let corrector = HybridCorrector()
        var hadErrors = false

        while let line = readLine(strippingNewline: true) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let before = residentFootprintMB()
            let start = Date()
            do {
                let result = try await corrector.correct(trimmed)
                let ms = Int(Date().timeIntervalSince(start) * 1000)
                let after = residentFootprintMB()
                print("── input:      \(trimmed)")
                print("   primary:    \(result.primary)")
                if !result.alternates.isEmpty {
                    print("   alternates: \(result.alternates.joined(separator: " | "))")
                }
                print("   noChange:   \(result.noChange)")
                print("   source:     \(result.source == .fastEditDistance ? "fastEditDistance" : "afm")")
                print("   latency:    \(ms) ms")
                print("   footprint:  \(String(format: "%.1f", before)) -> \(String(format: "%.1f", after)) MB (Δ \(String(format: "%.1f", after - before)))")
            } catch {
                // LOUD: surface the typed error to stderr, keep the loop alive,
                // but set an error flag so we exit non-zero.
                FileHandle.standardError.write(Data("ERROR: \(error)\n".utf8))
                hadErrors = true
            }
        }

        if hadErrors {
            FileHandle.standardError.write(Data("hydratype-cli: one or more corrections failed — exiting non-zero\n".utf8))
            exit(1)
        }
    }
}
