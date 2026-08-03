// Probe.swift — E-SPIKE-1 device-only throwaway measurement probe.
//
// ┌───────────────────────────────────────────────────────────────────────────┐
// │ HYDRA_AFM CAVEAT — THROWAWAY, DEVICE-ONLY.                                   │
// │ This file DOES NOT COMPILE on this machine or in CI. It needs iOS 26,        │
// │ UIKit + `import FoundationModels`, and a real Custom Keyboard Extension      │
// │ target running on a physical device (or a sim) with Apple Intelligence      │
// │ enabled. It exists ONLY to measure whether AFM can run in-extension          │
// │ (slice E-SPIKE-1 / hardening H1). Delete after the README verdict is filled. │
// │ Do NOT wire it into shipping code and do NOT let CI try to build it.         │
// └───────────────────────────────────────────────────────────────────────────┘
//
// How to use: create a throwaway Custom Keyboard Extension target, make its
// principal class this `SpikeKeyboardViewController`, add the App Group +
// FoundationModels, install the keyboard, attach Console.app to the device
// (filter subsystem `com.mock1ngbb.hydratype`, category `afm-spike`), open any
// plain text field, and type ONE character. Read the logged lines. If the
// extension dies before the "post" line prints, that silence == jetsam.

#if canImport(UIKit) && canImport(FoundationModels)
import UIKit
import os
import FoundationModels

/// Structured, LOUD logger. Every measurement is a log line so the result
/// survives even when the process is jetsammed mid-run.
private let spikeLog = Logger(subsystem: "com.mock1ngbb.hydratype", category: "afm-spike")

/// os_proc_available_memory() returns the bytes of memory headroom the process
/// has left before the OS jetsams (kills) it. It is the correct gauge for an
/// app extension's ~50–60 MB ceiling (NOT total device RAM).
@inline(__always)
private func availableMemoryMB() -> Double {
    Double(os_proc_available_memory()) / (1024.0 * 1024.0)
}

final class SpikeKeyboardViewController: UIInputViewController {

    /// Run the probe exactly once, on the first keystroke only.
    private var didRunProbe = false

    override func viewDidLoad() {
        super.viewDidLoad()
        // Minimal UI: a single button so the keyboard is usable enough to type.
        let btn = UIButton(type: .system)
        btn.setTitle("space", for: .normal)
        btn.frame = CGRect(x: 0, y: 0, width: 200, height: 44)
        btn.addTarget(self, action: #selector(handleKey), for: .touchUpInside)
        view.addSubview(btn)
        spikeLog.notice("SPIKE viewDidLoad · baseline headroom=\(availableMemoryMB(), format: .fixed(precision: 1)) MB")
    }

    @objc private func handleKey() {
        textDocumentProxy.insertText(" ")
        guard !didRunProbe else { return }
        didRunProbe = true
        Task { await runProbe() }
    }

    /// The E-SPIKE-1 measurement, in the exact order the README specifies.
    private func runProbe() async {
        // STEP 1 — baseline memory (LOUD).
        let baseline = availableMemoryMB()
        spikeLog.notice("SPIKE step1 baseline_headroom=\(baseline, format: .fixed(precision: 1)) MB")

        // STEP 2 — availability. If unavailable in-extension, that alone is a
        // BROKER_REQUIRED signal; record the reason and STOP (do not build a session).
        let availability = SystemLanguageModel.default.availability
        switch availability {
        case .available:
            spikeLog.notice("SPIKE step2 availability=AVAILABLE")
        case .unavailable(let reason):
            spikeLog.error("SPIKE step2 availability=UNAVAILABLE reason=\(String(describing: reason), privacy: .public) → BROKER_REQUIRED signal; stopping")
            return
        @unknown default:
            spikeLog.error("SPIKE step2 availability=UNKNOWN_CASE → treat as BROKER_REQUIRED; stopping")
            return
        }

        // STEP 3 — one session + one response. This is the memory-critical moment;
        // if the extension is going to jetsam, it happens at/after model load here.
        // No model id is hardcoded (Commodity Intelligence): use the system default.
        let prompt = "i went to teh stroe"
        let t0 = Date()
        do {
            // Canonical live form: @InstructionsBuilder closure (the WWDC25
            // `init(instructions: String)` convenience drifts from current docs;
            // see docs/reference/apple-foundation-models.md §2 "signature drift").
            let session = LanguageModelSession {
                "Correct the user's text for intent and tone. Reply with only the corrected sentence."
            }
            spikeLog.notice("SPIKE step3 session_constructed headroom=\(availableMemoryMB(), format: .fixed(precision: 1)) MB")

            let response = try await session.respond(to: prompt)
            let latencyMs = Date().timeIntervalSince(t0) * 1000.0

            // STEP 4 — post memory (only reached if we SURVIVED the response).
            let post = availableMemoryMB()
            spikeLog.notice("SPIKE step4 SURVIVED latency=\(latencyMs, format: .fixed(precision: 0))ms post_headroom=\(post, format: .fixed(precision: 1)) MB delta=\(baseline - post, format: .fixed(precision: 1)) MB")
            spikeLog.notice("SPIKE result_text=\(response.content, privacy: .public)")
            spikeLog.notice("SPIKE ⇒ candidate IN_EXTENSION_OK (confirm no jetsam over 3 runs, headroom stayed positive)")
        } catch {
            // A thrown error (not a kill) — still LOUD, still a BROKER_REQUIRED lean.
            spikeLog.error("SPIKE step3 THREW \(String(describing: error), privacy: .public) headroom=\(availableMemoryMB(), format: .fixed(precision: 1)) MB → lean BROKER_REQUIRED")
        }

        // STEP 5 note: if NO "step4"/"THREW" line ever prints for this run, the
        // process was jetsammed mid-load. That SILENCE is the result. Cross-check
        // Console for a `memorystatus`/`EXC_RESOURCE (MEMORY)` kill of the keyboard
        // process and read peak footprint from the jetsam report → BROKER_REQUIRED.
    }
}
#else
#warning("Probe.swift is a device-only E-SPIKE-1 throwaway: needs iOS UIKit + FoundationModels. Not for this build/CI.")
#endif
