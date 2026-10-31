import XCTest
import BlindCore
#if canImport(FoundationModels)
import FoundationModels
#endif
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


/// Production controller controls in its existing XCTest text-only mode.
/// These assert lifecycle state, not microphone/audio/VoiceOver or model acceptance.
@MainActor
final class ConversationControlLifecycleTests: XCTestCase {
    func testQuietAndResumeDoNotMuteEndOrStartSensors() {
        let model = NavigationModel()
        XCTAssertTrue(model.textOnly)
        let prior = model.ambientDescriptions
        defer { model.ambientDescriptions = prior; model.endConversation() }
        model.startConversation()
        let generation = model.assistantSession.generation
        let camera = model.cameraAwareness, running = model.running
        model.stopDescriptions()
        XCTAssertFalse(model.ambientDescriptions)
        XCTAssertEqual(model.assistantSession.state, .active)
        XCTAssertEqual(model.assistantSession.generation, generation)
        model.resumeDescriptions()
        XCTAssertTrue(model.ambientDescriptions)
        XCTAssertEqual(model.assistantSession.state, .active)
        XCTAssertEqual(model.assistantSession.generation, generation)
        XCTAssertEqual(model.cameraAwareness, camera)
        XCTAssertEqual(model.running, running)
        XCTAssertFalse(model.voice.listening)
    }

    func testMuteAndEndRemainStoppedAcrossForegroundAndDescriptionResume() {
        let model = NavigationModel()
        XCTAssertTrue(model.textOnly)
        let prior = model.ambientDescriptions
        defer { model.ambientDescriptions = prior; model.endConversation() }
        model.startConversation()
        let active = model.assistantSession.generation
        model.muteConversation()
        XCTAssertEqual(model.assistantSession.state, .muted)
        XCTAssertFalse(model.assistantSession.accepts(generation: active))
        model.suspendExperience(); model.resumeExperienceIfNeeded(); model.resumeDescriptions()
        XCTAssertEqual(model.assistantSession.state, .muted)
        XCTAssertFalse(model.assistantSession.shouldListen)
        XCTAssertFalse(model.voice.listening)
        model.endConversation()
        model.suspendExperience(); model.resumeExperienceIfNeeded(); model.resumeDescriptions()
        XCTAssertEqual(model.assistantSession.state, .ended)
        XCTAssertFalse(model.assistantSession.shouldListen)
        XCTAssertFalse(model.voice.listening)
        model.startConversation()
        XCTAssertEqual(model.assistantSession.state, .active)
        XCTAssertFalse(model.voice.listening, "Text-only fixture must never start real capture")
    }
    func testReportedCompletionKeepsExactParentSourceAcrossPauseAndRestart() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        var state = CompanionWorkingState()
        state.changeGoal("school", originalRequest: "Help me get ready for school", sourceID: "typed-parent", at: date)
        let source = try XCTUnwrap(state.goalSource)
        _ = state.respond(to: .find(object: "coat"), message: "Help me find my coat", arabic: false)
        XCTAssertFalse(state.recordCompletedSubtask("Help me find my coat", report: "I found my keys"))
        XCTAssertFalse(state.recordCompletedSubtask("Help me find my coat", report: "I have not found my coat"))
        XCTAssertTrue(state.recordCompletedSubtask("Help me find my coat", report: "I found my coat"))
        let reports = state.reportedCompletedSteps
        XCTAssertEqual(reports, ["User reported completing Help me find my coat: I found my coat"])
        XCTAssertEqual(state.goalSource, source)
        XCTAssertTrue(state.suspendGoal())
        var restored = try JSONDecoder().decode(CompanionWorkingState.self, from: JSONEncoder().encode(state))
        XCTAssertTrue(restored.resumeGoal())
        XCTAssertEqual(restored.goal, "school")
        XCTAssertEqual(restored.goalSource?.originalRequest, "Help me get ready for school")
        XCTAssertEqual(restored.goalSource?.sourceID, "typed-parent")
        XCTAssertEqual(restored.goalSource?.recordedAt, date)
        XCTAssertEqual(restored.reportedCompletedSteps, reports)
        XCTAssertTrue(restored.proposedStep.isEmpty, "A retained report must not become a fresh movement suggestion")
    }

}

