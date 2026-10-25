import ARKit
import BlindCore
import BlindMemory
import Foundation

/// Optional historical geometry consumer of the existing feed. Does not own the camera,
/// invoke models, modify RTAB-Map, authorize routes or expose raw coordinates to language models.
final class NativeARObservationBridge {
    private let pipeline = NativeObservationPipeline()
    private var sessionID: UUID?
    private var memory: MemoryStore?
    private(set) var lastOutcome: NativeObservationPipeline.Outcome?
    private var outcomeGeneration = UUID()
    /// Created only when the pipeline's dedicated writer invokes an operation. The
    /// separate SQLite file does not share places.memory's synchronous writer lock.
    private final class ObservationStoreOwner {
        let memory: MemoryStore
        var store: NativeObservationStore?
        init(_ memory: MemoryStore) { self.memory = memory }
        func get() throws -> NativeObservationStore {
            if let store { return store }
            let opened = try memory.makeNativeObservationStore(); store = opened; return opened
        }
    }
    private static func storage(_ memory: MemoryStore) -> NativeObservationStorage {
        let owner = ObservationStoreOwner(memory)
        return NativeObservationStorage(load: {
            let snapshot = try owner.get().load()
            let rows = try snapshot.rows.map { row in
                let entry = try NativeObservationEncodedRecord(payload: row.payload)
                guard entry.id.uuidString == row.id, entry.sessionID.uuidString == row.sessionID,
                      entry.capturedAt == row.capturedAt else { throw NativeObservationError.invalidMetadata }
                return entry
            }
            return try NativeObservationHistory(records: rows, evictedRecordCount: snapshot.evictedRecordCount)
        }, append: { records in
            let result = try owner.get().append(records.map {
                NativeObservationRow(id: $0.id.uuidString, sessionID: $0.sessionID.uuidString,
                    capturedAt: $0.capturedAt, payload: $0.payload)
            })
            let ids = result.retainedIDs.compactMap(UUID.init(uuidString:))
            guard ids.count == result.retainedIDs.count else { throw NativeObservationError.invalidArchive }
            return NativeObservationStorage.Commit(retainedIDs: Set(ids), evictedRecordCount: result.evictedRecordCount,
                insertedRecordCount: result.insertedRecordCount, insertedPayloadBytes: result.insertedPayloadBytes)
        }, delete: { try owner.get().clear() })
    }
    var observationStatistics: NativeObservationPipeline.Statistics { pipeline.statistics() }
    @discardableResult func readHistoricalSnapshot(_ completion: @escaping (NativeObservationSnapshot) -> Void) -> Bool {
        pipeline.readSnapshot(completion)
    }
    // These control/offer methods are called by NavigationModel's existing main-actor owner.
    func begin(sessionID: UUID, memory: MemoryStore?) {
        stop(); guard let memory else { return }
        self.sessionID = sessionID; self.memory = memory
        let generation = outcomeGeneration
        pipeline.begin(sessionID: sessionID, storage: Self.storage(memory)) { [weak self] outcome in
            DispatchQueue.main.async { [weak self] in
                guard self?.outcomeGeneration == generation else { return }; self?.lastOutcome = outcome
            }
        }
    }
    func offer(_ frame: ARFrame, sessionID: UUID, mapTarget: SpatialMapBinding? = nil,
               receivedAt: Double, receivedDate: Date) {
        guard self.sessionID == sessionID else { return }
        let context = NativeARObservationAdapter.Context(sessionID: sessionID,
            frameID: "arkit-session:\(sessionID.uuidString)", mapTarget: mapTarget,
            receivedAt: receivedAt, receivedDate: receivedDate)
        let generation = outcomeGeneration
        pipeline.offer(sessionID: sessionID, capturedAt: frame.timestamp, extract: {
            try NativeARObservationAdapter.capture(frame, context: context)
        }) { [weak self] outcome in
            DispatchQueue.main.async { [weak self] in
                guard self?.outcomeGeneration == generation else { return }; self?.lastOutcome = outcome
            }
        }
    }
    func stop() {
        pipeline.stop(); sessionID = nil; outcomeGeneration = UUID()
    }
    /// Connect to the existing private spatial/map-history deletion path; no new UI needed.
    func clearHistory(memory: MemoryStore?, completion: @escaping (Bool) -> Void) {
        stop()
        guard let memory = memory ?? self.memory else { completion(false); return }
        pipeline.clear(storage: Self.storage(memory)) { [weak self] outcome in
            DispatchQueue.main.async { [weak self] in self?.lastOutcome = outcome; completion(outcome == .cleared) }
        }
    }
}
