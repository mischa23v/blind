import XCTest
import BlindCore
import BlindMemory
import GRDB
#if canImport(BlindAssist)
@testable import BlindAssist
#endif

final class RecordedRouteStoreTests: XCTestCase {
    final class Clock: @unchecked Sendable {
        let lock = NSLock(); private var value = 0.0
        func read() -> Double { lock.lock(); defer { lock.unlock() }; return value }
        func set(_ n: Double) { lock.lock(); value = n; lock.unlock() }
    }
    private func record(_ session: UUID, time: Double, tracking: NativeObservationRecord.Tracking = .normal) -> NativeObservationRecord {
        var c = NativeCameraTransform.identity.columns; c[12] = time*0.01
        return .init(sessionID: session, coordinateFrameID: "source-\(session.uuidString)", producer: .arkit,
            sourceID: "frame-\(time)", capturedAt: time, receivedAt: time, observedAt: Date(), tracking: tracking,
            cameraConvention: .arKitRightUpBack, cameraToSessionWorld: .init(columns: c),
            intrinsics: .init(width: 2, height: 2, fx: 1, fy: 1, cx: 1, cy: 1), depth: nil)
    }
    private func snapshot(_ store: RecordedRouteStore) -> RecordedRouteStore.Snapshot? {
        var result: RecordedRouteStore.Snapshot?; let done = expectation(description: "snapshot")
        store.preview { result = $0; done.fulfill() }; wait(for: [done], timeout: 5); return result
    }
    func testDiagnosticRequiresOptInAndReusesAdmittedSampleThenStops() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let clock = Clock(), session = UUID()
        let store = RecordedRouteStore(url: directory.appendingPathComponent("routes.sqlite"), now: clock.read)
        XCTAssertFalse(store.startTestRecording())
        store.begin(sessionID: session); clock.set(60)
        let first = record(session, time: 60)
        store.offer(sessionID: session, at: 60) { first }; _ = snapshot(store)
        XCTAssertNil(store.testRecordingSnapshot().recording)
        XCTAssertTrue(store.startTestRecording()); XCTAssertFalse(store.startTestRecording())
        clock.set(60.3); let second = record(session, time: 60.3)
        store.offer(sessionID: session, at: 60.3) { second }; _ = snapshot(store)
        let recorded = try XCTUnwrap(store.testRecordingSnapshot().recording)
        XCTAssertEqual(recorded.entries.map { $0.sample.observationID }, [second.id])
        XCTAssertNil(recorded.entries[0].cameraInMap)
        XCTAssertTrue(store.markTestProblem(.apparentWallCrossing))
        store.stopTestRecording(); clock.set(60.6)
        let third = record(session, time: 60.6)
        store.offer(sessionID: session, at: 60.6) { third }; _ = snapshot(store)
        XCTAssertEqual(store.testRecordingSnapshot().recording?.entries.count, 1)
        XCTAssertEqual(store.testRecordingSnapshot().recording?.status, .stopped)
        XCTAssertFalse(store.markTestProblem(.other))
        let deleted = expectation(description: "delete diagnostic")
        store.deleteTestRecording { success in XCTAssertTrue(success); deleted.fulfill() }
        XCTAssertNil(store.testRecordingSnapshot().recording); wait(for: [deleted], timeout: 5)
    }
    func testDiagnosticLateExtractionAndSessionRestartCannotResume() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let clock = Clock(), session = UUID()
        let store = RecordedRouteStore(url: directory.appendingPathComponent("routes.sqlite"), now: clock.read)
        store.begin(sessionID: session); clock.set(60); XCTAssertTrue(store.startTestRecording())
        let extracting = expectation(description: "existing extraction entered"), release = DispatchSemaphore(value: 0)
        let frame = record(session, time: 60)
        store.offer(sessionID: session, at: 60) {
            extracting.fulfill(); _ = release.wait(timeout: .now() + 5); return frame
        }
        wait(for: [extracting], timeout: 5)
        let oldID = store.testRecordingSnapshot().recording?.id
        store.stopTestRecording(); XCTAssertFalse(store.startTestRecording()) // Never replace an unsaved session.
        let deleted = expectation(description: "diagnostic delete after in-flight capture")
        store.deleteTestRecording { success in XCTAssertTrue(success); deleted.fulfill() }
        release.signal(); wait(for: [deleted], timeout: 5)
        XCTAssertTrue(store.startTestRecording())
        XCTAssertNotEqual(store.testRecordingSnapshot().recording?.id, oldID)
        _ = snapshot(store)
        XCTAssertEqual(store.testRecordingSnapshot().recording?.entries.count, 0)
        store.begin(sessionID: UUID())
        XCTAssertEqual(store.testRecordingSnapshot().recording?.status, .stopped)
        let cleared = expectation(description: "private route clear")
        store.clear { _ in cleared.fulfill() }
        XCTAssertNil(store.testRecordingSnapshot().recording)
        wait(for: [cleared], timeout: 5)
    }
    func testRejectedPlanUpdateEndsDiagnosticInsteadOfKeepingStaleAssociation() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let clock = Clock(), session = UUID()
        let store = RecordedRouteStore(url: directory.appendingPathComponent("routes.sqlite"), now: clock.read)
        store.begin(sessionID: session); clock.set(60); XCTAssertTrue(store.startTestRecording())
        let map = SpatialMapBinding(mapID: "fixture", frameID: "map", revision: "r1")
        let plan = NavigationTestRecording.Plan(revision: UUID(), goalRevision: UUID(), map: map,
            points: [Point3(0,0,0), Point3(1,0,0)], alignment: nil, recordedAt: 60)
        XCTAssertTrue(store.setTestPlan(plan))
        clock.set(60.3); let frame = record(session, time: 60.3)
        store.offer(sessionID: session, at: 60.3) { frame }; _ = snapshot(store)
        XCTAssertFalse(store.setTestPlan(plan)) // Delayed route event after sample receipt.
        XCTAssertEqual(store.testRecordingSnapshot().recording?.status, .stopped)
        XCTAssertEqual(store.testRecordingSnapshot().rejectedPlans, 1)
        XCTAssertEqual(store.testRecordingSnapshot().recording?.plans.count, 1)
    }
    func testOwnedRouteDeduplicationCancellationAndProvenanceNeverInventAlignment() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let clock = Clock(), store = RecordedRouteStore(url: directory.appendingPathComponent("routes.sqlite"), now: clock.read)
        store.begin(sessionID: UUID()); clock.set(60); XCTAssertTrue(store.startTestRecording())
        let route = NavigationTestRecording.OwnedRoute(map: .init(mapID: "synthetic", frameID: "map", revision: "r1"),
            routeRevision: UUID(), goalRevision: UUID(), bodyRevision: UUID(), obstacleRevision: UUID(),
            artifactSHA256: String(repeating: "a", count: 64), points: [Point3(0,0,0), Point3(2,0,0)])
        XCTAssertTrue(store.recordOwnedTestPlan(route)); clock.set(60.1)
        XCTAssertTrue(store.recordOwnedTestPlan(route))
        XCTAssertEqual(store.testRecordingSnapshot().recording?.plans.count, 1)
        let plan = try XCTUnwrap(store.testRecordingSnapshot().recording?.plans.first)
        XCTAssertEqual(plan.points, route.points); XCTAssertEqual(plan.bodyRevision, route.bodyRevision)
        XCTAssertEqual(plan.obstacleRevision, route.obstacleRevision); XCTAssertEqual(plan.artifactSHA256, route.artifactSHA256)
        XCTAssertNil(plan.alignment); XCTAssertEqual(plan.recordedAt, 60)
        XCTAssertTrue(store.recordOwnedTestPlan(nil))
        XCTAssertEqual(store.testRecordingSnapshot().recording?.plans.count, 2)
        XCTAssertEqual(store.testRecordingSnapshot().recording?.plans.last?.points, [])
        XCTAssertEqual(store.testRecordingSnapshot().recording?.plans.last?.recordedAt, 60.1)
    }
    private func drain(_ store: RecordedRouteStore) async {
        await withCheckedContinuation { continuation in store.drainTestSavesForTesting { continuation.resume() } }
    }
    func testDurableDiagnosticReopensExactSampleStoppedAndClearRemovesArchive() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let clock = Clock(), session = UUID(), url = directory.appendingPathComponent("routes.sqlite")
        let store = RecordedRouteStore(url: url, now: clock.read)
        store.begin(sessionID: session); clock.set(60); XCTAssertTrue(store.startTestRecording())
        let frame = record(session, time: 60)
        store.offer(sessionID: session, at: 60) { frame }
        // Serial persistence fence also follows the admitted-sample worker.
        await drain(store); clock.set(60.3); XCTAssertTrue(store.markTestProblem(.apparentFurnitureCrossing))
        store.stopTestRecording(); await drain(store)
        let before = try XCTUnwrap(store.testRecordingSnapshot().recording)
        XCTAssertEqual(store.testRecordingSnapshot().pendingEvents, 0)
        let reopened = RecordedRouteStore(url: url, now: clock.read)
        let opened = await withCheckedContinuation { continuation in
            reopened.reopenTestRecording(id: before.id.uuidString) { continuation.resume(returning: $0) }
        }
        XCTAssertTrue(opened)
        let after = try XCTUnwrap(reopened.testRecordingSnapshot().recording)
        XCTAssertEqual(after.entries, before.entries); XCTAssertEqual(after.markers, before.markers)
        XCTAssertEqual(after.archiveEvents, before.archiveEvents); XCTAssertEqual(after.status, .stopped)
        XCTAssertTrue(after.restoredHistorical); XCTAssertFalse(after.restoredInterrupted)
        let erased = await withCheckedContinuation { continuation in reopened.clear { continuation.resume(returning: $0) } }
        XCTAssertTrue(erased)
        let rows = await withCheckedContinuation { continuation in reopened.listSavedTestRecordings { continuation.resume(returning: $0) } }
        XCTAssertEqual(rows?.count, 0)
    }
    func testInterruptedCommittedPrefixReopensWithoutRecordingOrStopTime() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let clock = Clock(), session = UUID(), url = directory.appendingPathComponent("routes.sqlite")
        let store = RecordedRouteStore(url: url, now: clock.read)
        store.begin(sessionID: session); clock.set(60); XCTAssertTrue(store.startTestRecording())
        XCTAssertTrue(store.markTestProblem(.other)); await drain(store)
        let before = try XCTUnwrap(store.testRecordingSnapshot().recording)
        let reopened = RecordedRouteStore(url: url, now: clock.read)
        let opened = await withCheckedContinuation { continuation in
            reopened.reopenTestRecording(id: before.id.uuidString) { continuation.resume(returning: $0) }
        }
        XCTAssertTrue(opened)
        let after = try XCTUnwrap(reopened.testRecordingSnapshot().recording)
        XCTAssertTrue(after.restoredInterrupted); XCTAssertNil(after.endedAt)
        XCTAssertEqual(after.archiveEvents, before.archiveEvents); XCTAssertEqual(after.status, .stopped)
        XCTAssertFalse(reopened.markTestProblem(.wrongDirection))
    }
    func testFullArchiveSlotsKeepUnsavedTailUntilExplicitDeleteAndRetry() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("routes.sqlite"), clock = Clock()
        let repository = try RecordedRouteRepository(path: url.path), trip = try repository.state()
        var ids: [String] = []
        for i in 0..<3 {
            let id = UUID().uuidString; ids.append(id)
            _ = try repository.createNavigationTest(id: id, startedAt: Double(i), createdAt: Double(i), trip: trip)
        }
        let release = DispatchSemaphore(value: 0)
        let store = RecordedRouteStore(url: url, now: clock.read, factory: { path in
            _ = release.wait(timeout: .now() + 5); return try RecordedRouteRepository(path: path)
        })
        store.begin(sessionID: UUID()); clock.set(60); XCTAssertTrue(store.startTestRecording())
        XCTAssertTrue(store.markTestProblem(.missedObstacle)); release.signal(); await drain(store)
        let failed = store.testRecordingSnapshot()
        XCTAssertTrue(failed.saveFailed); XCTAssertGreaterThanOrEqual(failed.pendingEvents, 2)
        XCTAssertEqual(failed.recording?.markers.count, 1); XCTAssertEqual(failed.recording?.status, .stopped)
        let removed = await withCheckedContinuation { continuation in
            store.deleteSavedTestRecording(id: ids[0]) { continuation.resume(returning: $0) }
        }
        XCTAssertTrue(removed); store.retryTestSave(); await drain(store)
        let saved = store.testRecordingSnapshot()
        XCTAssertFalse(saved.saveFailed); XCTAssertEqual(saved.pendingEvents, 0)
        XCTAssertEqual(saved.recording?.markers, failed.recording?.markers)
        XCTAssertEqual(saved.recording?.archiveEvents, failed.recording?.archiveEvents)
    }
    func testDeleteAndClearFenceQueuedArchiveCreationAndPendingReopen() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("routes.sqlite"), clock = Clock()
        let release = DispatchSemaphore(value: 0), entered = expectation(description: "diagnostic repository open entered")
        defer { release.signal() }
        let store = RecordedRouteStore(url: url, now: clock.read, factory: { path in
            entered.fulfill(); release.wait()
            return try RecordedRouteRepository(path: path)
        })
        store.begin(sessionID: UUID()); clock.set(60); XCTAssertTrue(store.startTestRecording())
        let id = try XCTUnwrap(store.testRecordingSnapshot().recording?.id.uuidString)
        await fulfillment(of: [entered], timeout: 5)
        // The initial create is in flight, not merely still queued.
        let deleted = await withCheckedContinuation { continuation in
            store.deleteTestRecording { continuation.resume(returning: $0) }; release.signal()
        }
        XCTAssertTrue(deleted); XCTAssertNil(store.testRecordingSnapshot().recording)
        let rows = await withCheckedContinuation { continuation in store.listSavedTestRecordings { continuation.resume(returning: $0) } }
        XCTAssertFalse(rows?.contains(where: { $0.id == id }) ?? true)
        // Hold this fresh owner's repository open so erase cannot finish before
        // the pending-erase admission check; this is not a timing race assertion.
        let releaseClear = DispatchSemaphore(value: 0)
        let eraseStore = RecordedRouteStore(url: url, factory: { path in
            _ = releaseClear.wait(timeout: .now() + 5); return try RecordedRouteRepository(path: path)
        })
        var prematureReopen: Bool?
        let cleared = await withCheckedContinuation { continuation in
            eraseStore.clear { continuation.resume(returning: $0) }
            eraseStore.reopenTestRecording(id: id) { prematureReopen = $0 }
            releaseClear.signal()
        }
        XCTAssertTrue(cleared); XCTAssertEqual(prematureReopen, false)
        XCTAssertNil(eraseStore.testRecordingSnapshot().recording)
    }
    func testCorruptTypedArchiveNeverInstallsHistoricalRecording() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("routes.sqlite"), repository = try RecordedRouteRepository(path: url.path)
        let id = UUID().uuidString
        let session = try repository.createNavigationTest(id: id, startedAt: 1, createdAt: 1, trip: repository.state())
        _ = try repository.appendNavigationTest(rows: [.init(sequence: 0, payload: Data("not a typed event".utf8))], session: session, status: "recording")
        let store = RecordedRouteStore(url: url)
        let opened = await withCheckedContinuation { continuation in store.reopenTestRecording(id: id) { continuation.resume(returning: $0) } }
        XCTAssertFalse(opened); XCTAssertNil(store.testRecordingSnapshot().recording)
    }
    func testMultipleDurabilityBatchesRetainOrderAndTerminalStatus() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let clock = Clock(), url = directory.appendingPathComponent("routes.sqlite")
        let store = RecordedRouteStore(url: url, now: clock.read)
        store.begin(sessionID: UUID()); clock.set(60); XCTAssertTrue(store.startTestRecording())
        for i in 0..<100 { XCTAssertTrue(store.markTestProblem(i % 2 == 0 ? .missedObstacle : .falseBlockage)) }
        store.stopTestRecording(); await drain(store)
        let before = try XCTUnwrap(store.testRecordingSnapshot().recording)
        XCTAssertEqual(before.archiveEvents.count, 101)
        XCTAssertEqual(store.testRecordingSnapshot().savedEvents, 101)
        XCTAssertEqual(store.testRecordingSnapshot().pendingEvents, 0)
        let reopened = RecordedRouteStore(url: url, now: clock.read)
        let opened = await withCheckedContinuation { continuation in
            reopened.reopenTestRecording(id: before.id.uuidString) { continuation.resume(returning: $0) }
        }
        XCTAssertTrue(opened)
        XCTAssertEqual(reopened.testRecordingSnapshot().recording?.archiveEvents, before.archiveEvents)
        XCTAssertEqual(reopened.testRecordingSnapshot().recording?.status, .stopped)
        XCTAssertEqual(reopened.testRecordingSnapshot().recording?.restoredInterrupted, false)
    }
    func testConstantMemoryQuotaRollsPastOldLimitWhilePinningStartAndMeeting() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let clock = Clock(), session = UUID()
        let store = RecordedRouteStore(url: directory.appendingPathComponent("routes.sqlite"), now: clock.read,
            factory: { try RecordedRouteRepository(path: $0, payloadQuota: 8192) })
        store.begin(sessionID: session); clock.set(60)
        let first = record(session, time: 60); store.offer(sessionID: session, at: 60) { first }; _ = snapshot(store)
        let pin = expectation(description: "named observed point")
        store.pinLatest(kind: .meetingPoint, label: "Family", origin: .trustedInterface) { XCTAssertTrue($0); pin.fulfill() }
        wait(for: [pin], timeout: 5)
        for i in 1..<180 {
            let time = 60 + Double(i)*0.21; clock.set(time)
            let sample = record(session, time: time); store.offer(sessionID: session, at: time) { sample }
            XCTAssertLessThanOrEqual(snapshot(store)?.volatileSampleCount ?? 1000, 64)
        }
        store.stop(); let result = try XCTUnwrap(snapshot(store))
        XCTAssertGreaterThan(result.trip?.nextSequence ?? 0, 100)
        XCTAssertEqual(result.trip?.anchors.filter { $0.kind == .start }.first?.sequence, 0)
        XCTAssertEqual(result.trip?.anchors.filter { $0.kind == .meetingPoint }.count, 1)
        XCTAssertGreaterThan(result.trip?.evictedCount ?? 0, 0)
        XCTAssertFalse(result.capacityReached)
        XCTAssertTrue(result.preview?.gaps.contains(.retentionLoss) == true)
    }
    func testActiveTripSurvivesNewSessionAndRestartWithBoundedReversePages() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("routes.sqlite"), clock = Clock(), session = UUID()
        let store = RecordedRouteStore(url: url, now: clock.read); store.begin(sessionID: session); clock.set(60)
        for i in 0..<90 {
            let time = 60 + Double(i)*0.21; clock.set(time)
            let sample = record(session, time: time); store.offer(sessionID: session, at: time) { sample }; _ = snapshot(store)
        }
        store.stop(); let prior = try XCTUnwrap(snapshot(store))
        let reopened = RecordedRouteStore(url: url, now: clock.read)
        reopened.begin(sessionID: UUID())
        let current = try XCTUnwrap(snapshot(reopened))
        XCTAssertEqual(current.trip?.id, prior.trip?.id)
        XCTAssertLessThanOrEqual(current.preview?.reverseSamples.count ?? 0, 64)
        XCTAssertNotNil(current.nextPage)
        let page = expectation(description: "earlier page")
        reopened.page(cursor: current.nextPage, reference: nil) { next in
            XCTAssertLessThanOrEqual(next.preview?.reverseSamples.count ?? 0, 64)
            XCTAssertEqual(next.preview?.reverseSamples.last?.sourceID, "frame-60.0")
            page.fulfill()
        }
        wait(for: [page], timeout: 5)
    }
    func testTrackingLossAndSameSessionRestartWithdrawPinUntilFreshCapture() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let clock = Clock(), session = UUID()
        let store = RecordedRouteStore(url: directory.appendingPathComponent("routes.sqlite"), now: clock.read)
        store.begin(sessionID: session); clock.set(60)
        let first = record(session, time: 60)
        store.offer(sessionID: session, at: 60) { first }; _ = snapshot(store)
        func pin(_ expected: Bool) {
            let done = expectation(description: "fresh reference")
            store.pinLatest(kind: .entrance, label: "Entrance", origin: .trustedInterface) {
                XCTAssertEqual($0, expected); done.fulfill()
            }
            wait(for: [done], timeout: 5)
        }
        let release = DispatchSemaphore(value: 0), entered = DispatchSemaphore(value: 0)
        clock.set(60.20)
        store.offer(sessionID: session, at: 60.20) {
            entered.signal()
            _ = release.wait(timeout: .now()+5)
            return self.record(session, time: 60.20)
        }
        XCTAssertEqual(entered.wait(timeout: .now()+5), .success)
        store.breakContinuity(); pin(false); release.signal(); _ = snapshot(store)
        pin(false) // The extraction begun before loss must not restore current evidence.
        XCTAssertEqual(snapshot(store)?.trip?.anchors.count, 1)
        clock.set(60.41); let fresh = record(session, time: 60.41)
        store.offer(sessionID: session, at: 60.41) { fresh }; _ = snapshot(store); pin(true)
        store.begin(sessionID: session); pin(false)
        clock.set(60.62); let restarted = record(session, time: 60.62)
        store.offer(sessionID: session, at: 60.62) { restarted }; _ = snapshot(store); pin(true)
        XCTAssertEqual(snapshot(store)?.trip?.anchors.count, 3)
        for (i, tracking) in [NativeObservationRecord.Tracking.limited, .unavailable].enumerated() {
            let time = 60.83 + Double(i)*0.21; clock.set(time)
            store.breakContinuity()
            let limited = record(session, time: time, tracking: tracking)
            store.offer(sessionID: session, at: time) { limited }; _ = snapshot(store); pin(false)
            XCTAssertEqual(snapshot(store)?.preview?.reverseSamples.first?.tracking, tracking)
        }
        clock.set(61.25); let recovered = record(session, time: 61.25)
        store.offer(sessionID: session, at: 61.25) { recovered }; _ = snapshot(store); pin(true)
        XCTAssertEqual(snapshot(store)?.trip?.anchors.count, 4)
        let oldSession = UUID()
        store.offer(sessionID: oldSession, at: 0) { XCTFail("Stale session must not extract"); return self.record(oldSession, time: 0) }
        pin(true) // Old-session timestamp rollback must not withdraw current normal evidence.

    }
    func testColdBudgetHasBoundedVolatileLossAndKeepsOriginalStart() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let clock = Clock(), session = UUID(), store = RecordedRouteStore(url: directory.appendingPathComponent("routes.sqlite"), now: clock.read)
        store.begin(sessionID: session)
        let first = record(session, time: 0)
        for i in 0..<100 {
            let sample = i == 0 ? first : record(session, time: Double(i)*0.21)
            store.offer(sessionID: session, at: sample.capturedAt) { sample }; _ = snapshot(store)
        }
        let pending = try XCTUnwrap(snapshot(store))
        XCTAssertEqual(pending.volatileSampleCount, 64); XCTAssertEqual(pending.droppedVolatileSampleCount, 36)
        XCTAssertEqual(pending.preview?.reverseSamples.last?.observationID, first.id)
        XCTAssertTrue(pending.preview?.gaps.contains(.durabilityLoss) == true)
        clock.set(120); store.stop()
        XCTAssertEqual(snapshot(store)?.durableSampleCount, 64)
    }
    func testLegacyChunkImportPreservesTripAndDoesNotReimportAfterClear() throws {
        struct LegacyChunk: Encodable { let historyID: UUID; let startIndex: Int; let samples: [RecordedRouteSample] }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var history = RecordedRouteHistory(); let session = UUID()
        for i in 0..<33 { try history.observe(record(session, time: Double(i)*0.21)) }
        for index in [0,25] {
            let data = try JSONEncoder().encode(LegacyChunk(historyID: history.id, startIndex: index, samples: Array(history.samples[index..<min(index+25,33)])))
            try data.write(to: directory.appendingPathComponent(String(format: "%08d.json", index)))
        }
        let store = RecordedRouteStore(url: directory.appendingPathComponent("routes.sqlite"))
        let imported = try XCTUnwrap(snapshot(store)); XCTAssertEqual(imported.trip?.id, history.id.uuidString)
        XCTAssertEqual(imported.durableSampleCount, 33); XCTAssertEqual(imported.preview?.reverseSamples.last?.observationID, history.samples[0].observationID)
        let done = expectation(description: "legacy erasure")
        store.clear { XCTAssertTrue($0); done.fulfill() }; wait(for: [done], timeout: 5)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("00000000.json").path))
        let reopened = RecordedRouteStore(url: directory.appendingPathComponent("routes.sqlite"))
        XCTAssertEqual(snapshot(reopened)?.durableSampleCount, 0)
    }
    func testNonJSONEnumerationIsBounded() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for i in 0..<1025 { try Data().write(to: directory.appendingPathComponent(".noise-\(i)")) }
        let store = RecordedRouteStore(url: directory.appendingPathComponent("routes.sqlite"))
        XCTAssertTrue(snapshot(store)?.loadFailed == true)
    }
    func testNamedReferenceAmbiguityAndUntrustedMarkAreNotGuessed() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let clock = Clock(), session = UUID(), store = RecordedRouteStore(url: directory.appendingPathComponent("routes.sqlite"), now: clock.read)
        store.begin(sessionID: session)
        for i in 0..<2 {
            let time = 60 + Double(i)*0.21; clock.set(time)
            let sample = record(session, time: time); store.offer(sessionID: session, at: time) { sample }; _ = snapshot(store)
            let pin = expectation(description: "observed entrance")
            store.pinLatest(kind: .entrance, label: "Entrance \(i)", origin: .trustedInterface) { XCTAssertTrue($0); pin.fulfill() }
            wait(for: [pin], timeout: 5)
        }
        let ambiguous = expectation(description: "reference ambiguity")
        store.preview(referenceKind: .entrance) { XCTAssertTrue($0.referenceUnavailable); XCTAssertNil($0.preview); ambiguous.fulfill() }
        wait(for: [ambiguous], timeout: 5)
        let denied = expectation(description: "unverified voice cannot mark")
        store.pinLatest(kind: .meetingPoint, label: "Untrusted", origin: .unverifiedMicrophone) { XCTAssertFalse($0); denied.fulfill() }
        wait(for: [denied], timeout: 5)
        XCTAssertEqual(snapshot(store)?.trip?.anchors.count, 3)
    }
    func testFailedGRDBEraseFencesSamplesAndAnchorsUntilExplicitRetry() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let clock = Clock(), session = UUID(), url = directory.appendingPathComponent("routes.sqlite")
        let store = RecordedRouteStore(url: url, now: clock.read)
        store.begin(sessionID: session); clock.set(60)
        let sample = record(session, time: 60); store.offer(sessionID: session, at: 60) { sample }; _ = snapshot(store)
        let raw = try DatabaseQueue(path: url.path)
        try raw.write { try $0.execute(sql: "CREATE TRIGGER failErase BEFORE DELETE ON recordedTrip BEGIN SELECT RAISE(ABORT,'injected erase failure'); END") }
        let failed = expectation(description: "failed erase")
        store.clear { XCTAssertFalse($0); failed.fulfill() }; wait(for: [failed], timeout: 5)
        store.begin(sessionID: UUID())
        let fenced = try XCTUnwrap(snapshot(store)); XCTAssertNil(fenced.preview); XCTAssertNil(fenced.trip); XCTAssertTrue(fenced.loadFailed)
        try raw.write { try $0.execute(sql: "DROP TRIGGER failErase") }
        let retry = expectation(description: "erase retry")
        store.clear { XCTAssertTrue($0); retry.fulfill() }; wait(for: [retry], timeout: 5)
        XCTAssertNil(snapshot(store)?.preview)
    }
    func testOldSessionExtractionFailureCannotOwnReplacementSession() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let clock = Clock(), a = UUID(), b = UUID()
        let store = RecordedRouteStore(url: directory.appendingPathComponent("routes.sqlite"), now: clock.read)
        store.begin(sessionID: a); clock.set(60)
        let release = DispatchSemaphore(value: 0), entered = DispatchSemaphore(value: 0)
        store.offer(sessionID: a, at: 60) {
            entered.signal()
            _ = release.wait(timeout: .now()+5)
            throw RecordedRouteError.invalidArchive
        }
        XCTAssertEqual(entered.wait(timeout: .now()+5), .success)
        store.begin(sessionID: b); release.signal(); _ = snapshot(store)
        let sample = record(b, time: 60.21); clock.set(60.21)
        store.offer(sessionID: b, at: 60.21) { sample }; _ = snapshot(store)
        let pin = expectation(description: "new owner normal evidence")
        store.pinLatest(kind: .meetingPoint, label: "B", origin: .trustedInterface) { XCTAssertTrue($0); pin.fulfill() }
        wait(for: [pin], timeout: 5)
        XCTAssertEqual(snapshot(store)?.preview?.reverseSamples.first?.sessionID, b)
    }
    func testDelayedClearCannotEraseLaterSessionSamples() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let clock = Clock(), a = UUID(), b = UUID(), store = RecordedRouteStore(url: directory.appendingPathComponent("routes.sqlite"), now: clock.read)
        store.begin(sessionID: a); clock.set(60)
        let release = DispatchSemaphore(value: 0), entered = DispatchSemaphore(value: 0)
        store.offer(sessionID: a, at: 60) { entered.signal(); _ = release.wait(timeout: .now()+5); return self.record(a, time: 60) }
        XCTAssertEqual(entered.wait(timeout: .now()+5), .success)
        let erased = expectation(description: "delayed clear")
        store.clear { XCTAssertTrue($0); erased.fulfill() }; store.begin(sessionID: b); release.signal()
        wait(for: [erased], timeout: 5)
        clock.set(61); let sample = record(b, time: 61)
        store.offer(sessionID: b, at: 61) { sample }; _ = snapshot(store); store.stop()
        let current = try XCTUnwrap(snapshot(store))
        XCTAssertEqual(current.preview?.reverseSamples.first?.sessionID, b)
        XCTAssertFalse(current.preview?.reverseSamples.contains { $0.sessionID == a } ?? true)
    }
    func testClearRetiresQueuedReadAndStaleAnchorCannotResurrect() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let clock = Clock(), session = UUID(), store = RecordedRouteStore(url: directory.appendingPathComponent("routes.sqlite"), now: clock.read)
        store.begin(sessionID: session); clock.set(60)
        let sample = record(session, time: 60); store.offer(sessionID: session, at: 60) { sample }; _ = snapshot(store)
        let old = expectation(description: "withheld read")
        store.preview { XCTAssertTrue($0.busy); XCTAssertNil($0.preview); old.fulfill() }
        Thread.sleep(forTimeInterval: 0.05)
        let clear = expectation(description: "clear")
        store.clear { XCTAssertTrue($0); clear.fulfill() }; wait(for: [old,clear], timeout: 5)
        XCTAssertNil(snapshot(store)?.preview)
        let denied = expectation(description: "stale last sample unavailable")
        store.pinLatest(kind: .entrance, label: "Old", origin: .trustedInterface) { XCTAssertFalse($0); denied.fulfill() }; wait(for: [denied], timeout: 5)
    }
}
