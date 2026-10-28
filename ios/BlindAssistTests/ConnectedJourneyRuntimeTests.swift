import Foundation
import XCTest
@testable import BlindCore
@testable import BlindAssist

// Synchronous task metadata only; the unsafe handle never leaves this closure.
private func runtimeTaskContext() -> String {
    let hasTask = withUnsafeCurrentTask { $0 != nil }
    return "taskPriority=\(Task.currentPriority.rawValue) hasTask=\(hasTask)"
}

// Per-test metadata only. No stdout in timed callbacks; no global/task-based recorder.
private final class RuntimeTraceBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private let capacity = 512
    private var records: [String] = []
    private var cursor = 0
    private var dropped = 0
    private var closed = false
    func record(_ message: String) {
        let bounded = String(message.prefix(2048))
        lock.lock()
        defer { lock.unlock() }
        guard !closed else { return } // Late work is intentionally uncaptured, never printed in another test.
        if records.count < capacity { records.append(bounded) }
        else { records[cursor] = bounded; cursor = (cursor + 1) % capacity; dropped += 1 }
    }
    func flushAfterTest() {
        lock.lock()
        guard !closed else { lock.unlock(); return }
        closed = true
        let snapshot = cursor == 0 ? records : Array(records[cursor...] + records[..<cursor])
        let omitted = dropped
        records.removeAll(keepingCapacity: false)
        lock.unlock()
        // Snapshot is immutable and the lock is released before any output.
        for record in snapshot { print(record) }
        print("NATIVE_RUNTIME_TRACE records=\(snapshot.count) dropped=\(omitted) late_events=uncaptured_after_teardown observer=buffered")
    }
}

private actor RuntimeIO: ConnectedJourneyRuntimeIO {
    // Test-only phase trace: no stored map, destination or personal payload is logged.
    private let traceBuffer: RuntimeTraceBuffer
    private let diagnosticID = UUID().uuidString
    private func trace(_ phase: String) {
        traceBuffer.record("NATIVE_RUNTIME_IO id=\(diagnosticID) phase=\(phase) uptime=\(ProcessInfo.processInfo.systemUptime) \(runtimeTaskContext())")
    }
    var data: Data?
    var writes: [JourneyRuntimeEnvelope] = []
    var holdWrites = false
    var failWrites = false
    var waiters: [CheckedContinuation<Void, Never>] = []
    var holdRead = false
    var readWaiter: CheckedContinuation<Void,Never>?
    init(_ data: Data? = nil, holdRead:Bool = false, traceBuffer: RuntimeTraceBuffer) { self.data = data; self.holdRead = holdRead; self.traceBuffer = traceBuffer }
    func read() async -> Data? {
        trace("read-start")
        if holdRead {
            trace("read-held")
            await withCheckedContinuation { readWaiter = $0 }
        }
        trace("read-return")
        return data
    }
    func releaseRead() { holdRead = false; readWaiter?.resume(); readWaiter = nil }
    func write(_ payload: JourneyRuntimeWrite) async throws {
        trace("write-start")
        if holdWrites {
            trace("write-held")
            await withCheckedContinuation { waiters.append($0) }
        }
        if failWrites { trace("write-injected-failure"); throw JourneyRuntimeError.storageUnavailable }
        let envelope = try payload.envelope()
        data = try envelope.encoded(); writes.append(envelope)
        trace("write-return")
    }
    func configure(hold: Bool, fail: Bool = false) { holdWrites = hold; failWrites = fail }
    func release() { holdWrites = false; waiters.forEach { $0.resume() }; waiters = [] }
    func blocked() -> Bool { !waiters.isEmpty }
}

