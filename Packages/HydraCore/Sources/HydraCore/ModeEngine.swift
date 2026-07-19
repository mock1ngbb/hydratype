// E1-S3 — `ModeEngine`: holds the current correction mode for a field session and
// applies override precedence. A manual override always wins over the field default
// and is sticky for the duration of the field session (until `resetForNewField`).

import Foundation

public final class ModeEngine {
    public private(set) var fieldKind: FieldKind
    private var manualOverride: CorrectionMode?

    public init(fieldKind: FieldKind = .plain) {
        self.fieldKind = fieldKind
    }

    /// The effective mode: manual override if set, else the field-kind default.
    public var mode: CorrectionMode {
        manualOverride ?? CorrectionMode.defaultMode(for: fieldKind)
    }

    /// User manually forces a mode. Sticky until the field session resets.
    public func override(_ mode: CorrectionMode) {
        manualOverride = mode
    }

    /// Clear a manual override, reverting to the field-kind default.
    public func clearOverride() {
        manualOverride = nil
    }

    /// Called when focus moves to a new field. Updates the detected kind and drops
    /// any override (override is per-field-session, not global — thread T22).
    public func resetForNewField(kind: FieldKind) {
        fieldKind = kind
        manualOverride = nil
    }

    /// Whether a manual override is currently in force (for UI state / logging).
    public var hasOverride: Bool { manualOverride != nil }
}
