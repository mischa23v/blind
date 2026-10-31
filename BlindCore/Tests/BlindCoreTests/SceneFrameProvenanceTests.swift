import XCTest
@testable import BlindCore

final class SceneFrameProvenanceTests: XCTestCase {
    private let point = Point3(0, 1, 0)
    private func optical(_ pitch: Double) -> Point3 { Point3(0, sin(pitch), -cos(pitch)) }
    private func allows(_ original: Point3, _ current: Point3, capturedAt: Double = 10,
                        now: Double = 10.1, frameAt: Double = 10.1,
                        hazard: Hazard = .observing, tracking: Bool = true) -> Bool {
        RequestedVisualCapturePose.sceneDeliveryAllowed(capturedAt: capturedAt, now: now,
            origin: point, current: point, currentFrameAt: frameAt, hazard: hazard, tracking: tracking,
            originForward: original, currentForward: current)
    }
    func testStablePitchedViewDoesNotLoseItsLegacyYaw() {
        for degrees in [-60.0, -45, 0, 45, 60] {
            let view = optical(degrees * .pi / 180)
            XCTAssertTrue(allows(view, view), "Stable pitch \(degrees)")
        }
        let tilted = optical(-.pi / 4)
        XCTAssertFalse(SceneDelivery.allowed(capturedAt: 10, now: 10.1, origin: point, current: point,
            currentFrameAt: 10.1, hazard: .observing, tracking: true,
            originForward: tilted, currentForward: tilted), "The legacy API does not accept raw optical vectors")
    }
    func testPitchOnlyChangeIsStillRejected() {
        XCTAssertFalse(allows(optical(-.pi / 4), optical(-.pi / 3)))
        XCTAssertTrue(allows(optical(-.pi / 4), optical(-.pi / 4 + .pi / 180)))
    }
    func testNearVerticalUnknownHeadingIsNotInvented() {
        for degrees in [-90.0, -80, 80, 90] {
            let view = optical(degrees * .pi / 180)
            XCTAssertFalse(allows(view, view))
        }
    }
    func testCaptureAndCurrentFrameAgeRemainAuthoritative() {
        let view = optical(-.pi / 4)
        XCTAssertFalse(allows(view, view, capturedAt: 11))
        XCTAssertFalse(allows(view, view, capturedAt: -10))
        XCTAssertFalse(allows(view, view, frameAt: 9))
        XCTAssertFalse(allows(view, view, frameAt: 11))
        XCTAssertFalse(allows(view, view, capturedAt: .nan))
        XCTAssertFalse(allows(view, view, now: .infinity))
    }
    func testTrackingHazardAndMalformedPoseStillWithhold() {
        let view = optical(-.pi / 4)
        XCTAssertFalse(allows(view, view, tracking: false))
        XCTAssertFalse(allows(view, view, hazard: .obstacle))
        XCTAssertFalse(allows(Point3(0, 0, 0), view))
        XCTAssertFalse(allows(Point3(0, .nan, -1), view))
    }
}
