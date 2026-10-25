"""Extract exact production clock callbacks; replace only Apple/platform collaborators.

This is not an Apple SDK, speech-engine, Foundation Models or device test.
Usage: python generate-clock-native-harness.py NavigationModel.swift OutputTests.swift
"""
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text()
def declaration(signature):
    start = source.index(signature)
    begin = source.index('{', start)
    depth = 0
    for i in range(begin, len(source)):
        if source[i] == '{': depth += 1
        elif source[i] == '}':
            depth -= 1
            if depth == 0: return source[start:i+1]
    raise ValueError(signature)
methods = [
    '@discardableResult private func routeHistoricalLocationInquiry(',
    'private func acquireClockReply(', 'private var activeModelClockReplyID:', 'private func modelClockReceipt(',
    'private func modelReplyText(', 'private func queueModelConversationSpeech(', 'private func clockDeliveryReceipt(',
    'private func clockDeliveryIsCurrent(', '@discardableResult private func showConversationReply(',
    '@discardableResult private func routeClockInquiry(', 'private func startClockExpiry(',
    'private func revalidateClockReplies(', 'private func interruptOrdinaryConversation(',
    'private func queueConversationSpeech(', 'private func drainConversationSpeech(',
    '@discardableResult func speakRequested(', '@MainActor private func readCompanionToolForTurn('
]
header = '''import Foundation
import XCTest
@testable import BlindCore

// These collaborators stand in for unavailable Apple/runtime services. All
// acquisition, lease, callback, queue, display and repeat methods below are
// extracted verbatim from NavigationModel.swift by the accompanying generator.
@MainActor private final class ClockNativeHarness {
    struct Session {
        enum State { case active, ended }
        var state: State = .active
        var generation: UInt64 = 3
        func accepts(generation: UInt64) -> Bool { self.generation == generation }
    }
    final class Feedback {
        var speechPriority: Int?
        var stopped: [UUID] = []
        func stopRequestedSpeech(_ id: UUID) { stopped.append(id) }
    }
    struct Voice { var awaitingUtterance = false }
    struct ConversationCapture {}
    struct Working {
        var goalRevision = "kept-goal"
        var actionProgress = CompanionActionProgressLedger()
        var historicalText: String?, historicalSummary: String?
        func historicalLocationReply(to question: String, arabic: Bool, concise: Bool = false) -> String? {
            concise ? historicalSummary : historicalText
        }
        var goal = "", metadataApplications = 0
        mutating func apply(_ update: ClockFixtureUpdate, latest: String) {
            metadataApplications += 1; goal = update.goal
        }
    }
    enum DispatchKind { case answer }
    var assistantSession = Session()
    var feedback = Feedback()
    var voice = Voice()
    var companionWorkingState = Working()
    var requestID = UUID()
    var assistantDialogue = AssistantDialogue()
    var preferredName = "", objectiveDraft = "", message = ""
    // Platform tokenizer seam only; these fixtures do not execute NLTokenizer.
    static func wordCount(_ text: String) -> Int { CompanionReferenceReading.wordCount(text) }
    var assistantAudience = AssistantAudience.general
    var availableCompanionTools: Set<CompanionToolKind> = []
    var companionModelContext: String? = nil
    var dialogueWrites = 0, stateWrites = 0
    struct Indoor { func cancelRoute() {} }
    var indoor = Indoor()
    func stopReturn() {}
    func clearBoardingReading() {} // No boarding source in the clock platform fixture.
    func persistDialogue() { dialogueWrites += 1 }
    func persistWorkingState() { stateWrites += 1 }
    var textOnly = false
    var arabic = false
    var busy = false
    var questionIsChat = false
    var streamedConversationText = ""
    var observedDisplays: [String] = []
    var sceneAnswer = "" { didSet { observedDisplays.append(sceneAnswer) } }
    var currentReply = "" { didSet { observedDisplays.append(currentReply) } }
    var clockReplies: [UUID: CompanionClockReplyLease] = [:]
    var sceneClockReceipt: CompanionClockDeliveryReceipt?
    var currentClockReceipt: CompanionClockDeliveryReceipt?
    var sceneClockOrigin: CompanionCommandOrigin = .trustedInterface
    var currentClockOrigin: CompanionCommandOrigin = .trustedInterface
    var clockExpiryTask: Task<Void, Never>?
    var modelClockOperation: CompanionClockReplyLease.Binding?
    var modelClockSpeechQueuedID: UUID?
    var unverifiedConversationID = UUID()
    var unverifiedConversationTask: Task<Void, Never>?
    var unverifiedConversationTimeout: Task<Void, Never>?
    var questionTask: Task<Void, Never>?
    var questionTimeoutTask: Task<Void, Never>?
    var conversationEvidenceCaptures: [String: ConversationCapture] = [:]
    private var conversationSpeech: [ConversationSpeech] = []
    private var activeConversationSpeech: ConversationSpeech?
    var spoken: [String] = []
    var readCount = 0
    var afterRead: (() -> Void)?
    let baseWall = Date()
    var sampleAge = 0.0
    var sampleWallAge = 0.0
    var sampleZone = TimeZone(secondsFromGMT: 0)!
    var clockSample: (wall: Date, monotonic: Double, zone: TimeZone) {
        (baseWall.addingTimeInterval(sampleWallAge), 100 + sampleAge, sampleZone)
    }
    func move(_ age: Double, wall: Double? = nil) { sampleAge = age; sampleWallAge = wall ?? age }
    func conversationCaptureIsCurrent(_ capture: ConversationCapture) -> Bool { true }
    func dispatchText(_ text: String, kind: DispatchKind, requested: Bool, replace: Bool,
                      narrationID: UUID?, speechID: UUID?) -> Bool { spoken.append(text); return true }
    func speakOperation(_ text: String) { spoken.append(text) }
    func deliverConversationReply(_ text: String) { _ = showConversationReply(text, settled: true) }
'''
# The revision field and captured local must come from the native source, not
# matching fixture constants. The old 16 callback scenarios retain this capture.
answer_method = declaration('private func answerConversation(')
revision_field = next(line for line in source.splitlines() if line.strip().startswith('private var conversationMemoryRevision ='))
memory_capture = next(line for line in answer_method.splitlines() if line.strip().startswith('let memoryRevision ='))
header += '\n' + revision_field + '\n'
struct = declaration('private struct ConversationSpeech')
# Native clock tool case, verbatim, with other unrelated adapters omitted.
tool = declaration('@MainActor private func readCompanionTool(')
a = tool.index('        case .deviceClock:')
b = tool.index('        case .savedMemory:', a)
clock_case = tool[a:b]
read = '''
    @MainActor private func readCompanionTool(_ request: CompanionToolRequest, originalUserQuery: String) async -> CompanionToolResult {
        readCount += 1
        let result: CompanionToolResult = {
            switch request.kind {
'''+clock_case+'''
            default: return CompanionToolResult(status: .unavailable, source: "test collaborator")
            }
        }()
        afterRead?()
        return result
    }
'''
# Exact post-model partial callback body, with the same captured inputs.
partial = declaration('}) { @MainActor [weak self] phrase in')
partial = partial[partial.index('{'):]
wrapper = '''
    func partialCallback() -> @MainActor (String) -> Void {
        let question = "Tell me an ordinary fact."
        let revision = companionWorkingState.goalRevision
'''+memory_capture+'''
        let id = requestID, sessionGeneration = assistantSession.generation
        return '''+partial+'''
    }
'''
start = source.index('            guard let text = self.modelReplyText(rawText),')
end = source.index('            if self.activeModelClockReplyID == nil, let update = answer.taskUpdate {', start)
final_guard = source[start:end]
proposal_start = source.index('            guard self.companionWorkingState.actionProgress.allowsProposal(text, goalRevision: revision) else', end)
proposal_end = source.index('            if self.textOnly || self.assistantSession.state != .active {', proposal_start)
proposal_gate = source[proposal_start:proposal_end]
wrapper += '''
    func finishAfterMetadata(_ rawText: String) {
        let revision = companionWorkingState.goalRevision
'''+final_guard+proposal_gate+'''
    }
'''
scenarios = '''
    func exercise(_ number: Int) async throws {
        defer { clockExpiryTask?.cancel() }
        switch number {
        case 1:
            afterRead = { [weak self] in self?.move(8, wall: 4) }
            let result = await readCompanionToolForTurn(.init(kind: .deviceClock), id: requestID, generation: assistantSession.generation, originalUserQuery: "What time is it?")
            XCTAssertEqual(result.status, .stale)
            XCTAssertEqual(readCount, 1)
            XCTAssertEqual(clockReplies.values.first?.issuedAt, 100)
        case 2:
            afterRead = { [weak self] in self?.sampleZone = TimeZone(identifier: "Asia/Riyadh")! }
            let result = await readCompanionToolForTurn(.init(kind: .deviceClock), id: requestID, generation: assistantSession.generation, originalUserQuery: "What time is it?")
            XCTAssertEqual(result.status, .stale)
        case 3:
            let lease = try XCTUnwrap(acquireClockReply())
            voice.awaitingUtterance = true
            queueConversationSpeech(lease.reply, request: requestID, generation: assistantSession.generation,
                evidence: [lease.evidence], codeOwned: true)
            XCTAssertEqual(conversationSpeech.count, 1)
            move(8, wall: 4); voice.awaitingUtterance = false
            drainConversationSpeech()
            XCTAssertTrue(spoken.isEmpty)
            XCTAssertTrue(conversationSpeech.isEmpty)
        case 4:
            let lease = try XCTUnwrap(acquireClockReply())
            let callback = partialCallback()
            move(8, wall: 4); callback(lease.reply)
            XCTAssertTrue(sceneAnswer.isEmpty)
            XCTAssertTrue(streamedConversationText.isEmpty)
        case 5:
            let lease = try XCTUnwrap(acquireClockReply())
            let callback = partialCallback(); callback(lease.reply)
            XCTAssertEqual(sceneAnswer, lease.reply)
            move(6, wall: 4); finishAfterMetadata(lease.reply)
            XCTAssertNotEqual(currentReply, lease.reply)
            XCTAssertNotEqual(sceneAnswer, lease.reply)
        case 6:
            let lease = try XCTUnwrap(acquireClockReply())
            XCTAssertTrue(showConversationReply(lease.reply, settled: true))
            move(6, wall: 4)
            XCTAssertFalse(speakRequested(lease.reply))
            XCTAssertTrue(spoken.isEmpty)
            XCTAssertEqual(clockReplies.count, 1)
            XCTAssertEqual(clockReplies.values.first?.issuedAt, 100)
        case 7:
            busy = true; questionIsChat = false
            let originalRequest = requestID
            XCTAssertTrue(routeClockInquiry("what time is it", origin: .unverifiedMicrophone))
            XCTAssertEqual(requestID, originalRequest)
            XCTAssertTrue(busy, "Independent in-flight camera/search work remains active")
            XCTAssertEqual(companionWorkingState.goalRevision, "kept-goal")
            XCTAssertEqual(currentClockOrigin, .unverifiedMicrophone)
            XCTAssertEqual(activeConversationSpeech?.origin, .unverifiedMicrophone)
        case 8:
            let lease = try XCTUnwrap(acquireClockReply())
            XCTAssertTrue(showConversationReply(lease.reply, settled: true))
            queueConversationSpeech(lease.reply, request: requestID, generation: assistantSession.generation,
                evidence: [lease.evidence], codeOwned: true)
            let speech = try XCTUnwrap(activeConversationSpeech)
            move(5); revalidateClockReplies()
            XCTAssertEqual(feedback.stopped, [speech.id])
            XCTAssertNil(activeConversationSpeech)
            XCTAssertNotEqual(currentReply, lease.reply)
            XCTAssertTrue(clockReplies[lease.binding.replyID]!.invalidated)
        case 9:
            let lease = try XCTUnwrap(acquireClockReply())
            let callback = partialCallback()
            requestID = UUID(); callback(lease.reply)
            XCTAssertTrue(sceneAnswer.isEmpty)
            XCTAssertFalse(showConversationReply(lease.reply, settled: true))
        case 10:
            move(99)
            let callback = partialCallback(); callback("Two plus two is four.")
            XCTAssertEqual(sceneAnswer, "Two plus two is four.")
            XCTAssertTrue(clockReplies.isEmpty)
        case 11:
            let lease = try XCTUnwrap(acquireClockReply())
            XCTAssertTrue(showConversationReply(lease.reply, settled: true, origin: .unverifiedMicrophone))
            _ = speakRequested(lease.reply)
            XCTAssertEqual(activeConversationSpeech?.origin, .unverifiedMicrophone)
        case 12:
            let callback = partialCallback(); callback("It's 3:00.")
            XCTAssertTrue(sceneAnswer.isEmpty)
            finishAfterMetadata("It's 3:00.")
            XCTAssertNotEqual(currentReply, "It's 3:00.")
            XCTAssertFalse(currentReply.isEmpty)
        case 13:
            let result = await readCompanionToolForTurn(.init(kind: .deviceClock), id: requestID, generation: assistantSession.generation, originalUserQuery: "What time is it?")
            XCTAssertEqual(result.status, .success)
            let canonical = try XCTUnwrap(result.evidence.first?.text)
            let callback = partialCallback()
            callback("Right now, it's a made-up time. Walk forward.")
            XCTAssertEqual(sceneAnswer, canonical)
            queueModelConversationSpeech("Anything from the model is untrusted.", request: requestID,
                generation: assistantSession.generation, reports: [], evidence: result.evidence)
            XCTAssertEqual(spoken, [canonical])
            queueModelConversationSpeech("Another chunk should not replay the clock.", request: requestID,
                generation: assistantSession.generation, reports: [], evidence: result.evidence)
            XCTAssertEqual(spoken.count, 1)
            finishAfterMetadata("The local time is definitely a different number.")
            XCTAssertEqual(currentReply, canonical)
        case 14:
            let result = await readCompanionToolForTurn(.init(kind: .deviceClock), id: requestID, generation: assistantSession.generation, originalUserQuery: "What time is it?")
            let first = try XCTUnwrap(activeModelClockReplyID)
            move(4)
            _ = await readCompanionToolForTurn(.init(kind: .deviceClock), id: requestID, generation: assistantSession.generation, originalUserQuery: "What time is it?")
            XCTAssertEqual(activeModelClockReplyID, first)
            move(6, wall: 4)
            partialCallback()("The local time is a newer model guess.")
            XCTAssertTrue(sceneAnswer.isEmpty)
            finishAfterMetadata(result.evidence[0].text)
            XCTAssertNotEqual(currentReply, result.evidence[0].text)
            XCTAssertEqual(clockReplies[first]?.issuedAt, 100)
        case 15:
            sampleAge = .nan
            let result = await readCompanionToolForTurn(.init(kind: .deviceClock), id: requestID, generation: assistantSession.generation, originalUserQuery: "What time is it?")
            XCTAssertEqual(result.status, .unavailable)
            XCTAssertNotNil(activeModelClockReplyID, "Selecting the operation remains fenced even without evidence")
            XCTAssertTrue(clockReplies.isEmpty)
            let guess = "This moment reads a totally unrecognized model time."
            XCTAssertNil(modelReplyText(guess))
            partialCallback()(guess)
            queueModelConversationSpeech(guess, request: requestID, generation: assistantSession.generation, reports: [], evidence: [])
            XCTAssertTrue(sceneAnswer.isEmpty)
            XCTAssertTrue(spoken.isEmpty)
            finishAfterMetadata(guess)
            XCTAssertNotEqual(currentReply, guess)
            XCTAssertFalse(currentReply.isEmpty)
        case 16:
            let proposal = "Close the fridge"
            _ = companionWorkingState.actionProgress.ingestUserReport("The fridge is closed",
                sourceID: "fixture-report", goalRevision: companionWorkingState.goalRevision, at: baseWall)
            XCTAssertFalse(companionWorkingState.actionProgress.allowsProposal(proposal,
                goalRevision: companionWorkingState.goalRevision))
            finishAfterMetadata(proposal)
            XCTAssertFalse(observedDisplays.contains(proposal), "Rejected nonclock output must never reach a display observer")
            XCTAssertNotEqual(sceneAnswer, proposal)
            XCTAssertFalse(currentReply.isEmpty)
        default: XCTFail("Unknown scenario")
        }
    }
}

final class ClockNativeCallbackTests: XCTestCase {
    @MainActor func testRejectedProposalNeverReachesDisplayObservers() async throws { try await ClockNativeHarness().exercise(16) }
    @MainActor func testSlowToolRetainsOriginalAnchor() async throws { try await ClockNativeHarness().exercise(1) }
    @MainActor func testToolZoneChangeFailsAtPostAwaitBoundary() async throws { try await ClockNativeHarness().exercise(2) }
    @MainActor func testCodeOwnedQueueCannotBypassOriginalDeadline() async throws { try await ClockNativeHarness().exercise(3) }
    @MainActor func testActualPartialCallbackRejectsClockRollback() async throws { try await ClockNativeHarness().exercise(4) }
    @MainActor func testDelayedFinalMetadataCannotRedisplayStaleClock() async throws { try await ClockNativeHarness().exercise(5) }
    @MainActor func testActualRepeatDoesNotReacquireClock() async throws { try await ClockNativeHarness().exercise(6) }
    @MainActor func testUnverifiedReadOnlyInquiryPreservesIndependentWork() async throws { try await ClockNativeHarness().exercise(7) }
    @MainActor func testPlaybackExpiryWithdrawsExactClockSpeech() async throws { try await ClockNativeHarness().exercise(8) }
    @MainActor func testOldPartialCallbackCannotCrossRequestBoundary() async throws { try await ClockNativeHarness().exercise(9) }
    @MainActor func testOrdinaryConversationDoesNotRequireClockOrCamera() async throws { try await ClockNativeHarness().exercise(10) }
    @MainActor func testUnverifiedClockRepeatRetainsProvenance() async throws { try await ClockNativeHarness().exercise(11) }
    @MainActor func testFirstClockAcquisitionFailureNeverFallsBackToModelTime() async throws { try await ClockNativeHarness().exercise(15) }
    @MainActor func testActualClockToolOperationIgnoresAllModelProseAndSpeaksOnce() async throws { try await ClockNativeHarness().exercise(13) }
    @MainActor func testRepeatedToolCannotRenewOperationBoundClockAnswer() async throws { try await ClockNativeHarness().exercise(14) }
    @MainActor func testModelTimeGuessNeverBecomesPartialOrFinalDisplay() async throws { try await ClockNativeHarness().exercise(12) }
}
'''
# Exact already-admitted review retirement, not a copied cancellation rule.
# Selection validation and durable revision remain covered by the full review replay.
review_source = declaration('@discardableResult func reviseScopedConversationRecord(')
retirement_start = review_source.index('            conversationMemoryRevision = UUID()')
assert review_source.index('revised.reviseReviewedSource(selection, replacement: replacement)') < retirement_start
retirement_end = review_source.index('            #if DEBUG', retirement_start)
retirement = review_source[retirement_start:retirement_end]
assert 'interruptOrdinaryConversation(origin: .trustedInterface)' in retirement
wrapper += '''
    func retireAdmittedReviewSpeech() {
'''+retirement+'''
    }
    func exerciseHistoricalReviewOwnership(_ pendingBehindMobility: Bool, oversized: Bool = false) throws {
        // Authored renderer seam, not real source parsing. Full metadata and the
        // concise child reply are deliberately distinct; lookup replay covers rendering.
        let history = "You told me yesterday your cup was not in the kitchen. I don't know where it is now."
        let technical = "Historical report, 2026-10-24T12:00:00Z. Original stored context: place ID: synthetic-private-place; floor ID: synthetic-floor; room ID: synthetic-room; object instance ID: synthetic-container; map ID: synthetic-map; frame ID: synthetic-frame; revision: synthetic-revision. " + history
        let fallback = "I have a longer saved report. I can't fit the whole clue in this reply. I don't know where it is now."
        companionWorkingState.historicalText = technical
        companionWorkingState.historicalSummary = oversized
            ? "You told me yesterday " + Array(repeating: "a", count: 60).joined(separator: " ") + " not in the kitchen. I don't know where it is now." : history
        let expected = oversized ? fallback : history
        let owner = requestID, memoryRevision = conversationMemoryRevision
        busy = true; questionIsChat = false
        if pendingBehindMobility { feedback.speechPriority = 3 }
        XCTAssertTrue(routeHistoricalLocationInquiry("Where did I leave my cup?", origin: .trustedInterface))
        XCTAssertEqual(sceneAnswer, expected); XCTAssertEqual(currentReply, expected)
        XCTAssertEqual(message, expected)
        for text in [sceneAnswer, currentReply, message] {
            XCTAssertFalse(text.contains("synthetic-private-place")); XCTAssertFalse(text.contains("place ID:"))
            XCTAssertFalse(text.contains("Historical report")); XCTAssertFalse(text.contains("2026-10-24T"))
        }
        if !oversized { XCTAssertTrue(expected.contains("not in the kitchen")) }
        if pendingBehindMobility {
            XCTAssertEqual(conversationSpeech.count, 1, "Exactly one bounded historical entry waits behind mobility.")
            let pending = try XCTUnwrap(conversationSpeech.first)
            XCTAssertTrue(pending.codeOwned); XCTAssertEqual(pending.request, owner)
            XCTAssertLessThanOrEqual(Self.wordCount(pending.text), 30)
            XCTAssertEqual(pending.text, expected)
            XCTAssertFalse(pending.text.contains("displayed"))
            if oversized {
                XCTAssertFalse(pending.text.contains("kitchen"), "Never publish a partial clue with a later negation omitted.")
                XCTAssertTrue(pending.text.contains("I don't know where it is now."))
            } else { XCTAssertTrue(pending.text.contains("not in the kitchen")) }
            XCTAssertTrue(spoken.isEmpty); XCTAssertNil(activeConversationSpeech)
            retireAdmittedReviewSpeech()
            XCTAssertTrue(conversationSpeech.isEmpty); XCTAssertNil(activeConversationSpeech)
            XCTAssertEqual(feedback.speechPriority, 3); XCTAssertTrue(feedback.stopped.isEmpty)
            feedback.speechPriority = nil; drainConversationSpeech()
            XCTAssertTrue(spoken.isEmpty, "Retired history cannot start after mobility finishes.")
        } else {
            let active = try XCTUnwrap(activeConversationSpeech, "Historical speech must have an ordinary-conversation owner.")
            XCTAssertEqual(active.text, expected); XCTAssertTrue(active.codeOwned)
            XCTAssertEqual(active.request, owner); XCTAssertEqual(spoken, [expected])
            XCTAssertTrue(conversationSpeech.isEmpty)
            retireAdmittedReviewSpeech()
            XCTAssertNil(activeConversationSpeech); XCTAssertTrue(conversationSpeech.isEmpty)
            XCTAssertEqual(feedback.stopped, [active.id], "Only the owned historical speech ID is stopped.")
        }
        XCTAssertNotEqual(conversationMemoryRevision, memoryRevision)
        XCTAssertEqual(requestID, owner); XCTAssertTrue(busy); XCTAssertEqual(readCount, 0)
    }
'''
scenarios = scenarios.replace('final class ClockNativeCallbackTests: XCTestCase {', '''final class ClockNativeCallbackTests: XCTestCase {
    @MainActor func testHistoricalHelperOwnsSpeechRetiredByAdmittedReview() async throws { try ClockNativeHarness().exerciseHistoricalReviewOwnership(false) }
    @MainActor func testHistoricalHelperPendingBehindMobilityIsDiscardedWithoutStoppingMobility() async throws {
        try ClockNativeHarness().exerciseHistoricalReviewOwnership(true)
        try ClockNativeHarness().exerciseHistoricalReviewOwnership(true, oversized: true)
    }
''', 1)

