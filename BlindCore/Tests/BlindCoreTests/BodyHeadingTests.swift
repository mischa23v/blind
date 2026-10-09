import XCTest
@testable import BlindCore

final class BodyHeadingTests: XCTestCase {
    /// Horizontal direction for a yaw in degrees: 0 looks along -z, positive turns left.
    private func direction(_ degrees: Double) -> Point3 {
        let r = degrees * .pi / 180
        return Point3(-sin(r), 0, -cos(r))
    }

    /// Straight walk with one sample every 0.1 s; the camera points `cameraOffset` degrees from the walk.
    @discardableResult
    private func walk(_ e: inout BodyHeadingEstimator, from start: Point3, heading degrees: Double,
                      seconds: Double, startTime: Double, speed: Double = 1.2,
                      cameraOffset: Double = 0) -> (end: Point3, time: Double) {
        let dir = direction(degrees)
        let steps = Int((seconds / 0.1).rounded())
        var position = start, time = startTime
        for i in 0...steps {
            time = startTime + Double(i) * 0.1
            let d = speed * Double(i) * 0.1
            position = Point3(start.x + dir.x * d, start.y, start.z + dir.z * d)
            e.observe(camera: position, cameraForward: direction(degrees + cameraOffset), at: time, tracking: true)
        }
        return (position, time)
    }

    @discardableResult
    private func stand(_ e: inout BodyHeadingEstimator, at position: Point3, camera degrees: Double,
                       from startTime: Double, seconds: Double) -> Double {
        let steps = Int((seconds / 0.1).rounded())
        var time = startTime
        for i in 0...steps {
            time = startTime + Double(i) * 0.1
            e.observe(camera: position, cameraForward: direction(degrees), at: time, tracking: true)
        }
        return time
    }

