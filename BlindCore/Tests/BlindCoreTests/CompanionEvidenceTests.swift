import XCTest
@testable import BlindCore

final class CompanionEvidenceTests: XCTestCase {
    private let historical = ["Help me find my cup", "I last left it on the kitchen table"]

    func testHistoricalReportNeverConfirmsCurrentLocation() {
        for reply in ["Your cup is on the kitchen table.", "It's on the kitchen table.",
                      "It is still there.", "Your cup must be on the table.",
                      "Your cup is sitting on the kitchen table.", "It should be where you left it.",
                      "The cup lies on the table.", "There is no cup on the table."] {
            XCTAssertFalse(CompanionEvidenceGuard.allows(reply, reports: historical), reply)
        }
    }
    func testArabicPastReportDoesNotBecomeCurrentFact() {
        let report = "آخر مرة تركت الكوب على طاولة المطبخ"
        XCTAssertEqual(CompanionEvidenceGuard.reportScope(report), .historical)
        for reply in ["كوبك على طاولة المطبخ.", "الكوب موجود على الطاولة.", "هو على الطاولة.", "وجدت الكوب."] {
            XCTAssertFalse(CompanionEvidenceGuard.allows(reply, reports: [report]), reply)
        }
        XCTAssertTrue(CompanionEvidenceGuard.allows("قلت: «آخر مرة تركت الكوب على طاولة المطبخ».", reports: [report]))
    }
    func testExactAttributionPreservesProvenanceAndNegation() {
        XCTAssertTrue(CompanionEvidenceGuard.allows("You said: “I last left it on the kitchen table”. That could be a place to check.", reports: historical))
        XCTAssertTrue(CompanionEvidenceGuard.allows("You said: “The door is not closed.”", reports: ["The door is not closed."]))
        XCTAssertFalse(CompanionEvidenceGuard.allows("You said: “The door is closed.”", reports: ["The door is not closed."]))
        XCTAssertFalse(CompanionEvidenceGuard.allows("You said the cup is on the table.", reports: historical))
        XCTAssertFalse(CompanionEvidenceGuard.allows("You said: “I last left it on the kitchen table”. It is there now.", reports: historical))
    }
    func testReportScopeDoesNotExtractPastQuestionsPlansOrUncertainty() {
        XCTAssertEqual(CompanionEvidenceGuard.reportScope("I last left it on the kitchen table"), .historical)
        XCTAssertEqual(CompanionEvidenceGuard.reportScope("The door was open"), .historical)
        XCTAssertEqual(CompanionEvidenceGuard.reportScope("Is the door open?"), .uncertain)
        XCTAssertEqual(CompanionEvidenceGuard.reportScope("I think the door is open"), .uncertain)
        XCTAssertEqual(CompanionEvidenceGuard.reportScope("I will open the door"), .uncertain)
        XCTAssertEqual(CompanionEvidenceGuard.reportScope("The door is not closed"), .currentReported)
    }
    func testDeliveredAssistantWordsAreConversationHistoryNotObservationsOrUserReports() {
        let prior = CompanionEvidence(kind: .assistantUtterance, text: "The door is open.", source: "delivered assistant words")
        XCTAssertTrue(CompanionEvidenceGuard.allows("I said: “The door is open.”", reports: [], evidence: [prior]))
        XCTAssertFalse(CompanionEvidenceGuard.allows("The door is open.", reports: [], evidence: [prior]))
        XCTAssertFalse(CompanionEvidenceGuard.allows("You said: “The door is open.”", reports: [], evidence: [prior]))
        XCTAssertFalse(CompanionEvidenceGuard.allows("I said: “The door is closed.”", reports: [], evidence: [prior]))
    }
    func testQueuedObservationIsRejectedAtLaterDispatch() {
        let generatedAt = Date()
        let source = CompanionEvidence(kind: .currentObservation, text: "The door is open.", source: "gated local frame",
            observedAt: generatedAt, expiresAt: generatedAt.addingTimeInterval(0.1))
        XCTAssertTrue(CompanionEvidenceGuard.allows(source.text, reports: [], evidence: [source], now: generatedAt))
        XCTAssertFalse(CompanionEvidenceGuard.allows(source.text, reports: [], evidence: [source], now: generatedAt.addingTimeInterval(0.2)))
    }
    func testOnlyWholeExplicitCompletionReportsCanChangeProgress() {
        XCTAssertTrue(CompanionEvidenceGuard.explicitCompletionReport("I'm done.", latest: "I'm done."))
        XCTAssertTrue(CompanionEvidenceGuard.explicitCompletionReport("I found it", latest: "I found it"))
        XCTAssertFalse(CompanionEvidenceGuard.explicitCompletionReport("done", latest: "I'm not done"))
        XCTAssertFalse(CompanionEvidenceGuard.explicitCompletionReport("I'm not done", latest: "I'm not done"))
        XCTAssertFalse(CompanionEvidenceGuard.explicitCompletionReport("I will be done", latest: "I will be done"))
        XCTAssertFalse(CompanionEvidenceGuard.explicitCompletionReport("Have I finished?", latest: "Have I finished?"))
        XCTAssertFalse(CompanionEvidenceGuard.explicitCompletionReport("لم انتهيت", latest: "لم انتهيت"))
    }
    func testExpiredProvenanceCannotHideBehindNonstandardWording() {
        let now = Date()
        let record = CompanionEvidence(kind: .currentObservation, text: "Visible text candidate: Milk.", source: "Vision",
            observedAt: now.addingTimeInterval(-2), expiresAt: now.addingTimeInterval(-1))
        XCTAssertFalse(CompanionEvidenceGuard.allows(record.text, reports: [], evidence: [record], now: now))
        XCTAssertFalse(CompanionEvidenceGuard.allows("Visible text candidate: Milk.", reports: []))
    }
    func testUserCurrentReportIsStillNotIndependentObservation() {
        XCTAssertFalse(CompanionEvidenceGuard.allows("The door is open.", reports: ["The door is open"]))
        XCTAssertTrue(CompanionEvidenceGuard.allows("You said: “The door is open”.", reports: ["The door is open"]))
    }
    func testGeneralConversationAndClarificationRemainAvailable() {
        for reply in ["Hello! What would you like to talk about?", "Where did you last have your cup?",
                      "Let's talk about dinosaurs instead.", "I'm here to help.",
                      "Blue light scatters more strongly in the atmosphere."] {
            XCTAssertTrue(CompanionEvidenceGuard.allows(reply, reports: []), reply)
        }
    }
    func testUnsupportedActionPerceptionIdentityAndMoneyAreRejected() {
        for reply in ["I checked the table.", "I found your cup.", "I've searched the room.",
                      "I saved your location.", "I sent the message.", "This is your brother.",
                      "This is a 100 riyal note.", "The current camera shows a cup.", "Turn left to reach the kitchen.", "Walk to the table."] {
            XCTAssertFalse(CompanionEvidenceGuard.allows(reply, reports: historical), reply)
        }
    }
    func testCurrentEvidenceRequiresExactCompleteClaimAndFreshness() {
        let now = Date()
        let live = CompanionEvidence(kind: .currentObservation, text: "The door is open.", source: "gated local frame",
                                     observedAt: now.addingTimeInterval(-0.2), expiresAt: now.addingTimeInterval(0.5))
        XCTAssertTrue(CompanionEvidenceGuard.allows("The door is open.", reports: [], evidence: [live], now: now))
        XCTAssertFalse(CompanionEvidenceGuard.allows("The door is closed.", reports: [], evidence: [live], now: now))
        XCTAssertFalse(CompanionEvidenceGuard.allows("The door is open and the cup is on the table.", reports: [], evidence: [live], now: now))
        XCTAssertFalse(CompanionEvidenceGuard.allows("The door is open.", reports: [], evidence: [live], now: now.addingTimeInterval(1)))
        var memory = live; memory.kind = .historicalMemory
        XCTAssertFalse(CompanionEvidenceGuard.allows("The door is open.", reports: [], evidence: [memory], now: now))
        memory = live; memory.observedAt = now.addingTimeInterval(1)
        XCTAssertFalse(memory.isCurrent(at: now))
        memory = live; memory.expiresAt = now.addingTimeInterval(600)
        XCTAssertFalse(memory.isCurrent(at: now))
    }
    func testSpatialSafetyCannotBeBypassedByToolOrAttribution() {
        let now = Date()
        let claim = "The stairs are two metres ahead."
        let record = CompanionEvidence(kind: .currentObservation, text: claim, source: "test", observedAt: now, expiresAt: now.addingTimeInterval(1))
        XCTAssertFalse(CompanionEvidenceGuard.allows(claim, reports: [], evidence: [record], now: now))
        XCTAssertFalse(CompanionEvidenceGuard.allows("You said: “The path is clear.”", reports: ["The path is clear."]))
    }
    func testSentenceStreamEmitsOnlyNewCompleteValidatedSentences() {
        var stream = CompanionSentenceStream()
        XCTAssertEqual(stream.append("Hello", reports: []), [])
        XCTAssertEqual(stream.append("Hello! What would", reports: []), ["Hello!"])
        XCTAssertEqual(stream.append("Hello! What would", reports: []), [])
        XCTAssertEqual(stream.append("Hello! What would you like to discuss?", reports: []), ["What would you like to discuss?"])
        XCTAssertEqual(stream.append("Hello! What would you like to discuss?", final: true, reports: []), [])
        XCTAssertFalse(stream.rejected)
    }
    func testSentenceStreamStopsOnUnsupportedClaimAndRevision() {
        var stream = CompanionSentenceStream()
        XCTAssertEqual(stream.append("Let's check. Your cup is on the table.", reports: historical), ["Let's check."])
        XCTAssertTrue(stream.rejected)
        XCTAssertEqual(stream.append("Hello.", final: true, reports: historical), [])
        var revised = CompanionSentenceStream()
        XCTAssertEqual(revised.append("Hello.", reports: []), ["Hello."])
        XCTAssertEqual(revised.append("Goodbye.", reports: []), [])
        XCTAssertTrue(revised.rejected)
    }
    func testStreamDoesNotSplitQuotedReportOrRepeatFinalFragment() {
        var stream = CompanionSentenceStream()
        let quote = "You said: “The door is not closed.”"
        XCTAssertEqual(stream.append("You said: “The door is not closed.", reports: ["The door is not closed."]), [])
        XCTAssertEqual(stream.append(quote, reports: ["The door is not closed."]), [quote])
        XCTAssertEqual(stream.append(quote + " I can't verify that", final: true, reports: ["The door is not closed."]), ["I can't verify that"])
        XCTAssertFalse(stream.rejected)
    }
    func testToolCallsAreBoundedAndUnavailableCannotInventEvidence() async {
        actor Counter { var count = 0; func bump() { count += 1 } }
        let counter = Counter()
        let runtime = CompanionToolRuntime(available: [.savedMemory]) { _ in
            await counter.bump()
            return CompanionToolResult(status: .success, source: "local store")
        }
        let first = await runtime.run(.init(kind: .currentObservation))
        XCTAssertEqual(first.status, .unavailable)
        _ = await runtime.run(.init(kind: .savedMemory))
        _ = await runtime.run(.init(kind: .savedMemory))
        let fourth = await runtime.run(.init(kind: .savedMemory))
        XCTAssertEqual(fourth.status, .callLimit)
        let count = await counter.count
        XCTAssertEqual(count, 2)
    }
    func testToolFailurePayloadAndStaleOrMislabelledEvidenceAreDiscarded() async {
        let now = Date()
        let old = CompanionEvidence(kind: .currentObservation, text: "The door is open.", source: "camera", observedAt: now.addingTimeInterval(-10), expiresAt: now.addingTimeInterval(-9))
        let runtime = CompanionToolRuntime(available: [.currentObservation]) { _ in
            CompanionToolResult(status: .success, source: "camera", evidence: [old])
        }
        let stale = await runtime.run(.init(kind: .currentObservation))
        XCTAssertEqual(stale.status, .stale)
        XCTAssertTrue(stale.evidence.isEmpty)
        let failure = CompanionToolRuntime(available: [.currentObservation]) { _ in
            CompanionToolResult(status: .offline, source: "camera", evidence: [old])
        }
        let failed = await failure.run(.init(kind: .currentObservation))
        XCTAssertEqual(failed.status, .offline)
        XCTAssertTrue(failed.evidence.isEmpty)
        let evidence = await failure.currentEvidence()
        XCTAssertTrue(evidence.isEmpty)
    }
    func testToolTimeoutReturnsPromptlyAndDiscardsLateResult() async {
        // Deliberately ignores cancellation to verify the caller-visible bound.
        let runtime = CompanionToolRuntime(available: [.savedMemory], timeout: 0.02) { _ in
            await withCheckedContinuation { continuation in
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.15) {
                    continuation.resume(returning: CompanionToolResult(status: .success, source: "late store",
                        evidence: [.init(kind: .historicalMemory, text: "Old note", source: "late store")]))
                }
            }
        }
        let started = Date()
        let result = await runtime.run(.init(kind: .savedMemory))
        XCTAssertEqual(result.status, .timedOut)
        XCTAssertLessThan(Date().timeIntervalSince(started), 0.12)
        try? await Task.sleep(nanoseconds: 180_000_000)
        let evidence = await runtime.currentEvidence()
        XCTAssertTrue(evidence.isEmpty)
    }
    func testCancellationStopsWaitingAndDoesNotPublishEvidence() async {
        let runtime = CompanionToolRuntime(available: [.savedMemory]) { _ in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            return CompanionToolResult(status: .success, source: "store", evidence: [.init(kind: .historicalMemory, text: "Old note", source: "store")])
        }
        let task = Task { await runtime.run(.init(kind: .savedMemory)) }
        try? await Task.sleep(nanoseconds: 10_000_000)
        task.cancel()
        let result = await task.value
        XCTAssertEqual(result.status, .cancelled)
        let evidence = await runtime.currentEvidence()
        XCTAssertTrue(evidence.isEmpty)
    }
}
