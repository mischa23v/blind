import XCTest
@testable import BlindCore

final class ContextWindowPolicyTests: XCTestCase {
    func testPromptBudgetPreservesLatestAndWholeOriginalRecords() throws {
        let latest = "Do not cancel. I last left it there, not here."
        let reports = (0..<30).map { "Report \($0): " + String(repeating: "not now; historical. ", count: 8) }
        let instructions = "Never invent a current observation; preserve source and negation."
        let plan = try ContextWindowPolicy.makePrompt(latest: latest, instructions: instructions,
            fields: [.init("userReportsNotObservations", reports), .init("assistantWordsNotFacts", ["Two ideas: stories or music."])], reduced: false)
        XCTAssertTrue(plan.prompt.contains("Latest user message (verbatim):\n" + latest + "\n"))
        XCTAssertLessThanOrEqual(plan.inputUTF8Bytes, ContextWindowPolicy.maximumInputUTF8Bytes)
        XCTAssertEqual(plan.inputUTF8Bytes, instructions.utf8.count + plan.prompt.utf8.count)
        XCTAssertTrue((plan.context["userReportsNotObservations"] ?? []).allSatisfy { reports.contains($0) })
        XCTAssertLessThan(plan.context["userReportsNotObservations"]?.count ?? 0, reports.count)
        XCTAssertEqual(plan.context["userReportsNotObservations"]?.last, reports.last)
    }
    func testReducedContextPreservesUnicodeLatestWithoutTruncation() throws {
        let latest = String(repeating: "ليس الآن. ", count: 120)
        let normal = try ContextWindowPolicy.makePrompt(latest: latest, instructions: "Keep provenance.", fields: [.init("reports", [String(repeating: "old ", count: 400)])], reduced: false)
        let reduced = try ContextWindowPolicy.makePrompt(latest: latest, instructions: "Keep provenance.", fields: [.init("reports", [String(repeating: "old ", count: 400)])], reduced: true)
        XCTAssertTrue(normal.prompt.contains(latest))
        XCTAssertTrue(reduced.prompt.contains(latest))
        XCTAssertLessThan(reduced.inputUTF8Bytes, normal.inputUTF8Bytes)
        XCTAssertLessThanOrEqual(try JSONEncoder().encode(reduced.context).count, ContextWindowPolicy.reducedContextUTF8Bytes)
        XCTAssertGreaterThan(reduced.estimatedInputTokens, 0)
    }
    func testOversizeLatestAndInstructionsFailRatherThanClip() {
        XCTAssertThrowsError(try ContextWindowPolicy.makePrompt(latest: String(repeating: "x", count: 2001), instructions: "test", fields: [], reduced: true))
        XCTAssertThrowsError(try ContextWindowPolicy.makePrompt(latest: "hello", instructions: String(repeating: "x", count: 3501), fields: [], reduced: false))
        XCTAssertThrowsError(try ContextWindowPolicy.makePrompt(latest: String(repeating: "😀", count: 2000), instructions: String(repeating: "x", count: 3000), fields: [], reduced: true))
    }
    func testOverflowAllowsOnlyOneRetryBeforeOutput() {
        var state = ContextWindowPolicy.Recovery()
        XCTAssertEqual(state.onOverflow(emittedText: "", cancelled: false), .retryReduced)
        XCTAssertEqual(state.retries, 1)
        XCTAssertEqual(state.onOverflow(emittedText: "", cancelled: false), .stop)
        XCTAssertEqual(state.retries, 1)
    }
    func testOverflowAfterEmissionPreservesPrefixWithoutRetry() {
        var state = ContextWindowPolicy.Recovery()
        XCTAssertEqual(state.onOverflow(emittedText: "Where did you last have it?", cancelled: false), .preservePartial)
        XCTAssertEqual(state.retries, 0)
        let suffix = ContextWindowPolicy.incompleteSuffix(delivered: "Where did you last have it?", arabic: false)
        XCTAssertFalse(suffix.contains("Where did you"))
        XCTAssertTrue(suffix.contains("couldn't finish"))
        XCTAssertEqual(ContextWindowPolicy.incompleteSuffix(delivered: String(repeating: "word ", count: 35), arabic: false), "")
    }
    func testCancellationWinsBeforeAnyRecovery() {
        var state = ContextWindowPolicy.Recovery()
        XCTAssertEqual(state.onOverflow(emittedText: "", cancelled: true), .cancelled)
        XCTAssertEqual(state.onOverflow(emittedText: "Hello.", cancelled: true), .cancelled)
        XCTAssertEqual(state.retries, 0)
    }
    func testModelCancellationRequiresWholeExplicitUserCommand() {
        for input in ["do not cancel", "don't cancel the task", "if I say cancel, what happens?", "Explain the word cancel", "\"cancel\"", "لا تلغ المهمة", "cancel the old task and find my cup"] {
            XCTAssertFalse(CompanionTaskMutationPolicy.cancellation(quote: "cancel", latest: input), input)
            XCTAssertFalse(CompanionTaskMutationPolicy.cancellation(quote: input, latest: input), input)
        }
        for input in ["cancel the task", "Please cancel that.", "الغ المهمة"] {
            XCTAssertTrue(CompanionTaskMutationPolicy.cancellation(quote: input, latest: input), input)
        }
    }
    func testModelGoalMustBeExactCompleteSupportedUserIntent() {
        XCTAssertTrue(CompanionTaskMutationPolicy.newGoal(proposal: "Help me find my cup", latest: "Help me find my cup"))
        XCTAssertFalse(CompanionTaskMutationPolicy.newGoal(proposal: "find my cup", latest: "Do not find my cup"))
        XCTAssertFalse(CompanionTaskMutationPolicy.newGoal(proposal: "The cup is open", latest: "The cup is open"))
        XCTAssertFalse(CompanionTaskMutationPolicy.newGoal(proposal: "find my cup", latest: "If I say find my cup, what happens?"))
    }
    func testToolOutputsStayWithinPerResultAndWholeTurnByteBudgets() async throws {
        let source = String(repeating: "r", count: 80)
        let evidence = (0..<4).map { index in
            CompanionEvidence(id: String(index), kind: .historicalMemory, text: String(repeating: "معلومة قديمة وليست الآن ", count: 10), source: source)
        }
        let runtime = CompanionToolRuntime(available: [.savedMemory]) { _ in
            CompanionToolResult(status: .success, source: source, summary: String(repeating: "historical only ", count: 30), evidence: evidence)
        }
        for _ in 0..<3 {
            let result = await runtime.run(.init(kind: .savedMemory))
            XCTAssertLessThanOrEqual(try JSONEncoder().encode(result).count, ContextWindowPolicy.maximumToolResultUTF8Bytes)
            XCTAssertTrue(result.evidence.allSatisfy { evidence.contains($0) })
        }
        let used = await runtime.resultUTF8BytesUsed()
        XCTAssertLessThanOrEqual(used, ContextWindowPolicy.maximumTurnToolResultUTF8Bytes)
    }
    func testToolQueryUTF8BudgetRejectsOversizeWithoutExecution() async {
        let runtime = CompanionToolRuntime(available: [.savedMemory]) { _ in
            XCTFail("Oversize query must not execute")
            return CompanionToolResult(status: .success, source: "test")
        }
        let result = await runtime.run(.init(kind: .savedMemory, query: String(repeating: "😀", count: 200)))
        XCTAssertEqual(result.status, .unavailable)
    }
}
