import XCTest
import BlindCore
@testable import BlindAssist

/// Deterministic result-policy tests, not Foundation Models acceptance.
/// No model, asset download, network, or microphone is used.
final class ConversationRuntimeFailureTests: XCTestCase {
    func testRuntimeFailureNeverMasqueradesAsGeneratedContent() {
        for failure in [LocalImageAnswer.ConversationRuntimeFailure.generationFailed, .modelUnavailable] {
            for arabic in [false, true] {
                let answer = LocalImageAnswer.conversationFailure(failure, arabic: arabic)
                XCTAssertNil(answer.text)
                XCTAssertNil(answer.taskUpdate)
                XCTAssertEqual(answer.conversationRuntimeFailure, failure)
                XCTAssertEqual(answer.conversationOperationalFallback, answer.status)
                XCTAssertFalse(answer.status.isEmpty)
                if failure == .modelUnavailable {
                    // Preserve the pre-existing unavailable-provider contract;
                    // operational metadata must not change its public wording.
                    let expected = arabic
                        ? "نموذج المحادثة غير متاح على هذا الجهاز. لا يلزم اشتراك أو مفتاح API."
                        : "The on-device conversation model is unavailable on this device. No subscription or API key is needed."
                    XCTAssertEqual(answer.status, expected)
                    XCTAssertEqual(answer.conversationOperationalFallback, expected)
                }
            }
        }
    }
    func testGenerationFallbackIsLocalizedAndDoesNotBlameTheQuestion() {
        XCTAssertEqual(LocalImageAnswer.conversationFailure(.generationFailed, arabic: false).conversationOperationalFallback,
                       "I couldn't finish an on-device reply just now.")
        XCTAssertEqual(LocalImageAnswer.conversationFailure(.generationFailed, arabic: true).conversationOperationalFallback,
                       "تعذر إكمال الرد على الجهاز الآن.")
    }
    func testEvidenceRefusalAndCancellationAreNotRuntimeFailure() {
        for answer in [
            LocalImageAnswer(text: "I can't verify that.", status: "Unsupported local claim withheld; current evidence is unknown."),
            LocalImageAnswer(text: nil, status: "Conversation interrupted."),
            LocalImageAnswer(text: nil, status: "That request exceeds the local context budget. Try a shorter question.")
        ] {
            XCTAssertNil(answer.conversationRuntimeFailure)
            XCTAssertNil(answer.conversationOperationalFallback)
        }
    }
    func testExistingTextIsNeverReplacedOrReplayedByOperationalFallback() {
        let answer = LocalImageAnswer(text: "Already delivered.", status: "failure", conversationRuntimeFailure: .generationFailed)
        XCTAssertNil(answer.conversationOperationalFallback)
        XCTAssertEqual(answer.text, "Already delivered.")
    }
}