@MainActor final class ConnectedJourneyRuntimeTests: XCTestCase {
    typealias F = ConnectedFixture
    private enum WaitError: Error { case timedOut }
    private let traceBuffer = RuntimeTraceBuffer()
    private var registeredTraceTeardown = false
    private func makeIO(_ data: Data? = nil, holdRead: Bool = false) -> RuntimeIO {
        if !registeredTraceTeardown {
            let buffer = traceBuffer
            addTeardownBlock { buffer.flushAfterTest() }
            registeredTraceTeardown = true
        }
        return RuntimeIO(data, holdRead: holdRead, traceBuffer: traceBuffer)
    }
    private func makeRuntime(io: RuntimeIO) -> ConnectedJourneyRuntime {
        let runtime = ConnectedJourneyRuntime(io: io, sha256: F.sha256)
#if DEBUG
        let testName = name
        let traceBuffer = traceBuffer
        runtime.diagnosticPhaseRecorder = { phase, operation, uptime in
            traceBuffer.record("NATIVE_RUNTIME_PHASE test=\(testName) operation=\(operation) phase=\(phase) uptime=\(uptime) \(runtimeTaskContext())")
        }
#endif
        return runtime
    }
    private func until(_ runtime: ConnectedJourneyRuntime, file: StaticString = #filePath, line: UInt = #line,
                       _ condition: @escaping @MainActor () -> Bool) async throws {
        if condition() { return }
        // Diagnostic only: preserve the original three-second bound and failure semantics.
        let started = ProcessInfo.processInfo.systemUptime
        var publications = 0
        let traceBuffer = traceBuffer
        let testName = name
        traceBuffer.record("NATIVE_RUNTIME_WAIT test=\(name) line=\(line) phase=start uptime=\(started) \(runtimeTaskContext())")
        let done = expectation(description: "bounded runtime state publication")
        let previous = runtime.onChange
        var completed = false
        runtime.onChange = {
            publications += 1
            previous?()
            guard !completed, condition() else { return }
            completed = true; done.fulfill()
            traceBuffer.record("NATIVE_RUNTIME_WAIT test=\(testName) line=\(line) phase=fulfilled uptime=\(ProcessInfo.processInfo.systemUptime) \(runtimeTaskContext())")
        }
        defer { runtime.onChange = previous }
        // Await publication instead of scheduling 3,000 polling tasks on the main owner.
        // The original nominal three-second bound is unchanged; real Apple timing remains a gate.
        await fulfillment(of: [done], timeout: 3)
        traceBuffer.record("NATIVE_RUNTIME_WAIT test=\(name) line=\(line) phase=returned elapsed=\(ProcessInfo.processInfo.systemUptime - started) publications=\(publications) fulfilled=\(completed) loading=\(runtime.loading) maps=\(runtime.pendingMapWorkCount) writes=\(runtime.pendingWriteCount) \(runtimeTaskContext())")
        guard condition() else {
            XCTFail("Runtime wait expired: loading=\(runtime.loading), maps=\(runtime.pendingMapWorkCount), writes=\(runtime.pendingWriteCount), storageError=\(runtime.storageError), status=\(runtime.status)", file: file, line: line)
            throw WaitError.timedOut // Never continue with incomplete map state and report a misleading missing-map error.
        }
    }
    /// Wait for the actual operations and owner publication, not a wall-clock
    /// assumption about Simulator worker admission. Not used while IO is held.
    private func completedWork(_ runtime: ConnectedJourneyRuntime,
                               file: StaticString = #filePath, line: UInt = #line) async throws {
        enum CompletionError: Error { case unfinishedOrFailed }
        try await runtime.waitForPendingOperationsForTesting()
        XCTAssertFalse(runtime.loading, file: file, line: line)
        XCTAssertEqual(runtime.pendingMapWorkCount, 0, file: file, line: line)
        XCTAssertEqual(runtime.pendingWriteCount, 0, file: file, line: line)
        XCTAssertFalse(runtime.storageError, file: file, line: line)
        XCTAssertTrue(runtime.durable, file: file, line: line)
        guard !runtime.loading, runtime.pendingMapWorkCount == 0, runtime.pendingWriteCount == 0,
              !runtime.storageError, runtime.durable else { throw CompletionError.unfinishedOrFailed }
    }
    private func installed(_ suppliedIO: RuntimeIO? = nil) async throws -> ConnectedJourneyRuntime {
        let io = suppliedIO ?? makeIO()
        let runtime = makeRuntime(io: io)
        runtime.restore(); try await completedWork(runtime)
        let catalog = try F.catalog()
        // Deliberate burst proves the one-latest catalog task retains ALL accepted
        // installations rather than dropping a map when coalescing work.
        for map in catalog.installations.values { try runtime.install(map, portals: catalog.portals) }
        XCTAssertLessThanOrEqual(runtime.pendingMapWorkCount, 2)
        try await completedWork(runtime)
        XCTAssertTrue(runtime.durable); return runtime
    }
    private func capture(_ runtime: ConnectedJourneyRuntime, _ endpoint: JourneyEndpoint, time: Double, yaw: Double = -.pi/2) throws -> SpatialLocalizationCapture {
        let position = try F.catalog().node(endpoint).position
        return .init(sessionID: try XCTUnwrap(runtime.expectedSessionID), binding: endpoint.binding,
            floorID: endpoint.floorID, roomID: endpoint.roomID, position: .init(position.x,1.3,position.z),
            bodyYaw: yaw, source: .alignedMapPose, headingSource: .bodyAligned, trackingNormal: true,
            positionUncertainty: 0.05, headingUncertainty: 0.05, capturedAt: time)
    }
    private func observe(_ runtime: ConnectedJourneyRuntime, _ endpoint: JourneyEndpoint, time: Double, yaw: Double = -.pi/2) throws {
        let value = try capture(runtime, endpoint, time: time, yaw: yaw)
        try runtime.accept(value, support: SpatialIntegrationFixture.support(value), now: time)
    }
    func testDormantNativeRuntimePersistsDestinationButCannotInventCalibrationOrPose() async throws {
        let io = makeIO(), runtime = try await installed(io)
        try runtime.setDestination(binding: F.c, nodeID: "p", origin: .trustedInterface)
        try await until(runtime) { runtime.pendingWriteCount == 0 }
        XCTAssertEqual(runtime.goal?.target.endpoint.nodeID, "p")
        XCTAssertThrowsError(try runtime.beginLocalization(in: F.a))
        XCTAssertThrowsError(try runtime.next(now: 1))
        let restored = makeRuntime(io: io)
        restored.restore(); try await until(restored) { !restored.loading }
        XCTAssertEqual(restored.goal?.revision, runtime.goal?.revision)
        XCTAssertNil(restored.expectedSessionID)
        XCTAssertThrowsError(try restored.next(now: 1))
        let savedBytes = await io.read()
        let saved = try JourneyRuntimeEnvelope(data: XCTUnwrap(savedBytes))
        XCTAssertEqual(saved.installations.count, 3)
        XCTAssertEqual(saved.portals.count, 2)
    }
    func testCancelIsSynchronousAndLatestOnlyWhileWriterIsBlocked() async throws {
        let io = makeIO(), runtime = try await installed(io)
        try runtime.configure(body: F.body, limits: F.limits)
        try runtime.setDestination(binding: F.c, nodeID: "p", origin: .trustedInterface)
        try await until(runtime) { runtime.pendingWriteCount == 0 }
        _ = try runtime.beginLocalization(in: F.a)
        try observe(runtime, F.endpoint(F.a,"s"), time: 1)
        try await until(runtime) { runtime.pendingWriteCount == 0 }
        try observe(runtime, F.endpoint(F.a,"s"), time: 1.1)
        let ticket = try runtime.next(now: 1.1)
        XCTAssertTrue(runtime.permits(ticket.route, now: 1.1))
        await io.configure(hold: true)
        var retired = 0; runtime.onOutputRetired = { retired += 1 }
        for i in 0..<50 { try runtime.setDestination(binding: F.c, nodeID: i % 2 == 0 ? "p" : "m", origin: .trustedInterface) }
        try runtime.cancel(origin: .trustedInterface)
        XCTAssertEqual(runtime.goal?.status, .cancelled)
        XCTAssertFalse(runtime.permits(ticket.route, now: 1.1))
        XCTAssertLessThanOrEqual(runtime.pendingWriteCount, 2)
        XCTAssertGreaterThan(retired, 0)
        // Main owner remains responsive; independent hazards are not on this IO path.
        let independentHazardMarker = 42; XCTAssertEqual(independentHazardMarker, 42)
        await io.release(); try await until(runtime) { runtime.pendingWriteCount == 0 }
        let written = await io.read()
        XCTAssertEqual(try JourneyRuntimeEnvelope(data: XCTUnwrap(written)).journey.goal?.status, .cancelled)
        XCTAssertThrowsError(try runtime.next(now: 1.1))
        traceBuffer.record("NATIVE_RUNTIME_SLOW_IO=cancelImmediate:true,pendingWritesAtMost:2,latestDiskGoal:cancelled,oldTicket:false")
    }
    func testPauseRestartAndResumeRetainRealGoalButNeedFreshEvidence() async throws {
        let runtime = try await installed()
        try runtime.configure(body: F.body, limits: F.limits)
        try runtime.setDestination(binding: F.c, nodeID: "p", origin: .trustedInterface)
        try await until(runtime) { runtime.pendingWriteCount == 0 }
        _ = try runtime.beginLocalization(in: F.a)
        try observe(runtime, F.endpoint(F.a,"s"), time: 1)
        try await until(runtime) { runtime.pendingWriteCount == 0 }
        try observe(runtime, F.endpoint(F.a,"s"), time: 1.1)
        let ticket = try runtime.next(now: 1.1), revision = runtime.goal?.revision
        try runtime.hold(origin: .trustedInterface)
        XCTAssertEqual(runtime.goal?.status, .paused); XCTAssertFalse(runtime.permits(ticket.route, now: 1.1))
        runtime.cameraRestarted(); XCTAssertEqual(runtime.goal?.revision, revision)
        try runtime.resume(origin: .trustedInterface)
        try await until(runtime) { runtime.pendingWriteCount == 0 }
        XCTAssertThrowsError(try runtime.next(now: 1.1))
        _ = try runtime.beginLocalization(in: F.a)
        try observe(runtime, F.endpoint(F.a,"s"), time: 2)
        XCTAssertNoThrow(try runtime.next(now: 2))
        XCTAssertEqual(runtime.goal?.target.endpoint.binding, F.c)
    }
    func testFailedSaveNewCommandAndEraseCannotReviveSupersededGoal() async throws {
        let io = makeIO(), runtime = try await installed(io)
        try runtime.setDestination(binding: F.c, nodeID: "p", origin: .trustedInterface)
        try await until(runtime) { runtime.pendingWriteCount == 0 }
        await io.configure(hold: false, fail: true)
        try runtime.setDestination(binding: F.b, nodeID: "m", origin: .trustedInterface)
        try await until(runtime) { runtime.pendingWriteCount == 0 }
        XCTAssertTrue(runtime.storageError)
        try runtime.cancel(origin: .trustedInterface)
        XCTAssertEqual(runtime.goal?.status, .cancelled)
        try await until(runtime) { runtime.pendingWriteCount == 0 }
        await io.configure(hold: false)
        try runtime.retryPersistence(); try await until(runtime) { runtime.pendingWriteCount == 0 }
        let written = await io.read()
        XCTAssertEqual(try JourneyRuntimeEnvelope(data: XCTUnwrap(written)).journey.goal?.status, .cancelled)
        try runtime.eraseHistory(origin: .trustedInterface)
        XCTAssertNil(runtime.goal); XCTAssertNil(runtime.snapshot.start)
        try await until(runtime) { runtime.pendingWriteCount == 0 }
        let restored = makeRuntime(io: io)
        restored.restore(); try await until(restored) { !restored.loading }
        XCTAssertNil(restored.goal); XCTAssertTrue(restored.snapshot.events.isEmpty)
    }
    func testSyntheticFullNativeRuntimeOutAndBackRequiresDeliveredOneUseChoice() async throws {
        let runtime = try await installed(), catalog = try F.catalog()
        try runtime.configure(body: F.body, limits: F.limits)
        try runtime.setDestination(binding: F.c, nodeID: "p", origin: .trustedInterface)
        try await until(runtime) { runtime.pendingWriteCount == 0 }
        var time = 10.0, output: [String] = []
        _ = try runtime.beginLocalization(in: F.a)
        try observe(runtime, F.endpoint(F.a,"s"), time: time)
        try await until(runtime) { runtime.pendingWriteCount == 0 }
        time += 0.1; try observe(runtime, F.endpoint(F.a,"s"), time: time)
        for binding in [F.a,F.b,F.c] {
            if binding != F.a {
                _ = try runtime.beginLocalization(in: binding)
                time += 0.1; try observe(runtime, F.endpoint(binding,"s"), time: time)
                try await until(runtime) { runtime.pendingWriteCount == 0 }
                time += 0.1; try observe(runtime, F.endpoint(binding,"s"), time: time)
            }
            for node in ["m","p"] {
                let ticket = try runtime.next(now: time), cue = try XCTUnwrap(ticket.route.directionalCue())
                XCTAssertEqual(ticket.route.target.id,node)
                output.append("\(binding.mapID):\(node):\(String(format: "%.1f",cue.distance))")
                time += 0.1; try observe(runtime, F.endpoint(binding,node), time: time)
                try await until(runtime) { runtime.pendingWriteCount == 0 }
                XCTAssertFalse(runtime.permits(ticket.route,now:time))
            }
        }
        XCTAssertEqual(runtime.goal?.status,.arrived)
        try runtime.saveReference(origin:.trustedInterface,now:time)
        try await until(runtime) { runtime.pendingWriteCount == 0 }
        guard case .clarify(let question) = try runtime.requestReturn(origin:.trustedInterface,arabic:false) else { return XCTFail() }
        XCTAssertThrowsError(try runtime.resolveReturn(.journeyStart,origin:.trustedInterface,now:time))
        XCTAssertTrue(runtime.beginClarificationSpeech(question))
        XCTAssertFalse(runtime.clarificationSpeechFinished(id:UUID(),text:question.text,outcome:.completed,now:time))
        XCTAssertTrue(runtime.clarificationSpeechFinished(id:question.id,text:question.text,outcome:.completed,now:time))
        // Harmless fresh camera samples must not destroy semantic delivery receipts.
        time += 0.1; try observe(runtime,F.endpoint(F.c,"p"),time:time,yaw:.pi/2)
        try runtime.resolveReturn(.journeyStart,origin:.trustedInterface,now:time)
        XCTAssertThrowsError(try runtime.resolveReturn(.savedReference,origin:.trustedInterface,now:time))
        try await until(runtime) { runtime.pendingWriteCount == 0 }
        time += 0.1; try observe(runtime,F.endpoint(F.c,"p"),time:time,yaw:.pi/2)
        for binding in [F.c,F.b,F.a] {
            if binding != F.c {
                _ = try runtime.beginLocalization(in:binding)
                time += 0.1; try observe(runtime,F.endpoint(binding,"p"),time:time,yaw:.pi/2)
                try await until(runtime) { runtime.pendingWriteCount == 0 }
                time += 0.1; try observe(runtime,F.endpoint(binding,"p"),time:time,yaw:.pi/2)
            }
            for node in ["m","s"] {
                let ticket = try runtime.next(now:time), cue = try XCTUnwrap(ticket.route.directionalCue())
                output.append("\(binding.mapID):\(node):\(String(format:"%.1f",cue.distance))")
                XCTAssertEqual(ticket.route.target.id,node)
                time += 0.1; try observe(runtime,F.endpoint(binding,node),time:time,yaw:.pi/2)
                try await until(runtime) { runtime.pendingWriteCount == 0 }
            }
        }
        XCTAssertEqual(runtime.goal?.status,.arrived)
        XCTAssertEqual(runtime.snapshot.events.filter { $0.kind == .portalEndpointsAssociated }.count,4)
        XCTAssertEqual(output,["bedroom-map:m:1.0","bedroom-map:p:1.0","hall-map:m:2.0","hall-map:p:2.0","study-map:m:1.0","study-map:p:1.0","study-map:m:1.0","study-map:s:1.0","hall-map:m:2.0","hall-map:s:2.0","bedroom-map:m:1.0","bedroom-map:s:1.0"])
        XCTAssertEqual(catalog.installations.count,3)
        traceBuffer.record("SYNTHETIC_NATIVE_RUNTIME_FULL_SEQUENCE=" + output.joined(separator:","))
    }
    func testMapIOWithdrawalInvalidGoalAndDeletionFenceStaleOutput() async throws {
        let runtime = try await installed()
        try runtime.configure(body:F.body,limits:F.limits)
        try runtime.setDestination(binding:F.c,nodeID:"p",origin:.trustedInterface)
        try await until(runtime) { runtime.pendingWriteCount == 0 }
        _ = try runtime.beginLocalization(in:F.a)
        try observe(runtime,F.endpoint(F.a,"s"),time:1)
        try await until(runtime) { runtime.pendingWriteCount == 0 }
        try observe(runtime,F.endpoint(F.a,"s"),time:1.1)
        let ticket = try runtime.next(now:1.1)
        runtime.mapOwnershipWithdrawn()
        XCTAssertFalse(runtime.permits(ticket.route,now:1.1))
        XCTAssertThrowsError(try runtime.beginLocalization(in:F.a))
        XCTAssertThrowsError(try runtime.next(now:1.2))
        try runtime.mapRemovalSettled(F.c)
        try await until(runtime) { runtime.pendingMapWorkCount == 0 && runtime.pendingWriteCount == 0 }
        XCTAssertEqual(runtime.goal?.target.endpoint.binding,F.c)
        XCTAssertThrowsError(try runtime.setDestination(binding:F.a,nodeID:"unknown",origin:.trustedInterface))
        try runtime.retryPersistence(); try await until(runtime) { runtime.pendingWriteCount == 0 }
        XCTAssertThrowsError(try runtime.next(now:1.2))
    }

