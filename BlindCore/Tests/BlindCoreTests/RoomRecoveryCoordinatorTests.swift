import XCTest
@testable import BlindCore

final class RoomRecoveryCoordinatorTests: XCTestCase {
    private func place(_ id: String, image: Double? = nil, at: Double? = nil,
                       distance: Double? = nil, previous: Bool = false) -> RoomRecoveryCandidate {
        RoomRecoveryCandidate(placeID: id, roomID: "place:" + id, appearanceScore: image,
                              appearanceObservedAt: at, distanceMetres: distance, isPreviousRoom: previous)
    }
    func testAppearanceOutranksNearestGPSButDoesNotIdentify() {
        var recovery = RoomRecoveryCoordinator()
        let next = recovery.next(candidates: [place("near", distance: 1), place("seen", image: 0.9, at: 0, distance: 100)], now: 0)
        XCTAssertEqual(next?.placeID, "seen")
        XCTAssertEqual(recovery.state, next.map(RoomRecoveryCoordinator.State.trying))
    }
    func testRepeatedFramesDoNotRestartOrInflateAttempts() {
        var recovery = RoomRecoveryCoordinator()
        let candidates = [place("a", distance: 5)]
        let initial = recovery.next(candidates: candidates, now: 0)
        for i in 1...100 { XCTAssertNil(recovery.next(candidates: candidates, now: Double(i) / 10)) }
        XCTAssertEqual(recovery.attempts, 1)
        XCTAssertEqual(recovery.state, initial.map(RoomRecoveryCoordinator.State.trying))
    }
    func testTimeoutBackoffTriesNextNotSameMap() {
        var recovery = RoomRecoveryCoordinator(attemptTimeout: 5, backoff: 2)
        let candidates = [place("a", distance: 1), place("b", distance: 2)]
        XCTAssertEqual(recovery.next(candidates: candidates, now: 0)?.placeID, "a")
        XCTAssertNil(recovery.next(candidates: candidates, now: 5))
        XCTAssertNil(recovery.next(candidates: candidates, now: 6))
        XCTAssertEqual(recovery.next(candidates: candidates, now: 7)?.placeID, "b")
    }
    func testBudgetTerminalAndNoticeOnlyOnce() {
        var recovery = RoomRecoveryCoordinator(maximumAttempts: 1)
        let attempt = recovery.next(candidates: [place("a", distance: 0)], now: 0)!
        recovery.failed(attemptID: attempt.id, now: 1)
        XCTAssertEqual(recovery.state, .exhausted)
        XCTAssertTrue(recovery.takeExhaustionNotice()); XCTAssertFalse(recovery.takeExhaustionNotice())
        XCTAssertNil(recovery.next(candidates: [place("b", image: 1, at: 2)], now: 2))
    }
    func testUnknownAndPreviousRoomAloneDoNotResetCamera() {
        var recovery = RoomRecoveryCoordinator(episodeTimeout: 10)
        XCTAssertNil(recovery.next(candidates: [place("a", previous: true)], now: 0))
        XCTAssertEqual(recovery.attempts, 0)
        XCTAssertNil(recovery.next(candidates: [], now: 10))
        XCTAssertEqual(recovery.state, .exhausted)
    }
    func testStaleFutureInvalidAppearanceIgnored() {
        let invalid = [place("stale", image: 1, at: 0), place("future", image: 1, at: 11),
                       place("nan", image: .nan, at: 10), place("over", image: 1.01, at: 10),
                       place("negative", distance: -1), place("far", distance: 151)]
        XCTAssertTrue(RoomRecoveryCoordinator.rank(invalid, now: 10).isEmpty)
    }
    func testSuccessfulRecoveryNeedsCurrentTokenPlaceAndVerifiedFrame() {
        var recovery = RoomRecoveryCoordinator()
        let attempt = recovery.next(candidates: [place("a", distance: 0)], now: 0)!
        XCTAssertFalse(recovery.recovered(attemptID: UUID(), placeID: "a", frameVerified: true, now: 1))
        XCTAssertFalse(recovery.recovered(attemptID: attempt.id, placeID: "b", frameVerified: true, now: 1))
        XCTAssertFalse(recovery.recovered(attemptID: attempt.id, placeID: "a", frameVerified: false, now: 1))
        XCTAssertTrue(recovery.recovered(attemptID: attempt.id, placeID: "a", frameVerified: true, now: 1))
        XCTAssertEqual(recovery.state, .recovered("a"))
        XCTAssertNil(recovery.next(candidates: [place("b", distance: 0)], now: 2))
    }
    func testStaleCompletionAfterResetRejected() {
        var recovery = RoomRecoveryCoordinator()
        let old = recovery.next(candidates: [place("a", distance: 0)], now: 0)!
        recovery.reset()
        let newer = recovery.next(candidates: [place("a", distance: 0)], now: 2)!
        XCTAssertNotEqual(old.id, newer.id)
        XCTAssertFalse(recovery.recovered(attemptID: old.id, placeID: "a", frameVerified: true, now: 3))
    }
    func testRemovedCandidateCancelsOldAttemptBeforeAnotherTry() {
        var recovery = RoomRecoveryCoordinator(backoff: 1)
        let old = recovery.next(candidates: [place("a", distance: 0)], now: 0)!
        XCTAssertNil(recovery.next(candidates: [place("b", distance: 0)], now: 1))
        XCTAssertFalse(recovery.recovered(attemptID: old.id, placeID: "a", frameVerified: true, now: 1))
        XCTAssertEqual(recovery.next(candidates: [place("b", distance: 0)], now: 2)?.placeID, "b")
    }
    func testClockRollbackStopsAttempts() {
        var recovery = RoomRecoveryCoordinator()
        _ = recovery.next(candidates: [place("a", distance: 0)], now: 2)
        XCTAssertNil(recovery.next(candidates: [place("b", distance: 0)], now: 1))
        XCTAssertEqual(recovery.state, .exhausted)
    }
    func testDuplicatePlaceCannotConsumeTwoAttempts() {
        var recovery = RoomRecoveryCoordinator(backoff: 1)
        let candidates = [place("a", image: 0.9, at: 0), place("a", distance: 0)]
        let attempt = recovery.next(candidates: candidates, now: 0)!
        recovery.failed(attemptID: attempt.id, now: 1)
        XCTAssertNil(recovery.next(candidates: candidates, now: 3))
        XCTAssertEqual(recovery.attempts, 1)
    }
    func testLateSuccessAfterAttemptDeadlineRejected() {
        var recovery = RoomRecoveryCoordinator(attemptTimeout: 5)
        let attempt = recovery.next(candidates: [place("a", distance: 0)], now: 0)!
        XCTAssertFalse(recovery.recovered(attemptID: attempt.id, placeID: "a", frameVerified: true, now: 5))
    }
    func testBusyDeferralDoesNotConsumeAttemptOrExtendEpisode() {
        var recovery = RoomRecoveryCoordinator(episodeTimeout: 10)
        let candidates = [place("a", distance: 0)]
        XCTAssertNil(recovery.next(candidates: candidates, now: 0, allowNewAttempt: false))
        XCTAssertNil(recovery.next(candidates: candidates, now: 9, allowNewAttempt: false))
        XCTAssertEqual(recovery.attempts, 0)
        XCTAssertNil(recovery.next(candidates: candidates, now: 10, allowNewAttempt: true))
        XCTAssertEqual(recovery.state, .exhausted)
    }
    func testBusyDeferralStillExpiresActiveAttemptAndRejectsLateCompletion() {
        var recovery = RoomRecoveryCoordinator(attemptTimeout: 5)
        let candidates = [place("a", distance: 0), place("b", distance: 1)]
        let first = recovery.next(candidates: candidates, now: 0)!
        XCTAssertNil(recovery.next(candidates: candidates, now: 5, allowNewAttempt: false))
        XCTAssertEqual(recovery.state, .waiting)
        XCTAssertFalse(recovery.recovered(attemptID: first.id, placeID: "a", frameVerified: true, now: 6))
        XCTAssertEqual(recovery.next(candidates: candidates, now: 8)?.placeID, "b")
    }
}
