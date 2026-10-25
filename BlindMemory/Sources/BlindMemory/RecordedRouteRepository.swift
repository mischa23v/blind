import Foundation
import GRDB

public enum RecordedRouteRepositoryError: Error, Equatable { case invalid, staleCursor, conflict, missingSample, anchorLimit, quota }
public struct RecordedRouteRow: Sendable, Equatable {
    public let id, sessionID, sourceFrameID: String
    public let capturedAt: Double
    public let payload: Data
    public init(id: String, sessionID: String, sourceFrameID: String, capturedAt: Double, payload: Data) {
        self.id = id; self.sessionID = sessionID; self.sourceFrameID = sourceFrameID; self.capturedAt = capturedAt; self.payload = payload
    }
}
public struct RecordedRouteAnchor: Sendable, Equatable {
    public enum Kind: String, Sendable { case start, entrance, meetingPoint }
    public let id: String
    public let sequence: Int64
    public let kind: Kind
    public let label: String
}
public struct RecordedTripState: Sendable, Equatable {
    public let id, epoch: String
    public let nextSequence: Int64
    public let retainedBytes, retainedCount, evictedCount: Int64
    public let anchors: [RecordedRouteAnchor]
    public let legacyImportFinished: Bool
}
public struct RecordedRouteStoredSample: Sendable, Equatable {
    public let sequence: Int64
    public let row: RecordedRouteRow
}
/// Cursor is tied to the trip and erase generation. `before` is an exclusive sequence.
/// New appends do not change an existing return's captured upper bound.
public struct RecordedRouteCursor: Sendable, Equatable {
    public let tripID, epoch: String
    public let before: Int64
    public let referenceID: String?
    public let encounteredGap: Bool
    public init(tripID: String, epoch: String, before: Int64, referenceID: String? = nil, encounteredGap: Bool = false) {
        self.tripID = tripID; self.epoch = epoch; self.before = before; self.referenceID = referenceID; self.encounteredGap = encounteredGap
    }
}
public struct RecordedRoutePage: Sendable, Equatable {
    public let samples: [RecordedRouteStoredSample]
    public let next: RecordedRouteCursor?
    /// Missing sequence intervals, newest bound first; never filled with invented geometry.
    public let missingRanges: [ClosedRange<Int64>]
    public let reachedReference: Bool
    public let hasMissingHistory: Bool
}
public struct RecordedRouteAppendReceipt: Sendable, Equatable {
    public let state: RecordedTripState
    public let insertedCount: Int
    public let insertedBytes: Int
    public let evictedCount: Int
}

