import XCTest
import BlindCore
@testable import NativeStateReplay

/// Exercises production response selection, not a classifier or copied answer.
final class FindClarificationTests: XCTestCase {
    private func say(_ text: String, to state: inout CompanionWorkingState, arabic: Bool = false, at: Double = 100) throws -> String {
        try state.respond(to: XCTUnwrap(CompanionUtterance.parse(text)), message: text,
                          now: Date(timeIntervalSince1970: at), arabic: arabic)
    }
    func testUnknownFixedPlacesAndBelongingsAskUsefulNonPossessiveHistory() throws {
        for text in ["Help me find my fridge", "Where is the refrigerator?", "Find the bathroom", "Find the front door", "Find my cup", "Find my backpack"] {
            var state = CompanionWorkingState()
            let reply = try say(text, to: &state)
            XCTAssertTrue(reply.hasSuffix("Do you know which room or area to look in?"), reply)
            XCTAssertFalse(reply.contains("last have"), reply)
            XCTAssertFalse(state.goal.isEmpty)
            XCTAssertTrue(state.reportedCompletedSteps.isEmpty)
        }
    }
    func testArabicAndRephraseKeepGoalWithoutInventedLocation() throws {
        var state = CompanionWorkingState()
        let first = try say("وين الثلاجة", to: &state, arabic: true)
        XCTAssertEqual(first, "لا أعرف مكان «الثلاجة» بعد. هل تعرف في أي غرفة أو مكان نبحث؟")
        let revision = state.goalRevision
        let second = try say("ساعدني ألاقي الثلاجة", to: &state, arabic: true)
        XCTAssertEqual(second, first)
        XCTAssertEqual(state.goalRevision, revision)
        XCTAssertTrue(state.reportedCompletedSteps.isEmpty)
    }
    func testFailedSearchUsesSameQuestionButNeverTurnsMissIntoAbsence() throws {
        var state = CompanionWorkingState()
        state.lastSearch = SearchRecord(target: "fridge", located: false, at: Date(timeIntervalSince1970: 90))
        let reply = try say("Find my fridge", to: &state)
        XCTAssertTrue(reply.contains("didn't locate your fridge"), reply)
        XCTAssertTrue(reply.hasSuffix("Do you know which room or area to look in?"), reply)
        XCTAssertFalse(reply.contains("isn't here"), reply)
        XCTAssertTrue(state.reportedCompletedSteps.isEmpty)
    }
    func testAnswerAndCorrectionBecomeAttributedHistoryNotCurrentLocation() throws {
        var state = CompanionWorkingState()
        _ = try say("Find my fridge", to: &state)
        _ = try say("It was in the kitchen", to: &state, at: 101)
        _ = try say("It was in the garage", to: &state, at: 102)
        let reply = try say("Where is my fridge?", to: &state, at: 103)
        XCTAssertTrue(reply.contains("You told me"), reply)
        XCTAssertTrue(reply.contains("garage"), reply)
        XCTAssertFalse(reply.contains("kitchen"), reply)
        XCTAssertFalse(reply.contains("last had"), reply)
        XCTAssertTrue(reply.contains("I don't know where it is now"), reply)
        XCTAssertTrue(state.reportedCompletedSteps.isEmpty)
    }
    func testNewBelongingGoalDoesNotReuseFridgeHistoryOrCompleteParent() throws {
        var state = CompanionWorkingState(); state.changeGoal("Get a drink")
        _ = try say("Find my fridge", to: &state)
        _ = try say("It was in the kitchen", to: &state, at: 101)
        let revision = state.goalRevision
        let reply = try say("Find my cup", to: &state, at: 102)
        XCTAssertEqual(reply, "I don't know where your cup is yet. Do you know which room or area to look in?")
        XCTAssertNotEqual(state.goalRevision, revision)
        XCTAssertEqual(state.focusObject, "cup")
        XCTAssertEqual(state.parentGoal?.goal, "Get a drink")
        XCTAssertTrue(state.reportedCompletedSteps.isEmpty)
        let acknowledgement = try say("I saw my cup on the table", to: &state, at: 103)
        XCTAssertEqual(acknowledgement, "Got it. You said your cup was on the table. I'll remember that.")
        let history = try say("Where is my cup?", to: &state, at: 104)
        XCTAssertTrue(history.contains("your cup was on the table"), history)
        XCTAssertTrue(history.contains("I don't know where it is now"), history)
    }
}
