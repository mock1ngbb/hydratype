// E0-S1 smoke — proves both targets share the App Group container. The keyboard
// extension writes a stamp; the host app reads it back (and vice versa). Loud on
// failure: throws `StoreError.containerUnavailable` rather than returning nil.

import Foundation

public enum AppGroupSmoke {
    public static let defaultGroupID = "group.com.mock1ngbb.hydratype"
    private static let filename = "appgroup-smoke.txt"

    private static func containerFile(_ groupID: String) throws -> URL {
        guard let dir = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: groupID
        ) else {
            throw StoreError.containerUnavailable(
                "no container for App Group \(groupID) — check entitlements on this target"
            )
        }
        return dir.appendingPathComponent(filename)
    }

    /// Write a stamp into the shared container. Returns the value written.
    @discardableResult
    public static func write(_ value: String, groupID: String = defaultGroupID) throws -> String {
        try value.data(using: .utf8)!.write(to: containerFile(groupID), options: .atomic)
        return value
    }

    /// Read back the stamp the other target wrote. Returns nil only if nothing has
    /// been written yet (a genuine empty state), never on a masked error.
    public static func read(groupID: String = defaultGroupID) throws -> String? {
        let url = try containerFile(groupID)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return String(data: try Data(contentsOf: url), encoding: .utf8)
    }
}
