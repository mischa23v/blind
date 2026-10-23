import XCTest
@testable import BlindCore

final class ColorInspectionWorkTests: XCTestCase {
    func testDirectAndContextualShareOneNativeSlot() throws {
        var work = ColorInspectionWork()
        let direct = try XCTUnwrap(work.begin(owner: .requested(UUID()), now: 10))
        XCTAssertNil(work.begin(owner: .contextual(UUID()), now: 11))
        XCTAssertNil(work.begin(owner: .requested(UUID()), now: 11))
        XCTAssertTrue(work.ownsRequested(direct))
        XCTAssertTrue(work.retireRequested(direct))
        XCTAssertFalse(work.isAvailable)
        XCTAssertTrue(work.completeNative(direct))
        let contextual = try XCTUnwrap(work.begin(owner: .contextual(UUID()), now: 12))
        XCTAssertNil(work.begin(owner: .requested(UUID()), now: 13))
        XCTAssertNil(work.expireRequested(now: 50))
        XCTAssertFalse(work.isAvailable)
        XCTAssertTrue(work.completeNative(contextual))
    }

    func testNeverReturningNativeCallEndsLogicalWaitWithoutAllowingReplacement() throws {
        var work = ColorInspectionWork()
        let lease = try XCTUnwrap(work.begin(owner: .requested(UUID()), now: 10))
        XCTAssertNil(work.expireRequested(now: 15.999))
        XCTAssertEqual(work.expireRequested(now: 16), lease)
        XCTAssertFalse(work.ownsRequested(lease))
        XCTAssertNil(work.expireRequested(now: 30))
        XCTAssertFalse(work.isAvailable)
        XCTAssertNil(work.begin(owner: .requested(UUID()), now: 100))
        XCTAssertNil(work.begin(owner: .contextual(UUID()), now: 100))
        XCTAssertTrue(work.completeNative(lease))
        XCTAssertTrue(work.isAvailable)
    }

    func testCancelledOldCompletionCannotRetireOrReleaseSuccessor() throws {
        var work = ColorInspectionWork()
        let old = try XCTUnwrap(work.begin(owner: .requested(UUID()), now: 10))
        work.cancelRequested()
        XCTAssertFalse(work.ownsRequested(old))
        XCTAssertFalse(work.isAvailable)
        XCTAssertNil(work.begin(owner: .contextual(UUID()), now: 11))
        XCTAssertTrue(work.completeNative(old))
        let successor = try XCTUnwrap(work.begin(owner: .requested(UUID()), now: 12))
        XCTAssertFalse(work.completeNative(old))
        XCTAssertFalse(work.retireRequested(old))
        XCTAssertTrue(work.ownsRequested(successor))
        XCTAssertFalse(work.isAvailable)
    }

    func testInvalidOrRegressingClockDoesNotAdmitOrExpireWork() throws {
        var work = ColorInspectionWork()
        XCTAssertNil(work.begin(owner: .requested(UUID()), now: .nan))
        let lease = try XCTUnwrap(work.begin(owner: .requested(UUID()), now: 10))
        XCTAssertNil(work.expireRequested(now: .infinity))
        XCTAssertNil(work.expireRequested(now: 9))
        XCTAssertTrue(work.ownsRequested(lease))
    }

    func testStaleLiveCompletionSettlesUnavailableButLostOwnerStaysSilent() throws {
        var work = ColorInspectionWork()
        let lease = try XCTUnwrap(work.begin(owner: .requested(UUID()), now: 10))
        XCTAssertEqual(work.completionDisposition(lease, ownerAllowed: true, captureAllowed: true), .useResult)
        XCTAssertEqual(work.completionDisposition(lease, ownerAllowed: true, captureAllowed: false), .unavailable)
        // Replacement, session, privacy and hazard failures all reject ownership.
        XCTAssertEqual(work.completionDisposition(lease, ownerAllowed: false, captureAllowed: true), .ignore)
        XCTAssertEqual(work.completionDisposition(lease, ownerAllowed: false, captureAllowed: false), .ignore)
        work.cancelRequested()
        XCTAssertEqual(work.completionDisposition(lease, ownerAllowed: true, captureAllowed: true), .ignore)
        XCTAssertFalse(work.isAvailable)
    }

    func testLateCompletionAfterTimeoutCannotDeliverTwice() throws {
        var work = ColorInspectionWork()
        let lease = try XCTUnwrap(work.begin(owner: .requested(UUID()), now: 10))
        XCTAssertEqual(work.expireRequested(now: 16), lease)
        XCTAssertEqual(work.completionDisposition(lease, ownerAllowed: true, captureAllowed: true), .ignore)
        XCTAssertTrue(work.completeNative(lease))
        XCTAssertNil(work.expireRequested(now: 100))
    }
}