    func testUnverifiedCommandsCannotEvenRetireActiveNativeRoute() async throws {
        let runtime = try await installed()
        try runtime.configure(body:F.body,limits:F.limits)
        try runtime.setDestination(binding:F.c,nodeID:"p",origin:.trustedInterface)
        try await until(runtime) { runtime.pendingWriteCount == 0 }
        _ = try runtime.beginLocalization(in:F.a)
        try observe(runtime,F.endpoint(F.a,"s"),time:1)
        try await until(runtime) { runtime.pendingWriteCount == 0 }
        try observe(runtime,F.endpoint(F.a,"s"),time:1.1)
        let ticket = try runtime.next(now:1.1)
        XCTAssertThrowsError(try runtime.setDestination(binding:F.b,nodeID:"s",origin:.unverifiedMicrophone))
        XCTAssertThrowsError(try runtime.hold(origin:.unverifiedMicrophone))
        XCTAssertThrowsError(try runtime.resume(origin:.unverifiedMicrophone))
        XCTAssertThrowsError(try runtime.cancel(origin:.unverifiedMicrophone))
        XCTAssertThrowsError(try runtime.requestReturn(origin:.unverifiedMicrophone,arabic:false))
        XCTAssertThrowsError(try runtime.saveReference(origin:.unverifiedMicrophone,now:1.1))
        XCTAssertThrowsError(try runtime.resolveReturn(.journeyStart,origin:.unverifiedMicrophone,now:1.1))
        XCTAssertThrowsError(try runtime.eraseHistory(origin:.unverifiedMicrophone))
        XCTAssertTrue(runtime.permits(ticket.route,now:1.1))
    }

