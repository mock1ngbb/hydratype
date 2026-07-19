// HydraType host app (E0-S1). SwiftUI shell; for now it drives the App Group smoke
// test so we can prove — on device/sim — that the host and keyboard extension share
// group.com.mock1ngbb.hydratype. Dashboard/calibration screens land in E3/E4.

import SwiftUI
import HydraCore
import FoundationModels

@main
struct HydraTypeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var status: String = "Not run"
    @State private var isError = false

    var body: some View {
        NavigationStack {
            List {
                Section("App Group smoke") {
                    Text(status)
                        .foregroundStyle(isError ? .red : .primary)
                        .font(.callout.monospaced())
                    Button("Write host stamp") { writeStamp() }
                    Button("Read keyboard stamp") { readStamp() }
                }
                Section("Model") {
                    Text(modelAvailabilityLine())
                        .font(.callout)
                }
            }
            .navigationTitle("HydraType")
        }
    }

    private func writeStamp() {
        do {
            let value = "host@\(Int(Date().timeIntervalSince1970))"
            try AppGroupSmoke.write(value)
            status = "Host wrote: \(value)"
            isError = false
        } catch {
            // LOUD — surface the typed error, never swallow.
            status = "WRITE FAILED: \(error)"
            isError = true
        }
    }

    private func readStamp() {
        do {
            if let value = try AppGroupSmoke.read() {
                status = "Read back: \(value)"
                isError = false
            } else {
                status = "No stamp yet (empty shared container)"
                isError = false
            }
        } catch {
            status = "READ FAILED: \(error)"
            isError = true
        }
    }

    private func modelAvailabilityLine() -> String {
        switch SystemLanguageModel.default.availability {
        case .available:
            return "Foundation Models: available"
        case .unavailable(let reason):
            return "Foundation Models: unavailable — \(reason)"
        @unknown default:
            return "Foundation Models: unknown availability"
        }
    }
}
