import XCTest
@testable import BlindCore
#if canImport(NativeScene)
@testable import NativeScene
#else
@testable import BlindAssist
#endif

final class ObservedSceneRuntimeTests: XCTestCase {
    @MainActor func testRejectedFrameDisplaysEvidenceFailureNotTrailState() async throws {
        let runtime = ObservedSceneRuntime(clock: { 1 }), session = UUID()
        runtime.begin(session: session)
        runtime.offer(frame(1), session: session, floor: 0, body: body, now: 0.8)
        XCTAssertEqual(runtime.liveStatus, "stale"); XCTAssertNil(runtime.plan)
    }
    func frame(_ time: Double, camera: Point3 = Point3(0, 1, 0), sparse: Bool = false) -> Observation {
        var samples: [DepthSample] = []
        if !sparse {
            for x in -25...25 { for z in 3...55 {
                samples.append(.init(Point3(Double(x) * 0.04 + 0.011, 0, Double(z) * 0.04 + 0.013)))
            } }
        }
        return Observation(timestamp: time, camera: camera, forward: Point3(0, 0, 1), samples: samples)
    }
    let body = BodyEnvelope(radius: 0.1, height: 1.2, margin: 0.05)
    @MainActor func testNativeRuntimeFeedsActualAccumulatorAndRejectsAbandonedCompletion() async throws {
        let runtime = ObservedSceneRuntime(clock: { 2 }), first = UUID(), second = UUID()
        runtime.begin(session: first)
        runtime.offer(frame(1), session: first, floor: 0, body: body, now: 1)
        runtime.stop(); runtime.begin(session: second)
        try await runtime.waitForCurrentWorkForTesting()
        XCTAssertNil(runtime.snapshot)
        runtime.offer(frame(2), session: second, floor: 0, body: body, now: 2)
        try await runtime.waitForCurrentWorkForTesting()
        XCTAssertEqual(runtime.snapshot?.sessionID, second)
        XCTAssertFalse(runtime.snapshot?.cells.isEmpty ?? true)
        XCTAssertEqual(runtime.plan?.local.state, .candidatePath)
        runtime.setIntent(.returnToStart); XCTAssertNil(runtime.plan)
        runtime.trackingLost(); XCTAssertNil(runtime.snapshot)
    }
    @MainActor func testRuntimeRechecksClockAfterWorkerAndWatchdogExpiresPlan() async throws {
        let expired = ObservedSceneRuntime(clock: { 9 }), session = UUID()
        expired.begin(session: session); expired.offer(frame(1), session: session, floor: 0, body: body, now: 1)
        try await expired.waitForCurrentWorkForTesting()
        XCTAssertNotNil(expired.snapshot); XCTAssertNil(expired.plan)
        let fresh = ObservedSceneRuntime(clock: { 1 }); fresh.begin(session: session)
        fresh.offer(frame(1), session: session, floor: 0, body: body, now: 1)
        try await fresh.waitForCurrentWorkForTesting()
        XCTAssertNotNil(fresh.plan); fresh.revalidate(now: 1.6); XCTAssertNil(fresh.plan)
    }
    @MainActor func testPreLossAndPreRestartFramesCannotSeedNewScene() async throws {
        let runtime = ObservedSceneRuntime(clock: { 2 }), session = UUID()
        runtime.begin(session: session); runtime.trackingLost(at: 1.5)
        runtime.offer(frame(1.4), session: session, floor: 0, body: body, now: 1.6)
        try await runtime.waitForCurrentWorkForTesting()
        XCTAssertNil(runtime.snapshot); XCTAssertEqual(runtime.liveStatus, "trackingUnavailable")
        runtime.begin(session: session, capturedAfter: 2)
        runtime.offer(frame(1.9), session: session, floor: 0, body: body, now: 2)
        try await runtime.waitForCurrentWorkForTesting()
        XCTAssertNil(runtime.snapshot)
    }
    @MainActor func testRejectedFutureTimestampDoesNotPoisonLaterCapture() async throws {
        let runtime = ObservedSceneRuntime(clock: { 2 }), session = UUID()
        runtime.begin(session: session)
        runtime.offer(frame(.infinity), session: session, floor: 0, body: body, now: 2)
        runtime.offer(frame(1_000), session: session, floor: 0, body: body, now: 2)
        runtime.offer(frame(2), session: session, floor: 0, body: body, now: 2)
        try await runtime.waitForCurrentWorkForTesting()
        XCTAssertEqual(runtime.plan?.capturedAt, 2)
    }
    @MainActor func testGoalAndBodyChangesFenceQueuedPlansWithoutRetiringScene() async throws {
        let queue = DispatchQueue(label: "test.observed-scene.fence", qos: .utility)
        let runtime = ObservedSceneRuntime(clock: { 2 }, queue: queue), session = UUID()
        defer { runtime.onChange = nil }
        // Functional checks wait for the actual owner callback. The original
        // 1.2s budget remains a separate latency assertion, not a readiness oracle.
        let started = ProcessInfo.processInfo.systemUptime
        var forbiddenPublication = false
        runtime.onChange = {
            if runtime.snapshot != nil || runtime.plan != nil { forbiddenPublication = true }
        }
        runtime.begin(session: session); runtime.bindGoalRevision("first")
        queue.suspend()
        let firstAccepted = runtime.offer(frame(1), session: session, floor: 0, body: body, now: 1)
        runtime.bindGoalRevision("new trusted goal")
        let busyGoalAccepted = runtime.offer(frame(1.2), session: session, floor: 0, body: body, now: 1.2)
        queue.resume()
        XCTAssertTrue(firstAccepted); XCTAssertFalse(busyGoalAccepted)
        try await runtime.waitForCurrentWorkForTesting()
        let goalTiming = runtime.diagnosticLastWorkTimingForTesting()
        XCTAssertEqual(goalTiming?.planWasInvoked, false)
        XCTAssertFalse(forbiddenPublication)
        XCTAssertNil(runtime.plan); XCTAssertNil(runtime.snapshot)

        queue.suspend()
        let bodyAccepted = runtime.offer(frame(1.5), session: session, floor: 0, body: body, now: 1.5)
        runtime.invalidateBody()
        let busyBodyAccepted = runtime.offer(frame(1.7), session: session, floor: 0, body: body, now: 1.7)
        queue.resume()
        XCTAssertTrue(bodyAccepted); XCTAssertFalse(busyBodyAccepted)
        try await runtime.waitForCurrentWorkForTesting()
        let bodyTiming = runtime.diagnosticLastWorkTimingForTesting()
        XCTAssertEqual(bodyTiming?.planWasInvoked, false)
        XCTAssertFalse(forbiddenPublication)
        XCTAssertNil(runtime.plan); XCTAssertNil(runtime.snapshot)
        // Observe every subsequent delivery too: neither stale generation may surface.
        runtime.onChange = {
            if let snapshot = runtime.snapshot, snapshot.capturedAt != 2 { forbiddenPublication = true }
            if runtime.plan != nil { forbiddenPublication = true }
        }
        XCTAssertTrue(runtime.offer(frame(2), session: session, floor: 0, body: nil, now: 2))
        try await runtime.waitForCurrentWorkForTesting()
        let freshTiming = runtime.diagnosticLastWorkTimingForTesting()
        XCTAssertEqual(freshTiming?.planWasInvoked, false)
        XCTAssertFalse(forbiddenPublication)
        XCTAssertNotNil(runtime.snapshot); XCTAssertNil(runtime.plan)
        XCTAssertEqual(runtime.snapshot?.capturedAt, 2)
        XCTAssertEqual(runtime.liveStatus, "bodyEnvelopeUnavailable")
        let elapsed = ProcessInfo.processInfo.systemUptime - started
        if elapsed > 1.2 {
            for (phase, timing) in [("goal", goalTiming), ("body", bodyTiming), ("fresh", freshTiming)] {
                print("OBSERVED_SCENE_FENCE_PHASE phase=\(phase) \(timing?.report() ?? "timingMissing")")
            }
        }
        print("OBSERVED_SCENE_FENCE_LATENCY elapsed=\(elapsed) originalBudget=1.2 functionalCompletion=true")
        XCTAssertLessThanOrEqual(elapsed, 1.2, "Original latency budget exceeded; functional completion is not a speed claim")
    }

