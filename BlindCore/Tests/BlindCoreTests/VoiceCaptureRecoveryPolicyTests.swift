import XCTest
@testable import BlindCore

final class VoiceCaptureRecoveryPolicyTests: XCTestCase {
    func testCancelledSessionCannotRestartEvenWithBackgroundOptIn() throws {
        var policy = VoiceCaptureRecoveryPolicy()
        let session = policy.begin(continuous: true)
        let retry = try XCTUnwrap(policy.nextRetry(inBackground: false, backgroundAllowed: false, now: 0))
        policy.cancel()
        XCTAssertFalse(policy.allowsCapture(session: session, inBackground: false, backgroundAllowed: true))
        XCTAssertFalse(policy.claim(retry, inBackground: true, backgroundAllowed: true))
        XCTAssertFalse(policy.interruptionEnded(shouldResume: true))
        XCTAssertFalse(policy.requested)
    }

    func testPrivateRouteLossCancelsRecoveryEvenDuringInterruption() throws {
        var policy = VoiceCaptureRecoveryPolicy()
        let session = policy.begin(continuous: true)
        let retry = try XCTUnwrap(policy.nextRetry(inBackground: true, backgroundAllowed: true, now: 0))
        policy.interruptionBegan()
        policy.privateRouteLost()
        XCTAssertFalse(policy.requested)
        XCTAssertFalse(policy.continuous)
        XCTAssertFalse(policy.claim(retry, inBackground: true, backgroundAllowed: true))
        XCTAssertFalse(policy.interruptionEnded(shouldResume: true))
        policy.mediaServicesReset()
        XCTAssertFalse(policy.allowsCapture(session: session, inBackground: false, backgroundAllowed: true))
        XCTAssertNil(policy.nextRetry(inBackground: false, backgroundAllowed: true, now: 10))
    }

    func testPrivateRouteLossOnlyAllowsANewExplicitSession() {
        var policy = VoiceCaptureRecoveryPolicy()
        let previous = policy.begin(continuous: true)
        policy.privateRouteLost()
        policy.privateRouteLost() // Repeated hardware notifications stay stopped.
        XCTAssertFalse(policy.requested)
        // Automatic foreground/answer-window startup is not a privacy restart.
        let held = policy.begin(continuous: true)
        XCTAssertFalse(policy.requested)
        XCTAssertFalse(policy.allowsCapture(session: held, inBackground: false, backgroundAllowed: true))
        let next = policy.begin(continuous: true, explicitlyRequested: true)
        XCTAssertNotEqual(previous, next)
        XCTAssertFalse(policy.allowsCapture(session: previous, inBackground: false, backgroundAllowed: true))
        XCTAssertTrue(policy.allowsCapture(session: next, inBackground: false, backgroundAllowed: false))
    }

    func testOldPermissionAndSupersededRecoveryCannotAffectNewSession() throws {
        var policy = VoiceCaptureRecoveryPolicy()
        let oldSession = policy.begin(continuous: true)
        let oldRetry = try XCTUnwrap(policy.nextRetry(inBackground: false, backgroundAllowed: false, now: 0))
        policy.begin(continuous: true)
        XCTAssertFalse(policy.allowsCapture(session: oldSession, inBackground: false, backgroundAllowed: false))
        XCTAssertFalse(policy.claim(oldRetry, inBackground: false, backgroundAllowed: false))
        let first = try XCTUnwrap(policy.nextRetry(inBackground: false, backgroundAllowed: false, now: 1))
        let second = try XCTUnwrap(policy.nextRetry(inBackground: false, backgroundAllowed: false, now: 2))
        XCTAssertFalse(policy.claim(first, inBackground: false, backgroundAllowed: false))
        XCTAssertTrue(policy.claim(second, inBackground: false, backgroundAllowed: false))
        XCTAssertFalse(policy.claim(second, inBackground: false, backgroundAllowed: false))
    }

    func testBackgroundRequiresOptInAndManualCaptureNeverRetries() throws {
        var policy = VoiceCaptureRecoveryPolicy()
        let session = policy.begin(continuous: true)
        XCTAssertFalse(policy.allowsCapture(session: session, inBackground: true, backgroundAllowed: false))
        XCTAssertNil(policy.nextRetry(inBackground: true, backgroundAllowed: false, now: 0))
        let retry = try XCTUnwrap(policy.nextRetry(inBackground: true, backgroundAllowed: true, now: 0))
        XCTAssertFalse(policy.claim(retry, inBackground: true, backgroundAllowed: false))
        XCTAssertTrue(policy.claim(retry, inBackground: true, backgroundAllowed: true))
        policy.begin(continuous: false)
        XCTAssertNil(policy.nextRetry(inBackground: false, backgroundAllowed: true, now: 0))
    }

