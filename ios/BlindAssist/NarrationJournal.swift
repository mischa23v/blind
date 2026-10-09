import Foundation
import BlindMemory
import BlindCore

/// All journal database calls execute on this actor, never inside the hazard callback.
actor NarrationJournal {
    private let memory: MemoryStore
    init(memory: MemoryStore) { self.memory = memory }
    func recover() throws -> [NarrationRecord] {
        try memory.recoverPendingNarrations(); return try memory.recentNarrations()
    }
    func start(id: UUID, sessionID: UUID, goalRevision: String, snapshotID: String, sourceIDs: [String], text: String, at: Date) throws -> [NarrationRecord] {
        try memory.startNarration(id: id.uuidString, sessionID: sessionID.uuidString, goalRevision: goalRevision, snapshotID: snapshotID, sourceIDs: sourceIDs, text: text, at: at)
        return try memory.recentNarrations()
    }
    func finish(id: UUID, outcome: NarrationDelivery, at: Date) throws -> [NarrationRecord] {
        try memory.finishNarration(id: id.uuidString, outcome: outcome.rawValue, at: at); return try memory.recentNarrations()
    }
    func clear() throws -> [NarrationRecord] { try memory.clearNarrations(); return [] }
}
