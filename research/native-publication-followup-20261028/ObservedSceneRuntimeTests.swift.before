import XCTest
@testable import BlindCore
#if canImport(NativeScene)
@testable import NativeScene
#else
@testable import BlindAssist
#endif

final class ObservedSceneRuntimeTests: XCTestCase {
    @MainActor func testRejectedFrameDisplaysEvidenceFailureNotTrailState() async {
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
    @MainActor func testNativeRuntimeFeedsActualAccumulatorAndRejectsAbandonedCompletion() async {
        let runtime = ObservedSceneRuntime(clock: { 2 }), first = UUID(), second = UUID()
        runtime.begin(session: first)
        runtime.offer(frame(1), session: first, floor: 0, body: body, now: 1)
        runtime.stop(); runtime.begin(session: second)
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertNil(runtime.snapshot)
        runtime.offer(frame(2), session: second, floor: 0, body: body, now: 2)
        for _ in 0..<100 where runtime.snapshot == nil { try? await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertEqual(runtime.snapshot?.sessionID, second)
        XCTAssertFalse(runtime.snapshot?.cells.isEmpty ?? true)
        XCTAssertEqual(runtime.plan?.local.state, .candidatePath)
        runtime.setIntent(.returnToStart); XCTAssertNil(runtime.plan)
        runtime.trackingLost(); XCTAssertNil(runtime.snapshot)
    }
    @MainActor func testRuntimeRechecksClockAfterWorkerAndWatchdogExpiresPlan() async {
        let expired = ObservedSceneRuntime(clock: { 9 }), session = UUID()
        expired.begin(session: session); expired.offer(frame(1), session: session, floor: 0, body: body, now: 1)
        for _ in 0..<100 where expired.snapshot == nil { try? await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertNotNil(expired.snapshot); XCTAssertNil(expired.plan)
        let fresh = ObservedSceneRuntime(clock: { 1 }); fresh.begin(session: session)
        fresh.offer(frame(1), session: session, floor: 0, body: body, now: 1)
        for _ in 0..<100 where fresh.snapshot == nil { try? await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertNotNil(fresh.plan); fresh.revalidate(now: 1.6); XCTAssertNil(fresh.plan)
    }
    @MainActor func testPreLossAndPreRestartFramesCannotSeedNewScene() async {
        let runtime = ObservedSceneRuntime(clock: { 2 }), session = UUID()
        runtime.begin(session: session); runtime.trackingLost(at: 1.5)
        runtime.offer(frame(1.4), session: session, floor: 0, body: body, now: 1.6)
        try? await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertNil(runtime.snapshot); XCTAssertEqual(runtime.liveStatus, "trackingUnavailable")
        runtime.begin(session: session, capturedAfter: 2)
        runtime.offer(frame(1.9), session: session, floor: 0, body: body, now: 2)
        try? await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertNil(runtime.snapshot)
    }
    @MainActor func testRejectedFutureTimestampDoesNotPoisonLaterCapture() async {
        let runtime = ObservedSceneRuntime(clock: { 2 }), session = UUID()
        runtime.begin(session: session)
        runtime.offer(frame(.infinity), session: session, floor: 0, body: body, now: 2)
        runtime.offer(frame(1_000), session: session, floor: 0, body: body, now: 2)
        runtime.offer(frame(2), session: session, floor: 0, body: body, now: 2)
        for _ in 0..<100 where runtime.snapshot == nil { try? await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertEqual(runtime.plan?.capturedAt, 2)
    }
    @MainActor func testGoalAndBodyChangesFenceQueuedPlansWithoutRetiringScene() async {
        let queue = DispatchQueue(label: "test.observed-scene.fence", qos: .utility)
        let runtime = ObservedSceneRuntime(clock: { 2 }, queue: queue), session = UUID()
        defer { runtime.onChange = nil }
        // Preserve the original total nominal wait budget (100ms + 100ms + 1s).
        // Completion markers, rather than elapsed sleeps, establish slot retirement.
        let deadline = ProcessInfo.processInfo.systemUptime + 1.2
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
        let goalDrained = expectation(description: "old-goal worker and main delivery drained")
        queue.async { DispatchQueue.main.async { goalDrained.fulfill() } }
        await fulfillment(of: [goalDrained], timeout: max(0.001, min(1, deadline - ProcessInfo.processInfo.systemUptime)))
        XCTAssertFalse(forbiddenPublication)
        XCTAssertNil(runtime.plan); XCTAssertNil(runtime.snapshot)

        queue.suspend()
        let bodyAccepted = runtime.offer(frame(1.5), session: session, floor: 0, body: body, now: 1.5)
        runtime.invalidateBody()
        let busyBodyAccepted = runtime.offer(frame(1.7), session: session, floor: 0, body: body, now: 1.7)
        queue.resume()
        XCTAssertTrue(bodyAccepted); XCTAssertFalse(busyBodyAccepted)
        let bodyDrained = expectation(description: "old-body worker and main delivery drained")
        queue.async { DispatchQueue.main.async { bodyDrained.fulfill() } }
        await fulfillment(of: [bodyDrained], timeout: max(0.001, min(1, deadline - ProcessInfo.processInfo.systemUptime)))
        XCTAssertFalse(forbiddenPublication)
        XCTAssertNil(runtime.plan); XCTAssertNil(runtime.snapshot)
        // Observe every subsequent delivery too: neither stale generation may surface.
        runtime.onChange = {
            if let snapshot = runtime.snapshot, snapshot.capturedAt != 2 { forbiddenPublication = true }
            if runtime.plan != nil { forbiddenPublication = true }
        }
        XCTAssertTrue(runtime.offer(frame(2), session: session, floor: 0, body: nil, now: 2))
        for _ in 0..<100 where runtime.snapshot == nil && ProcessInfo.processInfo.systemUptime < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertFalse(forbiddenPublication)
        XCTAssertNotNil(runtime.snapshot); XCTAssertNil(runtime.plan)
        XCTAssertEqual(runtime.snapshot?.capturedAt, 2)
        XCTAssertEqual(runtime.liveStatus, "bodyEnvelopeUnavailable")
    }

}
