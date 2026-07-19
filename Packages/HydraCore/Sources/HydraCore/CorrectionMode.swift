// E1-S3 — correction mode + field-kind classification (thread T2/T4/T22).
//
// Kept UI-free: the platform shell (iOS keyboard / macOS IMKit) maps its native
// traits (`UIKeyboardType`, `UITextContentType`, etc.) into `FieldKind` and passes
// that in, so this core has no UIKit/AppKit dependency and compiles everywhere.

/// The kind of text field, as classified by the platform shell from native traits.
public enum FieldKind: String, Sendable, CaseIterable, Codable {
    case password
    case url
    case email
    case code
    case plain
}

/// What the corrector should do in the current field.
public enum CorrectionMode: String, Sendable, Equatable, Codable {
    /// No correction at all (credential/structured fields).
    case off
    /// Full intent-aware prose correction.
    case prose
    /// Correct only the user's current selection, leave the rest untouched.
    case selectionOnly
}

public extension CorrectionMode {
    /// Default mode for a field kind. Zero Local Secrets / safety axiom:
    /// password/url/email/code default to `.off`; plain prose gets correction.
    static func defaultMode(for kind: FieldKind) -> CorrectionMode {
        switch kind {
        case .password, .url, .email, .code:
            return .off
        case .plain:
            return .prose
        }
    }
}