/// Synthetic errors only; no Foundation Model generation, images or user data.
final class ConversationFailureDiagnosticTests: XCTestCase {
    func testUnknownErrorDoesNotLeakPrivateDescriptionDomainOrUserInfo() {
        let secret = "synthetic-private-marker"
        let error = NSError(domain: secret, code: 17, userInfo: [NSLocalizedDescriptionKey: secret, NSFilePathErrorKey: secret])
        let value = ConversationFailureDiagnostic.capture(error, phase: .prepareContext)
        XCTAssertEqual(value.phase, .prepareContext)
        XCTAssertEqual(value.category, .unclassified)
        XCTAssertEqual(value.family, .unclassified)
        XCTAssertNil(value.opaqueCode)
        XCTAssertFalse(value.receipt.contains(secret))
    }
    func testKnownBridgeDomainRetainsOnlyOpaqueBoundedCodeNotPayload() {
        let secret = "synthetic-private-marker"
        let error = NSError(domain: "FoundationModels.LanguageModelError", code: 2, userInfo: [NSLocalizedDescriptionKey: secret])
        let value = ConversationFailureDiagnostic.capture(error, phase: .generateReply)
        XCTAssertEqual(value.phase, .generateReply)
        XCTAssertEqual(value.family, .languageModel)
        XCTAssertEqual(value.category, .unclassified) // Never infer a cause from code 2.
        XCTAssertEqual(value.opaqueCode, 2)
        XCTAssertFalse(value.receipt.contains(secret))
        for code in [-1, 256, Int.max] {
            XCTAssertNil(ConversationFailureDiagnostic.capture(NSError(domain: "FoundationModels.LanguageModelError", code: code), phase: .generateReply).opaqueCode)
        }
    }
    func testDiagnosticIsNotModelTextOrTaskCompletion() {
        let diagnostic = ConversationFailureDiagnostic.capture(NSError(domain: "fixture", code: 1), phase: .generateReply)
        let answer = LocalImageAnswer.conversationFailure(.generationFailed, arabic: false, diagnostic: diagnostic)
        XCTAssertNil(answer.text)
        XCTAssertNil(answer.taskUpdate)
        XCTAssertEqual(answer.conversationFailureDiagnostic, diagnostic)
        XCTAssertEqual(answer.conversationOperationalFallback, "I couldn't finish an on-device reply just now.")
    }
    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    func testLegacyTypedCausesDoNotRetainAssociatedContext() {
        let context = LanguageModelSession.GenerationError.Context(debugDescription: "synthetic-private-marker")
        let cases: [(LanguageModelSession.GenerationError, ConversationFailureDiagnostic.Category)] = [
            (.exceededContextWindowSize(context), .contextOverflow), (.assetsUnavailable(context), .assetsUnavailable),
            (.guardrailViolation(context), .guardrailViolation), (.unsupportedGuide(context), .unsupportedGuide),
            (.unsupportedLanguageOrLocale(context), .unsupportedLanguageOrLocale), (.decodingFailure(context), .decodingFailure),
            (.rateLimited(context), .rateLimited), (.concurrentRequests(context), .concurrentRequests)
        ]
        for (error, expected) in cases {
            let value = ConversationFailureDiagnostic.capture(error, phase: .generateReply)
            XCTAssertEqual(value.category, expected)
            XCTAssertFalse(value.receipt.contains("synthetic-private-marker"))
        }
    }
    #endif
}

