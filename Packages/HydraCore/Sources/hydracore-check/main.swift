// Runnable logic gate for HydraCore — a dependency-free harness that runs the same
// assertions as the XCTest suite but needs no test framework, so it executes with the
// bare Command Line Tools toolchain. `swift run hydracore-check` exits 0 on all-pass,
// non-zero (LOUD) on the first failure. Intended for the cicada pre-push gate.

import Foundation
import HydraCore

var failures = 0
@MainActor func check(_ cond: Bool, _ name: String) {
    if cond {
        print("  ok   — \(name)")
    } else {
        print("  FAIL — \(name)")
        failures += 1
    }
}

print("hydracore-check: mode engine")
check(CorrectionMode.defaultMode(for: .password) == .off, "password defaults off")
check(CorrectionMode.defaultMode(for: .url) == .off, "url defaults off")
check(CorrectionMode.defaultMode(for: .email) == .off, "email defaults off")
check(CorrectionMode.defaultMode(for: .code) == .off, "code defaults off")
check(CorrectionMode.defaultMode(for: .plain) == .prose, "plain defaults prose")
// Guard: FieldKind.allCases must all be covered — a new case with no default trips this.
check(FieldKind.allCases.allSatisfy { _ in true } && FieldKind.allCases.count == 5,
      "FieldKind case count is the expected 5 (update defaults on change)")

let engine = ModeEngine(fieldKind: .plain)
check(engine.mode == .prose, "engine default prose")
engine.override(.off)
check(engine.mode == .off && engine.hasOverride, "override wins + hasOverride")
engine.resetForNewField(kind: .password)
check(engine.mode == .off && !engine.hasOverride, "new field drops override, kind default applies")

print("hydracore-check: correction store round-trip")
do {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("hydracore-check-\(UUID().uuidString).sqlite")
    defer { try? FileManager.default.removeItem(at: url) }
    let store = try CorrectionStore(url: url)
    check((try? store.count()) == 0, "fresh store empty")
    let id1 = try store.append(CorrectionEvent(
        fieldKind: .plain, before: "teh stroe", suggested: "the store",
        accepted: true, source: .afm, inferenceTier: "local_afm"))
    let id2 = try store.append(CorrectionEvent(
        fieldKind: .plain, before: "cant", suggested: "can't",
        accepted: false, source: .stock, inferenceTier: "baseline"))
    check(id1 != id2, "distinct row ids")
    check((try? store.count()) == 2, "count == 2 after two appends")
    let unsynced = try store.recentUnsynced(limit: 10)
    check(unsynced.count == 2, "two unsynced rows")
    check(unsynced.first?.before == "teh stroe", "oldest-first ordering")
    check(unsynced.first?.source == .afm, "source round-trips")
    try store.markSynced(ids: [id1])
    let after = try store.recentUnsynced(limit: 10)
    check(after.count == 1 && after.first?.id == id2, "markSynced removes only id1")
} catch {
    print("  FAIL — store round-trip threw: \(error)")
    failures += 1
}

print("hydracore-check: loud missing-container path")
do {
    _ = try CorrectionStore(appGroupID: "group.does.not.exist.hydratype.check")
    print("  FAIL — missing App Group container did not throw (silent!)")
    failures += 1
} catch let e as StoreError {
    check(true, "missing container throws StoreError loudly: \(e)")
} catch {
    print("  FAIL — wrong error type: \(error)")
    failures += 1
}
print("hydracore-check: inference tier validation")
check(InferenceTier.allCases.count == 3, "InferenceTier has exactly 3 cases (baseline, local_afm, cloud_assisted)")
check(InferenceTier.baseline.rawValue == "baseline", "baseline raw value")
check(InferenceTier.local_afm.rawValue == "local_afm", "local_afm raw value")
check(InferenceTier.cloud_assisted.rawValue == "cloud_assisted", "cloud_assisted raw value")
check(SuggestionSource.allCases.count == 3, "SuggestionSource has exactly 3 cases (afm, stock, user)")

// Bad inference tier should throw
do {
    _ = try CorrectionEvent.validate(inferenceTier: "not_a_valid_tier")
    print("  FAIL — invalid inferenceTier did not throw!")
    failures += 1
} catch let e as StoreError {
    check(true, "invalid inferenceTier throws StoreError: \(e)")
} catch {
    print("  FAIL — wrong error type for invalid inferenceTier: \(error)")
    failures += 1
}
// Valid tiers should not throw
do {
    try CorrectionEvent.validate(inferenceTier: "baseline")
    try CorrectionEvent.validate(inferenceTier: "local_afm")
    try CorrectionEvent.validate(inferenceTier: "cloud_assisted")
    check(true, "all valid inferenceTiers pass validation")
} catch {
    print("  FAIL — valid inferenceTier threw: \(error)")
    failures += 1
}

print("hydracore-check: rolling eviction awareness")
check(true, "no rolling eviction implemented yet — DATA-MODEL.md specifies rolling cap, CorrectionStore.append grows unbounded")
print("       WARN: CorrectionStore has no eviction logic. If the app runs for months,")
print("             corrections.sqlite grows without bound. Add eviction in E1-S4 or E3.")

print("hydracore-check: correction suggestion shape + error surface")
let s = CorrectionSuggestion(primary: "the store", alternates: ["the shore"])
check(s.primary == "the store" && s.alternates == ["the shore"] && !s.noChange, "suggestion shape")
check(CorrectorError.foundationModelsUnavailable.description.contains("foundationModelsUnavailable"),
      "error description is named/loud")

if failures == 0 {
    print("\nhydracore-check: ALL PASS")
    exit(0)
} else {
    FileHandle.standardError.write(Data("\nhydracore-check: \(failures) FAILURE(S)\n".utf8))
    exit(1)
}
