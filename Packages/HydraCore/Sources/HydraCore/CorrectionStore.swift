// E1-S4 — local cache/graph store of accepted/rejected corrections + personal vocab,
// living in the shared App Group container (thread T4). The keyboard extension appends
// lightweight rows; the host app reads unsynced rows and ships noised aggregates out.
//
// Raw SQLite3 (no third-party dependency) to stay well under the extension's memory
// ceiling. Loud by default: every SQLite failure throws a `StoreError` carrying the
// SQLite message — never a silent drop (NORTHSTAR axiom 4).

import Foundation
import os
import SQLite3

/// The source of a suggestion, for honest shadow measurement (E3).
public enum SuggestionSource: String, Sendable, Codable {
    case afm
    case stock
    case user
}

/// One correction event. Mirrors the row shape frozen in docs/privacy/DATA-MODEL.md.
public struct CorrectionEvent: Sendable, Equatable {
    public var id: Int64?
    public var timestamp: Date
    public var fieldKind: FieldKind
    public var before: String
    public var suggested: String
    public var accepted: Bool
    public var source: SuggestionSource
    public var inferenceTier: String
    public var synced: Bool

    public init(
        id: Int64? = nil,
        timestamp: Date = Date(),
        fieldKind: FieldKind,
        before: String,
        suggested: String,
        accepted: Bool,
        source: SuggestionSource,
        inferenceTier: String,
        synced: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.fieldKind = fieldKind
        self.before = before
        self.suggested = suggested
        self.accepted = accepted
        self.source = source
        self.inferenceTier = inferenceTier
        self.synced = synced
    }
}

public enum StoreError: Error, CustomStringConvertible {
    case open(String)
    case prepare(String)
    case step(String)
    case parse(String)
    case containerUnavailable(String)

    public var description: String {
        switch self {
        case .open(let m): return "StoreError.open: \(m)"
        case .prepare(let m): return "StoreError.prepare: \(m)"
        case .step(let m): return "StoreError.step: \(m)"
        case .parse(let m): return "StoreError.parse: \(m)"
        case .containerUnavailable(let m): return "StoreError.containerUnavailable: \(m)"
        }
    }
}