/// Executes the exact Feedback permission hook used before enqueue, platform
/// start and watchdog. It does not start AVFoundation playback or a sensor.
@MainActor
final class ModelResponseDeliveryTests: XCTestCase {
    private func fixture() throws -> (ModelResponseAuthority, ModelResponseAuthority.Binding, ModelResponseAuthority.Lease) {
        var authority = ModelResponseAuthority()
        let binding = ModelResponseAuthority.Binding(requestID: UUID(), sessionGeneration: 1, goalRevision: "test-goal")
        authority.begin(question: "Tell me a joke.", binding: binding, at: 10)
        let lease = try XCTUnwrap(authority.admit("I enjoy jokes.", binding: binding, createdAt: 10, now: 10))
        return (authority, binding, lease)
    }
    func testMissingDeliveryOwnerRejectsGeneratedTextWithoutAudio() throws {
        let (_, _, lease) = try fixture()
        XCTAssertFalse(Feedback().modelReplyIsCurrent(lease, text: lease.text))
    }
    func testExactCurrentConversationPassesFinalHookButBorrowedWordsDoNot() throws {
        let (authority, binding, lease) = try fixture(), feedback = Feedback()
        feedback.modelReplyPermission = { lease, text in authority.permits(lease, text: text, binding: binding, now: 11) }
        XCTAssertTrue(feedback.modelReplyIsCurrent(lease, text: lease.text))
        for text in ["Head straight.", "كمل على طول.", "Yes.", "نعم."] {
            XCTAssertFalse(feedback.modelReplyIsCurrent(lease, text: text), text)
        }
    }
    func testQueueDelayAndRepeatUseOriginalDeadlineAtFinalHook() throws {
        let (authority, binding, lease) = try fixture(), feedback = Feedback()
        var now = 11.0
        feedback.modelReplyPermission = { lease, text in authority.permits(lease, text: text, binding: binding, now: now) }
        XCTAssertTrue(feedback.modelReplyIsCurrent(lease, text: lease.text))
        now = 40
        XCTAssertFalse(feedback.modelReplyIsCurrent(lease, text: lease.text))
        now = 41
        XCTAssertFalse(feedback.modelReplyIsCurrent(lease, text: lease.text))
        XCTAssertEqual(lease.expiresAt, 40)
    }
    func testPlaybackTimeoutUsesOriginalModelDeadlineWithoutCameraTicks() throws {
        let (_, _, lease) = try fixture()
        XCTAssertEqual(Feedback.outputTimeoutInterval(modelReply: lease, now: 11), 29)
        XCTAssertEqual(Feedback.outputTimeoutInterval(modelReply: lease, now: 39), 1)
        XCTAssertEqual(Feedback.outputTimeoutInterval(modelReply: lease, now: 40), 0)
        XCTAssertEqual(Feedback.outputTimeoutInterval(modelReply: lease, now: 45), 0)
        XCTAssertEqual(Feedback.outputTimeoutInterval(modelReply: nil, now: 11), 120)
    }
    func testNewSessionRejectsOldQueuedReplyAtFinalHook() throws {
        let (authority, binding, lease) = try fixture(), feedback = Feedback()
        let next = ModelResponseAuthority.Binding(requestID: binding.requestID, sessionGeneration: 2, goalRevision: binding.goalRevision)
        feedback.modelReplyPermission = { lease, text in authority.permits(lease, text: text, binding: next, now: 11) }
        XCTAssertFalse(feedback.modelReplyIsCurrent(lease, text: lease.text))
    }
    func testPhysicalOwnerCannotBeSatisfiedByAnOlderConversationLease() throws {
        var (authority, binding, lease) = try fixture()
        let feedback = Feedback()
        authority.begin(question: "How do I continue to the kitchen?", binding: binding, at: 10)
        feedback.modelReplyPermission = { lease, text in authority.permits(lease, text: text, binding: binding, now: 11) }
        XCTAssertFalse(feedback.modelReplyIsCurrent(lease, text: lease.text))
    }
}

/// Hosted controller/sink regressions with injected model results. The DEBUG
/// seam is available only to XCTest in text-only mode. It enters the production
/// display, queue, drain, delivery and delayed-start checks, but substitutes a
/// silent platform sink: no model, camera, microphone, route or audio runs.
@MainActor
final class NavigationModelResponseSinkTests: XCTestCase {
    private let ordinaryText = "I enjoy jokes."

    private func fixture(question: String = "Tell me a joke.", at now: Double,
                         file: StaticString = #filePath, line: UInt = #line) -> NavigationModel {
        let model = NavigationModel()
        XCTAssertTrue(model.textOnly, file: file, line: line)
        XCTAssertTrue(model.debugBeginModelResponseTest(question: question, at: now), file: file, line: line)
        return model
    }

    private func assertHistorical(_ displayed: String, original: String,
                                  file: StaticString = #filePath, line: UInt = #line) {
        // Do not assume the simulator's saved language preference. The complete
        // original ordinary conversation remains readable with a new label.
        XCTAssertTrue(displayed.contains(original), file: file, line: line)
        XCTAssertNotEqual(displayed, original, file: file, line: line)
    }

    private func assertEmptySink(_ model: NavigationModel,
                                 file: StaticString = #filePath, line: UInt = #line) {
        let snapshot = model.debugModelResponseSinkSnapshot
        XCTAssertTrue(snapshot.queued.isEmpty, file: file, line: line)
        XCTAssertTrue(snapshot.started.isEmpty, file: file, line: line)
        XCTAssertFalse(snapshot.active, file: file, line: line)
        XCTAssertEqual(snapshot.pending, 0, file: file, line: line)
    }

