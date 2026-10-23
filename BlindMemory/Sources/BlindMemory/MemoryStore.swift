import Foundation
import GRDB

public enum MemoryError: Error { case conflict, missing, invalid, decided }
public struct RoomRevision: Sendable {
    public let id: String
    public let payload: Data
    public let source: String
    public let created: Date
}
public struct RoomProposal: Sendable {
    public let id: String
    public let room: String
    public let baseRevision: String
    public let payload: Data
}
public struct NarrationRecord: Sendable, Identifiable {
    public let id: String
    public let sessionID: String
    public let goalRevision: String
    public let snapshotID: String
    public let sourceIDs: [String]
    public let text: String
    public let outcome: String
    public let created: Date
}

/// Small adapter around GRDB transactions/migrations. No live pose is persisted.
/// AI callers can draft text; only the app's explicit review action calls approve.
public final class MemoryStore: Sendable {
    private let database: DatabaseQueue
    private let profile: String
    static func sql(_ name: String) throws -> String {
        guard let url = Bundle.module.url(forResource: name, withExtension: "sql") else { throw MemoryError.missing }
        return try String(contentsOf: url, encoding: .utf8)
    }
    public init(path: String, profile: String = "local") throws {
        guard !profile.isEmpty, profile.count <= 100 else { throw MemoryError.invalid }
        self.profile = profile
        var configuration = Configuration()
        configuration.foreignKeysEnabled = true
        database = try DatabaseQueue(path: path, configuration: configuration)
        var migrator = DatabaseMigrator()
        migrator.registerMigration("assistant-memory-v1") { db in try db.execute(sql: Self.sql("schema")) }
        migrator.registerMigration("assistant-memory-v2-deletion") { db in try db.execute(sql: Self.sql("deletion")) }
        migrator.registerMigration("assistant-memory-v3-narration") { db in try db.execute(sql: Self.sql("narration")) }
        migrator.registerMigration("assistant-memory-v4-private-values") { db in try db.execute(sql: Self.sql("private_values")) }
        try migrator.migrate(database)
    }
    private static func revision(_ row: Row) -> RoomRevision {
        RoomRevision(id: row["id"], payload: row["payload"], source: row["source"],
                     created: Date(timeIntervalSince1970: row["created"]))
    }
    public func current(room: String) throws -> RoomRevision? {
        try database.read { db in
            try Row.fetchOne(db, sql: "SELECT v.* FROM room r JOIN roomRevision v ON v.profile=r.profile AND v.room=r.id AND v.id=r.currentRevision WHERE r.profile=? AND r.id=?", arguments: [profile, room]).map(Self.revision)
        }
    }
    /// Imports an existing scan once, leaving its original files intact.
    public func importRoom(room: String, payload: Data, source: String = "legacy") throws -> RoomRevision {
        guard ["legacy", "scan"].contains(source), !room.isEmpty else { throw MemoryError.invalid }
        return try database.write { db in
            guard try !Self.isDeleted(db, profile: profile, room: room) else { throw MemoryError.missing }
            if let row = try Row.fetchOne(db, sql: "SELECT v.* FROM room r JOIN roomRevision v ON v.profile=r.profile AND v.room=r.id AND v.id=r.currentRevision WHERE r.profile=? AND r.id=?", arguments: [profile, room]) { return Self.revision(row) }
            let id = UUID().uuidString, now = Date().timeIntervalSince1970
            try db.execute(sql: "INSERT INTO room(profile,id) VALUES (?,?)", arguments: [profile, room])
            try db.execute(sql: Self.sql("insert_revision"), arguments: ["profile": profile, "room": room, "next": id, "base": nil, "payload": payload, "source": source, "created": now])
            try db.execute(sql: "UPDATE room SET currentRevision=? WHERE profile=? AND id=?", arguments: [id, profile, room])
            return RoomRevision(id: id, payload: payload, source: source, created: Date(timeIntervalSince1970: now))
        }
    }
    public func propose(room: String, baseRevision: String, payload: Data, source: String) throws -> RoomProposal {
        guard ["user", "ai_reviewed", "restore"].contains(source) else { throw MemoryError.invalid }
        return try database.write { db in
            let current = try String.fetchOne(db, sql: "SELECT currentRevision FROM room WHERE profile=? AND id=?", arguments: [profile, room])
            guard current == baseRevision else { throw MemoryError.conflict }
            let id = UUID().uuidString
            try db.execute(sql: "INSERT INTO roomProposal(profile,room,id,baseRevision,payload,source,created) VALUES (?,?,?,?,?,?,?)", arguments: [profile, room, id, baseRevision, payload, source, Date().timeIntervalSince1970])
            return RoomProposal(id: id, room: room, baseRevision: baseRevision, payload: payload)
        }
    }
    /// Payload is loaded from the stored proposal, never supplied by approval text.
    public func approve(room: String, proposalID: String) throws -> RoomRevision {
        try database.write { db in
            guard let p = try Row.fetchOne(db, sql: "SELECT * FROM roomProposal WHERE profile=? AND room=? AND id=?", arguments: [profile, room, proposalID]) else { throw MemoryError.missing }
            let status: String = p["status"], base: String = p["baseRevision"]
            guard status == "pending" else { throw MemoryError.decided }
            let current = try String.fetchOne(db, sql: "SELECT currentRevision FROM room WHERE profile=? AND id=?", arguments: [profile, room])
            guard current == base else { throw MemoryError.conflict }
            let id = UUID().uuidString, now = Date().timeIntervalSince1970
            let payload: Data = p["payload"], source: String = p["source"]
            try db.execute(sql: Self.sql("insert_revision"), arguments: ["profile": profile, "room": room, "next": id, "base": base, "payload": payload, "source": source, "created": now])
            try db.execute(sql: Self.sql("advance_room"), arguments: ["profile": profile, "room": room, "next": id, "base": base])
            guard db.changesCount == 1 else { throw MemoryError.conflict }
            try db.execute(sql: "UPDATE roomProposal SET status='approved' WHERE profile=? AND room=? AND id=? AND status='pending'", arguments: [profile, room, proposalID])
            return RoomRevision(id: id, payload: payload, source: source, created: Date(timeIntervalSince1970: now))
        }
    }
    public func reject(room: String, proposalID: String) throws {
        try database.write { db in
            try db.execute(sql: "UPDATE roomProposal SET status='rejected' WHERE profile=? AND room=? AND id=? AND status='pending'", arguments: [profile, room, proposalID])
            guard db.changesCount == 1 else { throw MemoryError.decided }
        }
    }
    public func history(room: String) throws -> [RoomRevision] {
        try database.read { db in try Row.fetchAll(db, sql: "SELECT * FROM roomRevision WHERE profile=? AND room=? ORDER BY created DESC, rowid DESC", arguments: [profile, room]).map(Self.revision) }
    }
    public func deleteRoom(_ room: String) throws {
        try database.write { db in
            // Retain only the opaque ID: failed filesystem cleanup must not resurrect a deleted scan.
            try db.execute(sql: "INSERT OR IGNORE INTO deletedRoom(profile,id) VALUES (?,?)", arguments: [profile, room])
            // Remove the head before cascading immutable revisions/proposals.
            try db.execute(sql: "UPDATE room SET currentRevision=NULL WHERE profile=? AND id=?", arguments: [profile, room])
            try db.execute(sql: "DELETE FROM room WHERE profile=? AND id=?", arguments: [profile, room])
        }
    }
    private static func isDeleted(_ db: Database, profile: String, room: String) throws -> Bool {
        try Bool.fetchOne(db, sql: "SELECT EXISTS(SELECT 1 FROM deletedRoom WHERE profile=? AND id=?)", arguments: [profile, room]) ?? false
    }
    public func isDeleted(room: String) throws -> Bool {
        try database.read { db in try Self.isDeleted(db, profile: profile, room: room) }
    }
    public func deletedRooms() throws -> [String] {
        try database.read { db in try String.fetchAll(db, sql: "SELECT id FROM deletedRoom WHERE profile=?", arguments: [profile]) }
    }
    /// Encoded payload budgets, not permission to persist live location or camera streams.
    /// Room recall keeps at most 16 320px thumbnails plus 16 scene and 16 object prints.
    /// 8 MiB budgets 16 RGB-sized thumbnails, 32 x 32 KiB archived prints, base64
    /// expansion and metadata. It is a ceiling, not a guarantee about Vision archive sizes.
    /// Item appearance has six prints and text marks, without thumbnails: 1 MiB.
    /// Other namespaces retain the original 64,000-byte budget. Oversize writes throw
    /// and preserve the previous value; callers must surface failure, not claim success.
    public static func maximumPayloadBytes(namespace: String) throws -> Int {
        switch namespace {
        case "room-recall": return 8 * 1024 * 1024
        case "item-appearance": return 1024 * 1024
        case "observed-objects": return 256 * 1024
        case "preferences", "objective", "dialogue", "people", "places", "companion", "items": return 64_000
        default: throw MemoryError.invalid
        }
    }
    private static func validateValueKey(namespace: String, id: String) throws {
        _ = try maximumPayloadBytes(namespace: namespace)
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, id.count <= 100 else { throw MemoryError.invalid }
    }
    public func saveValue(namespace: String, id: String, payload: Data) throws {
        try Self.validateValueKey(namespace: namespace, id: id)
        guard (1...(try Self.maximumPayloadBytes(namespace: namespace))).contains(payload.count) else { throw MemoryError.invalid }
        try database.write { db in try db.execute(sql: "INSERT INTO memoryValue(profile,namespace,id,payload,updated) VALUES (?,?,?,?,?) ON CONFLICT(profile,namespace,id) DO UPDATE SET payload=excluded.payload, updated=excluded.updated", arguments: [profile, namespace, id, payload, Date().timeIntervalSince1970]) }
    }
    public func value(namespace: String, id: String) throws -> Data? {
        try Self.validateValueKey(namespace: namespace, id: id)
        return try database.read { db in try Data.fetchOne(db, sql: "SELECT payload FROM memoryValue WHERE profile=? AND namespace=? AND id=?", arguments: [profile, namespace, id]) }
    }
    /// Idempotent and profile-scoped. Throws on failure; never replaces deletion with an empty record.
    public func deleteValue(namespace: String, id: String) throws {
        try Self.validateValueKey(namespace: namespace, id: id)
        try database.write { db in try db.execute(sql: "DELETE FROM memoryValue WHERE profile=? AND namespace=? AND id=?", arguments: [profile, namespace, id]) }
    }
    public func startNarration(id: String, sessionID: String, goalRevision: String, snapshotID: String, sourceIDs: [String] = [], text: String, at: Date) throws {
        guard [id, sessionID, goalRevision, snapshotID].allSatisfy({ !$0.isEmpty && $0.count <= 64 }),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.unicodeScalars.count <= 2000,
              at.timeIntervalSince1970.isFinite, sourceIDs.count <= 64,
              sourceIDs.allSatisfy({ !$0.isEmpty && $0.count <= 64 }) else { throw MemoryError.invalid }
        let sources = try JSONEncoder().encode(sourceIDs)
        // Match the table CHECK so oversized multibyte ID lists surface as MemoryError.invalid.
        guard sources.count <= 8192 else { throw MemoryError.invalid }
        try database.write { db in
            try db.execute(sql: "INSERT INTO narrationReceipt(profile,id,sessionID,goalRevision,snapshotID,sourceIDs,text,outcome,created) VALUES (?,?,?,?,?,?,?,'pending',?)",
                           arguments: [profile, id, sessionID, goalRevision, snapshotID, sources, text, at.timeIntervalSince1970])
            // Bounded history; current/newest entries survive, independent of wall-clock rollback.
            try db.execute(sql: "DELETE FROM narrationReceipt WHERE profile=? AND rowid NOT IN (SELECT rowid FROM narrationReceipt WHERE profile=? ORDER BY rowid DESC LIMIT 20)", arguments: [profile, profile])
        }
    }
    public func finishNarration(id: String, outcome: String, at: Date) throws {
        guard ["completed", "interrupted", "unknown"].contains(outcome), at.timeIntervalSince1970.isFinite else { throw MemoryError.invalid }
        try database.write { db in
            // A delayed callback cannot overwrite a terminal state or recreate deleted history.
            try db.execute(sql: "UPDATE narrationReceipt SET outcome=?, finished=? WHERE profile=? AND id=? AND outcome='pending'", arguments: [outcome, at.timeIntervalSince1970, profile, id])
        }
    }
    public func recoverPendingNarrations() throws {
        try database.write { db in try db.execute(sql: "UPDATE narrationReceipt SET outcome='unknown' WHERE profile=? AND outcome='pending'", arguments: [profile]) }
    }
    public func recentNarrations() throws -> [NarrationRecord] {
        try database.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM narrationReceipt WHERE profile=? ORDER BY rowid DESC LIMIT 20", arguments: [profile]).map {
                NarrationRecord(id: $0["id"], sessionID: $0["sessionID"], goalRevision: $0["goalRevision"], snapshotID: $0["snapshotID"], sourceIDs: try JSONDecoder().decode([String].self, from: $0["sourceIDs"]), text: $0["text"], outcome: $0["outcome"], created: Date(timeIntervalSince1970: $0["created"]))
            }
        }
    }
    public func clearNarrations() throws {
        try database.write { db in try db.execute(sql: "DELETE FROM narrationReceipt WHERE profile=?", arguments: [profile]) }
    }
}
