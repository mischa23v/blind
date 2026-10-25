import Foundation
import GRDB

/// Encoded typed historical evidence. Not ordinary memory, live pose, or model context.
public struct NativeObservationRow: Sendable, Equatable {
    public let id: String
    public let sessionID: String
    public let capturedAt: Double
    public let payload: Data

    public init(id: String, sessionID: String, capturedAt: Double, payload: Data) {
        self.id = id
        self.sessionID = sessionID
        self.capturedAt = capturedAt
        self.payload = payload
    }
}

public struct NativeObservationStoreSnapshot: Sendable, Equatable {
    /// Oldest insertion first, independent of wall-clock order across sessions.
    public let rows: [NativeObservationRow]
    public let evictedRecordCount: Int

    public init(rows: [NativeObservationRow], evictedRecordCount: Int) {
        self.rows = rows
        self.evictedRecordCount = evictedRecordCount
    }
}

public struct NativeObservationWriteResult: Sendable, Equatable {
    /// All retained IDs, oldest insertion first. Existing payloads are never rewritten.
    public let retainedIDs: [String]
    public let evictedRecordCount: Int
    /// Successfully committed inserts, including any inserted row evicted by this batch.
    public let insertedRecordCount: Int
    /// Logical encoded bytes inserted by this committed transaction, not SQLite I/O bytes.
    public let insertedPayloadBytes: Int

    public init(retainedIDs: [String], evictedRecordCount: Int, insertedRecordCount: Int, insertedPayloadBytes: Int) {
        self.retainedIDs = retainedIDs
        self.evictedRecordCount = evictedRecordCount
        self.insertedRecordCount = insertedRecordCount
        self.insertedPayloadBytes = insertedPayloadBytes
    }
}

/// Separate GRDB writer and SQLite file for bounded historical observations.
/// Limits apply to each profile, across all sessions. No JSON/model decoder is involved.
public final class NativeObservationStore: Sendable {
    public static let maximumRecordCount = 64
    public static let maximumPayloadBytes = 2 * 1024 * 1024
    private static let maximumEvictedRecordCount = 1_000_000_000
    private let database: DatabaseQueue
    private let profile: String
    private let beforeAppend: (@Sendable () throws -> Void)?

    public convenience init(path: String, profile: String = "local") throws {
        try self.init(path: path, profile: profile, configuration: Configuration())
    }

    /// Internal configuration/synchronization seam uses the real GRDB writer. Tests can
    /// observe SQL and stall an actual transaction without substituting a fake database.
    init(path: String, profile: String = "local", configuration: Configuration,
         beforeAppend: (@Sendable () throws -> Void)? = nil) throws {
        guard !profile.isEmpty, profile.count <= 100 else { throw MemoryError.invalid }
        self.profile = profile
        self.beforeAppend = beforeAppend
        var configuration = configuration
        configuration.foreignKeysEnabled = true
        database = try DatabaseQueue(path: path, configuration: configuration)
        var migrator = DatabaseMigrator()
        migrator.registerMigration("native-observation-history-v1") { db in
            try db.execute(sql: MemoryStore.sql("native_observations"))
        }
        try migrator.migrate(database)
    }

    public func load() throws -> NativeObservationStoreSnapshot {
        try database.read { db in
            let validated = try preflight(db)
            let rows = try Row.fetchAll(db, sql: "SELECT id,sessionID,capturedAt,payload FROM nativeObservation WHERE profile=? ORDER BY insertionSequence LIMIT 64", arguments: [profile]).map(Self.row)
            return NativeObservationStoreSnapshot(rows: rows, evictedRecordCount: validated.evictedRecordCount)
        }
    }

