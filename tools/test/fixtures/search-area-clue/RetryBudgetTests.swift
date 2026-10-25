import XCTest
import BlindCore
@testable import SearchAreaReplay

/// Authored portable adapter replay. Pending speech here is NOT AVSpeech.
final class SearchAreaRetryBudgetTests: XCTestCase {
    private func correctedSearch() -> SearchAreaReplay {
        let c = SearchAreaReplay()
        c.receiveCompanionUtterance("Help me find my fridge")
        c.receiveCompanionUtterance("in the kitchen")
        c.receiveCompanionUtterance("No, in the garage")
        c.receiveCompanionUtterance("Where is my fridge?")
        return c
    }
    func testPostForgetClarifiesWithoutAnotherSensorAttempt() {
        let c = correctedSearch(), goal = "Help me find my fridge"
        let revision = c.companionWorkingState.goalRevision
        XCTAssertEqual(c.everydayTasks.attempts, 2)
        let sensorCount = c.sensorPermissions.filter { $0 }.count
        c.receiveCompanionUtterance("Forget my fridge")
        XCTAssertNil(c.companionWorkingState.searchAreaClue.clue)
        c.receiveCompanionUtterance("Help me find my fridge")
        XCTAssertTrue(c.currentReply.contains("room or area"))
        XCTAssertEqual(c.companionWorkingState.searchAreaClue.deliveredVia, .trustedText)
        XCTAssertEqual(c.everydayTasks.attempts, 2)
        XCTAssertEqual(c.sensorPermissions.filter { $0 }.count, sensorCount)
        XCTAssertEqual(c.sensorPermissions.last, false)
        XCTAssertEqual(c.companionWorkingState.goal, goal)
        XCTAssertEqual(c.companionWorkingState.goalRevision, revision)
        XCTAssertTrue(c.companionWorkingState.factBook.facts.isEmpty)
        XCTAssertTrue(c.companionWorkingState.reportedCompletedSteps.isEmpty)
        XCTAssertTrue(c.modelInputs.isEmpty)
    }
    func testRepeatedExhaustedFindCannotReopenAdapterBudget() {
        let c = correctedSearch()
        let sensorCount = c.sensorPermissions.filter { $0 }.count
        for _ in 0..<5 {
            c.receiveCompanionUtterance("Help me find my fridge")
            XCTAssertTrue(c.currentReply.contains("garage"))
            XCTAssertEqual(c.everydayTasks.attempts, 2)
            XCTAssertEqual(c.everydayTasks.state, .needsHelp)
            XCTAssertEqual(c.sensorPermissions.filter { $0 }.count, sensorCount)
        }
        XCTAssertTrue(c.modelInputs.isEmpty)
    }
    func testDifferentTargetMayStartItsOwnBoundedAttempt() {
        let c = correctedSearch()
        c.receiveCompanionUtterance("Help me find my fridge")
        let sensorCount = c.sensorPermissions.filter { $0 }.count
        c.receiveCompanionUtterance("Help me find my backpack")
        XCTAssertEqual(c.everydayTasks.attempts, 1)
        XCTAssertEqual(c.sensorPermissions.filter { $0 }.count, sensorCount + 1)
        XCTAssertEqual(c.companionWorkingState.focusObject, "backpack")
        XCTAssertNil(c.companionWorkingState.searchAreaClue.clue)
    }
    func testCodeOnlyContinuationStillUsesExplicitReportedHistory() {
        let c = correctedSearch()
        c.receiveCompanionUtterance("Help me find my fridge")
        let sensorCount = c.sensorPermissions.filter { $0 }.count
        c.receiveCompanionUtterance("My fridge is in the kitchen")
        c.receiveCompanionUtterance("Help me find my fridge")
        XCTAssertTrue(c.currentReply.contains("kitchen"))
        XCTAssertFalse(c.currentReply.contains("garage"))
        XCTAssertNil(c.companionWorkingState.searchAreaClue.question)
        XCTAssertEqual(c.everydayTasks.attempts, 2)
        XCTAssertEqual(c.sensorPermissions.filter { $0 }.count, sensorCount)
        XCTAssertTrue(c.modelInputs.isEmpty)
    }
    func testLongItemNameCannotResetExhaustedBudgetWhenClarificationParserDeclines() {
        let c = SearchAreaReplay()
        let query = "Where is my little red school lunch bag?"
        XCTAssertNotNil(ItemCommand.parse(query))
        XCTAssertNil(CompanionUtterance.parse(query))
        XCTAssertFalse(c.routeEverydayTask(query))
        XCTAssertEqual(c.everydayTasks.attempts, 1)
        XCTAssertFalse(c.routeEverydayTask(query))
        XCTAssertEqual(c.everydayTasks.attempts, 2)
        XCTAssertTrue(c.routeEverydayTask(query))
        XCTAssertEqual(c.everydayTasks.state, .needsHelp)
        for _ in 0..<5 {
            XCTAssertTrue(c.routeEverydayTask(query))
            XCTAssertEqual(c.everydayTasks.attempts, 2)
            XCTAssertEqual(c.everydayTasks.state, .needsHelp)
            XCTAssertNil(c.everydayTicket)
        }
        XCTAssertTrue(c.sensorPermissions.isEmpty)
        XCTAssertTrue(c.modelInputs.isEmpty)
    }

}
