// E1b-S1 — headless macOS CLI harness over HydraCore. The fast build-test-observe
// loop from thread T34: pipe stdin text through `AFMCorrector`, pretty-print the
// `CorrectionSuggestion` with latency. No sandbox, full debugger + console.
//
//   echo "i cant beleive it" | swift run hydratype-cli
//
// Loud by default: an unavailable model prints the typed error and exits non-zero —
// never a silent empty print.

import Foundation
import HydraCore

@main
struct HydraTypeCLI {
    static func main() async {
        FileHandle.standardError.write(Data("hydratype-cli — reading lines from stdin (Ctrl-D to end)\n".utf8))

        guard #available(macOS 26.0, iOS 26.0, *) else {
            fail("this OS build predates Foundation Models (macOS/iOS 26). Cannot run AFM correction.")
        }

        #if HYDRA_AFM
        let corrector = AFMCorrector()
        while let line = readLine(strippingNewline: true) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let start = Date()
            do {
                let result = try await corrector.correct(trimmed)
                let ms = Int(Date().timeIntervalSince(start) * 1000)
                print("── input:      \(trimmed)")
                print("   primary:    \(result.primary)")
                if !result.alternates.isEmpty {
                    print("   alternates: \(result.alternates.joined(separator: " | "))")
                }
                print("   noChange:   \(result.noChange)")
                print("   latency:    \(ms) ms")
            } catch {
                // LOUD: surface the typed error to stderr, keep the loop alive.
                FileHandle.standardError.write(Data("ERROR: \(error)\n".utf8))
            }
        }
        #else
        fail("built without HYDRA_AFM — this CLI needs the Xcode/AFM build (swift build -Xswiftc -DHYDRA_AFM on macOS 26).")
        #endif
    }

    static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("hydratype-cli FATAL: \(message)\n".utf8))
        exit(1)
    }
}
