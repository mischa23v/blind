import XCTest
@testable import BlindCore

final class ReturnTrailTests: XCTestCase {
    func journey() -> Journey {
        var journey = Journey()
        journey.points = [JourneyPoint(seconds: 0, position: Point3(0, 1, 0), segment: 0),
                          JourneyPoint(seconds: 1, position: Point3(0, 1, -1), segment: 0),
                          JourneyPoint(seconds: 2, position: Point3(1, 1, -1), segment: 0)]
        return journey
    }
    func testRetracesCornerInOrderAndConfirmsArrival() {
        var trail = ReturnTrail()
        XCTAssertTrue(trail.begin(journey: journey(), camera: Point3(1, 1, -1), at: 10))
        let first = trail.update(camera: Point3(1, 1, -1), forward: Point3(0, 0, -1), at: 10.1, tracking: true, hazard: .observing)
        XCTAssertEqual(first?.sector, 6) // Left to the corner, not diagonally to the start.
        XCTAssertEqual(first?.remaining, 2)
        _ = trail.update(camera: Point3(0.5, 1, -1), forward: Point3(-1, 0, 0), at: 10.3, tracking: true, hazard: .observing)
        let corner = trail.update(camera: Point3(0, 1, -1), forward: Point3(-1, 0, 0), at: 10.5, tracking: true, hazard: .observing)
        XCTAssertEqual(corner?.sector, 6)
        _ = trail.update(camera: Point3(0, 1, -0.5), forward: Point3(0, 0, 1), at: 10.7, tracking: true, hazard: .observing)
        _ = trail.update(camera: Point3(0, 1, 0), forward: Point3(0, 0, 1), at: 10.9, tracking: true, hazard: .observing)
        XCTAssertEqual(trail.state, .arrived)
    }
    func testRejectsGapsTruncatedTrailsAndRemoteStartingPosition() {
        var trail = ReturnTrail(), broken = journey()
        broken.points[1].segment = 1
        XCTAssertFalse(trail.begin(journey: broken, camera: Point3(1, 1, -1), at: 1))
        XCTAssertFalse(trail.begin(journey: journey(), camera: Point3(10, 1, -1), at: 1))
        broken = journey(); broken.points[1].seconds = -1
        XCTAssertFalse(trail.begin(journey: broken, camera: Point3(1, 1, -1), at: 1))
    }
    func testHazardsPauseAndTrackingLossInvalidates() {
        var trail = ReturnTrail()
        _ = trail.begin(journey: journey(), camera: Point3(1, 1, -1), at: 1)
        XCTAssertNil(trail.update(camera: Point3(1, 1, -1), forward: Point3(0, 0, -1), at: 1.1, tracking: true, hazard: .obstacle))
        XCTAssertEqual(trail.state, .paused)
        XCTAssertNotNil(trail.update(camera: Point3(1, 1, -1), forward: Point3(0, 0, -1), at: 1.2, tracking: true, hazard: .observing))
        XCTAssertNil(trail.update(camera: Point3(1, 1, -1), forward: Point3(0, 0, -1), at: 1.3, tracking: false, hazard: .observing))
        XCTAssertEqual(trail.state, .invalidated)
    }
    func testStaleFrameAndPoseJumpNeverProduceCue() {
        for sample in [(Point3(1, 1, -1), 2.0), (Point3(10, 1, -1), 1.1)] {
            var trail = ReturnTrail()
            _ = trail.begin(journey: journey(), camera: Point3(1, 1, -1), at: 1)
            XCTAssertNil(trail.update(camera: sample.0, forward: Point3(0, 0, -1), at: sample.1, tracking: true, hazard: .observing))
            XCTAssertEqual(trail.state, .invalidated)
        }
    }
}
