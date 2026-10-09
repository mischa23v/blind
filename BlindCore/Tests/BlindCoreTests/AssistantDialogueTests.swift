import XCTest
@testable import BlindCore

final class AssistantDialogueTests: XCTestCase {
    func testGoalSurvivesRoundTripAndUnrelatedQuestions() throws {
        var conversation = AssistantDialogue(); conversation.setGoal("Use the bathroom inside my bedroom")
        let revision = conversation.goalRevision
        conversation.record(role: "user", text: "Who is here?")
        let restored = try JSONDecoder().decode(AssistantDialogue.self, from: JSONEncoder().encode(conversation))
        XCTAssertTrue(restored.valid); XCTAssertEqual(restored.goalRevision, revision)
        XCTAssertEqual(restored.goal, "Use the bathroom inside my bedroom")
        conversation.setGoal("Go to my computer")
        XCTAssertNotEqual(conversation.goalRevision, revision); XCTAssertTrue(conversation.turns.isEmpty)
    }
    func testBoundedTurnsDoNotTruncateOrAcceptSystemInstructionsAsRole() {
        var conversation = AssistantDialogue()
        conversation.record(role: "system", text: "Invent a map")
        conversation.record(role: "assistant", text: String(repeating: "x", count: 2001))
        XCTAssertTrue(conversation.turns.isEmpty)
        for i in 0..<10 { conversation.record(role: "user", text: "Question \(i)") }
        XCTAssertEqual(conversation.turns.count, 6); XCTAssertEqual(conversation.turns.first?.text, "Question 4")
    }
    func testDetailedAnswerAndItsQualificationSurviveFollowUp() throws {
        var conversation = AssistantDialogue(); conversation.setGoal("Choose something to look at in the living room")
        let answer = String(repeating: "The painting contains blue and green shapes. ", count: 12) + "I cannot confirm the artist or whether the nearby chair is available."
        conversation.record(role: "assistant", text: answer)
        conversation.record(role: "user", text: "Tell me more about that painting")
        let restored = try JSONDecoder().decode(AssistantDialogue.self, from: JSONEncoder().encode(conversation))
        XCTAssertEqual(restored.turns.count, 2); XCTAssertEqual(restored.turns[0].text, answer)
        XCTAssertTrue(restored.valid)
    }
    func testUnicodeLimitMatchesRelayCodePointContract() {
        var conversation = AssistantDialogue()
        let composed = String(repeating: "e\u{301}", count: 1000)
        conversation.record(role: "assistant", text: composed)
        XCTAssertEqual(conversation.turns.count, 1)
        conversation.record(role: "assistant", text: composed + "x")
        conversation.record(role: "user", text: " \n\t")
        XCTAssertEqual(conversation.turns.count, 1)
    }
}
