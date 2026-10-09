import XCTest
@testable import BlindCore

final class DetectorTests: XCTestCase {
    private func floor(_ height: Double = 0, confidence: UInt8 = 2) -> [DepthSample] {
        stride(from: 0.32, through: 2.15, by: 0.08).flatMap { ahead in
            stride(from: -0.3, through: 0.3, by: 0.05).map { side in
                DepthSample(Point3(side, height, -ahead), confidence: confidence)
            }
        }
    }
    private func frame(_ time: Double, _ samples: [DepthSample], tracking: Bool = true) -> Observation {
        Observation(timestamp: time, camera: Point3(0, 1.3, 0), forward: Point3(0, 0, -1),
                    samples: samples, trackingNormal: tracking)
    }
    private func calibrated() -> HazardDetector {
        var detector = HazardDetector(); detector.beginCalibration()
        for i in 0..<15 { _ = detector.process(frame(Double(i) / 15, floor())) }
        XCTAssertEqual(detector.floorHeight, 0)
        return detector
    }
    func testRequiresExplicitCalibration() {
        var detector = HazardDetector()
        XCTAssertEqual(detector.process(frame(1, floor())).hazard, .needsCalibration)
    }
    func testCalibrationNeedsStableConsecutiveFrames() {
        var detector = HazardDetector(); detector.beginCalibration()
        for i in 0..<8 { _ = detector.process(frame(Double(i) / 15, floor())) }
        _ = detector.process(frame(0.6, []))
        XCTAssertNil(detector.floorHeight)
        XCTAssertEqual(detector.calibrationProgress, 0)
    }
    func testRejectsNonLevelFloorCalibration() {
        var detector = HazardDetector(); detector.beginCalibration()
        let slope = floor().map { DepthSample(Point3($0.position.x, -$0.position.z * 0.3, $0.position.z)) }
        for i in 0..<30 { _ = detector.process(frame(Double(i) / 15, slope)) }
        XCTAssertNil(detector.floorHeight)
    }
    func testFlatFloorIsObservingNeverSafe() {
        var detector = calibrated()
        XCTAssertEqual(detector.process(frame(1.1, floor())).hazard, .observing)
    }
    func testEmptyDepthIsUnknown() {
        var detector = calibrated()
        XCTAssertEqual(detector.process(frame(1.1, [])).hazard, .uncertain)
    }
    func testLowConfidenceCannotBecomeFloorOrDrop() {
        var detector = calibrated()
        XCTAssertEqual(detector.process(frame(1.1, floor(-0.5, confidence: 1))).hazard, .uncertain)
    }
    func testDropWarnsOnFirstCredibleFrame() {
        var detector = calibrated()
        let samples = floor().filter { -$0.position.z < 1 } + floor(-0.4).filter { -$0.position.z >= 1 }
        let result = detector.process(frame(1.1, samples))
        XCTAssertEqual(result.hazard, .drop)
        XCTAssertGreaterThan(result.distance!, 0.9)
    }
    func testSingleBadPixelCannotTriggerDrop() {
        var detector = calibrated()
        let samples = floor() + [DepthSample(Point3(0, -1, -1))]
        for i in 0..<5 { XCTAssertEqual(detector.process(frame(1.1 + Double(i) * 0.1, samples)).hazard, .observing) }
    }
    func testTrackingLossStopsMonitoringAndFreshDangerStillWarnsImmediately() {
        var detector = calibrated()
        _ = detector.process(frame(1.1, floor(-0.4)))
        _ = detector.process(frame(1.2, floor(-0.4)))
        XCTAssertEqual(detector.process(frame(1.3, floor(-0.4), tracking: false)).hazard, .uncertain)
        XCTAssertEqual(detector.process(frame(1.4, floor(-0.4))).hazard, .drop)
    }
    func testTimestampGapCannotDelayFreshDanger() {
        var detector = calibrated()
        _ = detector.process(frame(1.1, floor(-0.4)))
        _ = detector.process(frame(1.2, floor(-0.4)))
        XCTAssertEqual(detector.process(frame(3, floor(-0.4))).hazard, .drop)
    }
    func testDuplicateTimestampIsUnknown() {
        var detector = calibrated()
        _ = detector.process(frame(1.1, floor()))
        XCTAssertEqual(detector.process(frame(1.1, floor())).hazard, .uncertain)
    }
    func testNearOnlyFloorIsUnknown() {
        var detector = calibrated()
        XCTAssertEqual(detector.process(frame(1.1, floor().filter { -$0.position.z < 0.9 })).hazard, .uncertain)
    }
    func testObstacleAndOverhead() {
        for (height, expected) in [(0.7, Hazard.obstacle), (1.6, Hazard.overhead)] {
            var detector = calibrated()
            let samples = floor() + floor(height).filter { -$0.position.z < 1.2 }
            let result = detector.process(frame(1.1, samples))
            XCTAssertEqual(result.hazard, expected)
        }
    }
    func testOutOfCorridorObstacleDoesNotTrigger() {
        var detector = calibrated()
        let samples = floor() + [DepthSample(Point3(1.5, 0.5, -1))]
        XCTAssertEqual(detector.process(frame(1.1, samples)).hazard, .observing)
    }
    func testResetRemovesWorldCoordinateCalibration() {
        var detector = calibrated(); detector.reset()
        XCTAssertNil(detector.floorHeight)
        XCTAssertEqual(detector.process(frame(1.1, floor())).hazard, .needsCalibration)
    }
    func testProjectionConventionsAndScaling() {
        let projection = DepthProjection(fx: 100, fy: 100, cx: 50, cy: 40)
        XCTAssertEqual(projection.cameraPoint(column: 50, row: 40, depth: 2), Point3(0, 0, -2))
        XCTAssertEqual(projection.cameraPoint(column: 60, row: 60, depth: 2), Point3(0.2, -0.4, -2))
        XCTAssertNil(projection.cameraPoint(column: 0, row: 0, depth: .nan))
        XCTAssertNil(DepthProjection(fx: 0, fy: 1, cx: 0, cy: 0).cameraPoint(column: 1, row: 1, depth: 1))
    }
}

