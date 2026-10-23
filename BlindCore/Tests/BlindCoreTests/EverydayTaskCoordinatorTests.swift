import XCTest
@testable import BlindCore

final class EverydayTaskCoordinatorTests: XCTestCase {
    private let all = Set(EverydayCapability.allCases)
    private func request(_ capability: EverydayCapability, _ query: String = "coat") -> EverydayTaskRequest {
        EverydayTaskRequest(capability: capability, query: query)!
    }
    private func ticket(_ next: EverydayTaskCoordinator.Next, file: StaticString = #filePath, line: UInt = #line) throws -> EverydayTaskCoordinator.Ticket {
        guard case .run(let value) = next else { XCTFail("Expected adapter dispatch", file: file, line: line); throw NSError(domain: "test", code: 1) }
        return value
    }
    func testSchoolJourneyRetainsGoalAndRequiresExplicitCompletion() throws {
        var task = EverydayTaskCoordinator()
        XCTAssertTrue(task.setGoal("Get ready for school"))
        let goal = task.goal
        task.begin(request(.findItem))
        let memory = try ticket(task.next(available: all, now: 0))
        XCTAssertEqual(memory.request.capability, .savedMemory)
        task.receive(memory, outcome: .historicalClue, now: 1)
        let live = try ticket(task.next(available: all, now: 2))
        XCTAssertEqual(live.request.capability, .findItem)
        task.receive(live, outcome: .informationReady, now: 3)
        XCTAssertTrue(task.completedSubtasks.isEmpty)
        XCTAssertEqual(task.state, .informationReady)
        XCTAssertTrue(task.confirmSubtaskComplete())
        task.begin(request(.findItem, "backpack"))
        XCTAssertEqual(task.goal, goal)
        XCTAssertEqual(task.completedSubtasks, ["coat"])
        XCTAssertEqual(task.emittedPromptCount, 0)
    }
    func testReadingAndClockDispatchDirectlyWithoutSensorOrMemoryPrerequisite() throws {
        for capability in [EverydayCapability.readText, .deviceClock, .clothingColor, .currency, .familiarPerson] {
            var task = EverydayTaskCoordinator(); task.begin(request(capability))
            let value = try ticket(task.next(available: [capability], now: 0))
            XCTAssertEqual(value.request.capability, capability)
            task.receive(value, outcome: .informationReady, now: 1)
            XCTAssertEqual(task.state, .informationReady)
            XCTAssertEqual(task.emittedPromptCount, 0)
        }
    }
    func testMissingMemoryFallsBackToLiveWithoutPrompt() throws {
        var task = EverydayTaskCoordinator(); task.begin(request(.findItem))
        XCTAssertEqual(task.next(available: [.findItem], now: 0), .unavailable(.savedMemory))
        XCTAssertEqual(try ticket(task.next(available: [.findItem], now: 1)).request.capability, .findItem)
        XCTAssertEqual(task.emittedPromptCount, 0)
    }
    func testHistoryDoesNotBecomeLivePresenceWhenLiveUnavailable() throws {
        var task = EverydayTaskCoordinator(); task.begin(request(.findItem))
        task.receive(try ticket(task.next(available: all, now: 0)), outcome: .historicalClue, now: 1)
        XCTAssertEqual(task.next(available: [.savedMemory], now: 2), .unavailable(.findItem))
        XCTAssertTrue(task.historicalClueAvailable)
        XCTAssertEqual(task.state, .needsHelp)
        XCTAssertTrue(task.completedSubtasks.isEmpty)
    }
    func testRetryBudgetAndPromptDedupe() throws {
        var task = EverydayTaskCoordinator(); task.begin(request(.readText))
        for now in [0.0, 2.0] {
            task.receive(try ticket(task.next(available: all, now: now)), outcome: .retryable(.uncertain), now: now + 1)
            _ = task.admitPrompt(for: .uncertain)
        }
        XCTAssertEqual(task.attempts, 2)
        XCTAssertEqual(task.emittedPromptCount, 1)
        XCTAssertEqual(task.state, .needsHelp)
        XCTAssertEqual(task.next(available: all, now: 5), .finished)
    }
    func testUnknownMemoryStillAttemptsLive() throws {
        var task = EverydayTaskCoordinator(); task.begin(request(.findItem))
        task.receive(try ticket(task.next(available: all, now: 0)), outcome: .retryable(.notObserved), now: 1)
        XCTAssertEqual(try ticket(task.next(available: all, now: 2)).request.capability, .findItem)
        XCTAssertFalse(task.historicalClueAvailable)
    }
    func testReplacementAndCancellationRejectLateResults() throws {
        var task = EverydayTaskCoordinator(); task.setGoal("School")
        task.begin(request(.readText)); let old = try ticket(task.next(available: all, now: 0))
        task.begin(request(.deviceClock)); XCTAssertFalse(task.receive(old, outcome: .informationReady, now: 1))
        let current = try ticket(task.next(available: all, now: 2))
        task.cancelSubtask(); XCTAssertNotNil(task.goal)
        XCTAssertFalse(task.receive(current, outcome: .informationReady, now: 3))
        task.cancelAll(); XCTAssertNil(task.goal)
    }
    func testInterruptionPreservesGoalButInvalidatesResult() throws {
        var task = EverydayTaskCoordinator(); task.setGoal("Read homework")
        task.begin(request(.readDocument)); let old = try ticket(task.next(available: all, now: 0))
        task.pause(); XCTAssertEqual(task.next(available: all, now: 1), .waiting)
        XCTAssertFalse(task.receive(old, outcome: .informationReady, now: 2))
        task.resume(); let replacement = try ticket(task.next(available: all, now: 3))
        XCTAssertNotEqual(old.id, replacement.id)
        XCTAssertEqual(task.attempts, 2)
        XCTAssertEqual(task.goal?.description, "Read homework")
    }
    func testRepeatedRequestDoesNotResetAttemptBudget() throws {
        var task = EverydayTaskCoordinator(); let wanted = request(.barcode)
        task.begin(wanted); let first = try ticket(task.next(available: all, now: 0))
        XCTAssertFalse(task.begin(wanted)); XCTAssertEqual(task.attempts, 1)
        XCTAssertEqual(task.next(available: all, now: 1), .waiting)
        task.receive(first, outcome: .retryable(.uncertain), now: 2)
        XCTAssertFalse(task.begin(wanted)); XCTAssertEqual(task.attempts, 1)
    }
    func testTimeoutAndClockRegressionFailBoundedly() throws {
        var task = EverydayTaskCoordinator(); task.begin(request(.readText))
        let old = try ticket(task.next(available: all, now: 0))
        XCTAssertFalse(task.receive(old, outcome: .informationReady, now: 20))
        _ = try ticket(task.next(available: all, now: 20))
        XCTAssertEqual(task.next(available: all, now: 40), .finished)
        XCTAssertEqual(task.lastFailure, .timedOut)
        task.begin(request(.light)); _ = try ticket(task.next(available: all, now: 100))
        XCTAssertEqual(task.next(available: all, now: 99), .finished)
        XCTAssertEqual(task.lastFailure, .stale)
    }
    func testHungMemoryFallsBackToLiveAfterBoundedAttempts() throws {
        var task = EverydayTaskCoordinator(); task.begin(request(.findItem))
        XCTAssertEqual(try ticket(task.next(available: all, now: 0)).request.capability, .savedMemory)
        XCTAssertEqual(try ticket(task.next(available: all, now: 20)).request.capability, .savedMemory)
        XCTAssertEqual(try ticket(task.next(available: all, now: 40)).request.capability, .findItem)
        XCTAssertEqual(task.attempts, 1)
        XCTAssertEqual(task.emittedPromptCount, 0)
    }
    func testDuplicateAdapterCallbackCannotFinishNextOperation() throws {
        var task = EverydayTaskCoordinator(); task.begin(request(.findItem))
        let memory = try ticket(task.next(available: all, now: 0))
        XCTAssertTrue(task.receive(memory, outcome: .historicalClue, now: 1))
        _ = try ticket(task.next(available: all, now: 2))
        XCTAssertFalse(task.receive(memory, outcome: .informationReady, now: 3))
        XCTAssertEqual(task.state, .active)
    }
    func testInvalidTimeNeverDispatches() {
        for now in [Double.nan, Double.infinity, -Double.infinity] {
            var task = EverydayTaskCoordinator(); task.begin(request(.currency))
            XCTAssertEqual(task.next(available: all, now: now), .finished)
        }
    }
    func testPromptBudgetAndCancelledSilence() {
        var task = EverydayTaskCoordinator(); task.begin(request(.readText))
        for reason in [EverydayTaskCoordinator.Failure.uncertain, .notObserved, .unavailable, .timedOut, .stale] { _ = task.admitPrompt(for: reason) }
        XCTAssertEqual(task.emittedPromptCount, 3)
        task.cancelAll(); XCTAssertFalse(task.admitPrompt(for: .timedOut))
    }
    func testNarrowRoutingAndConversationNegatives() {
        XCTAssertEqual(EverydayTaskRequest.route("What time is it?")?.capability, .deviceClock)
        XCTAssertEqual(EverydayTaskRequest.route("Read this label")?.capability, .readText)
        XCTAssertEqual(EverydayTaskRequest.route("Where is my coat?")?.capability, .findItem)
        for text in ["Write a poem about red", "What is your favorite color?", "Explain how money works", "Tell me about school", "What is the temperature in Khobar?", "What is a barcode?", "Why is the sky blue?"] {
            XCTAssertNil(EverydayTaskRequest.route(text), text)
        }
    }
    func testCurrencyGeneralKnowledgeRepeatedlyRemainsConversation() {
        for _ in 0..<5 {
            for question in ["What is money?", "What is denomination?", "What does denomination mean?", "Explain currency", "What is a banknote?"] {
                XCTAssertNil(EverydayTaskRequest.route(question), question)
            }
        }
        for question in ["Identify this banknote", "How much money am I holding?"] {
            XCTAssertEqual(EverydayTaskRequest.route(question)?.capability, .currency, question)
        }
    }
    func testRequestBoundsAndControlCharacters() {
        for query in ["", "  ", String(repeating: "x", count: 301), "coat\u{202E}text", "coat\ntext"] {
            XCTAssertNil(EverydayTaskRequest(capability: .findItem, query: query))
        }
    }
}