/// Exact typed companion dispatch and private selected-source state, with no
/// microphone, model invocation, network, food preparation or audio execution.
@MainActor
final class LocalRecipeCompanionAdapterTests: XCTestCase {
    private let marker = "Private authored recipe fixture."
    private func data() throws -> Data {
        try JSONSerialization.data(withJSONObject: ["schema": 1, "title": "Test source", "attribution": "Authored fixture only",
            "ingredients": [["name": "test", "quantity": "verbatim"]],
            "steps": [["text": marker, "timerSeconds": 60], ["text": "Second source text."]]])
    }
    private func fixture(enable: Bool = true) throws -> NavigationModel {
        let model = NavigationModel()
        XCTAssertTrue(model.debugBeginModelResponseTest(question: "Recipe adapter source test", at: 10))
        let owner = try XCTUnwrap(model.beginLocalRecipeSelection())
        XCTAssertTrue(model.selectLocalRecipe(try data(), owner: owner))
        if enable {
            XCTAssertTrue(model.enableLocalRecipeCommands(try XCTUnwrap(model.localRecipe.selection)))
        }
        return model
    }
    func testRealCompanionInputRequiresExplicitSourceEnableAndUsesPrivateLiteralOutput() throws {
        let model = try fixture(enable: false); defer { model.endConversation() }
        model.receiveCompanionUtterance("read recipe step")
        XCTAssertNil(model.localRecipe.response)
        XCTAssertFalse(model.currentReply.contains(marker))
        XCTAssertTrue(model.enableLocalRecipeCommands(try XCTUnwrap(model.localRecipe.selection)))
        model.receiveCompanionUtterance("read recipe step")
        XCTAssertTrue(model.currentReply.contains(marker))
        XCTAssertEqual(model.localRecipe.session?.stepIndex, 0)
        XCTAssertFalse(model.assistantDialogue.turns.contains { $0.text.contains(marker) })
        XCTAssertFalse(model.assistantDialogue.userRecords.contains { $0.text.contains(marker) })
    }
    func testActualNextPreviousAndTimerCommandsShareTheHelperSessionWithoutCompletionClaims() throws {
        let model = try fixture(); defer { model.endConversation() }
        model.receiveCompanionUtterance("start recipe timer")
        XCTAssertEqual(model.localRecipe.session?.timerState, .running)
        model.receiveCompanionUtterance("next recipe step")
        XCTAssertEqual(model.localRecipe.session?.stepIndex, 1)
        XCTAssertEqual(model.localRecipe.session?.timerState, .cancelled)
        XCTAssertTrue(model.currentReply.contains("Second source text."))
        model.receiveCompanionUtterance("previous recipe step")
        XCTAssertEqual(model.localRecipe.session?.stepIndex, 0)
        XCTAssertTrue(model.currentReply.contains(marker))
        model.receiveCompanionUtterance("stop recipe")
        XCTAssertNil(model.localRecipe.session); XCTAssertNil(model.localRecipe.selection)
        XCTAssertFalse(model.currentReply.contains(marker))
    }
    func testUnverifiedMicrophoneModelAndObservedOriginsCannotEnterActualAdapter() throws {
        let model = try fixture(); defer { model.endConversation() }
        let selection = model.localRecipe.selection
        for origin in CompanionCommandOrigin.allCases where origin != .trustedInterface {
            for text in ["read recipe step", "next recipe step", "start recipe timer", "forget recipe"] {
                XCTAssertFalse(model.debugRouteLocalRecipeCommand(text, origin: origin))
                XCTAssertEqual(model.localRecipe.selection, selection)
                XCTAssertEqual(model.localRecipe.session?.stepIndex, 0)
                XCTAssertEqual(model.localRecipe.session?.timerState, .idle)
            }
        }
    }
    func testOldPickerCannotResurrectRecipeAfterStopOrNewSelection() throws {
        let model = try fixture(); defer { model.endConversation() }
        let old = try XCTUnwrap(model.beginLocalRecipeSelection())
        model.endConversation(); model.startConversation()
        XCTAssertFalse(model.selectLocalRecipe(try data(), owner: old))
        XCTAssertNil(model.localRecipe.selection)
        let replaced = try XCTUnwrap(model.beginLocalRecipeSelection())
        let current = try XCTUnwrap(model.beginLocalRecipeSelection())
        model.cancelLocalRecipeSelection(replaced)
        XCTAssertFalse(model.selectLocalRecipe(try data(), owner: replaced))
        XCTAssertTrue(model.selectLocalRecipe(try data(), owner: current))
    }
    func testReplacementAndInvalidImportRetireExactOldOutputAndTimer() throws {
        let model = try fixture(); defer { model.endConversation() }
        let old = try XCTUnwrap(model.localRecipe.selection)
        model.receiveCompanionUtterance("start recipe timer")
        model.receiveCompanionUtterance("read recipe step")
        let owner = try XCTUnwrap(model.beginLocalRecipeSelection())
        XCTAssertNil(model.localRecipe.selection); XCTAssertFalse(model.currentReply.contains(marker))
        XCTAssertFalse(model.selectLocalRecipe(Data("{}".utf8), owner: owner))
        XCTAssertFalse(model.enableLocalRecipeCommands(old))
        XCTAssertNil(model.localRecipe.session)
    }
    func testLeavingReaderRequiresExplicitOptInAndAlwaysCancelsPageTimer() throws {
        let model = try fixture(enable: false); defer { model.endConversation() }
        model.localRecipeReaderDisappeared(); XCTAssertNil(model.localRecipe.selection)
        let owner = try XCTUnwrap(model.beginLocalRecipeSelection())
        XCTAssertTrue(model.selectLocalRecipe(try data(), owner: owner))
        XCTAssertTrue(model.enableLocalRecipeCommands(try XCTUnwrap(model.localRecipe.selection)))
        model.localRecipeReaderCommand(.startTimer)
        XCTAssertEqual(model.localRecipe.session?.timerState, .running)
        model.localRecipeReaderDisappeared()
        XCTAssertNotNil(model.localRecipe.selection); XCTAssertTrue(model.localRecipe.enabled)
        XCTAssertEqual(model.localRecipe.session?.timerState, .cancelled)
    }
    func testBackgroundAndEndRemoveSourceAndSourceDisplayRatherThanRestoringAuthority() throws {
        let model = try fixture(); defer { model.endConversation() }
        model.receiveCompanionUtterance("read recipe step")
        XCTAssertTrue(model.currentReply.contains(marker))
        model.suspendExperience()
        XCTAssertNil(model.localRecipe.selection); XCTAssertNil(model.localRecipe.session)
        XCTAssertFalse(model.currentReply.contains(marker))
        model.resumeExperienceIfNeeded()
        XCTAssertNil(model.localRecipe.selection)
    }
}