    func testOrdinaryChatReachesRealQueueAndDelayedStartThroughSilentSink() {
        let now = ProcessInfo.processInfo.systemUptime
        let model = fixture(at: now)
        defer { model.debugCancelModelResponseTest() }
        XCTAssertTrue(model.debugInjectModelResponse(ordinaryText))
        XCTAssertEqual(model.sceneAnswer, ordinaryText)
        XCTAssertEqual(model.currentReply, ordinaryText)
        let queued = model.debugModelResponseSinkSnapshot
        XCTAssertEqual(queued.queued, [ordinaryText])
        XCTAssertTrue(queued.started.isEmpty)
        XCTAssertTrue(queued.active)
        XCTAssertEqual(queued.pending, 0)

        model.debugAdvanceModelResponseTime(to: now + 1, revalidate: false)
        XCTAssertTrue(model.debugStartModelResponsePlayback())
        let started = model.debugModelResponseSinkSnapshot
        XCTAssertEqual(started.queued, [ordinaryText])
        XCTAssertEqual(started.started, [ordinaryText])
        XCTAssertTrue(started.active)
    }

    func testOrdinaryArabicChatReachesSilentSinkWithoutNavigationAuthority() {
        let now = ProcessInfo.processInfo.systemUptime
        let model = fixture(question: "قل لي نكتة.", at: now)
        defer { model.debugCancelModelResponseTest() }
        let text = "أحب القصص."
        XCTAssertTrue(model.debugInjectModelResponse(text))
        XCTAssertEqual(model.currentReply, text)
        XCTAssertEqual(model.debugModelResponseSinkSnapshot.queued, [text])
        XCTAssertTrue(model.debugStartModelResponsePlayback())
        XCTAssertEqual(model.debugModelResponseSinkSnapshot.started, [text])
    }

    func testKnownEnglishAndArabicMovementOutputsNeverReachDisplayOrSink() {
        let model = fixture(at: ProcessInfo.processInfo.systemUptime)
        defer { model.debugCancelModelResponseTest() }
        let scene = model.sceneAnswer, current = model.currentReply
        for text in ["Continue straight through the doorway.", "Continue straight.",
                     "Head straight.", "Sidestep twice.", "كمل على طول.", "واصل على طول."] {
            XCTAssertFalse(model.debugInjectModelResponse(text), text)
            XCTAssertEqual(model.sceneAnswer, scene, text)
            XCTAssertEqual(model.currentReply, current, text)
            assertEmptySink(model)
        }
    }

    func testPhysicalRequestBareYesCannotReachDisplayOrSinkInEitherLanguage() {
        for question in ["Can I walk to the door?", "هل أستطيع أن أصعد هذا الدرج؟",
                         "How do I continue to the kitchen?", "كيف أكمل للمطبخ؟", "كيف أواصل للمطبخ؟"] {
            let model = fixture(question: question, at: ProcessInfo.processInfo.systemUptime)
            defer { model.debugCancelModelResponseTest() }
            let scene = model.sceneAnswer, current = model.currentReply
            for text in ["Yes.", "نعم."] {
                XCTAssertFalse(model.debugInjectModelResponse(text), question + " / " + text)
                XCTAssertEqual(model.sceneAnswer, scene)
                XCTAssertEqual(model.currentReply, current)
                assertEmptySink(model)
            }
        }
    }

    func testExpiryLabelsOriginalConversationAsHistoryAndRetiresPlayback() {
        let now = ProcessInfo.processInfo.systemUptime
        let model = fixture(at: now)
        defer { model.debugCancelModelResponseTest() }
        XCTAssertTrue(model.debugInjectModelResponse(ordinaryText))
        XCTAssertTrue(model.debugStartModelResponsePlayback())
        model.debugAdvanceModelResponseTime(to: now + 31)
        assertHistorical(model.sceneAnswer, original: ordinaryText)
        assertHistorical(model.currentReply, original: ordinaryText)
        let expired = model.debugModelResponseSinkSnapshot
        XCTAssertEqual(expired.queued, [ordinaryText])
        XCTAssertEqual(expired.started, [ordinaryText])
        XCTAssertFalse(expired.active)
        XCTAssertEqual(expired.pending, 0)
    }

