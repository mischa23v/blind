import XCTest
import BlindCore
@testable import NativeStateReplay

final class WorkingStateProvenanceTests: XCTestCase {
    let old = Date(timeIntervalSince1970: 1_600_000_000)
    func testOriginalGoalSurvivesFindParaphrasePauseResumeAndRestart() throws {
        let original = "Please help me get ready for school after breakfast."
        var state = CompanionWorkingState()
        state.changeGoal("School", originalRequest: original, sourceID: "original-request", at: old)
        let find = "Find my backpack"
        _ = state.respond(to: try XCTUnwrap(CompanionUtterance.parse(find)), message: find, arabic: false)
        XCTAssertEqual(state.parentGoal?.source?.originalRequest, original)
        XCTAssertEqual(state.goalSource?.originalRequest, find)
        state.suspendGoal()
        state = try JSONDecoder().decode(CompanionWorkingState.self, from: JSONEncoder().encode(state))
        XCTAssertTrue(state.resumeGoal())
        XCTAssertEqual(state.parentGoal?.source?.recordedAt, old)
        XCTAssertEqual(state.goalSource?.originalRequest, find)
        XCTAssertTrue(state.recordCompletedSubtask(find, report: "I found my backpack"))
        XCTAssertEqual(state.goal, "School")
        XCTAssertEqual(state.goalSource?.originalRequest, original)
        XCTAssertEqual(state.goalSource?.recordedAt, old)
        XCTAssertEqual(state.goalSource?.sourceID, "original-request")
        state.removeReport(original)
        XCTAssertEqual(state.goal, "")
        XCTAssertNil(state.goalSource)
    }
    func testReplayUnknownDatesStaysUnknownAndDoesNotDuplicate() throws {
        var state = CompanionWorkingState()
        state.record("I left my cup on the shelf.", at: old)
        state.record("I put my keys in the drawer.", at: nil)
        state.record("I put my keys in the drawer.", at: nil)
        state = try JSONDecoder().decode(CompanionWorkingState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(state.reports.count, 2)
        XCTAssertEqual(state.reports[0].time, old)
        XCTAssertNil(state.reports[1].time)
        XCTAssertNil(state.goalSource)
        XCTAssertTrue(state.factBook.facts.isEmpty, "History replay must not manufacture present location facts")
    }
    func testChangingObjectsKeepsExactPronounReportsBoundAcrossRestart() throws {
        var state = CompanionWorkingState()
        let messages = ["Find my cup", "I left it on the shelf.", "Find my keys", "I put them in the drawer.", "Find my cup", "I left it on the desk."]
        for (index, message) in messages.enumerated() {
            let date = old.addingTimeInterval(Double(index))
            state.record(message, at: date)
            _ = state.respond(to: try XCTUnwrap(CompanionUtterance.parse(message)), message: message, now: date, arabic: false)
        }
        state = try JSONDecoder().decode(CompanionWorkingState.self, from: JSONEncoder().encode(state))
        let cup = CompanionMemoryRetrieval.read(query: "cup", now: old.addingTimeInterval(1000), locationReports: state.locationReports)
        let keys = CompanionMemoryRetrieval.read(query: "keys", now: old.addingTimeInterval(1000), locationReports: state.locationReports)
        XCTAssertEqual(cup.evidence.first?.text, messages[5])
        XCTAssertEqual(cup.evidence.first?.observedAt, old.addingTimeInterval(5))
        XCTAssertEqual(keys.evidence.first?.text, messages[3])
        XCTAssertEqual(keys.evidence.first?.observedAt, old.addingTimeInterval(3))
        XCTAssertFalse(cup.evidence.first!.isCurrent(at: old.addingTimeInterval(1000)))
        XCTAssertFalse(keys.evidence.first!.isCurrent(at: old.addingTimeInterval(1000)))
        state.removeReport(messages[5])
        XCTAssertTrue(CompanionMemoryRetrieval.read(query: "cup", now: old.addingTimeInterval(1000), locationReports: state.locationReports).evidence.isEmpty)
    }
    func testNewerLocationIsNotVetoedByOlderReportReplayedLater() throws {
        var state = CompanionWorkingState()
        let current = "I left my cup on the desk."
        let oldReport = "I left my cup on the shelf."
        _ = state.respond(to: try XCTUnwrap(CompanionUtterance.parse(current)), message: current, now: old.addingTimeInterval(10), arabic: false)
        _ = state.respond(to: try XCTUnwrap(CompanionUtterance.parse(oldReport)), message: oldReport, now: old, arabic: false)
        XCTAssertEqual(state.locationReports.first?.originalReport, current)
        XCTAssertEqual(state.factBook.latest(for: "cup")?.place, "on the desk")
    }
    func testFridgeReportsStayScopedAfterDifferentGoalAndRestart() throws {
        var state = CompanionWorkingState()
        state.changeGoal("Prepare breakfast", originalRequest: "Help me prepare breakfast", at: old)
        let revision = state.goalRevision
        state.actionProgress.ingestUserReport("The fridge is open", sourceID: "old-fridge", goalRevision: revision, at: old)
        state.changeGoal("Prepare a snack at school", originalRequest: "Help me prepare a snack at school", at: old.addingTimeInterval(10))
        state = try JSONDecoder().decode(CompanionWorkingState.self, from: JSONEncoder().encode(state))
        XCTAssertNil(state.actionProgress.latestReport(for: .refrigeratorDoor, goalRevision: state.goalRevision))
        XCTAssertTrue(state.actionProgress.allowsProposal("Open the fridge", goalRevision: state.goalRevision))
        XCTAssertNotNil(state.actionProgress.latestReport(for: .refrigeratorDoor, goalRevision: revision))
        XCTAssertFalse(state.actionProgress.contextFields(goalRevision: state.goalRevision).flatMap(\.values).joined().contains("old-fridge"))
    }
}