final class ProtocolTests: XCTestCase {
    func testBinaryRoundTripAndUnknownDistance() {
        let packet = WearablePacket(role: .belt, flags: 18, sequence: 255,
                                    distancesMM: [250, 1000, 65535, 65535, 2000, 65535, 400, 65535])
        XCTAssertEqual(packet.data.count, 20)
        XCTAssertEqual(WearablePacket(data: packet.data), packet)
        XCTAssertEqual(packet.hazard, .drop)
        XCTAssertNil(packet.detection.distance) // body range cannot locate a downward hazard
    }
    func testRejectMalformedPackets() {
        XCTAssertNil(WearablePacket(data: Data()))
        XCTAssertNil(WearablePacket(data: Data(repeating: 0, count: 20)))
        var bytes = [UInt8](repeating: 0, count: 20); bytes[0] = 1; bytes[1] = 1; bytes[2] = 128
        XCTAssertNil(WearablePacket(data: Data(bytes)))
    }
    func testFaultCannotMaskDrop() {
        let packet = WearablePacket(role: .belt, flags: 3, sequence: 1, distancesMM: Array(repeating: 65535, count: 8))
        XCTAssertEqual(packet.hazard, .drop)
        XCTAssertNil(packet.detection.distance)
    }
    func testRaisedGroundWarnsWithoutInventingDistanceFromOtherSensors() {
        let packet = WearablePacket(role: .belt, flags: 16 | 4 | 32, sequence: 1,
            distancesMM: [2000, 100, 65535, 65535, 65535, 65535, 65535, 65535])
        XCTAssertEqual(WearablePacket(data: packet.data), packet)
        XCTAssertEqual(packet.hazard, .obstacle)
        XCTAssertNil(packet.detection.distance)
        XCTAssertEqual(packet.detection.sector, 0)
        let invalid = WearablePacket(role: .belt, flags: 32, sequence: 1, distancesMM: packet.distancesMM)
        XCTAssertNil(WearablePacket(data: invalid.data))
    }
    func testFreshnessWrapReplayAndTimeout() {
        var freshness = PacketFreshness()
        func packet(_ seq: UInt8) -> WearablePacket {
            WearablePacket(role: .wrist, flags: 16, sequence: seq, distancesMM: Array(repeating: 65535, count: 8))
        }
        XCTAssertFalse(freshness.isFresh(at: 0))
        XCTAssertTrue(freshness.accept(packet(255), at: 1))
        XCTAssertTrue(freshness.accept(packet(0), at: 1.1))
        XCTAssertFalse(freshness.accept(packet(0), at: 1.2))
        XCTAssertFalse(freshness.accept(packet(255), at: 1.3))
        XCTAssertFalse(freshness.isFresh(at: 2))
    }
    func testCommandClamping() {
        XCTAssertEqual(Array(WearableCommand.haptic(sector: 90, durationMS: 9999)), [1, 1, 7, 170, 50, 0])
        XCTAssertEqual(WearableCommand.calibrate.count, 6)
    }
    func testAlertPriorityAndRateLimits() {
        XCTAssertEqual(AlertPolicy.highest([Detection(.uncertain), Detection(.drop), Detection(.obstacle)]).hazard, .drop)
        var policy = AlertPolicy()
        XCTAssertTrue(policy.shouldAnnounce(.drop, at: 0))
        XCTAssertFalse(policy.shouldAnnounce(.drop, at: 0.5))
        XCTAssertTrue(policy.shouldAnnounce(.drop, at: 2))
        XCTAssertFalse(policy.shouldAnnounce(.observing, at: 3))
    }
}

