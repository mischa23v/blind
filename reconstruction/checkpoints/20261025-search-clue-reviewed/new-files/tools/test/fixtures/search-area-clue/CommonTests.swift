import XCTest
import BlindCore
@testable import SearchAreaReplay

final class SearchAreaCommonTests: XCTestCase {
    func testThreeTurnAreaClueIsDeterministicWithoutInventingLocation() {
        let c = SearchAreaReplay()
        c.receiveCompanionUtterance("Help me find my fridge")
        let goal = c.companionWorkingState.goal, question = c.currentReply
        c.receiveCompanionUtterance("in the kitchen")
        let firstReply = c.currentReply
        c.receiveCompanionUtterance("No, in the garage")
        print("AUTHORED_AREA_REPLAY question=\(question) first=\(firstReply) final=\(c.currentReply) modelBoundaryInputs=\(c.modelInputs) goal=\(c.companionWorkingState.goal)")
        XCTAssertEqual(c.companionWorkingState.goal, goal)
        XCTAssertTrue(c.companionWorkingState.factBook.facts.isEmpty)
        XCTAssertTrue(c.companionWorkingState.reportedCompletedSteps.isEmpty)
        XCTAssertEqual(c.modelInputs, [], "A fallback invocation is not a claim that the real model fails")
        XCTAssertNotEqual(firstReply, question)
        XCTAssertTrue(firstReply.contains("in the kitchen"))
        XCTAssertTrue(c.currentReply.contains("in the garage"))
        XCTAssertFalse(c.currentReply.contains("in the kitchen"))
        XCTAssertTrue(c.currentReply.contains("clue"))
    }
}