    /// One transaction inserts only new records, then evicts the oldest rows to meet
    /// both quotas. A failed validation, SQL write, or counter overflow rolls it all back.
    /// An identical duplicate is a no-op; conflicting content for its ID is an error.
    public func append(_ rows: [NativeObservationRow]) throws -> NativeObservationWriteResult {
        guard rows.count <= Self.maximumRecordCount else { throw MemoryError.invalid }
        var batchBytes = 0
        for row in rows {
            try Self.validate(row)
            guard row.payload.count <= Self.maximumPayloadBytes - batchBytes else { throw MemoryError.invalid }
            batchBytes += row.payload.count
        }
        if rows.isEmpty {
            return try database.read { db in
                let validated = try preflight(db)
                return NativeObservationWriteResult(retainedIDs: validated.metadata.map(\.id), evictedRecordCount: validated.evictedRecordCount, insertedRecordCount: 0, insertedPayloadBytes: 0)
            }
        }
        return try database.write { db in
            let validated = try preflight(db)
            try beforeAppend?()
            var insertedCount = 0
            var insertedBytes = 0
            for row in rows {
                if let existing = try Row.fetchOne(db, sql: "SELECT id,sessionID,capturedAt,payload FROM nativeObservation WHERE profile=? AND id=?", arguments: [profile, row.id]) {
                    let stored = Self.row(existing)
                    guard stored.sessionID.caseInsensitiveCompare(row.sessionID) == .orderedSame,
                          stored.capturedAt == row.capturedAt,
                          stored.payload == row.payload else { throw MemoryError.conflict }
                    continue
                }
                // Retained history and earlier inserts in this transaction are sufficient
                // to enforce strict time order without an unbounded table of old sessions.
                if let latest = try Double.fetchOne(db, sql: "SELECT MAX(capturedAt) FROM nativeObservation WHERE profile=? AND sessionID=?", arguments: [profile, row.sessionID]) {
                    guard row.capturedAt > latest else { throw MemoryError.invalid }
                }
                try db.execute(sql: "INSERT INTO nativeObservation(profile,id,sessionID,capturedAt,payload,encodedBytes) VALUES (?,?,?,?,?,?)", arguments: [profile, row.id, row.sessionID, row.capturedAt, row.payload, row.payload.count])
                insertedCount += 1
                insertedBytes += row.payload.count
            }
            // At most 128 valid metadata rows plus one overflow sentinel; no payload ring.
            let metadata = try metadata(db, maximumCount: Self.maximumRecordCount * 2, maximumBytes: Self.maximumPayloadBytes * 2)
            var retainedBytes = metadata.reduce(0) { $0 + $1.encodedBytes }
            var evicted = 0
            while metadata.count - evicted > Self.maximumRecordCount || retainedBytes > Self.maximumPayloadBytes {
                retainedBytes -= metadata[evicted].encodedBytes
                evicted += 1
            }
            let previousEvictions = validated.evictedRecordCount
            guard evicted <= Self.maximumEvictedRecordCount - previousEvictions else { throw MemoryError.invalid }
            if evicted > 0 {
                let lastSequence = metadata[evicted - 1].insertionSequence
                try db.execute(sql: "DELETE FROM nativeObservation WHERE profile=? AND insertionSequence<=?", arguments: [profile, lastSequence])
                try db.execute(sql: "INSERT INTO nativeObservationState(profile,evictedRecordCount) VALUES (?,?) ON CONFLICT(profile) DO UPDATE SET evictedRecordCount=excluded.evictedRecordCount", arguments: [profile, previousEvictions + evicted])
            }
            return NativeObservationWriteResult(retainedIDs: metadata.dropFirst(evicted).map(\.id), evictedRecordCount: previousEvictions + evicted, insertedRecordCount: insertedCount, insertedPayloadBytes: insertedBytes)
        }
    }

    /// Idempotent, profile-scoped deletion of history and its eviction counter.
    public func clear() throws {
        try database.write { db in
            try db.execute(sql: "DELETE FROM nativeObservation WHERE profile=?", arguments: [profile])
            try db.execute(sql: "DELETE FROM nativeObservationState WHERE profile=?", arguments: [profile])
        }
    }

