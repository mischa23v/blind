import XCTest
@testable import BlindCore

final class CameraRecoveryPolicyTests: XCTestCase {
    private typealias Policy = CameraRecoveryPolicy
    private func schedule(_ policy: inout Policy, at now: Double) -> Policy.Retry? {
        policy.schedule(now: now, foregroundActive: true, cameraEnabled: true, authorized: true)
    }
    private func claim(_ policy: inout Policy, _ retry: Policy.Retry, at now: Double) -> Bool {
        policy.claim(retry, now: now, foregroundActive: true, cameraEnabled: true, authorized: true)
    }

    func testUnstartedPolicyNeverSilentlyStartsCamera() {
        var policy = Policy()
        XCTAssertNil(schedule(&policy, at: 10))
        XCTAssertEqual(policy.attempts, 0)
    }

    func testThreeRetriesHaveExactIncreasingDelaysThenStop() throws {
        var policy = Policy(); policy.beginExplicitSession()
        var now = 10.0
        for (index, delay) in Policy.retryDelays.enumerated() {
            let retry = try XCTUnwrap(schedule(&policy, at: now))
            XCTAssertEqual(retry.attempt, index + 1)
            XCTAssertEqual(retry.scheduledAt, now)
            XCTAssertEqual(retry.readyAt, now + delay)
            XCTAssertFalse(policy.exhausted)
            XCTAssertFalse(claim(&policy, retry, at: retry.readyAt - 0.001))
            XCTAssertTrue(claim(&policy, retry, at: retry.readyAt))
            XCTAssertFalse(claim(&policy, retry, at: retry.readyAt))
            now = retry.readyAt + 0.1
        }
        XCTAssertTrue(policy.exhausted)
        XCTAssertNil(schedule(&policy, at: now))
        XCTAssertNil(policy.pendingRetry)
    }

    func testRepeatedErrorsDoNotStackOrConsumePendingRetryBudget() throws {
        var policy = Policy(); policy.beginExplicitSession()
        let retry = try XCTUnwrap(schedule(&policy, at: 10))
        for now in [10.1, 10.5, 11, 12, 15] { XCTAssertNil(schedule(&policy, at: now)) }
        XCTAssertEqual(policy.pendingRetry, retry)
        XCTAssertEqual(policy.attempts, 1)
        XCTAssertTrue(claim(&policy, retry, at: 15))
    }

    func testForegroundAndCameraOffCannotScheduleOrClaim() throws {
        for foreground in [false, true] {
            var policy = Policy(); policy.beginExplicitSession()
            XCTAssertNil(policy.schedule(now: 10, foregroundActive: foreground,
                cameraEnabled: !foreground, authorized: true))
            XCTAssertEqual(policy.attempts, 0)
            let retry = try XCTUnwrap(schedule(&policy, at: 11))
            XCTAssertFalse(policy.claim(retry, now: 13, foregroundActive: foreground,
                cameraEnabled: !foreground, authorized: true))
            XCTAssertNil(policy.pendingRetry)
            XCTAssertEqual(policy.attempts, 1)
            XCTAssertFalse(claim(&policy, retry, at: 14))
        }
    }

    func testDeniedPermissionStaysBlockedAfterOrdinaryForegroundReturn() throws {
        var policy = Policy(); policy.beginExplicitSession()
        let retry = try XCTUnwrap(schedule(&policy, at: 10))
        XCTAssertFalse(policy.claim(retry, now: 12, foregroundActive: true, cameraEnabled: true, authorized: false))
        XCTAssertTrue(policy.blocked)
        policy.pause()
        XCTAssertNil(schedule(&policy, at: 13))
        policy.observeHealthyFrame(now: 14)
        XCTAssertTrue(policy.blocked)
        policy.beginExplicitSession()
        XCTAssertFalse(policy.blocked)
        XCTAssertNotNil(schedule(&policy, at: 15))
    }

    func testUnauthorizedScheduleLatchesDenialWithoutPermissionPrompt() {
        var policy = Policy(); policy.beginExplicitSession()
        XCTAssertNil(policy.schedule(now: 10, foregroundActive: true, cameraEnabled: true, authorized: false))
        XCTAssertTrue(policy.blocked)
        XCTAssertEqual(policy.attempts, 0)
        XCTAssertNil(schedule(&policy, at: 11))
    }