    @MainActor func testQueuedObsoletePlanKeepsHistoryAndNextValidPlanStillRuns() async throws {
        let queue = DispatchQueue(label: "test.observed-scene.history", qos: .utility)
        let runtime = ObservedSceneRuntime(clock: { 1.4 }, queue: queue), session = UUID()
        runtime.begin(session: session)
        queue.suspend()
        XCTAssertTrue(runtime.offer(frame(1), session: session, floor: 0, body: body, now: 1))
        runtime.invalidateBody()
        queue.resume()
        try await runtime.waitForCurrentWorkForTesting()
        let obsoleteTiming = runtime.diagnosticLastWorkTimingForTesting()
        XCTAssertEqual(obsoleteTiming?.planWasInvoked, false)
        XCTAssertNil(runtime.snapshot); XCTAssertNil(runtime.plan)

        // The obsolete plan did not cancel accumulation. A later empty current
        // frame exposes those historical hits but cannot use them as support.
        XCTAssertTrue(runtime.offer(frame(1.2, sparse: true), session: session, floor: 0, body: body, now: 1.2))
        try await runtime.waitForCurrentWorkForTesting()
        XCTAssertFalse(runtime.snapshot?.cells.isEmpty ?? true)
        XCTAssertTrue(runtime.snapshot?.cells.allSatisfy { $0.lastSeen == 1 } ?? false)
        XCTAssertEqual(runtime.diagnosticLastWorkTimingForTesting()?.planWasInvoked, true)
        XCTAssertEqual(runtime.plan?.local.state, .unknownTerrain)

        XCTAssertTrue(runtime.offer(frame(1.4), session: session, floor: 0, body: body, now: 1.4))
        try await runtime.waitForCurrentWorkForTesting()
        let currentTiming = runtime.diagnosticLastWorkTimingForTesting()
        XCTAssertEqual(currentTiming?.planWasInvoked, true)
        XCTAssertEqual(runtime.plan?.local.state, .candidatePath)
        XCTAssertEqual(runtime.plan?.capturedAt, 1.4)
        XCTAssertEqual(obsoleteTiming?.planWasInvoked, false) // Immutable earlier receipt.
        // Separate valid-work evidence: skipped obsolete plans cannot establish
        // current-plan latency. Formatting follows the actual completion fence.
        print("OBSERVED_SCENE_FENCE_PHASE phase=validCurrent \(currentTiming?.report() ?? "timingMissing")")
    }

