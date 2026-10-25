import XCTest
@testable import BlindCore

/// Authored, deterministic regressions against production Core state. These are
/// not model runs, camera observations, native UI tests or physical trials.
final class TaskMemoryRebuildRegressionTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testOldLocationReplayCannotReplaceNewerReport() throws {
        for object in ["cup", "كوبي"] {
            var book = CompanionFactBook()
            _ = book.record(object: object, place: "on the desk", tense: .earlier, hedged: false, at: now)
            XCTAssertNil(book.record(object: object, place: "on the shelf", tense: .earlier, hedged: false, at: now.addingTimeInterval(-100)))
            XCTAssertEqual(book.latest(for: object)?.place, "on the desk")
            XCTAssertEqual(book.latest(for: object)?.at, now)
            let saved = try JSONDecoder().decode(CompanionFactBook.self, from: JSONEncoder().encode(book))
            XCTAssertEqual(saved.latest(for: object)?.place, "on the desk")
        }
    }

    func testRepeatedGoalPreservesProgressAndInflightAdapter() throws {
        for goal in ["Get ready for school", "جهزني للمدرسة"] {
            var tasks = EverydayTaskCoordinator()
            XCTAssertTrue(tasks.setGoal(goal))
            let wanted = try XCTUnwrap(EverydayTaskRequest(capability: .findItem, query: "backpack"))
            tasks.begin(wanted)
            XCTAssertTrue(tasks.confirmSubtaskComplete())
            tasks.begin(try XCTUnwrap(EverydayTaskRequest(capability: .readText, query: "worksheet")))
            guard case .run(let ticket) = tasks.next(available: [.readText], now: 0) else { return XCTFail("Expected actual adapter ticket") }
            let originalGoal = tasks.goal
            XCTAssertFalse(tasks.setGoal(goal))
            XCTAssertEqual(tasks.goal, originalGoal)
            XCTAssertEqual(tasks.completedSubtasks, ["backpack"])
            XCTAssertTrue(tasks.receive(ticket, outcome: .informationReady, now: 1))
        }
    }

    func testRepeatedDialogueGoalDoesNotInvalidateCurrentRevision() {
        for goal in ["Find my backpack", "ساعدني ألاقي حقيبتي"] {
            var dialogue = AssistantDialogue()
            dialogue.setGoal(goal)
            let originalRevision = dialogue.goalRevision
            dialogue.record(role: "user", text: "What colour is this?")
            dialogue.record(role: "assistant", text: "I do not have a colour result yet.")
            dialogue.setGoal(goal)
            XCTAssertEqual(dialogue.goalRevision, originalRevision)
            XCTAssertEqual(dialogue.goal, goal)
            XCTAssertEqual(dialogue.turns.count, 2)
        }
    }

    func testTableArrivalAndBareDoneCannotCompleteModelAssociatedStep() {
        for report in ["I did it", "I'm done", "I’m done", "I finished", "I have completed", "I've already finished", "I finished it", "I got it", "I found them", "I'm at the table", "I am at the table", "I am in the bedroom", "I am now standing by the counter", "I've arrived at the table", "I reached the bedroom", "انا عند الطاولة", "أنا في غرفة النوم", "انا واقف عند الطاولة", "انا خلصت", "خلصت", "انتهيت"] {
            XCTAssertNil(CompanionReportedStep.proposed(step: "Find backpack", currentStep: "Find backpack", quote: report, latest: report, goalRevision: "school"), report)
        }
    }

    func testArabicAndEnglishObjectPronounsCannotBindModelSelectedStep() {
        for report in ["I opened it", "I got it", "I've retrieved them", "فتحتها", "أخذته", "أنا لقيته", "أنا جبتها", "وجدتهم", "حطيتها", "اغلقته", "انا فتحت هذا", "اخذت هذه", "أنا قد وجدته"] {
            XCTAssertNil(CompanionReportedStep.proposed(step: "Prepare for school", currentStep: "Prepare for school", quote: report, latest: report, goalRevision: "school"), report)
        }
        for report in ["I opened the fridge", "I got the milk", "فتحت الثلاجة", "أخذت الحليب", "أنا لقيت الحقيبة"] {
            XCTAssertNotNil(CompanionReportedStep.proposed(step: "Discuss needed items", currentStep: "Discuss needed items", quote: report, latest: report, goalRevision: "school"), report)
        }
    }
}
