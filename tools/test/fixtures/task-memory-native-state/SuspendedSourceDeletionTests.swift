import XCTest
import BlindCore
@testable import NativeStateReplay

final class SuspendedSourceDeletionTests: XCTestCase {
    func testDeletedCompletionCannotReappearWhenPausedGoalResumes() {
        var state = CompanionWorkingState()
        state.changeGoal("Help me make breakfast"); state.proposedStep = "Check the milk"
        let report = "I got the milk"
        state.record(report)
        state.apply(.init(goal: "", nextStep: "", completionReport: report,
                          completionStep: "Check the milk", contextRevision: state.goalRevision), latest: report)
        XCTAssertEqual(state.reportedCompletedSteps, ["Check the milk"])
        XCTAssertTrue(state.suspendGoal())
        XCTAssertTrue(state.removeReport(report))
        XCTAssertTrue(state.resumeGoal())
        XCTAssertTrue(state.reportedCompletedSteps.isEmpty)
    }
    func testDeletionCleansSuspendedParentButRetainsUnrelatedCompletion() {
        var state = CompanionWorkingState()
        state.changeGoal("Help me make breakfast"); state.proposedStep = "Check the milk"
        let report = "I got the milk"
        state.record(report)
        state.apply(.init(goal: "", nextStep: "", completionReport: report,
                          completionStep: "Check the milk", contextRevision: state.goalRevision), latest: report)
        state.reportedCompletedSteps.append("Reported packing lunch")
        _ = state.respond(to: .find(object: "cup"), message: "Find my cup", arabic: false)
        XCTAssertEqual(state.parentGoal?.reportedCompletedSteps, ["Check the milk", "Reported packing lunch"])
        state.proposedStep = "Ask about the cup"
        XCTAssertTrue(state.suspendGoal())
        XCTAssertTrue(state.removeReport(report))
        XCTAssertEqual(state.suspendedGoals.last?.proposedStep, "")
        XCTAssertEqual(state.suspendedGoals.last?.parentGoal?.reportedCompletedSteps, ["Reported packing lunch"])
        XCTAssertTrue(state.resumeGoal())
        XCTAssertTrue(state.resumeGoal())
        XCTAssertEqual(state.reportedCompletedSteps, ["Reported packing lunch"])
    }
}
