import XCTest
@testable import BlindCore

final class CurrencyRetakeSessionTests: XCTestCase {
    typealias Session = CurrencyRetakeSession

    func testOnlyExplicitTakeCanConsumeAnAttempt() {
        var session = Session()
        XCTAssertFalse(session.isPending)
        XCTAssertFalse(session.takeRetry(frameAt: 10, now: 10))
        XCTAssertTrue(session.arm(reason: .unknown, rejectedFrameAt: 10, now: 11))
        XCTAssertTrue(session.isPending)
        XCTAssertEqual(session.retriesUsed, 0)
        XCTAssertEqual(session.expiresAt, 41)
        XCTAssertEqual(session.reason, .unknown)
    }
    func testTwoAdditionalAttemptsThenRearmingCannotResetBudget() {
        var session = Session()
        XCTAssertTrue(session.arm(reason: .unknown, rejectedFrameAt: 10, now: 11))
        for retry in 1...2 {
            let time = Double(11 + retry)
            XCTAssertTrue(session.takeRetry(frameAt: time, now: time))
            XCTAssertEqual(session.retriesUsed, retry)
            XCTAssertFalse(session.isPending)
            XCTAssertEqual(session.arm(reason: .tooSmall, rejectedFrameAt: time, now: time + 0.1), retry < 2)
            XCTAssertEqual(session.expiresAt, 41)
        }
        XCTAssertFalse(session.arm(reason: .unknown, rejectedFrameAt: 14, now: 15))
        XCTAssertFalse(session.takeRetry(frameAt: 16, now: 16))
        XCTAssertEqual(session.retriesUsed, 2)
    }
    func testSameOrOlderFrameIsRejectedWithoutSpendingAttempt() {
        var session = Session()
        XCTAssertTrue(session.arm(reason: .unknown, rejectedFrameAt: 10, now: 11))
        XCTAssertFalse(session.takeRetry(frameAt: 10, now: 12))
        XCTAssertFalse(session.takeRetry(frameAt: 9, now: 12))
        XCTAssertTrue(session.isPending)
        XCTAssertEqual(session.retriesUsed, 0)
        XCTAssertTrue(session.takeRetry(frameAt: 11, now: 12))
    }
    func testDoubleRetryBeforeResultCannotReserveAnotherAttempt() {
        var session = Session()
        session.arm(reason: .unknown, rejectedFrameAt: 10, now: 11)
        XCTAssertTrue(session.takeRetry(frameAt: 12, now: 12))
        XCTAssertFalse(session.takeRetry(frameAt: 13, now: 13))
        XCTAssertEqual(session.retriesUsed, 1)
        XCTAssertTrue(session.arm(reason: .clipped, rejectedFrameAt: 12, now: 13))
    }
    func testRearmingSameRejectedFramePreservesOriginalWindow() {
        var session = Session()
        session.arm(reason: .unknown, rejectedFrameAt: 10, now: 11)
        XCTAssertTrue(session.arm(reason: .multiple, rejectedFrameAt: 10, now: 40))
        XCTAssertEqual(session.expiresAt, 41)
        XCTAssertEqual(session.retriesUsed, 0)
        XCTAssertTrue(session.takeRetry(frameAt: 40, now: 40.9))
    }
    func testExactExpiryClosesTakeAndCannotBeRearmed() {
        var session = Session()
        session.arm(reason: .unknown, rejectedFrameAt: 10, now: 11)
        XCTAssertFalse(session.takeRetry(frameAt: 40, now: 41))
        XCTAssertFalse(session.isPending)
        XCTAssertFalse(session.arm(reason: .unknown, rejectedFrameAt: 42, now: 42))
        XCTAssertEqual(session.expiresAt, 41)
    }
    func testExpiredResultCannotRestartWindow() {
        var session = Session()
        session.arm(reason: .unknown, rejectedFrameAt: 10, now: 11)
        XCTAssertTrue(session.takeRetry(frameAt: 12, now: 12))
        XCTAssertFalse(session.arm(reason: .processingFailure, rejectedFrameAt: 12, now: 41))
        XCTAssertFalse(session.arm(reason: .unknown, rejectedFrameAt: 42, now: 43))
        XCTAssertEqual(session.retriesUsed, 1)
    }
    func testResultFromWrongFrameFailsClosed() {
        for rejected in [10.0, 13.0] {
            var session = Session()
            session.arm(reason: .unknown, rejectedFrameAt: 10, now: 11)
            XCTAssertTrue(session.takeRetry(frameAt: 12, now: 12))
            XCTAssertFalse(session.arm(reason: .unknown, rejectedFrameAt: rejected, now: 13))
            XCTAssertFalse(session.takeRetry(frameAt: 14, now: 14))
        }
    }
    func testAllRetryableReasonsArmButUnavailableClears() {
        for reason: Session.Reason in [.unknown, .tooSmall, .clipped, .multiple, .processingFailure] {
            var session = Session()
            XCTAssertTrue(session.arm(reason: reason, rejectedFrameAt: 10, now: 11))
            XCTAssertEqual(session.reason, reason)
            XCTAssertFalse(session.arm(reason: .unavailable, rejectedFrameAt: 10, now: 12))
            XCTAssertFalse(session.isPending)
            XCTAssertNil(session.expiresAt)
            XCTAssertEqual(session.retriesUsed, 0)
        }
    }
    func testClearForSuccessCancelNewTaskBackgroundHazardOrAttentionInvalidation() {
        var session = Session()
        session.arm(reason: .unknown, rejectedFrameAt: 10, now: 11)
        session.takeRetry(frameAt: 12, now: 12)
        session.clear()
        XCTAssertFalse(session.isPending)
        XCTAssertNil(session.expiresAt)
        XCTAssertNil(session.reason)
        XCTAssertEqual(session.retriesUsed, 0)
        XCTAssertFalse(session.takeRetry(frameAt: 13, now: 13))
        XCTAssertTrue(session.arm(reason: .unknown, rejectedFrameAt: 13, now: 13))
        XCTAssertEqual(session.expiresAt, 43)
    }
    func testInvalidInitialTimesFailClosedUntilExplicitClear() {
        for (frame, now) in [(Double.nan, 11.0), (10.0, Double.infinity), (-1.0, 11.0),
                             (12.0, 11.0), (0.0, -1.0), (10.0, Double.greatestFiniteMagnitude)] {
            var session = Session()
            XCTAssertFalse(session.arm(reason: .unknown, rejectedFrameAt: frame, now: now))
            XCTAssertFalse(session.isPending)
            XCTAssertFalse(session.arm(reason: .unknown, rejectedFrameAt: 20, now: 20))
        }
    }
    func testBackwardClockOnArmAndTakeFailsClosed() {
        for rearm in [false, true] {
            var session = Session()
            session.arm(reason: .unknown, rejectedFrameAt: 10, now: 11)
            if rearm { XCTAssertFalse(session.arm(reason: .unknown, rejectedFrameAt: 10, now: 10.5)) }
            else { XCTAssertFalse(session.takeRetry(frameAt: 10.2, now: 10.5)) }
            XCTAssertFalse(session.takeRetry(frameAt: 12, now: 12))
            XCTAssertFalse(session.arm(reason: .unknown, rejectedFrameAt: 12, now: 12))
        }
    }
    func testInvalidRetryTimesCloseWithoutSpendingAttempt() {
        for (frame, now) in [(Double.nan, 12.0), (Double.infinity, 12.0), (13.0, 12.0),
                             (12.0, Double.nan), (12.0, Double.infinity), (-1.0, 12.0)] {
            var session = Session()
            session.arm(reason: .unknown, rejectedFrameAt: 10, now: 11)
            XCTAssertFalse(session.takeRetry(frameAt: frame, now: now))
            XCTAssertFalse(session.isPending)
            XCTAssertEqual(session.retriesUsed, 0)
        }
    }
    func testExactEnglishArabicRetryCommandsOnly() {
        for command in ["try again", "AGAIN!", " Retry ", "try\nagain", "حاول مجدداً", "مرة ثانية؟"] {
            XCTAssertTrue(Session.isRetryCommand(command), command)
        }
        for text in ["", "not again", "don't retry", "retry the map", "try again tomorrow", "ready",
                     "please read money again", "لا تحاول مجددا", String(repeating: "x", count: 129)] {
            XCTAssertFalse(Session.isRetryCommand(text), text)
        }
    }
}
