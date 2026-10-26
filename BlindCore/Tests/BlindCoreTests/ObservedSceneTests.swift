import XCTest
@testable import BlindCore

final class ObservedSceneTests: XCTestCase {
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
    func testActualPlannerPositiveThenOccludedHistoryCannotFillLiveHole() {
        var scene = ObservedSceneAccumulator(); let session = UUID(); scene.begin(sessionID: session)
        let a = scene.observe(frame(1), sessionID: session, now: 1)
        XCTAssertFalse(a.cells.isEmpty)
        let plan = scene.plan(target: Point3(0, 0, 1.6), floor: 0, body: body, now: 1)
        XCTAssertEqual(plan.local.state, .candidatePath); XCTAssertFalse(plan.local.points.isEmpty)
        XCTAssertFalse(plan.authorizesPhysicalGuidance)
        let b = scene.observe(frame(1.1, sparse: true), sessionID: session, now: 1.1)
        XCTAssertEqual(a.cells.count, b.cells.count) // historical map still inspectable
        XCTAssertEqual(scene.plan(target: Point3(0, 0, 1.6), floor: 0, body: body, now: 1.1).local.state, .unknownTerrain)
    }
    func testFreshObstacleOverridesOldFloor() {
        var scene = ObservedSceneAccumulator(); let session = UUID(); scene.begin(sessionID: session)
        scene.observe(frame(1), sessionID: session, now: 1)
        var blocked = frame(1.1)
        for x in -30...30 { for z in 23...28 { blocked.samples.append(.init(Point3(Double(x) * 0.04, 0.7, Double(z) * 0.04))) } }
        scene.observe(blocked, sessionID: session, now: 1.1)
        XCTAssertNotEqual(scene.plan(target: Point3(0, 0, 1.6), floor: 0, body: body, now: 1.1).local.state, .candidatePath)
    }
    func testMissingFloorAndStaleFrameWithhold() {
        var scene = ObservedSceneAccumulator(); let session = UUID(); scene.begin(sessionID: session)
        scene.observe(frame(1), sessionID: session, now: 1)
        XCTAssertEqual(scene.plan(target: Point3(0, 0, 1.6), floor: nil, body: body, now: 1).local.state, .needsCalibration)
        XCTAssertEqual(scene.plan(target: Point3(0, 0, 1.6), floor: 0, body: body, now: 2).local.state, .needsPosition)
        XCTAssertEqual(scene.observe(frame(1.1), sessionID: session, now: 2).status, .stale)
    }
    func testWrongSessionCannotRetireCurrentSceneButReplayedCurrentFrameDoes() {
        var scene = ObservedSceneAccumulator(); let session = UUID(); scene.begin(sessionID: session)
        let first = scene.observe(frame(1), sessionID: session, now: 1)
        XCTAssertEqual(scene.observe(frame(2), sessionID: UUID(), now: 2).status, .wrongSession)
        XCTAssertEqual(scene.snapshot().revision, first.revision)
        XCTAssertEqual(scene.observe(frame(1), sessionID: session, now: 1).status, .outOfOrder)
        XCTAssertEqual(scene.plan(target: Point3(0, 0, 1.6), floor: 0, body: body, now: 1).local.state, .needsPosition)
    }
    func testBoundedMapAndCorrelatedPixelCount() {
        var scene = ObservedSceneAccumulator(configuration: .init(maximumCells: 10)); let session = UUID(); scene.begin(sessionID: session)
        let first = scene.observe(frame(1), sessionID: session, now: 1)
        XCTAssertEqual(first.cells.count, 10); XCTAssertGreaterThan(first.evictedCellCount, 0)
        XCTAssertTrue(first.cells.allSatisfy { $0.observations == 1 })
        var pixels = frame(1.1, sparse: true); pixels.samples = Array(repeating: .init(Point3(0, 0, 1)), count: 10)
        let second = scene.observe(pixels, sessionID: session, now: 1.1)
        XCTAssertLessThanOrEqual(second.cells.map(\.observations).max() ?? 0, 2)
    }
    func testGrowingSceneRetainedGoalAndReturnNeverTeleportObservation() {
        var scene = ObservedSceneAccumulator(); let session = UUID(); scene.begin(sessionID: session)
        scene.observe(frame(1), sessionID: session, now: 1)
        let start = scene.snapshot().startCameraPosition!
        let goal = UUID(); scene.setIntent(.destination(Point3(0, 0, 1.6)), revision: goal)
        scene.observe(frame(1.2, camera: Point3(0.5, 1, 0)), sessionID: session, now: 1.2)
        XCTAssertEqual(scene.planCurrent(floor: 0, body: body, now: 1.2)?.target, Point3(0, 0, 1.6))
        scene.setIntent(.returnToStart, revision: UUID())
        // Reuse ReturnTrail: next recorded waypoint, never shortcut to origin.
        XCTAssertEqual(scene.planCurrent(floor: 0, body: body, now: 1.2)?.target, Point3(0.5, 1, 0))
        var towardStart = frame(1.3, camera: Point3(0.5, 1, 0)); towardStart.forward = Point3(-1, 0, 0)
        scene.observe(towardStart, sessionID: session, now: 1.3, hazard: .observing)
        XCTAssertEqual(scene.planCurrent(floor: 0, body: body, now: 1.3)?.target, start)
        scene.invalidate()
        scene.observe(frame(1.4, camera: Point3(8, 1, 8)), sessionID: session, now: 1.4)
        XCTAssertNil(scene.planCurrent(floor: 0, body: body, now: 1.4)) // no rebinding old return to new origin
    }
    func testPointingStraightDownRetainsObservedHitsButNotHeadingPlan() {
        var scene = ObservedSceneAccumulator(); let session = UUID(); scene.begin(sessionID: session)
        var down = frame(1); down.forward = Point3(0, 0, 0)
        XCTAssertFalse(scene.observe(down, sessionID: session, now: 1).cells.isEmpty)
        XCTAssertEqual(scene.plan(target: Point3(0, 0, 1.6), floor: 0, body: body, now: 1).local.state, .needsPosition)
    }
    func testInvalidAndLostTrackingClearCoordinateHistory() {
        var scene = ObservedSceneAccumulator(); let session = UUID(); scene.begin(sessionID: session)
        scene.observe(frame(1), sessionID: session, now: 1)
        var lost = frame(1.1); lost.trackingNormal = false
        XCTAssertEqual(scene.observe(lost, sessionID: session, now: 1.1).status, .invalidFrame)
        XCTAssertTrue(scene.snapshot().cells.isEmpty); XCTAssertNil(scene.snapshot().startCameraPosition)
    }
    func testExtremeFiniteTargetDoesNotReachPlannerIntegerConversion() {
        var scene = ObservedSceneAccumulator(); let session = UUID(); scene.begin(sessionID: session)
        scene.observe(frame(1), sessionID: session, now: 1)
        XCTAssertEqual(scene.plan(target: Point3(1.7e308, 0, 1.7e308), floor: 0, body: body, now: 1).local.state, .needsPosition)
    }
    func testRecorderContinuityBreakRetiresEarlierSceneGeometry() {
        var scene = ObservedSceneAccumulator(); let session = UUID(); scene.begin(sessionID: session)
        scene.observe(frame(1), sessionID: session, now: 1)
        let jumped = scene.observe(frame(1.1, camera: Point3(1, 1, 0), sparse: true), sessionID: session, now: 1.1)
        XCTAssertTrue(jumped.cells.isEmpty)
        XCTAssertEqual(jumped.startCameraPosition, Point3(1, 1, 0))
        XCTAssertEqual(jumped.recordedCameraDistance, 0)
    }
}
