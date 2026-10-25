import XCTest
@testable import BlindCore

final class RecordedRouteHistoryTests: XCTestCase {
    private let session = UUID()
    private func observation(_ x: Double, _ z: Double = 0, time: Double,
                             session: UUID? = nil, frame: String = "unknown-session", map: SpatialMapBinding? = nil,
                             tracking: NativeObservationRecord.Tracking = .normal) -> NativeObservationRecord {
        var columns = NativeCameraTransform.identity.columns; columns[12] = x; columns[14] = z
        return .init(sessionID: session ?? self.session, coordinateFrameID: frame, producer: .arkit,
            sourceID: "actual-frame-\(time)", mapTarget: map, capturedAt: time, receivedAt: time,
            observedAt: Date(timeIntervalSince1970: 1000 + time), tracking: tracking,
            cameraConvention: .arKitRightUpBack, cameraToSessionWorld: .init(columns: columns),
            intrinsics: .init(width: 2, height: 2, fx: 1, fy: 1, cx: 1, cy: 1), depth: nil)
    }
    func testBlankStartIncrementalGeometryRetracesDetourNotShortestRoute() throws {
        var history = RecordedRouteHistory()
        // Actual observed U-shaped path. A direct shortcut is deliberately not substituted.
        let points = [(0.0,0.0), (0.0,0.4), (0.4,0.4), (0.4,0.0)]
        for (i, point) in points.enumerated() { try history.observe(observation(point.0, point.1, time: Double(i)*0.2)) }
        let preview = try history.preview()
        XCTAssertEqual(preview.reverseSamples.map(\.cameraPosition), points.reversed().map { Point3($0.0, 0, $0.1) })
        XCTAssertTrue(preview.reachesRequestedReference)
        XCTAssertTrue(preview.reverseSamples.allSatisfy { $0.mapTarget == nil })
        XCTAssertFalse(preview.permitsPhysicalGuidance)
    }
    func testMapLayersRetainActualOrderWithoutInventedPortalOrFloor() throws {
        var history = RecordedRouteHistory()
        let room = SpatialMapBinding(mapID: "room", frameID: "room-frame", revision: "r1")
        let floor = SpatialMapBinding(mapID: "floor", frameID: "floor-frame", revision: "r1")
        let building = SpatialMapBinding(mapID: "building", frameID: "building-frame", revision: "r1")
        let targets: [SpatialMapBinding?] = [nil, room, floor, building, nil]
        for (i, target) in targets.enumerated() { try history.observe(observation(Double(i)*0.2, time: Double(i)*0.2, map: target)) }
        let preview = try history.preview()
        XCTAssertEqual(preview.reverseSamples.map(\.mapTarget), targets.reversed())
        XCTAssertEqual(preview.gaps, Array(repeating: .mapOwnershipChanged, count: 4))
        XCTAssertFalse(preview.reachesRequestedReference)
        XCTAssertFalse(preview.permitsPhysicalGuidance)
    }
    func testTrackingLossAndRestartNeverFillGapOrRebindUnknownPlace() throws {
        var history = RecordedRouteHistory()
        try history.observe(observation(0, time: 0))
        try history.observe(observation(0.2, time: 0.2, tracking: .limited))
        try history.observe(observation(0.3, time: 0.4))
        history = try RecordedRouteHistory(data: history.encoded())
        XCTAssertTrue(try history.preview().gaps.contains(.restarted))
        try history.observe(observation(100, time: 0, session: UUID(), frame: "new-unrecognized-place"))
        XCTAssertEqual(history.samples.last?.boundaryBefore, .sessionChanged)
        XCTAssertNil(history.samples.last?.mapTarget)
        XCTAssertFalse(try history.preview().permitsPhysicalGuidance)
    }
    func testInterruptionChangedGoalAndParentHandoffDoNotEraseOrAuthorizeHistory() throws {
        var history = RecordedRouteHistory()
        try history.observe(observation(0, time: 0))
        history.interrupt()
        try history.observe(observation(0.2, time: 0.2))
        XCTAssertEqual(history.samples.count, 2)
        XCTAssertEqual(history.samples.last?.boundaryBefore, .interrupted)
        XCTAssertFalse(try history.preview().permitsPhysicalGuidance)
        XCTAssertThrowsError(try history.preview(returningTo: UUID()))
    }
    func testClosedDoorOrNewObstacleCannotBeOverriddenByHistoricalPath() throws {
        var history = RecordedRouteHistory()
        try history.observe(observation(0, time: 0)); try history.observe(observation(0.2, time: 0.2))
        // History contains no clearance flag or route ticket. Even uninterrupted observations cannot authorize movement.
        XCTAssertFalse(try history.preview().permitsPhysicalGuidance)
        XCTAssertEqual(try history.preview().reverseSamples.count, 2)
    }
    func testJumpSamplingLossAndDuplicatePreserveExplicitGaps() throws {
        var history = RecordedRouteHistory()
        let first = observation(0, time: 0); try history.observe(first)
        XCTAssertThrowsError(try history.observe(first))
        try history.observe(observation(10, time: 0.2)); XCTAssertEqual(history.samples.last?.boundaryBefore, .poseJump)
        try history.observe(observation(10.2, time: 2)); XCTAssertEqual(history.samples.last?.boundaryBefore, .samplingGap)
        XCTAssertThrowsError(try history.observe(observation(10.2, time: 1)))
        XCTAssertEqual(history.pendingBoundary, .trackingLost)
    }
    func testDirectCodableDecodeValidatesAndRestoresNoLiveContinuity() throws {
        var history = RecordedRouteHistory()
        try history.observe(observation(0, time: 0)); try history.observe(observation(0.2, time: 0.2))
        let encoded = try history.encoded()
        let restored = try JSONDecoder().decode(RecordedRouteHistory.self, from: encoded)
        XCTAssertEqual(restored.pendingBoundary, .restarted)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        var samples = try XCTUnwrap(object["samples"] as? [[String: Any]])
        samples.append(samples[0]); object["samples"] = samples
        XCTAssertThrowsError(try JSONDecoder().decode(RecordedRouteHistory.self, from: JSONSerialization.data(withJSONObject: object)))
        samples.removeLast(); samples[1]["sessionID"] = UUID().uuidString; samples[1].removeValue(forKey: "boundaryBefore")
        object["samples"] = samples
        XCTAssertThrowsError(try JSONDecoder().decode(RecordedRouteHistory.self, from: JSONSerialization.data(withJSONObject: object)))
    }
    func testRecordedARKitScenesTrajectoryInvertsExtrinsicsAndPreservesHistoryOnly() throws {
        guard let path = ProcessInfo.processInfo.environment["BLIND_RECORDED_TRAJECTORY"] else {
            throw XCTSkip("Recorded dataset kept outside public repository; set BLIND_RECORDED_TRAJECTORY.")
        }
        let lines = try String(contentsOfFile: path).split(separator: "\n").prefix(100)
        var history = RecordedRouteHistory()
        for line in lines {
            let v = line.split(separator: " ").compactMap { Double($0) }
            XCTAssertEqual(v.count, 7)
            let angle = sqrt(v[1]*v[1]+v[2]*v[2]+v[3]*v[3]), a = [v[1]/angle,v[2]/angle,v[3]/angle]
            let c = cos(angle), s = sin(angle), t = 1-c
            let r: [[Double]] = [
                [t*a[0]*a[0]+c,t*a[0]*a[1]-s*a[2],t*a[0]*a[2]+s*a[1]],
                [t*a[0]*a[1]+s*a[2],t*a[1]*a[1]+c,t*a[1]*a[2]-s*a[0]],
                [t*a[0]*a[2]-s*a[1],t*a[1]*a[2]+s*a[0],t*a[2]*a[2]+c]]
            let extrinsic = NativeCameraTransform(columns: [r[0][0],r[1][0],r[2][0],0,r[0][1],r[1][1],r[2][1],0,r[0][2],r[1][2],r[2][2],0,v[4],v[5],v[6],1])
            let pose = try extrinsic.inverted()
            let record = NativeObservationRecord(sessionID: session, coordinateFrameID: "recorded-47333462",
                producer: .arkitScenesRecorded, sourceID: "trajectory-\(v[0])", capturedAt: v[0],
                poseSourceID: "lowres_wide.traj", receivedAt: nil, observedAt: nil, tracking: .notRecorded,
                cameraConvention: .pinholeRightDownForward, cameraToSessionWorld: pose,
                intrinsics: .init(width: 2, height: 2, fx: 1, fy: 1, cx: 1, cy: 1), depth: nil)
            try history.observe(record)
            let original = try extrinsic.applying(to: history.samples.last!.cameraPosition)
            XCTAssertEqual(original.distance(to: Point3(0,0,0)), 0, accuracy: 1e-8)
        }
        XCTAssertEqual(history.samples.count, 100)
        XCTAssertEqual(try history.preview().reverseSamples.map(\.observationID), history.samples.reversed().map(\.observationID))
        XCTAssertFalse(try history.preview().permitsPhysicalGuidance)
        XCTAssertTrue(history.samples.allSatisfy { $0.mapTarget == nil && $0.tracking == .notRecorded })
    }
}