    func testDeleteWhileRestoreIsPendingCannotReinstallQueuedOldMap() async throws {
        let catalog = try F.catalog()
        var owner = try F.prepared()
        try owner.setDestination(F.endpoint(F.c,"p"),origin:.trustedInterface,recordedAt:F.date,persist:{_ in})
        let seed = try JourneyRuntimeEnvelope(journey:owner.snapshot,installations:catalog.installations.values.map { try $0.encoded() },portals:catalog.portals).encoded()
        let io = makeIO(seed,holdRead:true), runtime = makeRuntime(io: io)
        runtime.restore()
        try runtime.install(XCTUnwrap(catalog.installations[F.c]),portals:catalog.portals)
        runtime.mapOwnershipWithdrawn(); try runtime.mapRemovalSettled(F.c)
        // Allow the read to enter its continuation before releasing it.
        try await Task.sleep(nanoseconds:10_000_000)
        await io.releaseRead()
        try await until(runtime) { !runtime.loading && runtime.pendingMapWorkCount == 0 && runtime.pendingWriteCount == 0 }
        try runtime.configure(body:F.body,limits:F.limits)
        XCTAssertThrowsError(try runtime.beginLocalization(in:F.c))
        XCTAssertEqual(runtime.goal?.target.endpoint.binding,F.c)
        let bytes = await io.read(), disk = try JourneyRuntimeEnvelope(data:XCTUnwrap(bytes))
        let bindings = try disk.installations.map { try SpatialMapInstallation(data:$0,sha256:F.sha256).binding }
        XCTAssertFalse(bindings.contains(F.c))
    }