/// Exact private typed-command dispatch and draft/source ownership. No native
/// composer, microphone, local model, network or actual email send is executed.
@MainActor
final class LocalEmailCompanionAdapterTests: XCTestCase {
    private let marker = "PRIVATE-DRAFT-FIXTURE"
    private func fixture(enable: Bool = true) throws -> (NavigationModel, UUID) {
        let model = NavigationModel()
        model.arabic = false
        XCTAssertTrue(model.debugBeginModelResponseTest(question: "Local draft source adapter test", at: 10))
        let owner = try XCTUnwrap(model.openLocalEmailDraft())
        if enable { XCTAssertTrue(model.enableLocalEmailCommands(try XCTUnwrap(model.localEmailDraft.snapshot))) }
        return (model, owner)
    }
    private func fill(_ model: NavigationModel) {
        model.receiveCompanionUtterance("email draft recipient: fixture@example.invalid")
        model.receiveCompanionUtterance("email draft subject: Exact authored subject")
        model.receiveCompanionUtterance("replace email draft body: " + marker)
    }
    func testTrustedPrivateInputUsesOneSharedDraftOnlyAfterExplicitEnable() throws {
        let (model, _) = try fixture(enable: false); defer { model.endConversation() }
        model.receiveCompanionUtterance("replace email draft body: " + marker)
        XCTAssertEqual(model.localEmailDraft.snapshot?.content.body, "")
        XCTAssertTrue(model.enableLocalEmailCommands(try XCTUnwrap(model.localEmailDraft.snapshot)))
        fill(model)
        XCTAssertEqual(model.localEmailDraft.snapshot?.content.body, marker)
        XCTAssertFalse(model.assistantDialogue.turns.contains { $0.text.contains(marker) })
        XCTAssertFalse(model.assistantDialogue.userRecords.contains { $0.text.contains(marker) })
        XCTAssertNil(model.localEmailDraft.handoff)
    }
    func testLiteralAppendAndUndoPreserveUserWordsInsteadOfExecutingEmbeddedCommands() throws {
        let (model, _) = try fixture(); defer { model.endConversation() }
        fill(model)
        let literal = "Keep Case.\ndiscard email draft.  \n"
        model.receiveCompanionUtterance("append email draft body: " + literal)
        XCTAssertEqual(model.localEmailDraft.snapshot?.content.body, marker + "\n\n" + literal)
        XCTAssertNil(model.localEmailDraft.handoff)
        model.receiveCompanionUtterance("undo email draft")
        XCTAssertEqual(model.localEmailDraft.snapshot?.content.body, marker)
    }
    func testRealUnverifiedMicrophoneNamespaceNeverReadsMutatesOrFallsThroughToModel() throws {
        let (model, _) = try fixture(); defer { model.endConversation() }
        fill(model)
        let before = model.localEmailDraft.snapshot
        for text in ["replace email draft body: MICROPHONE-PRIVATE-FIXTURE", "read email draft body", "discard email draft", "review email draft in Mail"] {
            model.receiveCompanionUtterance(text, fromVoice: true)
            XCTAssertEqual(model.localEmailDraft.snapshot, before)
            XCTAssertNil(model.localEmailDraft.handoff)
            XCTAssertFalse(model.currentReply.contains(marker))
            XCTAssertFalse(model.currentReply.contains("MICROPHONE-PRIVATE-FIXTURE"))
            XCTAssertFalse(model.busy)
        }
        XCTAssertFalse(model.assistantDialogue.turns.contains { $0.text.contains("MICROPHONE-PRIVATE-FIXTURE") })
    }
    func testPrivateReviewIsAttributedAndNeverBecomesDialogueOrTaskHistory() throws {
        let (model, _) = try fixture(); defer { model.endConversation() }
        fill(model)
        model.receiveCompanionUtterance("read email draft body")
        XCTAssertTrue(model.currentReply.hasPrefix("Your draft body, part 1 of 1: «"))
        XCTAssertTrue(model.currentReply.contains(marker))
        XCTAssertFalse(model.assistantDialogue.turns.contains { $0.text.contains(marker) })
        model.receiveCompanionUtterance("replace email draft body: Updated private literal.")
        XCTAssertFalse(model.currentReply.contains(marker))
        model.receiveCompanionUtterance("next email draft part")
        XCTAssertFalse(model.currentReply.contains("Updated private literal."))
    }
    func testMalformedQuotedOversizeAndSendCommandsCannotCauseHandoffOrEchoPrivatePayload() throws {
        let (model, _) = try fixture(); defer { model.endConversation() }
        fill(model)
        let before = model.localEmailDraft.snapshot
        for text in ["send email draft", "\"replace email draft body: " + marker + "\"", "if ready discard email draft",
                     "replace email draft body: " + String(repeating: "S", count: 2100)] {
            model.receiveCompanionUtterance(text)
            XCTAssertEqual(model.localEmailDraft.snapshot, before)
            XCTAssertNil(model.localEmailDraft.handoff)
            XCTAssertFalse(model.currentReply.contains(marker))
        }
    }
    func testNativeReviewReceiptUsesExactSnapshotAndQueuedDoesNotClaimDelivery() throws {
        let (model, _) = try fixture(); defer { model.endConversation() }
        fill(model)
        let expected = try XCTUnwrap(model.localEmailDraft.snapshot)
        model.debugPrepareLocalEmailHandoff(available: true)
        let handoff = try XCTUnwrap(model.localEmailDraft.handoff)
        XCTAssertEqual(handoff.snapshot, expected)
        model.editLocalEmailField(.body, text: "Cannot rewrite while native review owns it.", expected: expected)
        XCTAssertEqual(model.localEmailDraft.snapshot, expected)
        model.finishLocalEmailHandoff(handoff.id, outcome: .queued)
        XCTAssertNil(model.localEmailDraft.handoff)
        XCTAssertTrue(model.localEmailStatus.contains("Delivery and receipt are not confirmed"))
        let completed = model.localEmailStatus
        model.finishLocalEmailHandoff(handoff.id, outcome: .failed)
        XCTAssertEqual(model.localEmailStatus, completed)
    }
    func testUnavailableMailDoesNotCreateHandoffOrDiscardLocalWriting() throws {
        let (model, _) = try fixture(); defer { model.endConversation() }
        fill(model)
        model.debugPrepareLocalEmailHandoff(available: false)
        XCTAssertNil(model.localEmailDraft.handoff)
        XCTAssertEqual(model.localEmailDraft.snapshot?.content.body, marker)
        XCTAssertTrue(model.localEmailStatus.contains("was not sent"))
    }
    func testStopBackgroundDestroyAndLateCallbackCannotRestoreAnOldDraft() throws {
        let (model, owner) = try fixture(); defer { model.endConversation() }
        fill(model)
        model.debugPrepareLocalEmailHandoff(available: true)
        let old = try XCTUnwrap(model.localEmailDraft.handoff)
        model.suspendExperience()
        XCTAssertNil(model.localEmailDraft.snapshot); XCTAssertNil(model.localEmailDraft.handoff)
        XCTAssertEqual(model.localEmailDraft.checkpointCount, 0)
        model.resumeExperienceIfNeeded()
        let newer = try XCTUnwrap(model.openLocalEmailDraft())
        XCTAssertNotEqual(newer, owner)
        model.editLocalEmailField(.body, text: marker, expected: old.snapshot)
        model.finishLocalEmailHandoff(old.id, outcome: .queued)
        XCTAssertEqual(model.localEmailDraft.snapshot?.content.body, "")
        XCTAssertFalse(model.localEmailStatus.contains("accepted"))
        model.endConversation(); XCTAssertNil(model.localEmailDraft.snapshot)
    }
    func testHelperLifetimeRetainsOnlyExplicitlyEnabledSourceOrCurrentNativeReview() throws {
        let (model, owner) = try fixture(enable: false); defer { model.endConversation() }
        model.editLocalEmailField(.body, text: marker, expected: try XCTUnwrap(model.localEmailDraft.snapshot))
        model.localEmailReaderDisappeared(owner: owner)
        XCTAssertNil(model.localEmailDraft.snapshot)
        let current = try XCTUnwrap(model.openLocalEmailDraft())
        XCTAssertTrue(model.enableLocalEmailCommands(try XCTUnwrap(model.localEmailDraft.snapshot)))
        model.editLocalEmailField(.body, text: marker, expected: try XCTUnwrap(model.localEmailDraft.snapshot))
        model.localEmailReaderDisappeared(owner: current)
        XCTAssertEqual(model.localEmailDraft.snapshot?.content.body, marker)
        model.receiveCompanionUtterance("discard email draft")
        XCTAssertNil(model.localEmailDraft.snapshot); XCTAssertEqual(model.localEmailDraft.checkpointCount, 0)
    }
    func testStaleHelperBindingsCannotOverwriteNewCompanionRevisionOrOpenMailForIt() throws {
        let (model, _) = try fixture(); defer { model.endConversation() }
        fill(model)
        let old = try XCTUnwrap(model.localEmailDraft.snapshot)
        model.receiveCompanionUtterance("replace email draft body: Newer typed draft revision.")
        let newer = try XCTUnwrap(model.localEmailDraft.snapshot)
        model.editLocalEmailField(.body, text: "Old binding full text", expected: old)
        model.checkpointLocalEmailDraft(expected: old)
        model.undoLocalEmailDraft(expected: old)
        model.requestLocalEmailMailReview(expected: old)
        model.discardLocalEmailDraft(expected: old)
        XCTAssertEqual(model.localEmailDraft.snapshot, newer)
        XCTAssertNil(model.localEmailDraft.handoff)
        XCTAssertNotEqual(old.revision, newer.revision)
    }

    func testSceneQuestionNamespaceRejectsWithoutModelOrDraftAuthority() throws {
        let (model, _) = try fixture(); defer { model.endConversation() }
        fill(model)
        let before = model.localEmailDraft.snapshot
        for automatic in [false, true] {
            let privateQuestion = "replace email draft body: SCENE-PRIVATE-FIXTURE"
            model.assistantQuestion = privateQuestion
            model.readScene(cloud: false, question: privateQuestion, automatic: automatic)
            XCTAssertEqual(model.localEmailDraft.snapshot, before)
            XCTAssertNil(model.localEmailDraft.handoff)
            XCTAssertFalse(model.busy)
            XCTAssertEqual(model.assistantQuestion, "")
            XCTAssertFalse(model.currentReply.contains("SCENE-PRIVATE-FIXTURE"))
            XCTAssertFalse(model.assistantDialogue.turns.contains { $0.text.contains("SCENE-PRIVATE-FIXTURE") })
        }
    }

}