    func testRetriesBackOffAndStopAfterThreeUnhealthyAttempts() throws {
        var policy = VoiceCaptureRecoveryPolicy(); policy.begin(continuous: true)
        for (index, expected) in [1.0, 2.0, 4.0].enumerated() {
            policy.captureStarted(at: Double(index * 5))
            let retry = try XCTUnwrap(policy.nextRetry(inBackground: false, backgroundAllowed: false,
                                                      now: Double(index * 5 + 1)))
            XCTAssertEqual(retry.delay, expected)
            XCTAssertTrue(policy.claim(retry, inBackground: false, backgroundAllowed: false))
        }
        XCTAssertNil(policy.nextRetry(inBackground: false, backgroundAllowed: false, now: 20))
        XCTAssertFalse(policy.requested)
        XCTAssertFalse(policy.continuous)
    }

    func testStableCaptureReplenishesRetryBudget() throws {
        var policy = VoiceCaptureRecoveryPolicy(); policy.begin(continuous: true)
        _ = policy.nextRetry(inBackground: false, backgroundAllowed: false, now: 0)
        _ = policy.nextRetry(inBackground: false, backgroundAllowed: false, now: 2)
        policy.captureStarted(at: 5)
        let retry = try XCTUnwrap(policy.nextRetry(inBackground: false, backgroundAllowed: false, now: 35))
        XCTAssertEqual(retry.delay, 1)
        XCTAssertEqual(policy.attempts, 1)
    }

    func testInterruptionWaitsForResumeAndInvalidatesPendingRetry() throws {
        var policy = VoiceCaptureRecoveryPolicy()
        let session = policy.begin(continuous: true)
        let retry = try XCTUnwrap(policy.nextRetry(inBackground: false, backgroundAllowed: false, now: 0))
        policy.interruptionBegan()
        XCTAssertFalse(policy.allowsCapture(session: session, inBackground: false, backgroundAllowed: true))
        XCTAssertNil(policy.nextRetry(inBackground: false, backgroundAllowed: true, now: 2))
        XCTAssertFalse(policy.claim(retry, inBackground: false, backgroundAllowed: true))
        XCTAssertTrue(policy.interruptionEnded(shouldResume: true))
        XCTAssertTrue(policy.allowsCapture(session: session, inBackground: false, backgroundAllowed: false))
        policy.interruptionBegan()
        XCTAssertFalse(policy.interruptionEnded(shouldResume: false))
        XCTAssertFalse(policy.requested)
    }

    func testMediaResetCannotOverrideInterruptionOrCancellation() {
        var policy = VoiceCaptureRecoveryPolicy()
        let session = policy.begin(continuous: true)
        policy.mediaServicesLost()
        XCTAssertFalse(policy.allowsCapture(session: session, inBackground: false, backgroundAllowed: true))
        policy.interruptionBegan()
        policy.mediaServicesReset()
        XCTAssertFalse(policy.allowsCapture(session: session, inBackground: false, backgroundAllowed: true))
        XCTAssertTrue(policy.interruptionEnded(shouldResume: true))
        XCTAssertTrue(policy.allowsCapture(session: session, inBackground: false, backgroundAllowed: false))
        policy.cancel(); policy.mediaServicesReset()
        XCTAssertFalse(policy.allowsCapture(session: session, inBackground: false, backgroundAllowed: true))
    }

    func testFirstAcceptedPartialBeginsOnceBeforeFinalDelivery() {
        var turn = VoiceUtteranceTracker()
        XCTAssertFalse(turn.observe("  ", isEcho: false))
        XCTAssertTrue(turn.observe("Stop", isEcho: false))
        XCTAssertFalse(turn.observe("Stop talking", isEcho: false))
        XCTAssertEqual(turn.deliverable(isEcho: false), "Stop talking")
    }

    func testEchoCannotTriggerOnsetOrResurrectAfterPlaybackEnds() {
        var turn = VoiceUtteranceTracker()
        XCTAssertFalse(turn.observe("Hello friend", isEcho: true))
        XCTAssertNil(turn.deliverable(isEcho: false))
        XCTAssertFalse(turn.observe("Hello friend", isEcho: false))
        XCTAssertNil(turn.deliverable(isEcho: false))
        XCTAssertTrue(turn.observe("Where is my cup?", isEcho: false))
        XCTAssertEqual(turn.deliverable(isEcho: false), "Where is my cup?")
        XCTAssertNil(turn.deliverable(isEcho: true))
    }

