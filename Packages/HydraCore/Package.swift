// swift-tools-version: 6.0
// HydraCore — platform-agnostic correction core for hydratype.
// Per thread T34: this package compiles identically on iOS 26 and macOS 26 with
// zero platform-conditional code in its public surface. FoundationModels usage is
// gated with `#if canImport(FoundationModels)` so the package still builds (and its
// pure-logic tests still run) on toolchains/platforms where AFM is unavailable —
// LOUD failure at runtime, never a silent compile-out of the public API.
import PackageDescription

let package = Package(
    name: "HydraCore",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "HydraCore", targets: ["HydraCore"]),
        .executable(name: "hydratype-cli", targets: ["hydratype-cli"]),
        .executable(name: "hydracore-check", targets: ["hydracore-check"]),
    ],
    targets: [
        .target(
            name: "HydraCore"
        ),
        .executableTarget(
            name: "hydratype-cli",
            dependencies: ["HydraCore"]
        ),
        // Runnable logic gate: works with the plain Command Line Tools toolchain
        // (no XCTest/Testing framework needed), so `swift run hydracore-check`
        // verifies the pure-logic core in any environment and can be wired into the
        // cicada pre-push gate. The XCTest suite in Tests/ is the richer Xcode/CI form.
        .executableTarget(
            name: "hydracore-check",
            dependencies: ["HydraCore"]
        ),
        .testTarget(
            name: "HydraCoreTests",
            dependencies: ["HydraCore"]
        ),
    ]
)
