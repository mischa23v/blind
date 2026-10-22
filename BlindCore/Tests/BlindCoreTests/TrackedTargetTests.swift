import XCTest
@testable import BlindCore

final class TrackedTargetTests: XCTestCase {
    private let forward = Point3(0, 0, -1)

    func testProgressIsSpokenOncePerBandThenReach() {
        var target = TrackedTarget(label: "cup", query: "cup", point: Point3(0, 0, -3.5), now: 0)
        guard case .guidance(let first) = target.update(from: Point3(0, 0, 0), facing: forward, now: 0.1, arabic: false, fromCamera: false) else {
            return XCTFail("First update gives the direction")
        }
        XCTAssertTrue(first.hasPrefix("cup:"))
        XCTAssertEqual(target.update(from: Point3(0, 0, -0.1), facing: forward, now: 0.2, arabic: false, fromCamera: false), .none)
        guard case .guidance = target.update(from: Point3(0, 0, -0.6), facing: forward, now: 0.3, arabic: false, fromCamera: false) else {
            return XCTFail("Crossing 3 m is spoken")
        }
        XCTAssertEqual(target.update(from: Point3(0, 0, -0.7), facing: forward, now: 0.4, arabic: false, fromCamera: false), .none)
        guard case .reached(let reach) = target.update(from: Point3(0, 0, -3.0), facing: forward, now: 0.5, arabic: false, fromCamera: true) else {
            return XCTFail("Within 0.6 m is reach")
        }
        XCTAssertTrue(reach.hasPrefix("Within reach. From the camera:"))
    }

    func testTurningRepeatsDirectionAndLossEndsTracking() {
        var target = TrackedTarget(label: "cup", query: "cup", point: Point3(0, 0, -2.5), now: 0)
        _ = target.update(from: Point3(0, 0, 0), facing: forward, now: 0, arabic: false, fromCamera: false)
        guard case .guidance = target.update(from: Point3(0, 0, 0), facing: Point3(1, 0, 0), now: 1, arabic: false, fromCamera: false) else {
            return XCTFail("A 90 degree turn repeats the direction")
        }
        target.seen(at: Point3(0, 0, -2.5), now: 2)
        XCTAssertEqual(target.update(from: Point3(0, 0, 0), facing: Point3(1, 0, 0), now: 9, arabic: false, fromCamera: false), .none)
        guard case .lost(let lost) = target.update(from: Point3(0, 0, 0), facing: Point3(1, 0, 0), now: 10.5, arabic: false, fromCamera: false) else {
            return XCTFail("Not re-detected for 8 s ends tracking")
        }
        XCTAssertTrue(lost.hasPrefix("I can't see the cup any more."))
    }
}