    private func assertDirection(_ actual: Point3, _ expected: Point3, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.x, expected.x, accuracy: 0.02, file: file, line: line)
        XCTAssertEqual(actual.y, 0, file: file, line: line)
        XCTAssertEqual(actual.z, expected.z, accuracy: 0.02, file: file, line: line)
    }

    func testStraightWalkGivesBodyHeadingNotCameraHeading() {
        var e = BodyHeadingEstimator()
        // Walking toward +x while the chest camera points 30 degrees to one side.
        let end = walk(&e, from: Point3(2, 1, -3), heading: -90, seconds: 3, startTime: 0, cameraOffset: 30)
        let h = e.heading(at: end.time, declaredFixedMount: false)
        XCTAssertEqual(h.source, .walking)
        assertDirection(h.forward, Point3(1, 0, 0))
        XCTAssertGreaterThanOrEqual(h.confidence, 0.7)
        XCTAssertLessThanOrEqual(h.age, 0.11)
    }

    func testZigZagAndShortShuffleGiveNoConfidentHeading() {
        var zigzag = BodyHeadingEstimator()
        for i in 0...60 {
            let t = Double(i) * 0.1
            let forward = 0.6 * t
            let phase = forward.truncatingRemainder(dividingBy: 1.0)
            let x = 0.8 * (1 - abs(phase * 2 - 1))
            zigzag.observe(camera: Point3(x, 1, -forward), cameraForward: direction(0), at: t, tracking: true)
        }
        let z = zigzag.heading(at: 6, declaredFixedMount: false)
        XCTAssertTrue(z.source == .unknown || z.confidence < 0.5)

        var shuffle = BodyHeadingEstimator()
        let xs = [0.0, 0.12, 0.24, 0.36, 0.24, 0.12]
        for i in 0...60 {
            shuffle.observe(camera: Point3(xs[i % xs.count], 1, 0), cameraForward: direction(0),
                            at: Double(i) * 0.1, tracking: true)
        }
        XCTAssertEqual(shuffle.heading(at: 6, declaredFixedMount: false), .unknown)

        // A straight but short step (under 1.5 m) is not enough either.
        var short = BodyHeadingEstimator()
        let end = walk(&short, from: Point3(0, 1, 0), heading: 0, seconds: 1.0, startTime: 0)
        XCTAssertEqual(short.heading(at: end.time, declaredFixedMount: false), .unknown)
    }

    func testStoppingAgesWalkingHeadingToUnknown() {
        var e = BodyHeadingEstimator()
        let end = walk(&e, from: Point3(0, 1, 0), heading: 0, seconds: 4, startTime: 0)
        var t = stand(&e, at: end.end, camera: 0, from: end.time, seconds: 0.5)
        let fresh = e.heading(at: t, declaredFixedMount: false)
        XCTAssertEqual(fresh.source, .walking)
        assertDirection(fresh.forward, Point3(0, 0, -1))

        t = stand(&e, at: end.end, camera: 0, from: t, seconds: 9.5)
        let aged = e.heading(at: t, declaredFixedMount: false)
        XCTAssertEqual(aged.source, .walking)
        XCTAssertLessThan(aged.confidence, fresh.confidence)
        XCTAssertEqual(aged.age, 10, accuracy: 0.11)

        t = stand(&e, at: end.end, camera: 0, from: t, seconds: 11)
        XCTAssertEqual(e.heading(at: t, declaredFixedMount: false), .unknown)
        // The offset learned while walking still serves a declared fixed mount.
        XCTAssertEqual(e.heading(at: t, declaredFixedMount: true).source, .declaredMount)
    }

    func testTurningInPlaceWithoutMountDropsHeldHeading() {
        var e = BodyHeadingEstimator()
        let end = walk(&e, from: Point3(0, 1, 0), heading: 0, seconds: 4, startTime: 0)
        let t = stand(&e, at: end.end, camera: 90, from: end.time, seconds: 2)
        XCTAssertEqual(e.heading(at: t, declaredFixedMount: false), .unknown)
    }

    func testTrackingLossResets() {
        var e = BodyHeadingEstimator()
        let end = walk(&e, from: Point3(0, 1, 0), heading: 0, seconds: 4, startTime: 0)
        var t = stand(&e, at: end.end, camera: 0, from: end.time, seconds: 1)
        t += 0.1
        e.observe(camera: end.end, cameraForward: direction(0), at: t, tracking: false)
        XCTAssertEqual(e.heading(at: t, declaredFixedMount: false), .unknown)
        XCTAssertEqual(e.heading(at: t, declaredFixedMount: true), .unknown)
        XCTAssertFalse(e.mountSlipSuspected)
        // Tracking returns while standing: nothing is known until the person walks again.
        t = stand(&e, at: end.end, camera: 0, from: t + 0.1, seconds: 2)
        XCTAssertEqual(e.heading(at: t, declaredFixedMount: true), .unknown)
    }

    func testDeclaredMountGivesHeadingWhileStandingFromLearnedOffset() {
        var e = BodyHeadingEstimator()
        // Walking toward +x with the camera turned 30 degrees on the mount.
        let end = walk(&e, from: Point3(0, 1, 0), heading: -90, seconds: 5, startTime: 0, cameraOffset: 30)
        // The person turns 90 degrees left in place; the camera turns with the body.
        let t = stand(&e, at: end.end, camera: -90 + 30 + 90, from: end.time, seconds: 3)
        let h = e.heading(at: t, declaredFixedMount: true)
        XCTAssertEqual(h.source, .declaredMount)
        assertDirection(h.forward, direction(-90 + 90))
        XCTAssertFalse(e.mountSlipSuspected)
        // Without a declared mount the turn means the app does not assert a heading.
        XCTAssertEqual(e.heading(at: t, declaredFixedMount: false), .unknown)
    }

    func testSlippedMountIsFlaggedAndNotTrusted() {
        var e = BodyHeadingEstimator()
        let first = walk(&e, from: Point3(0, 1, 0), heading: 0, seconds: 6, startTime: 0)
        XCTAssertFalse(e.mountSlipSuspected)
        // The phone rotates 40 degrees on the chest and stays there while the person keeps walking.
        let second = walk(&e, from: first.end, heading: 0, seconds: 5, startTime: first.time, cameraOffset: 40)
        XCTAssertTrue(e.mountSlipSuspected)
        let t = stand(&e, at: second.end, camera: 40, from: second.time, seconds: 3)
        XCTAssertNotEqual(e.heading(at: t, declaredFixedMount: true).source, .declaredMount)
    }

    func testBriefCameraSwingIsNotTreatedAsSlip() {
        var e = BodyHeadingEstimator()
        let first = walk(&e, from: Point3(0, 1, 0), heading: 0, seconds: 6, startTime: 0)
        let swing = walk(&e, from: first.end, heading: 0, seconds: 1, startTime: first.time, cameraOffset: 40)
        walk(&e, from: swing.end, heading: 0, seconds: 4, startTime: swing.time)
        XCTAssertFalse(e.mountSlipSuspected)
    }

    func testNonFiniteInputNeverEntersEstimate() {
        var e = BodyHeadingEstimator()
        let first = walk(&e, from: Point3(0, 1, 0), heading: 0, seconds: 4, startTime: 0)
        XCTAssertEqual(e.heading(at: first.time, declaredFixedMount: false).source, .walking)

        e.observe(camera: Point3(.nan, 1, 0), cameraForward: direction(0), at: first.time + 0.1, tracking: true)
        let afterNaN = e.heading(at: first.time + 0.1, declaredFixedMount: true)
        XCTAssertEqual(afterNaN, .unknown)
        XCTAssertTrue(afterNaN.forward.isFinite)

        // A fresh walk is accepted again afterwards.
        let second = walk(&e, from: first.end, heading: 0, seconds: 4, startTime: 5)
        XCTAssertEqual(e.heading(at: second.time, declaredFixedMount: false).source, .walking)
        XCTAssertEqual(e.heading(at: .nan, declaredFixedMount: false), .unknown)

        e.observe(camera: second.end, cameraForward: Point3(0, 0, .infinity), at: second.time + 0.1, tracking: true)
        XCTAssertEqual(e.heading(at: second.time + 0.1, declaredFixedMount: false), .unknown)
        e.observe(camera: second.end, cameraForward: direction(0), at: .infinity, tracking: true)
        XCTAssertEqual(e.heading(at: second.time + 0.2, declaredFixedMount: false), .unknown)
    }
}