    private struct Metadata {
        let insertionSequence: Int64
        let id: String
        let encodedBytes: Int
    }
    /// Reject corrupt/externally overfilled history before loading any payload or
    /// beginning INSERTs. The caller already holds one GRDB read/write transaction.
    private func preflight(_ db: Database) throws -> (metadata: [Metadata], evictedRecordCount: Int) {
        let count = try evictionCount(db)
        return (try metadata(db, maximumCount: Self.maximumRecordCount, maximumBytes: Self.maximumPayloadBytes), count)
    }
    private func metadata(_ db: Database, maximumCount: Int, maximumBytes: Int) throws -> [Metadata] {
        // length(BLOB) consults SQLite's cached byte count without materializing blobs.
        let rows = try Row.fetchAll(db, sql: """
            SELECT insertionSequence,substr(id,1,37) AS id,typeof(id) AS idType,
                   substr(sessionID,1,37) AS sessionID,typeof(sessionID) AS sessionType,
                   CASE WHEN typeof(capturedAt) IN ('integer','real') THEN capturedAt END AS capturedAt,
                   CASE WHEN typeof(encodedBytes)='integer' THEN encodedBytes END AS encodedBytes,
                   length(payload) AS actualBytes,typeof(payload) AS payloadType
            FROM nativeObservation WHERE profile=? ORDER BY insertionSequence LIMIT ?
            """, arguments: [profile, maximumCount + 1])
        guard rows.count <= maximumCount else { throw MemoryError.invalid }
        var bytes = 0
        var lastTimestampBySession: [String: Double] = [:]
        return try rows.map { row in
            guard let sequence = Int64.fromDatabaseValue(row["insertionSequence"]),
                  let id = String.fromDatabaseValue(row["id"]), Self.isUUID(id),
                  let session = String.fromDatabaseValue(row["sessionID"]), Self.isUUID(session),
                  let time = Double.fromDatabaseValue(row["capturedAt"]), time.isFinite, time >= 0,
                  let size = Int.fromDatabaseValue(row["encodedBytes"]),
                  let actualSize = Int.fromDatabaseValue(row["actualBytes"]),
                  row["payloadType"] as String == "blob", row["idType"] as String == "text", row["sessionType"] as String == "text",
                  (1...Self.maximumPayloadBytes).contains(size), size == actualSize,
                  size <= maximumBytes - bytes else { throw MemoryError.invalid }
            let sessionKey = session.uppercased()
            if let previous = lastTimestampBySession[sessionKey], time <= previous { throw MemoryError.invalid }
            lastTimestampBySession[sessionKey] = time
            bytes += size
            return Metadata(insertionSequence: sequence, id: id, encodedBytes: size)
        }
    }
    private func evictionCount(_ db: Database) throws -> Int {
        guard let row = try Row.fetchOne(db, sql: "SELECT CASE WHEN typeof(evictedRecordCount)='integer' THEN evictedRecordCount END AS evictedRecordCount FROM nativeObservationState WHERE profile=?", arguments: [profile]) else { return 0 }
        guard let count = Int.fromDatabaseValue(row["evictedRecordCount"]),
              (0...Self.maximumEvictedRecordCount).contains(count) else { throw MemoryError.invalid }
        return count
    }
    private static func row(_ row: Row) -> NativeObservationRow {
        NativeObservationRow(id: row["id"], sessionID: row["sessionID"], capturedAt: row["capturedAt"], payload: row["payload"])
    }
    private static func isUUID(_ value: String) -> Bool {
        guard value.count == 36, let uuid = UUID(uuidString: value) else { return false }
        return uuid.uuidString.caseInsensitiveCompare(value) == .orderedSame
    }
    private static func validate(_ row: NativeObservationRow) throws {
        guard isUUID(row.id), isUUID(row.sessionID), row.capturedAt.isFinite, row.capturedAt >= 0,
        (1...maximumPayloadBytes).contains(row.payload.count) else { throw MemoryError.invalid }
    }
}