    func testPauseCancelsCallbackButDoesNotReplenishBudget() throws {
        var policy = Policy(); policy.beginExplicitSession()
        let first = try XCTUnwrap(schedule(&policy, at: 10))
        policy.pause()
        XCTAssertFalse(claim(&policy, first, at: 12))
        let second = try XCTUnwrap(schedule(&policy, at: 13))
        XCTAssertEqual(second.attempt, 2)
        XCTAssertEqual(second.readyAt, 18)
        XCTAssertNotEqual(first.generation, second.generation)
    }

    func testOldCallbackCannotCancelNewerPendingRetry() throws {
        var policy = Policy(); policy.beginExplicitSession()
        let first = try XCTUnwrap(schedule(&policy, at: 10))
        policy.pause()
        let second = try XCTUnwrap(schedule(&policy, at: 11))
        XCTAssertFalse(policy.claim(first, now: .nan, foregroundActive: false, cameraEnabled: false, authorized: false))
        XCTAssertEqual(policy.pendingRetry, second)
        XCTAssertFalse(policy.blocked)
        XCTAssertTrue(claim(&policy, second, at: second.readyAt))
    }

    func testExplicitStartReplenishesExhaustedBudgetAndRetiresOldCallbacks() throws {
        var policy = Policy(); policy.beginExplicitSession()
        var last: Policy.Retry?
        for now in [10.0, 20, 30] {
            last = try XCTUnwrap(schedule(&policy, at: now))
            XCTAssertTrue(claim(&policy, last!, at: last!.readyAt))
        }
        XCTAssertTrue(policy.exhausted)
        policy.pause()
        XCTAssertTrue(policy.exhausted)
        policy.beginExplicitSession()
        let replacement = try XCTUnwrap(schedule(&policy, at: 50))
        XCTAssertEqual(replacement.attempt, 1)
        XCTAssertFalse(claim(&policy, last!, at: 51))
        XCTAssertEqual(policy.pendingRetry, replacement)
    }

    func testHealthyFrameCancelsPendingRetryWithoutImmediatelyResettingBudget() throws {
        var policy = Policy(); policy.beginExplicitSession()
        let retry = try XCTUnwrap(schedule(&policy, at: 10))
        policy.observeHealthyFrame(now: 11)
        XCTAssertNil(policy.pendingRetry)
        XCTAssertEqual(policy.attempts, 1)
        XCTAssertFalse(claim(&policy, retry, at: 12))
        let second = try XCTUnwrap(schedule(&policy, at: 13))
        XCTAssertEqual(second.attempt, 2)
    }

    func testThirtySecondsContinuousHealthyFramesReplenishBudget() throws {
        var policy = Policy(); policy.beginExplicitSession()
        let retry = try XCTUnwrap(schedule(&policy, at: 10))
        XCTAssertTrue(claim(&policy, retry, at: 12))
        for index in 0..<60 { policy.observeHealthyFrame(now: 13 + Double(index) * 0.5) }
        XCTAssertEqual(policy.attempts, 1)
        policy.observeHealthyFrame(now: 43)
        XCTAssertEqual(policy.attempts, 0)
        XCTAssertEqual(schedule(&policy, at: 44)?.attempt, 1)
    }

    func testSparseFramesAndBriefRecoveriesCannotResetBudget() throws {
        var policy = Policy(); policy.beginExplicitSession()
        let retry = try XCTUnwrap(schedule(&policy, at: 10))
        XCTAssertTrue(claim(&policy, retry, at: 12))
        for now in [13.0, 14, 30, 43, 90] { policy.observeHealthyFrame(now: now) }
        XCTAssertEqual(policy.attempts, 1)
        XCTAssertEqual(schedule(&policy, at: 91)?.attempt, 2)
    }

    func testClockInvalidationCancelsPendingWithoutRenewingBudget() throws {
        for bad in [Double.nan, .infinity, -1, 9.9] {
            var policy = Policy(); policy.beginExplicitSession()
            let retry = try XCTUnwrap(schedule(&policy, at: 10))
            XCTAssertFalse(claim(&policy, retry, at: bad))
            XCTAssertNil(policy.pendingRetry)
            XCTAssertEqual(policy.attempts, 1)
            XCTAssertFalse(claim(&policy, retry, at: 12))
            XCTAssertEqual(schedule(&policy, at: 13)?.attempt, 2)
        }
    }
}