    func testReplacementOrHoldDuringDelayedRestoreOwnsLatestIntent() async throws {
        for command in ["valid", "invalid", "cancel", "hold", "erase-then-new", "no-maps"] {
            let catalog = try F.catalog()
            var previous = try F.prepared()
            try previous.setDestination(F.endpoint(F.c,"p"),origin:.trustedInterface,recordedAt:F.date,persist:{_ in})
            let bytes = try JourneyRuntimeEnvelope(journey:previous.snapshot,installations:command == "no-maps" ? [] : catalog.installations.values.map { try $0.encoded() },portals:command == "no-maps" ? [] : catalog.portals).encoded()
            let io = makeIO(bytes,holdRead:true), runtime = makeRuntime(io: io)
            runtime.restore()
            if command == "hold" { try runtime.hold(origin:.trustedInterface) }
            else {
                if command == "erase-then-new" { try runtime.eraseHistory(origin:.trustedInterface) }
                try runtime.setDestination(binding:F.b,nodeID:command == "invalid" ? "missing" : "m",origin:.trustedInterface)
                if command == "cancel" { try runtime.cancel(origin:.trustedInterface) }
            }
            try await Task.sleep(nanoseconds:10_000_000); await io.releaseRead()
            try await until(runtime) { !runtime.loading && runtime.pendingWriteCount == 0 }
            XCTAssertFalse(runtime.storageError)
            let savedBytes = await io.read(), saved = try JourneyRuntimeEnvelope(data:XCTUnwrap(savedBytes))
            if command == "hold" { XCTAssertEqual(saved.journey.goal?.status,.paused) }
            else if command == "invalid" || command == "cancel" || command == "no-maps" { XCTAssertEqual(saved.journey.goal?.status,.cancelled) }
            else {
                XCTAssertEqual(saved.journey.goal?.target.endpoint.binding,F.b)
                XCTAssertEqual(saved.journey.goal?.target.endpoint.nodeID,"m")
                XCTAssertEqual(saved.journey.goal?.status,.active)
            }
            XCTAssertThrowsError(try runtime.next(now:1))
        }
    }