    private final class PlanningGate: @unchecked Sendable {
        let entered: XCTestExpectation
        let release = DispatchSemaphore(value: 0)
        private let lock = NSLock()
        private var result: Bool?
        init(entered: XCTestExpectation) { self.entered = entered }
        func holdAfterRealPlan() {
            entered.fulfill()
            let released = release.wait(timeout: .now() + 5) == .success
            lock.lock(); result = released; lock.unlock()
        }
        var releasedNormally: Bool? { lock.lock(); defer { lock.unlock() }; return result }
    }

    @MainActor func testInvalidationAfterPlanningCompletesBeforeDeliveryRetainsBusySlot() async throws {
        for changeBody in [false, true] {
            let runtime = ObservedSceneRuntime(clock: { 1.2 }), session = UUID()
            let gate = PlanningGate(entered: expectation(description: "real plan computed before delivery"))
            defer { gate.release.signal(); runtime.diagnosticAfterPlanningForTesting = nil; runtime.onChange = nil }
            var forbiddenPublication = false
            runtime.onChange = {
                if runtime.snapshot != nil || runtime.plan != nil { forbiddenPublication = true }
            }
            runtime.diagnosticAfterPlanningForTesting = { gate.holdAfterRealPlan() }
            runtime.begin(session: session)
            XCTAssertTrue(runtime.offer(frame(1), session: session, floor: 0, body: body, now: 1))
            await fulfillment(of: [gate.entered], timeout: 5)
            XCTAssertNil(gate.releasedNormally)
            // Actual planCurrent has run. Hold its worker before main delivery,
            // then invalidate; this does not claim interruption inside Core.
            if changeBody { runtime.invalidateBody() } else { runtime.bindGoalRevision("replacement") }
            XCTAssertFalse(runtime.offer(frame(1.2), session: session, floor: 0, body: body, now: 1.2))
            XCTAssertNil(runtime.snapshot); XCTAssertNil(runtime.plan)
            gate.release.signal()
            try await runtime.waitForCurrentWorkForTesting()
            XCTAssertEqual(gate.releasedNormally, true)
            XCTAssertEqual(runtime.diagnosticLastWorkTimingForTesting()?.planWasInvoked, true)
            XCTAssertFalse(forbiddenPublication)
            XCTAssertNil(runtime.snapshot); XCTAssertNil(runtime.plan)

            runtime.onChange = nil; runtime.diagnosticAfterPlanningForTesting = nil
            XCTAssertTrue(runtime.offer(frame(1.2), session: session, floor: 0, body: body, now: 1.2))
            try await runtime.waitForCurrentWorkForTesting()
            XCTAssertEqual(runtime.diagnosticLastWorkTimingForTesting()?.planWasInvoked, true)
            XCTAssertEqual(runtime.plan?.local.state, .candidatePath)
            XCTAssertEqual(runtime.snapshot?.capturedAt, 1.2)
        }
    }

}