    func testCancellationImmediatelyLabelsConversationAndRetiresQueuedAttempt() {
        let model = fixture(at: ProcessInfo.processInfo.systemUptime)
        XCTAssertTrue(model.debugInjectModelResponse(ordinaryText))
        model.debugCancelModelResponseTest()
        assertHistorical(model.sceneAnswer, original: ordinaryText)
        assertHistorical(model.currentReply, original: ordinaryText)
        XCTAssertFalse(model.debugStartModelResponsePlayback())
        let cancelled = model.debugModelResponseSinkSnapshot
        XCTAssertEqual(cancelled.queued, [ordinaryText])
        XCTAssertTrue(cancelled.started.isEmpty)
        XCTAssertFalse(cancelled.active)
        XCTAssertEqual(cancelled.pending, 0)
    }

    func testMicrophoneInterruptionRetiresConversationDisplayAndPlayback() {
        let model = fixture(at: ProcessInfo.processInfo.systemUptime)
        defer { model.debugCancelModelResponseTest() }
        XCTAssertTrue(model.debugInjectModelResponse(ordinaryText))
        model.debugInterruptModelResponseTest()
        assertHistorical(model.sceneAnswer, original: ordinaryText)
        assertHistorical(model.currentReply, original: ordinaryText)
        XCTAssertFalse(model.debugStartModelResponsePlayback())
        XCTAssertFalse(model.debugModelResponseSinkSnapshot.active)
        XCTAssertEqual(model.debugModelResponseSinkSnapshot.pending, 0)
        XCTAssertEqual(model.debugModelResponseSinkSnapshot.queued, [ordinaryText])
        XCTAssertTrue(model.debugModelResponseSinkSnapshot.started.isEmpty)
    }

    private enum Replacement { case code, document, ocr }
    private func assertSameTextReplacementSurvivesRetirement(_ replacement: Replacement,
                                                            file: StaticString = #filePath, line: UInt = #line) {
        let now = ProcessInfo.processInfo.systemUptime
        let model = fixture(at: now, file: file, line: line)
        XCTAssertTrue(model.debugInjectModelResponse(ordinaryText, enqueue: false), file: file, line: line)
        switch replacement {
        case .code: model.debugReplaceModelDisplayWithCode(ordinaryText)
        case .document: model.debugReplaceModelDisplayWithDocument(ordinaryText)
        case .ocr: model.debugReplaceModelDisplayWithOCR(ordinaryText)
        }
        model.debugAdvanceModelResponseTime(to: now + 31)
        XCTAssertEqual(model.sceneAnswer, ordinaryText, file: file, line: line)
        XCTAssertEqual(model.currentReply, ordinaryText, file: file, line: line)
        model.debugCancelModelResponseTest()
        XCTAssertEqual(model.sceneAnswer, ordinaryText, file: file, line: line)
        XCTAssertEqual(model.currentReply, ordinaryText, file: file, line: line)
        assertEmptySink(model, file: file, line: line)
    }

    func testSameTextCodeReplacementSurvivesOldModelExpiryAndCancellation() {
        assertSameTextReplacementSurvivesRetirement(.code)
    }

    func testSameTextDocumentReplacementSurvivesOldModelExpiryAndCancellation() {
        assertSameTextReplacementSurvivesRetirement(.document)
    }

    func testSameTextOCRReplacementSurvivesOldModelExpiryAndCancellation() {
        assertSameTextReplacementSurvivesRetirement(.ocr)
    }

    func testOlderDeadlineUpdateDoesNotRelabelNewerModelReply() {
        let now = ProcessInfo.processInfo.systemUptime
        let model = fixture(at: now)
        defer { model.debugCancelModelResponseTest() }
        XCTAssertTrue(model.debugInjectModelResponse(ordinaryText, enqueue: false))
        XCTAssertTrue(model.debugBeginModelResponseTest(question: "Tell me a story.", at: now + 20))
        assertHistorical(model.sceneAnswer, original: ordinaryText)
        assertHistorical(model.currentReply, original: ordinaryText)
        let newerText = "A funny surprise could happen."
        XCTAssertTrue(model.debugInjectModelResponse(newerText, enqueue: false))

        // The older reply's deadline has passed, but the newer original lease
        // still owns both display revisions. No run-loop/timer sleep is needed.
        model.debugAdvanceModelResponseTime(to: now + 31)
        XCTAssertEqual(model.sceneAnswer, newerText)
        XCTAssertEqual(model.currentReply, newerText)
        model.debugAdvanceModelResponseTime(to: now + 51)
        assertHistorical(model.sceneAnswer, original: newerText)
        assertHistorical(model.currentReply, original: newerText)
        assertEmptySink(model)
    }

