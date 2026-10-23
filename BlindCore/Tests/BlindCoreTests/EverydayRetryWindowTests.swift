import XCTest
@testable import BlindCore

final class EverydayRetryWindowTests: XCTestCase {
    func testFreshFrameRetryIsDelayedAndConsumedOnce() {
        var window = EverydayRetryWindow(); let id = UUID()
        window.schedule(ticketID: id, now: 10, frameAt: 10)
        XCTAssertFalse(window.takeIfReady(ticketID: id, now: 10.5, frameAt: 10.5, quiescent: true, available: true))
        XCTAssertTrue(window.takeIfReady(ticketID: id, now: 11, frameAt: 11, quiescent: true, available: true))
        XCTAssertFalse(window.isPending)
        XCTAssertFalse(window.takeIfReady(ticketID: id, now: 12, frameAt: 12, quiescent: true, available: true))
    }
    func testNewerAndFreshFrameRequired() {
        var window = EverydayRetryWindow(); let id = UUID()
        window.schedule(ticketID: id, now: 10, frameAt: 10)
        XCTAssertFalse(window.takeIfReady(ticketID: id, now: 11, frameAt: 10, quiescent: true, available: true))
        XCTAssertFalse(window.takeIfReady(ticketID: id, now: 12, frameAt: 11, quiescent: true, available: true))
        XCTAssertTrue(window.takeIfReady(ticketID: id, now: 12.5, frameAt: 12, quiescent: true, available: true))
    }
    func testBusyDefersWithoutExtendingDeadline() {
        var window = EverydayRetryWindow(); let id = UUID()
        window.schedule(ticketID: id, now: 10, frameAt: 10)
        XCTAssertFalse(window.takeIfReady(ticketID: id, now: 15, frameAt: 15, quiescent: false, available: true))
        window.schedule(ticketID: id, now: 19, frameAt: 19)
        XCTAssertFalse(window.takeIfReady(ticketID: id, now: 20.01, frameAt: 20, quiescent: true, available: true))
        XCTAssertFalse(window.isPending)
    }
    func testCancellationReplacementAndUnavailableInvalidate() {
        for mode in 0..<4 {
            var window = EverydayRetryWindow(); let id = UUID()
            window.schedule(ticketID: id, now: 10, frameAt: 10)
            if mode == 0 { window.cancel() }
            XCTAssertFalse(window.takeIfReady(ticketID: mode == 1 ? UUID() : mode == 2 ? nil : id,
                now: 11, frameAt: 11, quiescent: true, available: mode != 3))
            XCTAssertFalse(window.isPending)
        }
    }
    func testInvalidOrRegressedTimeFailsClosed() {
        for time in [Double.nan, Double.infinity, -1, 9] {
            var window = EverydayRetryWindow(); let id = UUID()
            window.schedule(ticketID: id, now: 10, frameAt: 10)
            XCTAssertFalse(window.takeIfReady(ticketID: id, now: time, frameAt: 10, quiescent: true, available: true))
            XCTAssertFalse(window.isPending)
        }
        for frame in [Double.nan, Double.infinity, -1, 12] {
            var window = EverydayRetryWindow(); let id = UUID()
            window.schedule(ticketID: id, now: 10, frameAt: 10)
            XCTAssertFalse(window.takeIfReady(ticketID: id, now: 11, frameAt: frame, quiescent: true, available: true))
            XCTAssertFalse(window.isPending)
        }
    }
    func testInvalidScheduleNeverArmsAndRepeatedScheduleDoesNotReplaceOwner() {
        var window = EverydayRetryWindow(); let id = UUID()
        window.schedule(ticketID: id, now: 10, frameAt: 11)
        XCTAssertFalse(window.isPending)
        window.schedule(ticketID: id, now: 10, frameAt: 10)
        window.schedule(ticketID: UUID(), now: 11, frameAt: 11)
        XCTAssertTrue(window.takeIfReady(ticketID: id, now: 11, frameAt: 11, quiescent: true, available: true))
    }
}
