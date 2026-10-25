import XCTest
@testable import BlindCore
final class HeldSearchIntentTests: XCTestCase {
    func testExplicitQuietResumeRetainsTargetButNeverCachedResult() {
        var intent = HeldSearchIntent()
        XCTAssertTrue(intent.hold(target: "my backpack", goalRevision: "goal-A", origin: .trustedInterface))
        XCTAssertNil(intent.takeForFreshSearch(goalRevision: "goal-A", freshViewAvailable: true, nativeResourceIdle: true))
        XCTAssertTrue(intent.resume(origin: .trustedInterface))
        XCTAssertNil(intent.takeForFreshSearch(goalRevision: "goal-A", freshViewAvailable: false, nativeResourceIdle: true))
        XCTAssertNil(intent.takeForFreshSearch(goalRevision: "goal-A", freshViewAvailable: true, nativeResourceIdle: false))
        XCTAssertEqual(intent.takeForFreshSearch(goalRevision: "goal-A", freshViewAvailable: true, nativeResourceIdle: true), "my backpack")
        XCTAssertNil(intent.takeForFreshSearch(goalRevision: "goal-A", freshViewAvailable: true, nativeResourceIdle: true))
    }
    func testNewGoalAndUnverifiedSpeechCannotReviveHeldSearch() {
        var intent = HeldSearchIntent()
        XCTAssertFalse(intent.hold(target: "keys", goalRevision: "A", origin: .unverifiedMicrophone))
        XCTAssertFalse(intent.hasIntent)
        intent.hold(target: "keys", goalRevision: "A", origin: .trustedInterface)
        XCTAssertFalse(intent.resume(origin: .unverifiedMicrophone))
        XCTAssertTrue(intent.held)
        intent.resume(origin: .trustedInterface)
        XCTAssertNil(intent.takeForFreshSearch(goalRevision: "B", freshViewAvailable: true, nativeResourceIdle: true))
        XCTAssertFalse(intent.hasIntent)
    }
    func testRepeatedQuietWithoutNewSearchPreservesIntentAndDoesNotStartSensors() {
        var intent = HeldSearchIntent()
        intent.hold(target: "cup", goalRevision: "A", origin: .trustedInterface)
        intent.hold(target: nil, goalRevision: "A", origin: .trustedInterface)
        XCTAssertTrue(intent.hasIntent); XCTAssertTrue(intent.held)
        intent.resume(origin: .trustedInterface)
        XCTAssertEqual(intent.takeForFreshSearch(goalRevision: "A", freshViewAvailable: true, nativeResourceIdle: true), "cup")
    }
}