# Extract the entire native scheduled model closure, including initial and
# post-await admission, task metadata, display and persistence. Its pre-scheduling
# capture declarations are extracted separately so a late-capture race stays real.
task_signature = 'questionTask = Task { @MainActor [weak self] in'
task_offset = answer_method.index(task_signature)
pre_schedule = answer_method[:task_offset]
captures = []
for name in ['dialogue', 'sessionGeneration', 'revision', 'memoryRevision']:
    matches = [line for line in pre_schedule.splitlines() if line.strip().startswith('let ' + name + ' =')]
    assert len(matches) <= 1, name
    captures.extend(matches)
assert any('let dialogue =' in line for line in captures)
assert any('let sessionGeneration =' in line for line in captures)
saved_source = source
source = answer_method
scheduled = declaration(task_signature)
source = saved_source
scheduled = scheduled[scheduled.index('{'):]
wrapper += '''
    func scheduledModelTurn() -> @MainActor () async -> Void {
        let question = "Tell me an ordinary fact."
        let id = requestID
        let situation: [String: Any] = [:]
'''+ '\n'.join(captures) + '''
        return '''+scheduled+'''
    }
    // Rotation-only deliberately omits review cancellation to isolate the caller
    // fence. Actual review cancels questionTask; converse retains its own check.
    func exerciseHeldStart(_ cancel: Bool) async throws {
        LocalImageAssistant.reset()
        let pending = scheduledModelTurn()
        let start = ClockFixtureGate()
        let entered = ClockFixtureGate()
        let task = Task { await entered.open(); await start.wait(); await pending() }
        await entered.wait()
        if cancel { task.cancel() } else { conversationMemoryRevision = UUID() }
        await start.open(); await task.value
        print("Authored held-start cancellation=\\(cancel): adapter entries=\\(LocalImageAssistant.invocations); fixture sessions=\\(LocalImageAssistant.sessions)")
        XCTAssertEqual(LocalImageAssistant.invocations, 0, "The native caller must reject retired work before invoking the model adapter.")
        XCTAssertEqual(LocalImageAssistant.sessions, 0, "Callee cancellation is a separate boundary, not proof from counting adapter entry.")
        XCTAssertTrue(observedDisplays.isEmpty); XCTAssertTrue(spoken.isEmpty)
        XCTAssertEqual(companionWorkingState.metadataApplications, 0)
        XCTAssertEqual(dialogueWrites, 0); XCTAssertEqual(stateWrites, 0)
    }
    func exerciseReviewDuringInference() async throws {
        LocalImageAssistant.reset()
        let entered = ClockFixtureGate(), finish = ClockFixtureGate()
        LocalImageAssistant.entered = entered; LocalImageAssistant.finish = finish
        let pending = scheduledModelTurn()
        let task = Task { await pending() }
        await entered.wait()
        XCTAssertEqual(LocalImageAssistant.invocations, 1); XCTAssertEqual(LocalImageAssistant.sessions, 1)
        conversationMemoryRevision = UUID()
        await finish.open(); await task.value
        XCTAssertTrue(observedDisplays.isEmpty); XCTAssertTrue(spoken.isEmpty)
        XCTAssertEqual(companionWorkingState.metadataApplications, 0, "A retired turn must not apply metadata before final publication.")
        XCTAssertEqual(dialogueWrites, 0); XCTAssertEqual(stateWrites, 0)
    }
'''
scenarios = scenarios.replace('final class ClockNativeCallbackTests: XCTestCase {', '''final class ClockNativeCallbackTests: XCTestCase {
    @MainActor func testHeldStartRejectsRetiredMemoryBeforeAdapterInvocation() async throws { try await ClockNativeHarness().exerciseHeldStart(false) }
    @MainActor func testHeldStartCancellationSeparatesCallerAndCalleeBoundaries() async throws { try await ClockNativeHarness().exerciseHeldStart(true) }
    @MainActor func testMemoryRotationDuringInferenceWithholdsCallbacksMetadataAndFinalPublication() async throws { try await ClockNativeHarness().exerciseReviewDuringInference() }
''', 1)
# These are authored Apple/model seams, not an actual model/backend execution.
# Preserve the real converse cancellation check before counting fixture sessions.
local_source = Path(sys.argv[3]).read_text()
callee_start = local_source.index('    static func converse(')
callee_checkpoint = next(line for line in local_source[callee_start:].splitlines() if line.strip() == 'try Task.checkCancellation()')
collaborators = '''
private actor ClockFixtureGate {
    private var opened = false
    private var waits: [CheckedContinuation<Void, Never>] = []
    func wait() async {
        if opened { return }
        await withCheckedContinuation { waits.append($0) }
    }
    func open() { opened = true; let current = waits; waits = []; current.forEach { $0.resume() } }
}
private struct ClockFixtureUpdate { let goal: String }
private struct ClockFixtureAnswer { let text: String?; let status: String; let taskUpdate: ClockFixtureUpdate? }
@MainActor private enum LocalImageAssistant {
    static var invocations = 0, sessions = 0
    static var entered: ClockFixtureGate?, finish: ClockFixtureGate?
    static func reset() { invocations = 0; sessions = 0; entered = nil; finish = nil }
    static func converse(dialogue: AssistantDialogue, arabic: Bool, preferredName: String,
        audience: AssistantAudience, situation: [String: Any], workingState: ClockNativeHarness.Working,
        modelContext: String?, availableTools: Set<CompanionToolKind>, toolExecutor: CompanionToolExecutor?, requestID: UUID?,
        onSpeechCandidate: (@MainActor @Sendable (String, [String], [CompanionEvidence]) -> Void)? = nil,
        onReplyComplete: (@MainActor @Sendable (String) -> Void)? = nil,
        onPartial: (@MainActor @Sendable (String) -> Void)? = nil) async -> ClockFixtureAnswer {
        invocations += 1
        do {
'''+callee_checkpoint+'''
        } catch { return .init(text: nil, status: "cancelled", taskUpdate: nil) }
        sessions += 1
        await entered?.open(); await finish?.wait()
        let text = "Two plus two is four."
        onSpeechCandidate?(text, [], []); onPartial?(text)
        return .init(text: text, status: "complete", taskUpdate: .init(goal: "Keep the existing task"))
    }
}
'''

trace_source = Path(sys.argv[3]).read_text() if len(sys.argv) > 3 else ''
trace = ''
if trace_source:
    saved_source = source
    source = trace_source
    trace = '\n#if DEBUG\n' + declaration('struct DebugNativeSessionTrace:') + '\n#endif\n'
    trace += '\n// Exact native BehaviorTree.CPP adaptation, including its admission behavior.\n' + declaration('enum CompanionReactiveSequence') + '\n'
    source = saved_source
Path(sys.argv[2]).write_text(header+'\n'+struct+'\n'+'\n\n'.join(declaration(m) for m in methods)+read+wrapper+scenarios+trace+collaborators)
print(f'Extracted {len(methods)} native methods, clock tool case, partial callback and final admission guard.')