final class MappingTests: XCTestCase {
    private func node(_ id: String) -> MapNode { MapNode(id: id, name: id, level: "0", position: Point3(0, 0, 0)) }
    func testShortestAccessibleRoute() throws {
        let map = IndoorMap(name: "Center", nodes: [node("a"), node("b"), node("c")], edges: [
            MapEdge(from: "a", to: "b", distance: 2), MapEdge(from: "b", to: "c", distance: 2),
            MapEdge(from: "a", to: "c", distance: 1, accessible: false)])
        XCTAssertEqual(try map.route(from: "a", to: "c").map(\.id), ["a", "b", "c"])
        XCTAssertEqual(try map.route(from: "c", to: "a", accessibleOnly: false).map(\.id), ["c", "a"])
        XCTAssertEqual(try map.route(from: "a", to: "a").map(\.id), ["a"])
    }
    func testInvalidMapsAndDisconnectedRoutes() {
        XCTAssertThrowsError(try IndoorMap(name: "bad", nodes: [node("a"), node("a")], edges: []).validate())
        XCTAssertThrowsError(try IndoorMap(name: "bad", nodes: [node("a")], edges: [MapEdge(from: "a", to: "b", distance: -1)]).validate())
        XCTAssertThrowsError(try IndoorMap(name: "disconnected", nodes: [node("a"), node("b")], edges: []).route(from: "a", to: "b"))
    }
    func testNoComparisonBeforeRelocalization() {
        let old = MappedObject(id: "old", category: "chair", center: Point3(0, 0, 0))
        let new = MappedObject(id: "new", category: "chair", center: Point3(1, 0, 0))
        XCTAssertEqual(PlaceComparison.changes(baseline: [old], current: [new], relocalized: false), [])
        XCTAssertEqual(PlaceComparison.changes(baseline: [old], current: [new], relocalized: true), [.moved(category: "chair", distance: 1)])
    }
    func testMissingObjectsAreNotDeclaredRemoved() {
        let old = MappedObject(id: "old", category: "chair", center: Point3(0, 0, 0))
        XCTAssertEqual(PlaceComparison.changes(baseline: [old], current: [], relocalized: true), [.notObserved(category: "chair")])
    }
    func testIMDFPointImport() throws {
        let json = #"{"type":"FeatureCollection","features":[{"id":"door","geometry":{"type":"Point","coordinates":[46.7,24.7]},"properties":{"name":{"en":"Door"},"level_id":"0"}}]}"#
        let nodes = try IMDFImporter.landmarks(from: Data(json.utf8), originLatitude: 24.7, originLongitude: 46.7)
        XCTAssertEqual(nodes.first?.name, "Door")
        XCTAssertEqual(nodes.first?.position, Point3(0, 0, -0))
    }
}
