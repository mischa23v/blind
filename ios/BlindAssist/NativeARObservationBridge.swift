import ARKit
import BlindCore
import BlindMemory
import Foundation

/// Optional historical geometry consumer of the existing feed. Does not own the camera,
/// invoke models, modify RTAB-Map, authorize routes or expose raw coordinates to language models.
final class NativeARObservationBridge {
    private let pipeline = NativeObservationPipeline()
    private let recordedRoute = RecordedRouteStore()
    // Explicit local diagnostic controls; camera start never opts into test recording.
    @discardableResult func startNavigationTestRecording() -> Bool { recordedRoute.startTestRecording() }
    func stopNavigationTestRecording() { recordedRoute.stopTestRecording() }
    func deleteNavigationTestRecording(completion: @escaping (Bool) -> Void = { _ in }) { recordedRoute.deleteTestRecording(completion: completion) }
    func retryNavigationTestSave() { recordedRoute.retryTestSave() }
    @discardableResult func closeNavigationTestRecording() -> Bool { recordedRoute.closeTestRecording() }
    func listSavedNavigationTests(_ completion: @escaping ([NavigationTestSessionState]?) -> Void) { recordedRoute.listSavedTestRecordings(completion) }
    func reopenNavigationTest(id: String, completion: @escaping (Bool) -> Void) { recordedRoute.reopenTestRecording(id: id, completion: completion) }
    func deleteSavedNavigationTest(id: String, completion: @escaping (Bool) -> Void) { recordedRoute.deleteSavedTestRecording(id: id, completion: completion) }
    func navigationTestSnapshot() -> RecordedRouteStore.TestSnapshot { recordedRoute.testRecordingSnapshot() }
    @discardableResult func markNavigationTestProblem(_ problem: NavigationTestRecording.Problem) -> Bool {
        recordedRoute.markTestProblem(problem)
    }
    @discardableResult func recordOwnedNavigationTestPlan(_ route: NavigationTestRecording.OwnedRoute?) -> Bool {
        recordedRoute.recordOwnedTestPlan(route)
    }
    @discardableResult func recordNavigationTestPlan(_ plan: NavigationTestRecording.Plan) -> Bool {
        recordedRoute.setTestPlan(plan)
    }
    func trackingLost() { recordedRoute.breakContinuity() }
    func readRecordedRoute(referenceKind: RecordedRouteAnchor.Kind? = nil, _ completion: @escaping (RecordedRouteStore.Snapshot) -> Void) {
        recordedRoute.preview(referenceKind: referenceKind, completion)
    }
    func readRecordedRoutePage(cursor: RecordedRouteCursor, reference: String?, completion: @escaping (RecordedRouteStore.Snapshot) -> Void) {
        recordedRoute.page(cursor: cursor, reference: reference, completion: completion)
    }
    func pinRecordedReference(kind: RecordedRouteAnchor.Kind, label: String, origin: CompanionCommandOrigin, completion: @escaping (Bool) -> Void) {
        recordedRoute.pinLatest(kind: kind, label: label, origin: origin, completion: completion)
    }
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
        recordedRoute.begin(sessionID: sessionID)
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
        if case .normal = frame.camera.trackingState {} else { recordedRoute.breakContinuity() }
        recordedRoute.offer(sessionID: sessionID, at: frame.timestamp) {
            try NativeARObservationAdapter.captureRoutePose(frame, context: context)
        }
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
        recordedRoute.stop()
        pipeline.stop(); sessionID = nil; outcomeGeneration = UUID()
    }
    /// Connect to the existing private spatial/map-history deletion path; no new UI needed.
    func clearHistory(memory: MemoryStore?, completion: @escaping (Bool) -> Void) {
        stop()
        guard let memory = memory ?? self.memory else {
            recordedRoute.clear { _ in completion(false) } // Best effort trail purge; raw-store erasure remains unverified.
            return
        }
        // Fence BOTH stores synchronously. Never delay pipeline.clear until a
        // trailing main callback that may belong to an older camera session.
        var trailResult: Bool?, observationsResult: Bool?
        let finish: () -> Void = {
            if let trailResult, let observationsResult { completion(trailResult && observationsResult) }
        }
        recordedRoute.clear { result in trailResult = result; finish() }
        pipeline.clear(storage: Self.storage(memory)) { [weak self] outcome in
            DispatchQueue.main.async { [weak self] in
                self?.lastOutcome = outcome; observationsResult = outcome == .cleared; finish()
            }
        }
    }
}