    func testCorrectedEchoAndArabicHypothesesStayBoundedPerTurn() {
        var turn = VoiceUtteranceTracker()
        XCTAssertTrue(turn.observe("أين حقيبتي", isEcho: false))
        XCTAssertFalse(turn.observe("أين حقيبتي؟", isEcho: false))
        XCTAssertFalse(turn.observe("مرحباً أنا مساعدك", isEcho: true))
        XCTAssertNil(turn.deliverable(isEcho: false))
        turn = VoiceUtteranceTracker()
        XCTAssertTrue(turn.observe("توقف", isEcho: false))
    }
    func testTerminalFailureSurvivesCancelForegroundAndMediaReset() {
        var policy = VoiceCaptureRecoveryPolicy()
        let old = policy.begin(continuous: true)
        policy.requireExplicitRestart()
        XCTAssertTrue(policy.requiresExplicitRestart)
        for background in [false, true] {
            policy.cancel()
            policy.mediaServicesReset()
            let held = policy.begin(continuous: true)
            XCTAssertTrue(policy.requiresExplicitRestart)
            XCTAssertFalse(policy.requested)
            XCTAssertFalse(policy.allowsCapture(session: old, inBackground: background, backgroundAllowed: true))
            XCTAssertFalse(policy.allowsCapture(session: held, inBackground: background, backgroundAllowed: true))
            XCTAssertNil(policy.nextRetry(inBackground: background, backgroundAllowed: true, now: 100))
        }
    }

    func testExplicitRestartReplacesFailedSessionButStillObeysBackgroundPermission() {
        var policy = VoiceCaptureRecoveryPolicy()
        let old = policy.begin(continuous: true)
        policy.requireExplicitRestart()
        let next = policy.begin(continuous: true, explicitlyRequested: true)
        XCTAssertFalse(policy.requiresExplicitRestart)
        XCTAssertTrue(policy.requested)
        XCTAssertNotEqual(old, next)
        XCTAssertFalse(policy.allowsCapture(session: old, inBackground: false, backgroundAllowed: true))
        XCTAssertFalse(policy.allowsCapture(session: next, inBackground: true, backgroundAllowed: false))
        XCTAssertTrue(policy.allowsCapture(session: next, inBackground: false, backgroundAllowed: false))
    }

    func testAutomaticManualAnswerWindowCannotClearTerminalHold() {
        var policy = VoiceCaptureRecoveryPolicy()
        policy.begin(continuous: true)
        policy.requireExplicitRestart()
        policy.begin(continuous: false)
        XCTAssertTrue(policy.requiresExplicitRestart)
        XCTAssertFalse(policy.requested)
        XCTAssertFalse(policy.continuous)
    }

    func testSystemRefusalToResumeNeedsExplicitRestartNotForegroundRetry() {
        var policy = VoiceCaptureRecoveryPolicy()
        policy.begin(continuous: true)
        policy.interruptionBegan()
        XCTAssertFalse(policy.interruptionEnded(shouldResume: false))
        XCTAssertTrue(policy.requiresExplicitRestart)
        policy.begin(continuous: true)
        XCTAssertFalse(policy.requested)
        XCTAssertFalse(policy.interruptionEnded(shouldResume: true))
        policy.begin(continuous: true, explicitlyRequested: true)
        XCTAssertTrue(policy.requested)
    }

    func testExhaustedRetryBudgetCannotBeReplenishedByAutomaticBegin() throws {
        var policy = VoiceCaptureRecoveryPolicy()
        policy.begin(continuous: true)
        for now in [0.0, 1, 2] {
            let retry = try XCTUnwrap(policy.nextRetry(inBackground: false, backgroundAllowed: false, now: now))
            XCTAssertTrue(policy.claim(retry, inBackground: false, backgroundAllowed: false))
        }
        XCTAssertNil(policy.nextRetry(inBackground: false, backgroundAllowed: false, now: 3))
        XCTAssertTrue(policy.requiresExplicitRestart)
        policy.begin(continuous: true)
        XCTAssertFalse(policy.requested)
        policy.begin(continuous: true, explicitlyRequested: true)
        XCTAssertEqual(policy.attempts, 0)
        XCTAssertEqual(policy.nextRetry(inBackground: false, backgroundAllowed: false, now: 4)?.delay, 1)
    }

}
