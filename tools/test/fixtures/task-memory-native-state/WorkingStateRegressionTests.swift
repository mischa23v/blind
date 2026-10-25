import XCTest
import BlindCore
@testable import NativeStateReplay

/// Exact extracted production structs, not an iOS app build or model run.
final class WorkingStateRegressionTests: XCTestCase {
    func testRepeatedFindWithParentRetainsProgressAndRevision() throws {
        for (find, repeatFind) in [("Find my backpack", "Find my backpack"), ("Find my cup", "Where is my cup?"), ("وين حقيبتي", "ساعدني ألاقي حقيبتي")] {
            var state = CompanionWorkingState(); state.changeGoal("Get ready for school")
            _ = state.respond(to: try XCTUnwrap(CompanionUtterance.parse(find)), message: find, arabic: false)
            state.reportedCompletedSteps = ["Reported packing lunch"]
            let revision = state.goalRevision, original = state.goal
            _ = state.respond(to: try XCTUnwrap(CompanionUtterance.parse(repeatFind)), message: repeatFind, arabic: false)
            XCTAssertEqual(state.goalRevision, revision, repeatFind)
            XCTAssertEqual(state.goal, original, repeatFind)
            XCTAssertEqual(state.reportedCompletedSteps, ["Reported packing lunch"], repeatFind)
            XCTAssertEqual(state.parentGoal?.goal, "Get ready for school")
        }
    }
    func testGenericCompletionCannotEndFindOrRestoreParent() throws {
        for report in ["done", "I did it", "I'm done", "خلصت", "انتهيت"] {
            var state = CompanionWorkingState(); state.changeGoal("Get ready for school")
            let request = "Find my backpack"
            _ = state.respond(to: try XCTUnwrap(CompanionUtterance.parse(request)), message: request, arabic: false)
            let revision = state.goalRevision
            XCTAssertFalse(state.recordCompletedSubtask(request, report: report), report)
            XCTAssertEqual(state.goal, request)
            XCTAssertEqual(state.goalRevision, revision)
            XCTAssertTrue(state.reportedCompletedSteps.isEmpty)
        }
    }
}
