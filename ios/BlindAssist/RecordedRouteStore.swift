import Foundation
import BlindCore
import BlindMemory

/// Constant-memory camera-path adapter. Durable history is paginated by GRDB;
/// only one sample plus <=64 pending samples are retained in the recorder.
final class RecordedRouteStore: @unchecked Sendable {
    private let queue = DispatchQueue(label: "blind.recorded-route", qos: .utility)
    private let lock = NSLock()
    private var busy = false, readPending = false, clearPending = false, flushPending = false, anchorPending = false
    private var sessionID: UUID?, generation = UUID()
    private var lastAccepted = -Double.infinity
    private var restarted = false, trackingLost = false
    private var continuityEpoch = UUID()
    private var sampler = RecordedRouteSampler()
    // Explicit local diagnostic; memory/receipt state protected by lock. No export.
    private var testRecording: NavigationTestRecording?
    private var testOwnedRoute: NavigationTestRecording.OwnedRoute?
    private var testRejectedSamples = 0, testRejectedPlans = 0, testGapPending = false
    struct TestSnapshot {
        let recording: NavigationTestRecording?
        let rejectedSamples, rejectedPlans: Int
        let savedEvents, pendingEvents: Int
        let saving, saveFailed, deleting, erasePending: Bool
    }
    @discardableResult func startTestRecording() -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard sessionID != nil, !clearPending, !testDeleting, testRecording == nil,
              let recording = try? NavigationTestRecording(explicitStartAt: now()) else { return false }
        testRecording = recording; testOwnedRoute = nil; testRejectedSamples = 0; testRejectedPlans = 0; testGapPending = false
        testWriteGeneration = UUID(); testArchive = nil; testSaveFailed = false; testLastCommit = -.infinity; testCreatedAt = Date().timeIntervalSince1970
        scheduleTestSaveLocked(force: true); return true
    }
    func stopTestRecording() {
        lock.lock(); defer { lock.unlock() }; try? testRecording?.stop(at: now()); scheduleTestSaveLocked(force: true)
    }
    func deleteTestRecording(completion: @escaping (Bool) -> Void = { _ in }) {
        lock.lock()
        guard !testDeleting else { lock.unlock(); completion(false); return }
        let id = testRecording?.id.uuidString
        testWriteGeneration = UUID(); testRecording = nil; testOwnedRoute = nil; testArchive = nil
        testRejectedSamples = 0; testRejectedPlans = 0; testGapPending = false; testSaveFailed = false
        testDeleting = true; lock.unlock()
        queue.async {
            var success = true
            do {
                self.load()
                if let id {
                    guard !self.loadFailed, let repository = self.repository else { throw RecordedRouteRepositoryError.invalid }
                    if let state = try repository.listNavigationTests().first(where: { $0.id == id }) {
                        try repository.deleteNavigationTest(session: state)
                    }
                }
            } catch { success = false }
            self.lock.lock(); self.testDeleting = false; self.lock.unlock()
            let result = success
            DispatchQueue.main.async { completion(result) }
        }
    }
    func testRecordingSnapshot() -> TestSnapshot {
        lock.lock(); defer { lock.unlock() }
        scheduleTestSaveLocked()
        let committed = Int(testArchive?.nextSequence ?? 0)
        return .init(recording: testRecording, rejectedSamples: testRejectedSamples, rejectedPlans: testRejectedPlans,
            savedEvents: committed, pendingEvents: max(0, (testRecording?.archiveEvents.count ?? 0) - committed),
            saving: testSaveBusy, saveFailed: testSaveFailed, deleting: testDeleting, erasePending: clearPending)
    }
    @discardableResult func markTestProblem(_ problem: NavigationTestRecording.Problem) -> Bool {
        lock.lock(); defer { scheduleTestSaveLocked(force: true); lock.unlock() }
        guard testRecording != nil else { return false }
        do { try testRecording?.mark(problem, at: now()); return true } catch { return false }
    }
    /// Receipt time assigned under the same lock as samples. A cancelled owner
    /// clears comparison context; missing registration stays nil, never identity.
    @discardableResult func recordOwnedTestPlan(_ route: NavigationTestRecording.OwnedRoute?) -> Bool {
        lock.lock(); defer { scheduleTestSaveLocked(force: true); lock.unlock() }
        guard testRecording?.status == .recording else { return false }
        guard route != testOwnedRoute else { return true }
        let previous = testOwnedRoute; testOwnedRoute = route
        guard let context = route ?? previous else { return true }
        let plan = NavigationTestRecording.Plan(revision: route?.routeRevision ?? UUID(),
            goalRevision: context.goalRevision, map: context.map, points: route?.points ?? [], alignment: nil,
            recordedAt: now(), bodyRevision: context.bodyRevision, obstacleRevision: context.obstacleRevision,
            artifactSHA256: context.artifactSHA256)
        do { try testRecording?.setPlan(plan); return true }
        catch { testRejectedPlans += 1; try? testRecording?.stop(at: now()); return false }
    }
    @discardableResult func setTestPlan(_ plan: NavigationTestRecording.Plan) -> Bool {
        lock.lock(); defer { scheduleTestSaveLocked(force: true); lock.unlock() }
        guard testRecording != nil else { return false }
        do {
            guard plan.recordedAt <= now() else { throw NavigationTestRecording.Failure.invalidInput }
            try testRecording?.setPlan(plan); return true
        } catch {
            // Dropping a changed route must never keep associating later samples
            // with the preceding plan. Retain history, but end this diagnostic run.
            testRejectedPlans += 1; try? testRecording?.stop(at: now()); return false
        }
    }
    private var testArchive: NavigationTestSessionState?
    private var testWriteGeneration = UUID(), testSaveBusy = false, testSaveFailed = false
    private var testLastCommit = -Double.infinity
    private var testCreatedAt = 0.0
    private var testDeleting = false
    /// Caller holds lock. One queued bounded transaction at a time; no full-file rewrite.
    private func scheduleTestSaveLocked(force: Bool = false) {
        guard !testSaveBusy, !testSaveFailed, !testDeleting,
              let recording = testRecording, !recording.restoredHistorical else { return }
        let committed = Int(testArchive?.nextSequence ?? 0)
        guard testArchive == nil || committed < recording.archiveEvents.count else { return }
        guard force || testArchive == nil || recording.status != .recording ||
              recording.archiveEvents.count - committed >= 25 || now() - testLastCommit >= 5 else { return }
        testSaveBusy = true; let token = testWriteGeneration
        queue.async { self.persistTestBatch(token: token) }
    }
    private func persistTestBatch(token: UUID) {
        lock.lock()
        guard token == testWriteGeneration, let recording = testRecording, !recording.restoredHistorical else {
            testSaveBusy = false; scheduleTestSaveLocked(); lock.unlock(); return
        }
        let prior = testArchive, createdAt = testCreatedAt
        lock.unlock()
        do {
            load()
            guard !loadFailed, let repository, let trip else { throw RecordedRouteRepositoryError.invalid }
            var state = try prior ?? repository.createNavigationTest(id: recording.id.uuidString,
                startedAt: recording.startedAt, createdAt: createdAt, trip: trip)
            let start = Int(state.nextSequence)
            guard start <= recording.archiveEvents.count else { throw RecordedRouteRepositoryError.conflict }
            let selected = recording.archiveEvents.dropFirst(start).prefix(64)
            let rows = try selected.enumerated().map { offset, event in
                NavigationTestEventRow(sequence: Int64(start + offset), payload: try event.encoded())
            }
            var status = "recording"
            if case .ended(let terminal, _)? = selected.last { status = terminal.rawValue }
            if !rows.isEmpty { state = try repository.appendNavigationTest(rows: rows, session: state, status: status) }
            lock.lock()
            if token == testWriteGeneration {
                testArchive = state; testLastCommit = now()
            }
            testSaveBusy = false; scheduleTestSaveLocked(); lock.unlock()
        } catch {
            lock.lock()
            if token == testWriteGeneration {
                testSaveFailed = true
                try? testRecording?.stop(at: now()) // Retain ALL unsaved events for explicit retry.
            }
            testSaveBusy = false; lock.unlock()
        }
    }
    func retryTestSave() {
        lock.lock(); defer { lock.unlock() }
        guard testRecording?.restoredHistorical == false else { return }
        testSaveFailed = false; scheduleTestSaveLocked(force: true)
    }
    func listSavedTestRecordings(_ completion: @escaping ([NavigationTestSessionState]?) -> Void) {
        lock.lock(); guard !clearPending else { lock.unlock(); completion(nil); return }
        let token = testWriteGeneration; lock.unlock()
        queue.async {
            self.load()
            let rows: [NavigationTestSessionState]?
            if self.loadFailed { rows = nil } else { rows = try? self.repository?.listNavigationTests() }
            DispatchQueue.main.async {
                self.lock.lock(); let current = token == self.testWriteGeneration && !self.clearPending; self.lock.unlock()
                completion(current ? rows : nil)
            }
        }
    }
    @discardableResult func closeTestRecording() -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard let recording = testRecording, recording.status != .recording,
              !testSaveBusy, !testSaveFailed, !testDeleting,
              Int(testArchive?.nextSequence ?? -1) == recording.archiveEvents.count else { return false }
        testWriteGeneration = UUID(); testRecording = nil; testArchive = nil; testOwnedRoute = nil; return true
    }
    func deleteSavedTestRecording(id: String, completion: @escaping (Bool) -> Void) {
        lock.lock()
        guard !clearPending, !testDeleting, testRecording?.id.uuidString != id else { lock.unlock(); completion(false); return }
        if testRecording == nil { testWriteGeneration = UUID() } // Fence an in-flight historical read.
        testDeleting = true; lock.unlock()
        queue.async {
            var success = false
            do {
                self.load()
                guard !self.loadFailed, let repository = self.repository else { throw RecordedRouteRepositoryError.invalid }
                if let state = try repository.listNavigationTests().first(where: { $0.id == id }) {
                    try repository.deleteNavigationTest(session: state)
                }
                success = true
            } catch { success = false }
            self.lock.lock(); self.testDeleting = false; self.scheduleTestSaveLocked(force: true); self.lock.unlock()
            let result = success; DispatchQueue.main.async { completion(result) }
        }
    }
    func reopenTestRecording(id: String, completion: @escaping (Bool) -> Void) {
        lock.lock()
        guard !clearPending, testRecording == nil, !testDeleting, !testSaveBusy else { lock.unlock(); completion(false); return }
        testWriteGeneration = UUID(); let token = testWriteGeneration; lock.unlock()
        queue.async {
            var restored: NavigationTestRecording?, stored: NavigationTestSessionState?
            do {
                self.load()
                guard !self.loadFailed, let repository = self.repository,
                      let state = try repository.listNavigationTests().first(where: { $0.id == id }),
                      let uuid = UUID(uuidString: state.id) else { throw RecordedRouteRepositoryError.invalid }
                var events: [NavigationTestArchiveEvent] = [], after: Int64?
                while events.count < Int(state.nextSequence) {
                    let page = try repository.navigationTestEvents(session: state, after: after, limit: 64)
                    guard !page.isEmpty else { throw RecordedRouteRepositoryError.invalid }
                    for row in page {
                        guard row.sequence == Int64(events.count), events.count < 3257 else { throw RecordedRouteRepositoryError.invalid }
                        events.append(try .init(payload: row.payload)); after = row.sequence
                    }
                }
                let value = try NavigationTestRecording.restored(id: uuid, startedAt: state.startedAt, events: events)
                if state.status != "recording" {
                    guard value.status.rawValue == state.status, !value.restoredInterrupted else { throw RecordedRouteRepositoryError.invalid }
                } else { guard value.restoredInterrupted else { throw RecordedRouteRepositoryError.invalid } }
                restored = value; stored = state
            } catch { restored = nil }
            self.lock.lock()
            let current = token == self.testWriteGeneration && self.testRecording == nil && !self.testDeleting && !self.clearPending
            if current, let restored {
                self.testRecording = restored; self.testArchive = stored; self.testOwnedRoute = nil
                self.testRejectedSamples = 0; self.testRejectedPlans = 0; self.testSaveFailed = false
            }
            self.lock.unlock()
            let success = current && restored != nil
            DispatchQueue.main.async { completion(success) }
        }
    }