    func testRetiredTimerCallbackCannotRelabelNewerReplyEvenAfterItsExpiry() {
        let now = ProcessInfo.processInfo.systemUptime
        let model = fixture(at: now)
        defer { model.debugCancelModelResponseTest() }
        XCTAssertTrue(model.debugInjectModelResponse(ordinaryText, enqueue: false))
        let oldTimerOwner = model.debugModelDisplayTimerOwner
        XCTAssertTrue(model.debugBeginModelResponseTest(question: "Tell me another joke.", at: now + 20))
        // Equal text is still a different response owner and display revision.
        XCTAssertTrue(model.debugInjectModelResponse(ordinaryText, enqueue: false))
        let newTimerOwner = model.debugModelDisplayTimerOwner
        XCTAssertNotEqual(oldTimerOwner, newTimerOwner)

        model.debugAdvanceModelResponseTime(to: now + 51, revalidate: false)
        model.debugFireModelDisplayExpiry(owner: oldTimerOwner)
        XCTAssertEqual(model.sceneAnswer, ordinaryText)
        XCTAssertEqual(model.currentReply, ordinaryText)
        XCTAssertEqual(model.debugModelDisplayTimerOwner, newTimerOwner)

        // Invoke the exact timer callback, not a copy of its policy. Only the
        // current owner may retire this display; no run-loop wait or audio runs.
        model.debugFireModelDisplayExpiry(owner: newTimerOwner)
        assertHistorical(model.sceneAnswer, original: ordinaryText)
        assertHistorical(model.currentReply, original: ordinaryText)
        assertEmptySink(model)
    }

    func testDelayedPlatformStartAfterExpiryIsRejectedWithoutWatchdogRevalidation() {
        let now = ProcessInfo.processInfo.systemUptime
        let model = fixture(at: now)
        defer { model.debugCancelModelResponseTest() }
        XCTAssertTrue(model.debugInjectModelResponse(ordinaryText))
        XCTAssertEqual(model.debugModelResponseSinkSnapshot.queued, [ordinaryText])
        // Preserve the queued attempt and current display until the production
        // AVSpeech delegate's actual-start permission checks see the late time.
        model.debugAdvanceModelResponseTime(to: now + 31, revalidate: false)
        XCTAssertTrue(model.debugModelResponseSinkSnapshot.active)
        XCTAssertEqual(model.currentReply, ordinaryText)
        XCTAssertFalse(model.debugStartModelResponsePlayback())
        let rejected = model.debugModelResponseSinkSnapshot
        XCTAssertEqual(rejected.queued, [ordinaryText])
        XCTAssertTrue(rejected.started.isEmpty)
        XCTAssertFalse(rejected.active)
        XCTAssertEqual(rejected.pending, 0)
    }

    func testRepeatAfterExpiryCannotRemintOriginalOrHistoryLabelAsCodeSpeech() {
        let now = ProcessInfo.processInfo.systemUptime
        let model = fixture(at: now)
        defer { model.debugCancelModelResponseTest() }
        XCTAssertTrue(model.debugInjectModelResponse(ordinaryText, enqueue: false))
        model.debugAdvanceModelResponseTime(to: now + 31)
        let history = model.currentReply
        assertHistorical(history, original: ordinaryText)
        // Both a stale UI callback holding original bytes and a current history
        // card repeat retain the original expired model receipt.
        XCTAssertFalse(model.speakRequested(ordinaryText))
        XCTAssertFalse(model.speakRequested(history))
        XCTAssertFalse(model.debugInjectModelResponse(ordinaryText))
        XCTAssertEqual(model.currentReply, history)
        assertEmptySink(model)
    }

    func testRepeatAfterCancellationCannotRemintOriginalOrHistoryLabelAsCodeSpeech() {
        let model = fixture(at: ProcessInfo.processInfo.systemUptime)
        XCTAssertTrue(model.debugInjectModelResponse(ordinaryText, enqueue: false))
        model.debugCancelModelResponseTest()
        let history = model.currentReply
        assertHistorical(history, original: ordinaryText)
        XCTAssertFalse(model.speakRequested(ordinaryText))
        XCTAssertFalse(model.speakRequested(history))
        XCTAssertFalse(model.debugInjectModelResponse(ordinaryText))
        XCTAssertEqual(model.currentReply, history)
        assertEmptySink(model)
    }
}