    func testMaximumHistorySynchronousResidualIsBoundedAndMeasuredNotDeviceLatency() async throws {
        let catalog = try F.catalog(), word = String(repeating:"x",count:160)
        let endpoint = JourneyEndpoint(binding:.init(mapID:word,frameID:word,revision:word),floorID:word,nodeID:word,roomID:word)
        var snapshot = ConnectedJourneySnapshot()
        snapshot.references = (0..<64).map { _ in .init(id:UUID(),kind:.savedReference,endpoint:endpoint,
            context:.init(worldID:word,placeID:word,buildingID:word,floorID:word,roomID:word),artifactSHA256:String(repeating:"a",count:64),
            recordedAt:F.date,historicalCaptureID:UUID()) }
        snapshot.events = (0..<256).map { .init(sequence:UInt64($0),kind:.reachedNode,recordedAt:F.date,endpoint:endpoint,goalRevision:nil,portalID:nil,
            historicalCaptureID:UUID(),portalDepartureCaptureID:nil,portalDepartureRecordedAt:nil) }
        snapshot.nextSequence = 256
        let initial = try snapshot.encoded()
        // Pad one historical, non-authoritative event within the total byte cap to
        // exercise the permitted worst payload. It is never a current map endpoint.
        let padding = ConnectedJourneySnapshot.maximumBytes - initial.count - 2000
        if padding > 0 {
            let padded = JourneyEndpoint(binding:endpoint.binding,floorID:word,nodeID:String(repeating:"p",count:160+padding),roomID:word)
            snapshot.events[255] = .init(sequence:255,kind:.reachedNode,recordedAt:F.date,endpoint:padded,goalRevision:nil,portalID:nil,
                historicalCaptureID:UUID(),portalDepartureCaptureID:nil,portalDepartureRecordedAt:nil)
        }
        let historyBytes = try snapshot.encoded().count
        XCTAssertGreaterThan(historyBytes,500_000); XCTAssertLessThanOrEqual(historyBytes,512_000)
        let seed = try JourneyRuntimeEnvelope(journey:snapshot,installations:catalog.installations.values.map { try $0.encoded() },portals:catalog.portals).encoded()
        let io = makeIO(seed), runtime = makeRuntime(io: io)
        runtime.restore(); try await until(runtime) { !runtime.loading }
        var milliseconds:[Double] = []
        for _ in 0..<12 {
            let started = DispatchTime.now().uptimeNanoseconds
            try runtime.setDestination(binding:F.c,nodeID:"p",origin:.trustedInterface)
            milliseconds.append(Double(DispatchTime.now().uptimeNanoseconds-started)/1_000_000)
        }
        XCTAssertLessThanOrEqual(runtime.pendingWriteCount,2)
        try await until(runtime) { runtime.pendingWriteCount == 0 }
        traceBuffer.record("NATIVE_MAIN_OWNER_RESIDUAL=historyBytes:\(historyBytes),events:256,references:64,samples:12,hostMaxMilliseconds:\(String(format:"%.3f",milliseconds.max()!)),deviceHazardLatency:UNMEASURED")
    }
    func testInvalidCalibrationReplacementCannotReuseOldBodyOrRoute() async throws {
        let runtime = try await installed()
        try runtime.configure(body:F.body,limits:F.limits)
        try runtime.setDestination(binding:F.c,nodeID:"p",origin:.trustedInterface)
        try await until(runtime) { runtime.pendingWriteCount == 0 }
        _ = try runtime.beginLocalization(in:F.a)
        try observe(runtime,F.endpoint(F.a,"s"),time:1)
        try await until(runtime) { runtime.pendingWriteCount == 0 }
        try observe(runtime,F.endpoint(F.a,"s"),time:1.1)
        let ticket = try runtime.next(now:1.1)
        XCTAssertThrowsError(try runtime.configure(body:F.body,limits:.init(maximumPositionUncertainty:-1,maximumHeadingUncertainty:0.1)))
        XCTAssertFalse(runtime.permits(ticket.route,now:1.1))
        XCTAssertThrowsError(try runtime.beginLocalization(in:F.a))
        XCTAssertThrowsError(try runtime.next(now:1.1))
    }

    func testDeleteRestartCannotReimportSameRevisionAndForgetRestrictions() async throws {
        let io = makeIO(), runtime = try await installed(io), maps = try F.catalog()
        let restricted = try XCTUnwrap(maps.installations[F.a]).addingRestrictions(blocked:[MapConnection("s","m")],zones:[])
        try runtime.install(restricted,portals:maps.portals)
        try await completedWork(runtime)
        try runtime.withdrawMap(F.a)
        try await completedWork(runtime)
        let bytes = await io.read(), disk = try JourneyRuntimeEnvelope(data:XCTUnwrap(bytes))
        XCTAssertEqual(disk.retiredBindings,[F.a])
        XCTAssertFalse(try disk.installations.map { try SpatialMapInstallation(data:$0,sha256:F.sha256).binding }.contains(F.a))
        let restored = makeRuntime(io: io)
        restored.restore(); try await completedWork(restored)
        XCTAssertThrowsError(try restored.install(XCTUnwrap(maps.installations[F.a]),portals:maps.portals))
        try restored.configure(body:F.body,limits:F.limits)
        XCTAssertThrowsError(try restored.beginLocalization(in:F.a))
        XCTAssertThrowsError(try restored.next(now:1))
        traceBuffer.record("DELETED_REVISION_RESTART=geometryRemoved:true,tombstoneRetained:true,sameRevisionReimport:false,restrictionRollback:false")
    }

