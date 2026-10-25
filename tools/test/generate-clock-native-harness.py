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
    }
    enum DispatchKind { case answer }
    var assistantSession = Session()
    var feedback = Feedback()
    var voice = Voice()
    var companionWorkingState = Working()
    var requestID = UUID()
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
struct = declaration('private struct ConversationSpeech')
# Native clock tool case, verbatim, with other unrelated adapters omitted.
tool = declaration('@MainActor private func readCompanionTool(')
a = tool.index('        case .deviceClock:')
b = tool.index('        case .savedMemory:', a)
clock_case = tool[a:b]
read = '''
    @MainActor private func readCompanionTool(_ request: CompanionToolRequest) async -> CompanionToolResult {
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
            let result = await readCompanionToolForTurn(.init(kind: .deviceClock), id: requestID, generation: assistantSession.generation)
            XCTAssertEqual(result.status, .stale)
            XCTAssertEqual(readCount, 1)
            XCTAssertEqual(clockReplies.values.first?.issuedAt, 100)
        case 2:
            afterRead = { [weak self] in self?.sampleZone = TimeZone(identifier: "Asia/Riyadh")! }
            let result = await readCompanionToolForTurn(.init(kind: .deviceClock), id: requestID, generation: assistantSession.generation)
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
            let result = await readCompanionToolForTurn(.init(kind: .deviceClock), id: requestID, generation: assistantSession.generation)
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
            let result = await readCompanionToolForTurn(.init(kind: .deviceClock), id: requestID, generation: assistantSession.generation)
            let first = try XCTUnwrap(activeModelClockReplyID)
            move(4)
            _ = await readCompanionToolForTurn(.init(kind: .deviceClock), id: requestID, generation: assistantSession.generation)
            XCTAssertEqual(activeModelClockReplyID, first)
            move(6, wall: 4)
            partialCallback()("The local time is a newer model guess.")
            XCTAssertTrue(sceneAnswer.isEmpty)
            finishAfterMetadata(result.evidence[0].text)
            XCTAssertNotEqual(currentReply, result.evidence[0].text)
            XCTAssertEqual(clockReplies[first]?.issuedAt, 100)
        case 15:
            sampleAge = .nan
            let result = await readCompanionToolForTurn(.init(kind: .deviceClock), id: requestID, generation: assistantSession.generation)
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
trace_source = Path(sys.argv[3]).read_text() if len(sys.argv) > 3 else ''
trace = ''
if trace_source:
    saved_source = source
    source = trace_source
    trace = '\n#if DEBUG\n' + declaration('struct DebugNativeSessionTrace:') + '\n#endif\n'
    source = saved_source
Path(sys.argv[2]).write_text(header+'\n'+struct+'\n'+'\n\n'.join(declaration(m) for m in methods)+read+wrapper+scenarios+trace)
print(f'Extracted {len(methods)} native methods, clock tool case, partial callback and final admission guard.')