/// Small GRDB repository: bounded INSERTs, indexed keyset pages, pinned observed anchors.
/// There is ONE active trip per profile, independent of AR session/goal. Clear explicitly
/// creates a new erase epoch. No terminal 20k ring and no load-all-payload operation.
public final class RecordedRouteRepository: Sendable {
    public static let maximumSampleBytes = 4096
    public static let minimumAccountedBytes = 256
    public static let maximumEvictionCandidates = 1024
    public static let maximumBatchCount = 64
    public static let maximumPageCount = 64
    public static let maximumAnchors = 64
    public static let defaultPayloadQuota = 256 * 1024 * 1024
    private let db: DatabaseQueue
    private let profile: String
    private let quota: Int
    public convenience init(path: String, profile: String = "local", payloadQuota: Int = defaultPayloadQuota) throws {
        try self.init(path: path, profile: profile, payloadQuota: payloadQuota, configuration: Configuration())
    }
    init(path: String, profile: String = "local", payloadQuota: Int = defaultPayloadQuota, configuration: Configuration) throws {
        guard !profile.isEmpty, profile.utf8.count <= 100, payloadQuota >= 8192, payloadQuota <= Self.defaultPayloadQuota else { throw RecordedRouteRepositoryError.invalid }
        self.profile = profile; quota = payloadQuota
        var configuration = configuration; configuration.foreignKeysEnabled = true
        db = try DatabaseQueue(path: path, configuration: configuration)
        var migrator = DatabaseMigrator()
        migrator.registerMigration("private-recorded-route-v1") { database in try database.execute(sql: MemoryStore.sql("recorded_routes")) }
        try migrator.migrate(db)
        try db.write { database in
            try database.execute(sql: "INSERT OR IGNORE INTO recordedTrip(profile,id,epoch) VALUES (?,?,?)", arguments: [profile, UUID().uuidString, UUID().uuidString])
        }
        try db.read { database in
            let current = try state(database)
            guard let summary = try Row.fetchOne(database, sql: "SELECT COUNT(*) AS count,COALESCE(SUM(chargedBytes),0) AS bytes FROM recordedRouteSample WHERE profile=?", arguments: [profile]),
                  summary["count"] as Int64 == current.retainedCount, summary["bytes"] as Int64 == current.retainedBytes,
                  current.retainedBytes <= Int64(quota),
                  try Int.fetchOne(database, sql: "SELECT 1 FROM recordedRouteSample WHERE profile=? AND (typeof(payload)!='blob' OR typeof(encodedBytes)!='integer' OR encodedBytes NOT BETWEEN 1 AND 4096 OR encodedBytes!=length(payload) OR chargedBytes!=max(encodedBytes,256)) LIMIT 1", arguments: [profile]) == nil else { throw RecordedRouteRepositoryError.invalid }
        }
    }
    public func state() throws -> RecordedTripState { try db.read { try state($0) } }
    public func append(_ rows: [RecordedRouteRow], trip: RecordedTripState) throws -> RecordedRouteAppendReceipt {
        guard rows.count <= Self.maximumBatchCount else { throw RecordedRouteRepositoryError.invalid }
        try rows.forEach(Self.validate)
        return try db.write { database in
            var state = try state(database), inserted = 0, insertedBytes = 0
            guard state.id == trip.id, state.epoch == trip.epoch else { throw RecordedRouteRepositoryError.staleCursor }
            for row in rows {
                if let metadata = try Row.fetchOne(database, sql: "SELECT CASE WHEN typeof(sequence)='integer' THEN sequence END AS sequence,CASE WHEN typeof(encodedBytes)='integer' THEN encodedBytes END AS encodedBytes,CASE WHEN typeof(chargedBytes)='integer' THEN chargedBytes END AS chargedBytes,length(payload) AS actualBytes FROM recordedRouteSample WHERE profile=? AND id=?", arguments: [profile, row.id]) {
                    try checkSize(metadata)
                    let existing = try stored(database, sequence: metadata["sequence"])
                    guard existing.row == row else { throw RecordedRouteRepositoryError.conflict }
                    continue
                }
                guard state.nextSequence < Int64.max else { throw RecordedRouteRepositoryError.quota }
                if let latest = try Row.fetchOne(database, sql: "SELECT substr(sessionID,1,37) AS sessionID,substr(sourceFrameID,1,257) AS sourceFrameID,CASE WHEN typeof(capturedAt) IN ('integer','real') THEN capturedAt END AS capturedAt FROM recordedRouteSample WHERE profile=? ORDER BY sequence DESC LIMIT 1", arguments: [profile]) {
                    guard let session = String.fromDatabaseValue(latest["sessionID"]), UUID(uuidString: session) != nil,
                          let frame = String.fromDatabaseValue(latest["sourceFrameID"]), frame.utf8.count <= 256,
                          let time = Double.fromDatabaseValue(latest["capturedAt"]), time.isFinite, time >= 0 else { throw RecordedRouteRepositoryError.invalid }
                    if session == row.sessionID && frame == row.sourceFrameID {
                        guard row.capturedAt > time else { throw RecordedRouteRepositoryError.invalid }
                    }
                }
                try database.execute(sql: "INSERT INTO recordedRouteSample(profile,sequence,id,sessionID,sourceFrameID,capturedAt,payload,encodedBytes,chargedBytes) VALUES (?,?,?,?,?,?,?,?,?)", arguments: [profile, state.nextSequence, row.id, row.sessionID, row.sourceFrameID, row.capturedAt, row.payload, row.payload.count,max(row.payload.count,Self.minimumAccountedBytes)])
                if state.nextSequence == 0 {
                    try database.execute(sql: "INSERT INTO recordedRouteAnchor(profile,id,sequence,kind,label) VALUES (?,?,0,'start','')", arguments: [profile, UUID().uuidString])
                }
                try database.execute(sql: "UPDATE recordedTrip SET nextSequence=nextSequence+1,retainedCount=retainedCount+1,retainedBytes=retainedBytes+? WHERE profile=?", arguments: [max(row.payload.count,Self.minimumAccountedBytes), profile])
                inserted += 1; insertedBytes += row.payload.count
                state = try self.state(database)
            }
            // A minimum accounted record cost bounds metadata and eviction work even
            // for a malicious 1-byte payload. At most 1,024 candidates per transaction.
            var evicted = 0
            if state.retainedBytes > Int64(quota) {
                let candidates = try Row.fetchAll(database, sql: """
                    SELECT CASE WHEN typeof(s.sequence)='integer' THEN s.sequence END AS sequence,CASE WHEN typeof(s.encodedBytes)='integer' THEN s.encodedBytes END AS encodedBytes,CASE WHEN typeof(s.chargedBytes)='integer' THEN s.chargedBytes END AS chargedBytes,length(s.payload) AS actualBytes FROM recordedRouteSample s
                    WHERE s.profile=? AND NOT EXISTS (SELECT 1 FROM recordedRouteAnchor a WHERE a.profile=s.profile AND a.sequence=s.sequence)
                    ORDER BY s.sequence LIMIT 1024
                    """, arguments: [profile])
                var freed: Int64 = 0, through: Int64?
                for candidate in candidates {
                    try checkSize(candidate)
                    freed += candidate["chargedBytes"] as Int64; through = candidate["sequence"]; evicted += 1
                    if state.retainedBytes - freed <= Int64(quota) { break }
                }
                guard let through, state.retainedBytes - freed <= Int64(quota) else { throw RecordedRouteRepositoryError.quota }
                try database.execute(sql: "DELETE FROM recordedRouteSample WHERE profile=? AND sequence<=? AND NOT EXISTS (SELECT 1 FROM recordedRouteAnchor a WHERE a.profile=recordedRouteSample.profile AND a.sequence=recordedRouteSample.sequence)", arguments: [profile,through])
                try database.execute(sql: "UPDATE recordedTrip SET retainedBytes=retainedBytes-?,retainedCount=retainedCount-?,evictedCount=evictedCount+? WHERE profile=?", arguments: [freed,evicted,evicted,profile])
                state = try self.state(database)
            }
            return .init(state: state, insertedCount: inserted, insertedBytes: insertedBytes, evictedCount: evicted)
        }
    }
    public func pin(sequence: Int64, trip: RecordedTripState, kind: RecordedRouteAnchor.Kind, label: String) throws -> RecordedRouteAnchor {
        guard sequence >= 0, kind != .start, label.utf8.count <= 160,
              !label.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else { throw RecordedRouteRepositoryError.invalid }
        return try db.write { database in
            let current = try state(database)
            guard current.id == trip.id, current.epoch == trip.epoch else { throw RecordedRouteRepositoryError.staleCursor }
            if let same = current.anchors.first(where: { $0.sequence == sequence && $0.kind == kind && $0.label == label }) { return same }
            guard current.anchors.count < Self.maximumAnchors else { throw RecordedRouteRepositoryError.anchorLimit }
            guard try Int.fetchOne(database, sql: "SELECT 1 FROM recordedRouteSample WHERE profile=? AND sequence=?", arguments: [profile, sequence]) != nil else { throw RecordedRouteRepositoryError.missingSample }
            let pinnedBytes = try Int.fetchOne(database, sql: "SELECT COALESCE(SUM(chargedBytes),0) FROM recordedRouteSample s WHERE s.profile=? AND (s.sequence=? OR EXISTS (SELECT 1 FROM recordedRouteAnchor a WHERE a.profile=s.profile AND a.sequence=s.sequence))", arguments: [profile,sequence]) ?? 0
            guard pinnedBytes <= quota - Self.maximumSampleBytes else { throw RecordedRouteRepositoryError.quota }
            let id = UUID().uuidString
            try database.execute(sql: "INSERT INTO recordedRouteAnchor(profile,id,sequence,kind,label) VALUES (?,?,?,?,?)", arguments: [profile,id,sequence,kind.rawValue,label])
            return .init(id: id, sequence: sequence, kind: kind, label: label)
        }
    }
    public func reversePage(cursor: RecordedRouteCursor? = nil, returningTo anchorID: String? = nil, limit: Int = 64) throws -> RecordedRoutePage {
        guard (1...Self.maximumPageCount).contains(limit) else { throw RecordedRouteRepositoryError.invalid }
        return try db.read { database in
            let current = try state(database)
            let reference: Int64
            let selectedReference = anchorID ?? cursor?.referenceID
            if let cursor, let anchorID, cursor.referenceID != anchorID { throw RecordedRouteRepositoryError.staleCursor }
            if let anchorID = selectedReference {
                guard let anchor = current.anchors.first(where: { $0.id == anchorID }) else { throw RecordedRouteRepositoryError.missingSample }; reference = anchor.sequence
            } else { reference = 0 }
            let before = cursor?.before ?? current.nextSequence
            guard cursor.map({ $0.tripID == current.id && $0.epoch == current.epoch }) ?? true,
                  before >= reference, before <= current.nextSequence else { throw RecordedRouteRepositoryError.staleCursor }
            let metadata = try Row.fetchAll(database, sql: "SELECT CASE WHEN typeof(sequence)='integer' THEN sequence END AS sequence,CASE WHEN typeof(encodedBytes)='integer' THEN encodedBytes END AS encodedBytes,CASE WHEN typeof(chargedBytes)='integer' THEN chargedBytes END AS chargedBytes,length(payload) AS actualBytes FROM recordedRouteSample WHERE profile=? AND sequence<? AND sequence>=? ORDER BY sequence DESC LIMIT ?", arguments: [profile,before,reference,limit])
            try metadata.forEach(checkSize)
            var samples: [RecordedRouteStoredSample] = [], gaps: [ClosedRange<Int64>] = [], expected = before - 1
            for entry in metadata {
                let sequence: Int64 = entry["sequence"]
                if expected > sequence { gaps.append((sequence + 1)...expected) }
                samples.append(try stored(database, sequence: sequence)); expected = sequence - 1
            }
            let reached = samples.last?.sequence == reference || (before == 0 && current.nextSequence == 0)
            if samples.isEmpty, expected >= reference { gaps.append(reference...expected) }
            let hasGap = (cursor?.encounteredGap ?? false) || !gaps.isEmpty
            let next = reached || samples.isEmpty ? nil : RecordedRouteCursor(tripID: current.id, epoch: current.epoch,
                before: samples.last!.sequence, referenceID: selectedReference, encounteredGap: hasGap)
            return .init(samples: samples, next: next, missingRanges: gaps, reachedReference: reached, hasMissingHistory: hasGap)
        }
    }
    public func sequence(observationID: String, trip: RecordedTripState) throws -> Int64? {
        try db.read { database in
            let current = try state(database)
            guard current.id == trip.id, current.epoch == trip.epoch else { throw RecordedRouteRepositoryError.staleCursor }
            return try Int64.fetchOne(database, sql: "SELECT CASE WHEN typeof(sequence)='integer' THEN sequence END FROM recordedRouteSample WHERE profile=? AND id=?", arguments: [profile,observationID])
        }
    }
    /// Only for bounded legacy import, before active capture. An interrupted import
    /// can resume with the same immutable IDs; a different trip cannot be overwritten.
    public func adoptLegacyTrip(_ id: String) throws -> RecordedTripState {
        guard UUID(uuidString: id) != nil, quota >= 20_000_000 else { throw RecordedRouteRepositoryError.invalid }
        return try db.write { database in
            let current = try state(database)
            guard !current.legacyImportFinished, current.nextSequence == 0 || current.id == id else { throw RecordedRouteRepositoryError.conflict }
            try database.execute(sql: "UPDATE recordedTrip SET id=? WHERE profile=?", arguments: [id,profile])
            return try state(database)
        }
    }
    public func finishLegacyImport(trip: RecordedTripState) throws {
        try db.write { database in
            let current = try state(database)
            guard current.id == trip.id, current.epoch == trip.epoch else { throw RecordedRouteRepositoryError.staleCursor }
            try database.execute(sql: "UPDATE recordedTrip SET legacyImportFinished=1 WHERE profile=?", arguments: [profile])
        }
    }
    public func clear(trip: RecordedTripState) throws {
        try db.write { database in
            let current = try state(database)
            guard current.id == trip.id, current.epoch == trip.epoch else { throw RecordedRouteRepositoryError.staleCursor }
            try database.execute(sql: "DELETE FROM recordedRouteAnchor WHERE profile=?", arguments: [profile])
            try database.execute(sql: "DELETE FROM recordedTrip WHERE profile=?", arguments: [profile])
            try database.execute(sql: "INSERT INTO recordedTrip(profile,id,epoch,legacyImportFinished) VALUES (?,?,?,1)", arguments: [profile,UUID().uuidString,UUID().uuidString])
        }
    }
    private func state(_ database: Database) throws -> RecordedTripState {
        guard let row = try Row.fetchOne(database, sql: "SELECT substr(id,1,37) AS id,substr(epoch,1,37) AS epoch,CASE WHEN typeof(nextSequence)='integer' THEN nextSequence END AS nextSequence,CASE WHEN typeof(retainedBytes)='integer' THEN retainedBytes END AS retainedBytes,CASE WHEN typeof(retainedCount)='integer' THEN retainedCount END AS retainedCount,CASE WHEN typeof(evictedCount)='integer' THEN evictedCount END AS evictedCount,CASE WHEN typeof(legacyImportFinished)='integer' THEN legacyImportFinished END AS legacyImportFinished FROM recordedTrip WHERE profile=?", arguments: [profile]),
              let id = String.fromDatabaseValue(row["id"]), UUID(uuidString: id) != nil,
              let epoch = String.fromDatabaseValue(row["epoch"]), UUID(uuidString: epoch) != nil,
              let next = Int64.fromDatabaseValue(row["nextSequence"]), next >= 0,
              let bytes = Int64.fromDatabaseValue(row["retainedBytes"]), bytes >= 0,
              let count = Int64.fromDatabaseValue(row["retainedCount"]), count >= 0,
              let evicted = Int64.fromDatabaseValue(row["evictedCount"]), evicted >= 0,
              count <= next, evicted == next - count,
              let legacy = Int.fromDatabaseValue(row["legacyImportFinished"]), (0...1).contains(legacy) else { throw RecordedRouteRepositoryError.invalid }
        let anchors = try Row.fetchAll(database, sql: "SELECT substr(id,1,37) AS id,CASE WHEN typeof(sequence)='integer' THEN sequence END AS sequence,substr(kind,1,13) AS kind,substr(label,1,161) AS label FROM recordedRouteAnchor WHERE profile=? ORDER BY sequence LIMIT 65", arguments: [profile])
        guard anchors.count <= Self.maximumAnchors else { throw RecordedRouteRepositoryError.invalid }
        let decoded = try anchors.map { row -> RecordedRouteAnchor in
            guard let id = String.fromDatabaseValue(row["id"]), UUID(uuidString: id) != nil,
                  let sequence = Int64.fromDatabaseValue(row["sequence"]), sequence >= 0, sequence < next,
                  let raw = String.fromDatabaseValue(row["kind"]), let kind = RecordedRouteAnchor.Kind(rawValue: raw),
                  let label = String.fromDatabaseValue(row["label"]), label.utf8.count <= 160 else { throw RecordedRouteRepositoryError.invalid }
            return .init(id: id, sequence: sequence, kind: kind, label: label)
        }
        return .init(id: id, epoch: epoch, nextSequence: next, retainedBytes: bytes, retainedCount: count, evictedCount: evicted, anchors: decoded, legacyImportFinished: legacy == 1)
    }
    private func checkSize(_ row: Row) throws {
        guard let sequence = Int64.fromDatabaseValue(row["sequence"]), sequence >= 0,
              let bytes = Int.fromDatabaseValue(row["encodedBytes"]), (1...Self.maximumSampleBytes).contains(bytes),
              let actual = Int.fromDatabaseValue(row["actualBytes"]), bytes == actual,
              let charged = Int.fromDatabaseValue(row["chargedBytes"]), charged == max(bytes,Self.minimumAccountedBytes) else { throw RecordedRouteRepositoryError.invalid }
    }
    private func stored(_ database: Database, sequence: Int64) throws -> RecordedRouteStoredSample {
        guard let row = try Row.fetchOne(database, sql: "SELECT CASE WHEN length(id)=36 THEN id END AS id,CASE WHEN length(sessionID)=36 THEN sessionID END AS sessionID,CASE WHEN length(sourceFrameID)<=256 THEN sourceFrameID END AS sourceFrameID,CASE WHEN typeof(capturedAt) IN ('integer','real') THEN capturedAt END AS capturedAt,payload FROM recordedRouteSample WHERE profile=? AND sequence=?", arguments: [profile,sequence]),
              let id = String.fromDatabaseValue(row["id"]), let session = String.fromDatabaseValue(row["sessionID"]),
              let frame = String.fromDatabaseValue(row["sourceFrameID"]), let time = Double.fromDatabaseValue(row["capturedAt"]),
              let payload = Data.fromDatabaseValue(row["payload"]) else { throw RecordedRouteRepositoryError.invalid }
        let value = RecordedRouteRow(id: id, sessionID: session, sourceFrameID: frame, capturedAt: time, payload: payload)
        try Self.validate(value); return .init(sequence: sequence, row: value)
    }
    private static func validate(_ row: RecordedRouteRow) throws {
        guard UUID(uuidString: row.id) != nil, UUID(uuidString: row.sessionID) != nil,
              !row.sourceFrameID.isEmpty, row.sourceFrameID.utf8.count <= 256,
              row.capturedAt.isFinite, row.capturedAt >= 0,
              (1...Self.maximumSampleBytes).contains(row.payload.count) else { throw RecordedRouteRepositoryError.invalid }
    }
}
