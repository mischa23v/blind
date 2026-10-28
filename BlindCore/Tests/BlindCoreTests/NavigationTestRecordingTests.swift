import XCTest
@testable import BlindCore

final class NavigationTestRecordingTests: XCTestCase {
    private let session = UUID()
    private var sampler = RecordedRouteSampler()
    private let map = SpatialMapBinding(mapID: "synthetic-room", frameID: "map-frame", revision: "r1")
    private func sample(_ time: Double, tracking: NativeObservationRecord.Tracking = .normal) throws -> RecordedRouteSample {
        return try sampler.observe(.init(sessionID: session, coordinateFrameID: "camera-frame", producer: .arkit,
            sourceID: "synthetic-\(time)", mapTarget: map, capturedAt: time, receivedAt: time,
            observedAt: Date(timeIntervalSince1970: 1000 + time), tracking: tracking,
            cameraConvention: .arKitRightUpBack, cameraToSessionWorld: .identity,
            intrinsics: .init(width: 2, height: 2, fx: 1, fy: 1, cx: 1, cy: 1), depth: nil))
    }
    private func plan(at time: Double = 0, expiry: Double = 10, aligned: Bool = true) -> NavigationTestRecording.Plan {
        .init(revision: UUID(), goalRevision: UUID(), map: map, points: [Point3(0,0,0), Point3(2,0,0)],
              alignment: aligned ? .init(sessionID: session, sourceFrameID: "camera-frame", revision: "registration-1",
                calibrationRevision: "mount-1", evidenceID: "synthetic-only", map: map, sourceToMap: .identity,
                validFrom: 0, validThrough: expiry) : nil, recordedAt: time)
    }
    func testReadOnlyConnectedRouteSnapshotUsesActualOwnerWithoutRetiringTicket() throws {
        typealias F = ConnectedFixture
        var owner = try F.prepared()
        try owner.setDestination(F.endpoint(F.a, "p"), origin: .trustedInterface, recordedAt: F.date, persist: { _ in })
        try owner.plan(from: F.endpoint(F.a, "s"), now: 1)
        let ticket = try owner.next(now: 1)
        let diagnostic = try XCTUnwrap(owner.diagnosticOwnedRoute)
        XCTAssertEqual(diagnostic.map, F.a)
        XCTAssertEqual(diagnostic.routeRevision, ticket.route.routeID)
        XCTAssertEqual(diagnostic.goalRevision, ticket.route.goalRevision)
        XCTAssertEqual(diagnostic.bodyRevision, ticket.route.bodyRevision)
        XCTAssertEqual(diagnostic.obstacleRevision, ticket.route.obstacleRevision)
        XCTAssertEqual(diagnostic.artifactSHA256, ticket.route.artifactSHA256)
        XCTAssertEqual(diagnostic.points, [Point3(1,0,3), Point3(2,0,3), Point3(3,0,3)])
        XCTAssertTrue(owner.permits(ticket, now: 1))
        try owner.cancel(origin: .trustedInterface, recordedAt: F.date, persist: { _ in })
        XCTAssertNil(owner.diagnosticOwnedRoute)
    }
    func testExplicitRecordingStopAndLateCallback() throws {
        var recording = try NavigationTestRecording(explicitStartAt: 0)
        try recording.setPlan(plan()); try recording.observe(sample(0.2), receivedAt: 0.3)
        try recording.mark(.apparentFurnitureCrossing, at: 0.4); try recording.stop(at: 0.5)
        XCTAssertThrowsError(try recording.observe(sample(0.6), receivedAt: 0.6))
        XCTAssertEqual(recording.entries.count, 1); XCTAssertEqual(recording.status, .stopped)
        XCTAssertEqual(recording.markers.first?.lastObservationID, recording.entries.first?.sample.observationID)
        XCTAssertFalse(recording.permitsPhysicalGuidance)
        XCTAssertEqual(recording.entries.first?.receivedAt, 0.3)
    }
    func testNoAlignmentNeverSnapsCameraToPlannedRoute() throws {
        var recording = try NavigationTestRecording(explicitStartAt: 0)
        try recording.setPlan(plan(aligned: false)); try recording.observe(sample(0.2), receivedAt: 0.2)
        XCTAssertNil(recording.entries[0].cameraInMap); XCTAssertTrue(recording.overlaySegments.isEmpty)
        XCTAssertEqual(recording.entries[0].sample.cameraPosition, Point3(0,0,0))
        XCTAssertEqual(recording.plans[0].points.count, 2)
    }
    func testExpiredAndLimitedAndDelayedSamplesStayUnregistered() throws {
        var recording = try NavigationTestRecording(explicitStartAt: 0)
        try recording.setPlan(plan(at: 1, expiry: 2))
        try recording.observe(sample(0.5), receivedAt: 1.1)
        try recording.observe(sample(1.2, tracking: .limited), receivedAt: 1.2)
        try recording.observe(sample(2.1), receivedAt: 2.1)
        XCTAssertTrue(recording.entries.allSatisfy { $0.cameraInMap == nil })
        XCTAssertEqual(recording.entries[1].sample.tracking, .limited)
        XCTAssertNil(recording.entries[0].planIndex)
    }
    func testRevisionAndTrackingBoundariesRemainVisible() throws {
        var recording = try NavigationTestRecording(explicitStartAt: 0)
        try recording.setPlan(plan()); try recording.observe(sample(0.2), receivedAt: 0.2)
        try recording.setPlan(plan(at: 0.3)); try recording.observe(sample(0.4), receivedAt: 0.4)
        XCTAssertEqual(recording.plans.count, 2); XCTAssertEqual(recording.overlaySegments.count, 2)
        XCTAssertNotEqual(recording.entries[0].planIndex, recording.entries[1].planIndex)
    }
    func testContinuousSamplesFormLineButUnknownAndTrackingLossBreakIt() throws {
        var recording = try NavigationTestRecording(explicitStartAt: 0)
        try recording.setPlan(plan())
        try recording.observe(sample(0.2), receivedAt: 0.2)
        try recording.observe(sample(0.4), receivedAt: 0.4)
        XCTAssertNil(recording.entries[1].sample.boundaryBefore)
        XCTAssertEqual(recording.overlaySegments.map { $0.points.count }, [2])
        try recording.setPlan(plan(at: 0.5, aligned: false))
        try recording.observe(sample(0.6), receivedAt: 0.6)
        try recording.setPlan(plan(at: 0.7))
        try recording.observe(sample(0.8), receivedAt: 0.8)
        try recording.observe(sample(1.0, tracking: .limited), receivedAt: 1.0)
        try recording.observe(sample(1.2), receivedAt: 1.2)
        XCTAssertEqual(recording.overlaySegments.map { $0.points.count }, [2, 1, 1])
        XCTAssertTrue(recording.overlaySegments.allSatisfy { $0.map == map })
    }
    func testEventCapacityStopsInsteadOfSilentlyDroppingEvidence() throws {
        var recording = try NavigationTestRecording(explicitStartAt: 0)
        for i in 0..<NavigationTestRecording.maximumEvents { try recording.mark(.other, at: Double(i)) }
        XCTAssertThrowsError(try recording.mark(.other, at: 200))
        XCTAssertEqual(recording.status, .capacityReached); XCTAssertEqual(recording.markers.count, 128)
        XCTAssertThrowsError(try recording.setPlan(plan(at: 201)))
    }
    func testCancellationRetainsOldRouteButDoesNotAssociateNewSamples() throws {
        var recording = try NavigationTestRecording(explicitStartAt: 0)
        try recording.setPlan(plan()); try recording.observe(sample(0.2), receivedAt: 0.2)
        try recording.setPlan(.init(revision: UUID(), goalRevision: UUID(), map: map,
                                    points: [], alignment: nil, recordedAt: 0.3))
        try recording.observe(sample(0.4), receivedAt: 0.4)
        XCTAssertEqual(recording.plans[0].points.count, 2)
        XCTAssertTrue(recording.plans[1].points.isEmpty)
        XCTAssertNil(recording.entries[1].cameraInMap)
    }
    func testInvalidPlanAndNonmonotonicReceiptRejected() throws {
        var recording = try NavigationTestRecording(explicitStartAt: 1)
        XCTAssertThrowsError(try recording.setPlan(plan(at: 0)))
        try recording.setPlan(plan(at: 1))
        let beforeOptIn = try sample(0.9), future = try sample(2)
        XCTAssertThrowsError(try recording.observe(future, receivedAt: 1.5)) {
            XCTAssertEqual($0 as? NavigationTestRecording.Failure, .invalidInput)
        }
        XCTAssertThrowsError(try recording.observe(beforeOptIn, receivedAt: 1.5)) {
            XCTAssertEqual($0 as? NavigationTestRecording.Failure, .invalidInput)
        }
        XCTAssertTrue(recording.entries.isEmpty)
        XCTAssertThrowsError(try recording.stop(at: .nan))
    }
}