#if DEBUG
    /// Functional persistence fence for finite test input, not a latency assertion.
    /// Tests must release blocked capture/IO before awaiting this fence.
    func drainTestSavesForTesting(_ completion: @escaping () -> Void) {
        lock.lock(); scheduleTestSaveLocked(force: true); lock.unlock()
        queue.async { self.testSaveFence(completion) }
    }
    private func testSaveFence(_ completion: @escaping () -> Void) {
        lock.lock(); scheduleTestSaveLocked(force: true); let waiting = testSaveBusy; lock.unlock()
        if waiting { queue.async { self.testSaveFence(completion) } }
        else { DispatchQueue.main.async(execute: completion) }
    }
#endif
    private var pending: [RecordedRouteSample] = []
    private var repository: RecordedRouteRepository?
    private var trip: RecordedTripState?
    private var loaded = false, loadFailed = false, persistenceFailed = false, budgetDeferred = false
    private var lastSave = -Double.infinity
    private var droppedVolatile = 0
    private var budget: NativeObservationDurabilityBudget
    private let directory: URL, now: () -> Double
    private let factory: (String) throws -> RecordedRouteRepository
    init(url: URL? = nil, now: @escaping () -> Double = { ProcessInfo.processInfo.systemUptime },
         factory: @escaping (String) throws -> RecordedRouteRepository = { try RecordedRouteRepository(path: $0) }) {
        directory = (url ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RecordedRoutes", isDirectory: true).appendingPathComponent("routes.sqlite")).deletingLastPathComponent()
        self.now = now; self.factory = factory
        budget = .init(configuration: try! .init(bytesPerInterval: 524_288, intervalSeconds: 60, burstBytes: 131_072), now: now())
    }
    func begin(sessionID: UUID) {
        lock.lock(); try? testRecording?.stop(at: now()); scheduleTestSaveLocked(force: true); self.sessionID = sessionID; generation = UUID(); lastAccepted = -.infinity; restarted = true; continuityEpoch = UUID(); lock.unlock()
    }
    func breakContinuity() { lock.lock(); trackingLost = true; continuityEpoch = UUID(); lock.unlock() }
    func stop() {
        lock.lock(); try? testRecording?.stop(at: now()); scheduleTestSaveLocked(force: true); sessionID = nil; generation = UUID()
        guard !flushPending else { lock.unlock(); return }; flushPending = true; lock.unlock()
        queue.async {
            defer { self.lock.lock(); self.flushPending = false; self.lock.unlock() }
            self.sampler.interrupt(); self.flush()
        }
    }
    func offer(sessionID: UUID, at time: Double, sameFrameAssociation: SavedWorldFrameCameraAssociation? = nil, extract: @escaping () throws -> NativeObservationRecord) {
        lock.lock()
        guard self.sessionID == sessionID else { lock.unlock(); return }
        if time.isFinite && time < lastAccepted { trackingLost = true; continuityEpoch = UUID(); lastAccepted = -.infinity }
        guard self.sessionID == sessionID, time.isFinite, time >= 0, !busy, time-lastAccepted >= 0.2 else { lock.unlock(); return }
        busy = true; lastAccepted = time; let token = generation, evidence = continuityEpoch, diagnosticID = testRecording?.id; lock.unlock()
        queue.async {
            defer { self.lock.lock(); self.busy = false; self.lock.unlock() }
            self.lock.lock(); let current = self.generation == token; self.lock.unlock()
            guard current else { return }; self.load(); guard !self.loadFailed else { return }
            do {
                let observation = try extract()
                self.lock.lock()
                let current = self.generation == token && self.continuityEpoch == evidence, restart = self.restarted, loss = self.trackingLost
                self.lock.unlock()
                guard current, observation.sessionID == sessionID, observation.capturedAt == time else { return }
                if restart {
                    if self.trip?.nextSequence == 0 && self.pending.isEmpty { self.sampler = .init() } else { self.sampler.restart() }
                    self.lastSave = -.infinity
                }
                if loss { self.sampler.interrupt(.trackingLost) }
                let sample = try self.sampler.observe(observation)
                self.lock.lock()
                if self.generation == token && self.continuityEpoch == evidence {
                    if self.testRecording?.status == .recording, self.testRecording?.id == diagnosticID {
                        do {
                            let diagnosticSample = self.testGapPending ? sample.markingBoundary(.interrupted) : sample
                            try self.testRecording?.observe(diagnosticSample, receivedAt: self.now(), sameFrameReceipt: sameFrameAssociation)
                            self.testGapPending = false
                        } catch { self.testRejectedSamples += 1; self.testGapPending = true }
                        self.scheduleTestSaveLocked()
                    }
                    if sample.tracking == .normal { self.restarted = false; self.trackingLost = false }
                    else { self.trackingLost = true; self.continuityEpoch = UUID() }
                }
                self.lock.unlock()
                if self.pending.count == 64 {
                    // Preserve an unsaved original start; retain an explicit gap before
                    // the first surviving newer sample. No unbounded pending queue.
                    let index = self.trip?.nextSequence == 0 ? 1 : 0
                    self.pending.remove(at: index)
                    self.pending[index] = self.pending[index].markingBoundary(.durabilityLoss)
                    self.droppedVolatile += 1
                }
                self.pending.append(sample)
                if self.pending.count >= 25 || time-self.lastSave >= 5 { self.flush(); self.lastSave = time }
            } catch {
                self.lock.lock()
                let current = self.generation == token && self.continuityEpoch == evidence
                if current { self.trackingLost = true; self.continuityEpoch = UUID() }
                self.lock.unlock()
                if current { self.sampler.interrupt(.trackingLost) }
            }
        }
    }
    struct Snapshot {
        let preview: RecordedRoutePreview?
        let trip: RecordedTripState?
        let nextPage: RecordedRouteCursor?
        let persistenceFailed, loadFailed, busy, budgetDeferred: Bool
        let referenceUnavailable: Bool
        let durableSampleCount, volatileSampleCount, droppedVolatileSampleCount: Int
        var capacityReached: Bool { false } // No terminal recorder ring.
        var persistenceCapacityReached: Bool { false } // Quota retirement has explicit missing ranges instead.
    }
    private func withheld(busy: Bool) -> Snapshot {
        .init(preview: nil, trip: nil, nextPage: nil, persistenceFailed: false, loadFailed: false, busy: busy,
              budgetDeferred: false, referenceUnavailable: false, durableSampleCount: 0, volatileSampleCount: 0, droppedVolatileSampleCount: 0)
    }
    func preview(referenceKind: RecordedRouteAnchor.Kind? = nil, _ completion: @escaping (Snapshot) -> Void) { page(cursor: nil, reference: nil, referenceKind: referenceKind, completion: completion) }
    func page(cursor: RecordedRouteCursor?, reference: String?, referenceKind: RecordedRouteAnchor.Kind? = nil, completion: @escaping (Snapshot) -> Void) {
        lock.lock(); guard !readPending else { lock.unlock(); completion(withheld(busy: true)); return }
        readPending = true; let token = generation; lock.unlock()
        queue.async {
            self.load()
            var preview: RecordedRoutePreview?, next: RecordedRouteCursor?
            var referenceUnavailable = false
            do {
                if !self.loadFailed, let repository = self.repository {
                    let state = try repository.state()
                    var selectedReference = reference
                    if let referenceKind {
                        let candidates = state.anchors.filter { $0.kind == referenceKind }
                        guard candidates.count == 1 else { throw RecordedRouteError.invalidReference }
                        selectedReference = candidates[0].id
                    }
                    let page = try repository.reversePage(cursor: cursor, returningTo: selectedReference)
                    let samples = try page.samples.map { stored -> RecordedRouteSample in
                        let sample = try RecordedRouteSample(payload: stored.row.payload)
                        guard sample.observationID.uuidString == stored.row.id, sample.sessionID.uuidString == stored.row.sessionID,
                              sample.sourceFrameID == stored.row.sourceFrameID, sample.capturedAt == stored.row.capturedAt else { throw RecordedRouteError.invalidArchive }
                        return sample
                    }
                    var gaps = samples.compactMap(\.boundaryBefore).filter { $0 != .beginning }
                    if page.hasMissingHistory || (cursor == nil && reference == nil && state.evictedCount > 0) { gaps.append(.retentionLoss) }
                    if self.droppedVolatile > 0 { gaps.append(.durabilityLoss) }
                    if !samples.isEmpty { preview = .init(reverseSamples: samples, gaps: gaps, reachesRequestedReference: page.reachedReference && gaps.isEmpty) }
                    next = page.next
                    if let cursor = next, !gaps.isEmpty {
                        next = .init(tripID: cursor.tripID, epoch: cursor.epoch, before: cursor.before,
                            referenceID: cursor.referenceID, encounteredGap: true)
                    }
                    self.trip = state
                    if cursor == nil, !self.pending.isEmpty {
                        var volatileGaps = self.pending.compactMap(\.boundaryBefore).filter { $0 != .beginning }
                        if state.evictedCount > 0 { volatileGaps.append(.retentionLoss) }
                        if self.droppedVolatile > 0 { volatileGaps.append(.durabilityLoss) }
                        preview = .init(reverseSamples: self.pending.reversed(), gaps: volatileGaps, reachesRequestedReference: false)
                        next = state.nextSequence > 0 ? .init(tripID: state.id, epoch: state.epoch, before: state.nextSequence, referenceID: selectedReference, encounteredGap: !volatileGaps.isEmpty) : nil
                    }
                }
            } catch RecordedRouteError.invalidReference { referenceUnavailable = true }
            catch { self.persistenceFailed = true }
            let result = Snapshot(preview: preview, trip: self.trip, nextPage: next,
                persistenceFailed: self.persistenceFailed, loadFailed: self.loadFailed, busy: false, budgetDeferred: self.budgetDeferred, referenceUnavailable: referenceUnavailable,
                durableSampleCount: Int(self.trip?.retainedCount ?? 0), volatileSampleCount: self.pending.count, droppedVolatileSampleCount: self.droppedVolatile)
            DispatchQueue.main.async {
                self.lock.lock(); let current = self.generation == token; self.readPending = false; self.lock.unlock()
                completion(current ? result : self.withheld(busy: true))
            }
        }
    }
    func pinLatest(kind: RecordedRouteAnchor.Kind, label: String, origin: CompanionCommandOrigin, completion: @escaping (Bool) -> Void) {
        guard CommandAuthority.permits(.changeGoal, from: origin) else { completion(false); return }
        lock.lock(); guard !anchorPending, !restarted, !trackingLost, let activeSession = sessionID else { lock.unlock(); completion(false); return }
        anchorPending = true; let token = generation, evidence = continuityEpoch; lock.unlock()
        queue.async {
            var success = false
            self.lock.lock(); let current = token == self.generation && evidence == self.continuityEpoch && !self.restarted && !self.trackingLost; self.lock.unlock()
            if current, !self.loadFailed {
                self.flush()
                do {
                    if let repository = self.repository, let trip = self.trip, let sample = self.sampler.lastSample, sample.sessionID == activeSession, sample.tracking == .normal,
                       self.now() >= sample.capturedAt, self.now()-sample.capturedAt <= SavedWorldFrameRecovery.maximumFrameAge,
                       let sequence = try repository.sequence(observationID: sample.observationID.uuidString, trip: trip) {
                        _ = try repository.pin(sequence: sequence, trip: trip, kind: kind, label: label)
                        self.trip = try repository.state(); success = true
                    }
                } catch { success = false }
            }
            let result = success
            DispatchQueue.main.async {
                self.lock.lock(); let current = token == self.generation && evidence == self.continuityEpoch && !self.restarted && !self.trackingLost; self.anchorPending = false; self.lock.unlock()
                completion(current && result)
            }
        }
    }
    func clear(_ completion: @escaping (Bool) -> Void) {
        lock.lock(); testWriteGeneration = UUID(); testArchive = nil; testSaveFailed = false; testRecording = nil; testOwnedRoute = nil; testRejectedSamples = 0; testRejectedPlans = 0; testGapPending = false
        guard !clearPending else { lock.unlock(); completion(false); return }
        clearPending = true; sessionID = nil; generation = UUID(); lock.unlock()
        queue.async {
            let erasedTrip = self.trip
            self.pending = []; self.sampler.restart(); self.trip = nil; self.loadFailed = true
            var success = false
            do {
                // Loading here is storage-only. An existing failed clear retains the
                // repository for retry; an unopened store can still erase its disk data.
                if self.repository == nil { try self.openRepository() }
                if let repository = self.repository {
                    try repository.clear(trip: erasedTrip ?? repository.state()); self.trip = try repository.state()
                    try self.removeLegacyChunks()
                    self.loaded = true; self.loadFailed = false; self.persistenceFailed = false; self.droppedVolatile = 0; success = true
                }
            } catch { self.persistenceFailed = true }
            let result = success
            DispatchQueue.main.async {
                self.lock.lock(); self.clearPending = false; self.lock.unlock(); completion(result)
            }
        }
    }
    private func openRepository() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var directory = directory, values = URLResourceValues(); values.isExcludedFromBackup = true; try directory.setResourceValues(values)
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: directory.path)
        #endif
        repository = try factory(directory.appendingPathComponent("routes.sqlite").path)
    }
    private func load() {
        guard !loaded else { return }; loaded = true
        do { try openRepository(); try migrateLegacy(); trip = try repository?.state() }
        catch { loadFailed = true }
    }
    private func flush() {
        guard !loadFailed, let repository, let trip else { return }
        do {
            for _ in 0..<3 {
                guard !pending.isEmpty else { return }
                let rows = try pending.prefix(25).map { sample in
                    RecordedRouteRow(id: sample.observationID.uuidString, sessionID: sample.sessionID.uuidString,
                        sourceFrameID: sample.sourceFrameID, capturedAt: sample.capturedAt, payload: try sample.encoded())
                }
                let bytes = rows.reduce(0) { $0 + $1.payload.count }
                guard budget.charge(bytes: bytes, now: now()) == .admitted else { budgetDeferred = true; return }
                let receipt = try repository.append(rows, trip: trip)
                self.trip = receipt.state; pending.removeFirst(rows.count); persistenceFailed = false; budgetDeferred = false
            }
        } catch { persistenceFailed = true }
    }
    private struct LegacyChunk: Decodable { let historyID: UUID; let startIndex: Int; let samples: [RecordedRouteSample] }
    private func legacyFiles() throws -> [URL] {
        guard let iterator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants]) else { throw RecordedRouteError.invalidArchive }
        var result: [URL] = [], inspected = 0
        for case let file as URL in iterator {
            inspected += 1; guard inspected <= 1024 else { throw RecordedRouteError.invalidArchive }
            if file.pathExtension == "json" {
                guard result.count < 1000 else { throw RecordedRouteError.invalidArchive }; result.append(file)
            }
        }
        return result.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
    private func migrateLegacy() throws {
        guard let repository, try !repository.state().legacyImportFinished else { return }
        var offset = 0, bytes = 0, identity: UUID?
        var previous: RecordedRouteSample?
        for file in try legacyFiles() {
            let handle = try FileHandle(forReadingFrom: file)
            let data: Data
            do { data = try handle.read(upToCount: 131_073) ?? Data(); try handle.close() }
            catch { try? handle.close(); throw error }
            bytes += data.count
            guard !data.isEmpty, data.count <= 131_072, bytes <= RecordedRouteHistory.maximumBytes else { throw RecordedRouteError.invalidArchive }
            let chunk = try JSONDecoder().decode(LegacyChunk.self, from: data)
            guard chunk.startIndex == offset, !chunk.samples.isEmpty, chunk.samples.count <= 25,
                  file.lastPathComponent == String(format: "%08d.json", offset), identity.map({ $0 == chunk.historyID }) ?? true else { throw RecordedRouteError.invalidArchive }
            identity = chunk.historyID
            let trip = try repository.adoptLegacyTrip(chunk.historyID.uuidString)
            let rows = try chunk.samples.map { sample -> RecordedRouteRow in
                if let previous { _ = try RecordedRouteHistory(id: chunk.historyID, archivedSamples: [previous.markingBoundary(.beginning),sample]) }
                previous = sample
                return RecordedRouteRow(id: sample.observationID.uuidString, sessionID: sample.sessionID.uuidString,
                    sourceFrameID: sample.sourceFrameID, capturedAt: sample.capturedAt, payload: try sample.encoded())
            }
            _ = try repository.append(rows, trip: trip); offset += chunk.samples.count
            guard offset <= RecordedRouteHistory.maximumSamples else { throw RecordedRouteError.invalidArchive }
        }
        try repository.finishLegacyImport(trip: repository.state())
        // Originals remain until explicit privacy clear. The durable finish marker
        // prevents reimporting evicted samples on a later restart.
    }
    private func removeLegacyChunks() throws { for file in try legacyFiles() { try FileManager.default.removeItem(at: file) } }
}