// SQLite wants this transient-destructor for bound text so it copies the bytes.
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public final class CorrectionStore: @unchecked Sendable {
    private var db: OpaquePointer?
    public let path: URL
    private let lock = OSAllocatedUnfairLock()

    /// Open (creating if needed) a store at an explicit file URL. Tests pass a temp
    /// URL; production passes the App Group container path.
    public init(url: URL) throws {
        self.path = url
        guard sqlite3_open(url.path, &db) == SQLITE_OK, db != nil else {
            let msg = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            throw StoreError.open(msg)
        }
        try migrate()
    }

    /// Convenience: open in the App Group shared container.
    public convenience init(appGroupID: String, filename: String = "corrections.sqlite") throws {
        guard let dir = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            throw StoreError.containerUnavailable(
                "no container for App Group \(appGroupID) — check entitlements"
            )
        }
        try self.init(url: dir.appendingPathComponent(filename))
    }

    deinit {
        if let db { sqlite3_close(db) }
    }

    private func migrate() throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS corrections (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ts REAL NOT NULL,
            field_kind TEXT NOT NULL,
            before TEXT NOT NULL,
            suggested TEXT NOT NULL,
            accepted INTEGER NOT NULL,
            source TEXT NOT NULL,
            inference_tier TEXT NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0
        );
        CREATE INDEX IF NOT EXISTS idx_corrections_unsynced ON corrections(synced);
        """
        try exec(sql)
    }

    private func exec(_ sql: String) throws {
        var err: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &err) != SQLITE_OK {
            let msg = err.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(err)
            throw StoreError.step(msg)
        }
    }

    private func errmsg() -> String {
        db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
    }

    /// Append one event. Returns the assigned row id.
    @discardableResult
    public func append(_ event: CorrectionEvent) throws -> Int64 {
        try lock.withLock {
            let sql = """
            INSERT INTO corrections (ts, field_kind, before, suggested, accepted, source, inference_tier, synced)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?);
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw StoreError.prepare(errmsg())
            }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_double(stmt, 1, event.timestamp.timeIntervalSince1970)
            sqlite3_bind_text(stmt, 2, event.fieldKind.rawValue, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, event.before, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 4, event.suggested, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 5, event.accepted ? 1 : 0)
            sqlite3_bind_text(stmt, 6, event.source.rawValue, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 7, event.inferenceTier, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 8, event.synced ? 1 : 0)
            guard sqlite3_step(stmt) == SQLITE_DONE else {
                throw StoreError.step(errmsg())
            }
            return sqlite3_last_insert_rowid(db)
        }
    }

    /// The most recent unsynced events, oldest first (upload order), up to `limit`.
    public func recentUnsynced(limit: Int) throws -> [CorrectionEvent] {
        try lock.withLock {
            guard limit <= Int(Int32.max) else {
                throw StoreError.parse("limit \(limit) exceeds Int32.max")
            }
            let sql = """
            SELECT id, ts, field_kind, before, suggested, accepted, source, inference_tier, synced
            FROM corrections WHERE synced = 0 ORDER BY ts ASC LIMIT ?;
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw StoreError.prepare(errmsg())
            }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_int(stmt, 1, Int32(limit))

            var out: [CorrectionEvent] = []
            while true {
                let rc = sqlite3_step(stmt)
                if rc == SQLITE_DONE { break }
                guard rc == SQLITE_ROW else { throw StoreError.step(errmsg()) }
                out.append(try row(from: stmt))
            }
            return out
        }
    }

    /// Mark the given row ids as synced.
    public func markSynced(ids: [Int64]) throws {
        try lock.withLock {
            guard !ids.isEmpty else { return }
            let placeholders = ids.map { _ in "?" }.joined(separator: ",")
            let sql = "UPDATE corrections SET synced = 1 WHERE id IN (\(placeholders));"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw StoreError.prepare(errmsg())
            }
            defer { sqlite3_finalize(stmt) }
            for (i, id) in ids.enumerated() {
                sqlite3_bind_int64(stmt, Int32(i + 1), id)
            }
            guard sqlite3_step(stmt) == SQLITE_DONE else {
                throw StoreError.step(errmsg())
            }
        }
    }

    /// Total row count (for tests / the local dashboard).
    public func count() throws -> Int {
        try lock.withLock {
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM corrections;", -1, &stmt, nil) == SQLITE_OK else {
                throw StoreError.prepare(errmsg())
            }
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_step(stmt) == SQLITE_ROW else { throw StoreError.step(errmsg()) }
            return Int(sqlite3_column_int(stmt, 0))
        }
    }

    private func row(from stmt: OpaquePointer?) throws -> CorrectionEvent {
        func text(_ col: Int32) -> String {
            guard let c = sqlite3_column_text(stmt, col) else { return "" }
            return String(cString: c)
        }
        let fieldRaw = text(2)
        guard let fieldKind = FieldKind(rawValue: fieldRaw) else {
            throw StoreError.parse("unrecognized fieldKind rawValue '\(fieldRaw)' in row \(sqlite3_column_int64(stmt, 0))")
        }
        let sourceRaw = text(6)
        guard let source = SuggestionSource(rawValue: sourceRaw) else {
            throw StoreError.parse("unrecognized source rawValue '\(sourceRaw)' in row \(sqlite3_column_int64(stmt, 0))")
        }
        return CorrectionEvent(
            id: sqlite3_column_int64(stmt, 0),
            timestamp: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1)),
            fieldKind: fieldKind,
            before: text(3),
            suggested: text(4),
            accepted: sqlite3_column_int(stmt, 5) != 0,
            source: source,
            inferenceTier: text(7),
            synced: sqlite3_column_int(stmt, 8) != 0
        )
    }
}