    func testOuterEnvelopeCannotBypassNestedHistoryByteLimit() async throws {
        var snapshot = ConnectedJourneySnapshot()
        let endpoint = JourneyEndpoint(binding:F.a,floorID:"ground",nodeID:String(repeating:"x",count:600_000))
        snapshot.events = [.init(sequence:0,kind:.reachedNode,recordedAt:F.date,endpoint:endpoint,goalRevision:nil,portalID:nil,
            historicalCaptureID:nil,portalDepartureCaptureID:nil,portalDepartureRecordedAt:nil)]
        snapshot.nextSequence = 1
        // Deliberately bypass the writer's encoded() validation, simulating a
        // malformed restored file whose outer size is otherwise admissible.
        let bytes = try JSONEncoder().encode(JourneyRuntimeEnvelope(journey:snapshot,installations:[],portals:[]))
        XCTAssertLessThan(bytes.count,JourneyRuntimeEnvelope.maximumBytes)
        XCTAssertGreaterThan(bytes.count,ConnectedJourneySnapshot.maximumBytes)
        XCTAssertThrowsError(try JourneyRuntimeEnvelope(data:bytes))
        let runtime = makeRuntime(io: makeIO(bytes))
        runtime.restore(); try await until(runtime) { !runtime.loading }
        XCTAssertTrue(runtime.storageError); XCTAssertNil(runtime.goal)
        XCTAssertThrowsError(try runtime.next(now:1))
    }

}

extension ConnectedJourneyRuntimeTests {
    func testIntegratedAutomaticRecoveryAfterRejectedEvidence() async throws {
        for mode in ["wrong-support", "camera-only-heading"] {
            let runtime = try await installed()
            try runtime.configure(body: F.body, limits: F.limits)
            try runtime.setDestination(binding: F.c, nodeID: "p", origin: .trustedInterface)
            try await until(runtime) { runtime.pendingWriteCount == 0 }
            _ = try runtime.beginLocalization(in: F.a)
            try observe(runtime, F.endpoint(F.a,"s"), time: 1)
            try await until(runtime) { runtime.pendingWriteCount == 0 }
            try observe(runtime, F.endpoint(F.a,"s"), time: 1.1)
            let old = try runtime.next(now: 1.1), goal = runtime.goal?.revision
            let base = try capture(runtime, F.endpoint(F.a,"s"), time: 1.2)
            let invalid = SpatialLocalizationCapture(sessionID: base.sessionID, binding: base.binding,
                floorID: base.floorID, roomID: base.roomID, position: base.position, bodyYaw: base.bodyYaw,
                source: .alignedMapPose, headingSource: mode == "camera-only-heading" ? .cameraOnly : .bodyAligned,
                trackingNormal: true, positionUncertainty: 0.05, headingUncertainty: 0.05, capturedAt: 1.2)
            let support = SpatialFloorSupport(binding: invalid.binding, floorID: invalid.floorID,
                sessionID: invalid.sessionID, captureID: mode == "wrong-support" ? UUID() : invalid.id,
                height: 0, capturedAt: invalid.capturedAt)
            do { try runtime.accept(invalid,support:support,now:1.2); XCTFail("Invalid evidence should reject") }
            catch { traceBuffer.record("NATIVE_REPLAY_INVALID=mode:\(mode),capture:\(invalid.id),session:\(invalid.sessionID),error:\(error)") }
            XCTAssertFalse(runtime.permits(old.route,now:1.2))
            let fresh = try capture(runtime,F.endpoint(F.a,"s"),time:1.3)
            try runtime.accept(fresh,support:SpatialIntegrationFixture.support(fresh),now:1.3)
            XCTAssertEqual(runtime.goal?.revision,goal)
            XCTAssertFalse(runtime.permits(old.route,now:1.3))
            // Product expectation: fresh valid evidence automatically restores useful
            // guidance, without another UI command or hidden harness plan operation.
            do {
                let recovered = try runtime.next(now:1.3)
                traceBuffer.record("NATIVE_REPLAY_RECOVERY=mode:\(mode),fresh:\(fresh.id),session:\(fresh.sessionID),target:\(recovered.route.target.id),status:PASS")
            } catch {
                traceBuffer.record("NATIVE_REPLAY_RECOVERY=mode:\(mode),fresh:\(fresh.id),session:\(fresh.sessionID),status:FAIL,error:\(error)")
                XCTFail("Automatic recovery failed for \(mode): \(error)")
            }
        }
    }
    func testIntegratedRejectedEvidenceCannotInferMidLegStart() async throws {
        let runtime = try await installed()
        try runtime.configure(body:F.body,limits:F.limits)
        try runtime.setDestination(binding:F.c,nodeID:"p",origin:.trustedInterface)
        try await until(runtime) { runtime.pendingWriteCount == 0 }
        _ = try runtime.beginLocalization(in:F.a)
        try observe(runtime,F.endpoint(F.a,"s"),time:1)
        try await until(runtime) { runtime.pendingWriteCount == 0 }
        try observe(runtime,F.endpoint(F.a,"s"),time:1.1)
        let old = try runtime.next(now:1.1), goal = runtime.goal?.revision
        let bad = try capture(runtime,F.endpoint(F.a,"s"),time:1.2)
        let wrong = SpatialFloorSupport(binding:bad.binding,floorID:bad.floorID,sessionID:bad.sessionID,captureID:UUID(),height:0,capturedAt:1.2)
        XCTAssertThrowsError(try runtime.accept(bad,support:wrong,now:1.2))
        let between = SpatialLocalizationCapture(sessionID:try XCTUnwrap(runtime.expectedSessionID),binding:F.a,
            floorID:"ground",roomID:"bedroom",position:.init(1.5,1.3,3),bodyYaw:-.pi/2,
            source:.alignedMapPose,headingSource:.bodyAligned,trackingNormal:true,
            positionUncertainty:0.05,headingUncertainty:0.05,capturedAt:1.3)
        try runtime.accept(between,support:SpatialIntegrationFixture.support(between),now:1.3)
        XCTAssertFalse(runtime.permits(old.route,now:1.3))
        XCTAssertEqual(runtime.goal?.revision,goal)
        XCTAssertThrowsError(try runtime.next(now:1.3),"Unknown endpoint must not be snapped to a remembered start")
        traceBuffer.record("NATIVE_UNKNOWN_ENDPOINT=capture:\(between.id),session:\(between.sessionID),position:1.5/1.3/3,expected:withhold,status:PASS_IF_ASSERTIONS_PASS")
    }
}

