// swift-tools-version: 6.0
// HydraCore — shared correction core for hydratype. Compiles identically toward
// iOS 26 and macOS 26 with zero platform-conditional code (thread T34).
//
// Requires the full Xcode toolchain (the FoundationModels `@Generable`/`@Guide` macro
// plugin ships with Xcode, not the Command Line Tools). On this project's machine
// `xcode-select` points at Xcode, so plain `swift build`/`swift test` resolve the
// plugin. FoundationModels APIs are 26+, so the package baseline is 26 — no
// availability guards needed in the public surface.
import PackageDescription

let package = Package(
    name: "HydraCore",
    platforms: [
        .macOS("26.0"),
        .iOS("26.0"),
    ],
    products: [
        .library(name: "HydraCore", targets: ["HydraCore"]),
        .executable(name: "hydratype-cli", targets: ["hydratype-cli"]),
        .executable(name: "hydracore-check", targets: ["hydracore-check"]),
        .executable(name: "hydracore-bench", targets: ["hydracore-bench"]),
    ],
    targets: [
        .target(
            name: "HydraCore"
        ),
        .executableTarget(
            name: "hydratype-cli",
            dependencies: ["HydraCore"]
        ),
        // Framework-free runnable logic gate (no XCTest needed): `swift run
        // hydracore-check` verifies the pure-logic core and is wired into scripts/gate.sh
        // / the cicada pre-push gate. The XCTest suite in Tests/ is the richer form.
        .executableTarget(
            name: "hydracore-check",
            dependencies: ["HydraCore"]
        ),
        // Quality/regression harness: `swift run hydracore-bench` runs the fast
        // edit-distance corrector over a real-typo corpus (see
        // Sources/hydracore-bench/) reporting latency + accuracy. No live AFM needed.
        .executableTarget(
            name: "hydracore-bench",
            dependencies: ["HydraCore"]
        ),
        .testTarget(
            name: "HydraCoreTests",
            dependencies: ["HydraCore"]
        ),
    ]
)
