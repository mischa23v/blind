import XCTest
@testable import BlindCore

final class PlaceRecoveryTests: XCTestCase {
    func testStartupAndRestartDiscardPlaceAndDelayedFrames() {
        var recovery = PlaceRecovery()
        XCTAssertEqual(recovery.state, .unknown)
        recovery.begin(candidate: "own-bedroom", now: 10)
        for i in 0..<29 { XCTAssertNil(recovery.observe(normal: true, mapped: true, now: 10 + Double(i) / 15)) }
        XCTAssertEqual(recovery.observe(normal: true, mapped: true, now: 12), "own-bedroom")
        recovery.reset()
        XCTAssertEqual(recovery.state, .unknown)
        XCTAssertNil(recovery.observe(normal: true, mapped: true, now: 13))
    }
    func testTimeoutCannotDeclareNewPlaceOrAcceptLateSuccess() {
        var recovery = PlaceRecovery(); recovery.begin(candidate: "relative-bedroom", now: 0)
        XCTAssertTrue(recovery.expire(now: 30))
        XCTAssertEqual(recovery.state, .needsHelp)
        for i in 0..<60 { XCTAssertNil(recovery.observe(normal: true, mapped: true, now: 31 + Double(i) / 15)) }
    }
    func testTrackingBreakResetsConsecutiveEvidenceAndCandidateSwitch() {
        var recovery = PlaceRecovery(); recovery.begin(candidate: "home", now: 0)
        for _ in 0..<29 { _ = recovery.observe(normal: true, mapped: true, now: 1) }
        XCTAssertNil(recovery.observe(normal: false, mapped: true, now: 2))
        XCTAssertNil(recovery.observe(normal: true, mapped: true, now: 3))
        recovery.begin(candidate: "neighbor", now: 4)
        for _ in 0..<29 { XCTAssertNil(recovery.observe(normal: true, mapped: true, now: 5)) }
        XCTAssertEqual(recovery.observe(normal: true, mapped: true, now: 6), "neighbor")
    }
}
