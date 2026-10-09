import XCTest
@testable import BlindCore

final class SurveyCoverageTests: XCTestCase {
    func frame(_ time: Double = 1, camera: Point3 = Point3(0, 1.3, 0), tracking: Bool = true) -> Observation {
        Observation(timestamp: time, camera: camera, forward: Point3(0, 0, -1), samples:
            [DepthSample(Point3(0.1, 0, -1)), DepthSample(Point3(0.11, 0, -1)), DepthSample(Point3(0.12, 0, -1))], trackingNormal: tracking)
    }
    func testTrailDoesNotInventFloorCoverage() {
        var tracker = SurveyCoverage(); var observation = frame(); observation.samples = []
        tracker.observe(observation, floor: 0)
        XCTAssertEqual(tracker.trail.count, 1); XCTAssertTrue(tracker.floorCells.isEmpty)
    }
    func testOnlyMeasuredFloorWithConfidenceIsMarked() {
        var tracker = SurveyCoverage(); tracker.observe(frame(), floor: 0)
        XCTAssertEqual(tracker.floorCells.count, 1)
        XCTAssertFalse(tracker.floorCells.contains(SurveyCell(x: 0, z: 0)))
        var weak = frame(1.5); weak.samples = weak.samples.map { DepthSample($0.position, confidence: 1) }
        tracker = SurveyCoverage(); tracker.observe(weak, floor: 0); XCTAssertTrue(tracker.floorCells.isEmpty)
    }
    func testLostTrackingOrJumpClearsCoordinateDependentPreview() {
        var tracker = SurveyCoverage(); tracker.observe(frame(), floor: 0)
        tracker.observe(frame(1.1, camera: Point3(20, 1.3, 0)), floor: 0)
        XCTAssertEqual(tracker.state, .needsTracking); XCTAssertTrue(tracker.floorCells.isEmpty); XCTAssertTrue(tracker.trail.isEmpty)
        tracker.observe(frame(1.2), floor: 0); tracker.observe(frame(1.3, tracking: false), floor: 0)
        XCTAssertNil(tracker.camera); XCTAssertEqual(tracker.resets, 2)
    }
    func testNoCalibrationAndElevatedReturnsStayUnknown() {
        var tracker = SurveyCoverage(); tracker.observe(frame(), floor: nil)
        XCTAssertEqual(tracker.state, .needsFloor); XCTAssertTrue(tracker.floorCells.isEmpty)
        var high = frame(1.1); high.samples = high.samples.map { DepthSample(Point3($0.position.x, 1, $0.position.z)) }
        tracker.observe(high, floor: 0); XCTAssertTrue(tracker.floorCells.isEmpty)
    }
}