extension ConnectedJourneyRuntimeTests {
    func testRejectedEvidenceWaitsAtMidLegThenAutomaticallyReplansFromFreshAuthoredNode() async throws {
        let runtime = try await installed()
        try runtime.configure(body:F.body,limits:F.limits)
        try runtime.setDestination(binding:F.c,nodeID:"p",origin:.trustedInterface)
        try await until(runtime) { runtime.pendingWriteCount == 0 }
        _ = try runtime.beginLocalization(in:F.a)
        try observe(runtime,F.endpoint(F.a,"s"),time:1)
        try await until(runtime) { runtime.pendingWriteCount == 0 }
        try observe(runtime,F.endpoint(F.a,"s"),time:1.1)
        let old = try runtime.next(now:1.1), saved = try runtime.snapshot.encoded()
        let bad = try capture(runtime,F.endpoint(F.a,"s"),time:1.2)
        let wrong = SpatialFloorSupport(binding:bad.binding,floorID:bad.floorID,sessionID:bad.sessionID,
            captureID:UUID(),height:0,capturedAt:bad.capturedAt)
        XCTAssertThrowsError(try runtime.accept(bad,support:wrong,now:1.2))
        XCTAssertThrowsError(try runtime.saveReference(origin:.trustedInterface,now:1.2))
        XCTAssertTrue(runtime.durable, "No stale endpoint may turn a rejected save into an unrelated persistence failure")
        // Replaying an earlier session cannot become current by changing only its time.
        XCTAssertThrowsError(try runtime.accept(bad,support:SpatialIntegrationFixture.support(bad),now:1.2))
        let mid = SpatialLocalizationCapture(sessionID:try XCTUnwrap(runtime.expectedSessionID),binding:F.a,
            floorID:"ground",roomID:"bedroom",position:.init(1.5,1.3,3),bodyYaw: -.pi/2,
            source:.alignedMapPose,headingSource:.bodyAligned,trackingNormal:true,
            positionUncertainty:0.05,headingUncertainty:0.05,capturedAt:1.3)
        try runtime.accept(mid,support:SpatialIntegrationFixture.support(mid),now:1.3)
        XCTAssertThrowsError(try runtime.next(now:1.3), "An arbitrary mid-leg pose is not a new authored start")
        XCTAssertEqual(try runtime.snapshot.encoded(),saved)
        try observe(runtime,F.endpoint(F.a,"m"),time:1.4)
        let recovered = try runtime.next(now:1.4)
        XCTAssertEqual(recovered.route.target.id,"p", "Replan starts at fresh measured m, not the old s")
        XCTAssertNotEqual(recovered.route.routeID,old.route.routeID)
        XCTAssertFalse(runtime.permits(old.route,now:1.4))
        XCTAssertEqual(try runtime.snapshot.encoded(),saved)
        traceBuffer.record("NATIVE_RECOVERY_ENDPOINT=midLeg:withheld,freshAuthoredNode:m,next:p,oldSessionRejected:true,oldTicket:false,startGoalHistory:unchanged")
    }
    func testAutomaticRecoveryKeepsCurrentConservativeRestrictions() async throws {
        let runtime = try await installed(), map = try XCTUnwrap(F.catalog().installations[F.a])
        let restricted = try map.addingRestrictions(blocked:[MapConnection("s","m")],zones:[])
        try runtime.install(restricted)
        try await completedWork(runtime)
        try runtime.configure(body:F.body,limits:F.limits)
        try runtime.setDestination(binding:F.c,nodeID:"p",origin:.trustedInterface)
        try await completedWork(runtime)
        _ = try runtime.beginLocalization(in:F.a)
        try observe(runtime,F.endpoint(F.a,"m"),time:1)
        try await completedWork(runtime)
        try observe(runtime,F.endpoint(F.a,"m"),time:1.1)
        let old = try runtime.next(now:1.1), saved = try runtime.snapshot.encoded()
        let bad = try capture(runtime,F.endpoint(F.a,"m"),time:1.2)
        let wrong = SpatialFloorSupport(binding:bad.binding,floorID:bad.floorID,sessionID:bad.sessionID,
            captureID:UUID(),height:0,capturedAt:bad.capturedAt)
        XCTAssertThrowsError(try runtime.accept(bad,support:wrong,now:1.2))
        // Freshly established s cannot cross the still-blocked s-m edge.
        XCTAssertThrowsError(try observe(runtime,F.endpoint(F.a,"s"),time:1.3))
        XCTAssertThrowsError(try runtime.next(now:1.3))
        XCTAssertFalse(runtime.permits(old.route,now:1.3))
        XCTAssertEqual(try runtime.snapshot.encoded(),saved)
        // A fresh endpoint on the other side can reuse the retained goal, not the old route.
        try observe(runtime,F.endpoint(F.a,"m"),time:1.4)
        XCTAssertEqual(try runtime.next(now:1.4).route.target.id,"p")
        traceBuffer.record("NATIVE_RECOVERY_RESTRICTION=blocked:s-m,afterRejection:retained,blockedRecovery:withheld,admissibleFreshEndpoint:m,replan:automatic")
    }
}
