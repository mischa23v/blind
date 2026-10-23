import XCTest
@testable import BlindCore

/// Scripted controller state, not microphone, native recognition or device timing.
final class InterruptedObjectSearchTests: XCTestCase {
    private func pendingSearch(startedAt: Double = 100) -> ObjectSearch {
        var search = ObjectSearch(target: "cup", now: startedAt)
        search.attempted(now: startedAt + 1, found: nil)
        search.attempted(now: startedAt + 2, found: nil)
        search.hintTried = true
        return search
    }
    func testSpeechOnsetThenFinalAndSecondOrdinaryQuestionRetainOriginalSearch() throws {
        let original = pendingSearch()
        var receipt = InterruptedObjectSearch()
        receipt.capture(search: original, goalRevision: "cup-goal", generation: 7, now: 103)
        // The controller has cancelled live work before the final transcript arrives.
        receipt.capture(search: nil, goalRevision: "cup-goal", generation: 7, now: 105)
        receipt.capture(search: nil, goalRevision: "cup-goal", generation: 7, now: 107)
        let restored = try XCTUnwrap(receipt.restore(goalRevision: "cup-goal", generation: 7, now: 109))
        XCTAssertEqual(restored, original)
        XCTAssertEqual(restored.startedAt, 100)
        XCTAssertEqual(restored.attempts, 2)
        XCTAssertTrue(restored.hintTried)
        XCTAssertFalse(receipt.hasPending)
        XCTAssertNil(receipt.restore(goalRevision: "cup-goal", generation: 7, now: 110))
    }
    func testRepeatedInterruptionCannotExtendOriginalDeadline() throws {
        var receipt = InterruptedObjectSearch()
        receipt.capture(search: pendingSearch(), goalRevision: "cup", generation: 1, now: 103)
        let search = try XCTUnwrap(receipt.restore(goalRevision: "cup", generation: 1, now: 110))
        receipt.capture(search: search, goalRevision: "cup", generation: 1, now: 111)
        receipt.capture(search: nil, goalRevision: "cup", generation: 1, now: 119)
        XCTAssertNil(receipt.restore(goalRevision: "cup", generation: 1, now: 120))
        XCTAssertFalse(receipt.hasPending)
    }
    func testRestoreOnlyRemainingLifetimeAndAttempts() throws {
        var receipt = InterruptedObjectSearch()
        receipt.capture(search: pendingSearch(), goalRevision: "cup", generation: 1, now: 103)
        var search = try XCTUnwrap(receipt.restore(goalRevision: "cup", generation: 1, now: 119))
        XCTAssertEqual(search.attempted(now: 120, found: nil), .notLocated)
        XCTAssertEqual(search.attempts, 3)
    }
    func testExplicitPauseCancelOrSessionEndDiscardsReceipt() {
        for _ in ["pause", "cancel", "end session"] {
            var receipt = InterruptedObjectSearch()
            receipt.capture(search: pendingSearch(), goalRevision: "cup", generation: 1, now: 103)
            receipt.cancel()
            XCTAssertFalse(receipt.hasPending)
            XCTAssertNil(receipt.restore(goalRevision: "cup", generation: 1, now: 104))
        }
    }
    func testChangedGoalDoesNotResumeOldTarget() {
        var receipt = InterruptedObjectSearch()
        receipt.capture(search: pendingSearch(), goalRevision: "cup", generation: 1, now: 103)
        XCTAssertNil(receipt.restore(goalRevision: "backpack", generation: 1, now: 104))
        XCTAssertFalse(receipt.hasPending)
    }
    func testChangedSessionDoesNotResumeOldTarget() {
        var receipt = InterruptedObjectSearch()
        receipt.capture(search: pendingSearch(), goalRevision: "cup", generation: 1, now: 103)
        XCTAssertNil(receipt.restore(goalRevision: "cup", generation: 2, now: 104))
        XCTAssertFalse(receipt.hasPending)
    }
    func testNilCapturePreservesOnlyCurrentReceipt() {
        var receipt = InterruptedObjectSearch()
        receipt.capture(search: pendingSearch(), goalRevision: "cup", generation: 1, now: 103)
        receipt.capture(search: nil, goalRevision: "backpack", generation: 1, now: 104)
        XCTAssertFalse(receipt.hasPending)
    }
    func testInvalidTimesAndExpiredSearchCannotBeCapturedOrRestored() {
        for time in [Double.nan, .infinity, -.infinity, 99, 120, 130] {
            var receipt = InterruptedObjectSearch()
            receipt.capture(search: pendingSearch(), goalRevision: "cup", generation: 1, now: time)
            XCTAssertFalse(receipt.hasPending)
        }
        for time in [Double.nan, .infinity, -.infinity, 102] {
            var receipt = InterruptedObjectSearch()
            receipt.capture(search: pendingSearch(), goalRevision: "cup", generation: 1, now: 103)
            XCTAssertNil(receipt.restore(goalRevision: "cup", generation: 1, now: time))
        }
    }
    func testCompletedCancelledAndEmptySearchAreNotResumable() {
        var cancelled = pendingSearch(); cancelled.cancel()
        var found = pendingSearch(); found.attempted(now: 103, found: "cup")
        var notLocated = pendingSearch(); notLocated.attempted(now: 120, found: nil)
        for search in [cancelled, found, notLocated, ObjectSearch(target: " ", now: 100)] {
            var receipt = InterruptedObjectSearch()
            receipt.capture(search: search, goalRevision: "cup", generation: 1, now: 104)
            XCTAssertFalse(receipt.hasPending)
        }
    }
    func testRepeatedCaptureCannotReplacePendingSearchWithFreshBudget() throws {
        var receipt = InterruptedObjectSearch()
        let original = pendingSearch()
        receipt.capture(search: original, goalRevision: "cup", generation: 1, now: 103)
        receipt.capture(search: ObjectSearch(target: "cup", now: 105), goalRevision: "cup", generation: 1, now: 106)
        XCTAssertEqual(receipt.restore(goalRevision: "cup", generation: 1, now: 107), original)
    }
}
