import XCTest
@testable import BlindCore

/// Synthetic language/state cases through production Core APIs, not LLM/native
/// execution. No generated perception or physical guidance is tested as fact.
final class TaskMemorySourceAndCompletionTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testCanonicalLabelIsNeverTheExactUserGoalSource() throws {
        for (original, label) in [
            ("Please help me get my backpack so I can finish getting ready for school.", "Find backpack"),
            ("ساعدني ألاقي حقيبتي عشان أجهز للمدرسة", "حقيبة المدرسة")
        ] {
            let source = try XCTUnwrap(CompanionTaskSource(originalRequest: original, canonicalLabel: label, sourceID: "utterance", recordedAt: now))
            let restored = try JSONDecoder().decode(CompanionTaskSource.self, from: JSONEncoder().encode(source))
            XCTAssertEqual(restored.originalRequest, original)
            XCTAssertEqual(restored.canonicalLabel, label)
            XCTAssertEqual(restored.recordedAt, now)
            XCTAssertEqual(restored.memoryNote.text, original)
            XCTAssertNotEqual(restored.memoryNote.text, label)
            XCTAssertTrue(restored.memoryNote.source.contains("original user goal"))
        }
        let maximumID = String(repeating: "a", count: 75)
        let bounded = try XCTUnwrap(CompanionTaskSource(originalRequest: "Find my backpack", canonicalLabel: "backpack", sourceID: maximumID))
        XCTAssertEqual(CompanionMemoryRetrieval.read(query: "backpack", now: now, taskContext: [bounded.memoryNote]).evidence.first?.id, "task:" + maximumID)
        XCTAssertNil(CompanionTaskSource(originalRequest: "Find my backpack", canonicalLabel: "backpack", sourceID: maximumID + "a"))
        XCTAssertNil(CompanionTaskSource(originalRequest: "", canonicalLabel: "Find backpack", sourceID: "legacy"))
        XCTAssertNil(CompanionTaskSource(originalRequest: String(repeating: "x", count: 2001), canonicalLabel: "Find backpack", sourceID: "long"))
    }

    func testTargetNamedCompletionAcceptsWholeEnglishArabicReportsOnly() throws {
        let cases: [(String, [String])] = [
            ("cup", ["I found my cup", "I've found the cup.", "I have found my cup!", "I just located the cup", "I retrieved my cup"]),
            ("كوبي", ["لقيت كوبي", "أنا وجدت كوبي", "جبت كوبي."]),
            ("الحقيبة", ["وجدت الحقيبة", "لقيت الحقيبة", "أنا أحضرت الحقيبة!"])
        ]
        for (target, reports) in cases {
            let request = try XCTUnwrap(EverydayTaskRequest(capability: .findItem, query: target))
            for report in reports { XCTAssertTrue(CompanionTaskCompletion.matches(report, request: request), report) }
            for report in ["done", "I did it", "I'm done", "I’m at the table", "I found my keys", "I found it", "I have not found my cup", "I didn't find my cup", "I found my cup?", "Mom said I found my cup", "I found my cup in the game", "I found my cup but not the real one", "I found my cup and keys", "I found my cupboard", "خلصت", "انا عند الطاولة", "أنا لم أجد الحقيبة", "قالت أمي وجدت الحقيبة", "وجدت الحقيبة؟"] {
                XCTAssertFalse(CompanionTaskCompletion.matches(report, request: request), "\(target): \(report)")
            }
        }
        XCTAssertFalse(CompanionTaskCompletion.matches("I found my cup", request: try XCTUnwrap(EverydayTaskRequest(capability: .clothingColor, query: "cup"))))
    }

    func testPronounSourceRetrievesOnlyItsCodeBoundObjectAndOriginalTime() throws {
        let reports = [
            try XCTUnwrap(CompanionLocationReport(id: "cup", object: "cup", originalReport: "I left it on the desk.", recordedAt: now.addingTimeInterval(-20))),
            try XCTUnwrap(CompanionLocationReport(id: "keys", object: "keys", originalReport: "I put them in the drawer.", recordedAt: now.addingTimeInterval(-10))),
            try XCTUnwrap(CompanionLocationReport(id: "ar-cup", object: "كوبي", originalReport: "حطيته على المكتب", recordedAt: now))
        ]
        for (query, expected) in [("Where is my cup?", "cup"), ("Please recall my keys", "keys"), ("وين كوبي؟", "ar-cup")] {
            let result = CompanionMemoryRetrieval.read(query: query, now: now, locationReports: reports)
            let original = try XCTUnwrap(reports.first { $0.id == expected })
            XCTAssertEqual(result.evidence.count, 1, query)
            XCTAssertEqual(result.evidence.first?.text, original.originalReport)
            XCTAssertEqual(result.evidence.first?.observedAt, original.recordedAt)
            XCTAssertEqual(result.evidence.first?.kind, .userReport)
            XCTAssertNil(result.evidence.first?.expiresAt)
            XCTAssertFalse(result.evidence.first!.isCurrent(at: now))
            XCTAssertTrue(result.evidence.first!.source.contains(original.object))
        }
        let longestName = String(repeating: "c", count: ItemMemory.nameLimit)
        let longObject = try XCTUnwrap(CompanionLocationReport(id: "bounded-name", object: longestName, originalReport: "I left it on the desk.", recordedAt: now))
        XCTAssertEqual(CompanionMemoryRetrieval.read(query: longestName, now: now, locationReports: [longObject]).evidence.first?.text, longObject.originalReport)
        // Unbound pronouns must not be attached to the current query's object.
        let unbound = CompanionEvidence(id: "unbound", kind: .userReport, text: "I left it on the desk.", source: "original user conversation record")
        XCTAssertTrue(CompanionMemoryRetrieval.read(query: "cup", now: now, reports: [unbound]).evidence.isEmpty)
        XCTAssertNil(CompanionLocationReport(id: "bad", object: "keys", originalReport: "I left my cup on the desk.", recordedAt: now))
    }

    func testNewestCorrectionWinsDespiteReorderedHistoryWithoutRefreshingTime() throws {
        let old = try XCTUnwrap(CompanionLocationReport(id: "old", object: "cup", originalReport: "I left my cup on the shelf.", recordedAt: now.addingTimeInterval(-100)))
        let newest = try XCTUnwrap(CompanionLocationReport(id: "new", object: "cup", originalReport: "I left it on the desk.", recordedAt: now.addingTimeInterval(-20)))
        let raw = CompanionEvidence(id: "old-raw", kind: .userReport, text: old.originalReport, source: "original user conversation record", observedAt: old.recordedAt)
        for ordered in [[old, newest], [newest, old]] {
            let saved = try JSONDecoder().decode([CompanionLocationReport].self, from: JSONEncoder().encode(ordered))
            let result = CompanionMemoryRetrieval.read(query: "my cup shelf", now: now.addingTimeInterval(1000), reports: [raw], locationReports: saved)
            XCTAssertEqual(result.evidence.first?.id, "new")
            XCTAssertEqual(result.evidence.first?.text, newest.originalReport)
            XCTAssertEqual(result.evidence.first?.observedAt, newest.recordedAt)
            XCTAssertFalse(result.evidence.contains { $0.id == "old" })
        }
    }

    func testUnknownHistoricalDatesStayUnknownAcrossRestart() throws {
        let original = try XCTUnwrap(CompanionLocationReport(id: "old", object: "cup", originalReport: "I left it on the desk."))
        let restored = try JSONDecoder().decode(CompanionLocationReport.self, from: JSONEncoder().encode(original))
        let result = CompanionMemoryRetrieval.read(query: "cup", now: now, locationReports: [restored])
        XCTAssertNil(result.evidence.first?.observedAt)
        XCTAssertEqual(result.evidence.first?.text, original.originalReport)
        XCTAssertEqual(result.evidence.first?.kind, .userReport)
    }

    func testRoomAndQuestionInterruptionsLeaveBroaderGoalAndProgressUntouched() throws {
        var task = EverydayTaskCoordinator()
        task.setGoal("Get ready for school")
        task.begin(try XCTUnwrap(EverydayTaskRequest(capability: .findItem, query: "backpack")))
        task.confirmSubtaskComplete()
        let goal = task.goal
        for interruption in ["What colour is this?", "ما لون هذا؟", "Which room is this?", "أنا في غرفة النوم", "What time is it?"] {
            var dialogue = AssistantDialogue(); dialogue.setGoal(goal!.description)
            dialogue.record(role: "user", text: interruption)
            task.pause()
            task.begin(try XCTUnwrap(EverydayTaskRequest(capability: .clothingColor, query: interruption)))
            task.cancelSubtask()
            XCTAssertEqual(task.goal, goal)
            XCTAssertEqual(task.completedSubtasks, ["backpack"])
            XCTAssertEqual(dialogue.goal, goal?.description)
        }
    }

    func testFridgeInstructionNotCompletionAndReportsRetireOnlyMatchingSuggestion() throws {
        for report in ["I opened it", "I've opened it", "فتحتها", "أنا فتحت الثلاجة", "The fridge is open", "الثلاجة مفتوحة"] {
            var ledger = CompanionActionProgressLedger()
            let suggestion = try XCTUnwrap(ledger.recordProposedSuggestion("Open the fridge door", goalRevision: "prepare-food", sourceID: "suggestion", at: now))
            XCTAssertTrue(ledger.markIssued(suggestionID: suggestion.id, goalRevision: "prepare-food", at: now))
            XCTAssertTrue(ledger.reports.isEmpty)
            XCTAssertNil(ledger.latestReport(for: .refrigeratorDoor, goalRevision: "prepare-food"))
            let receipt = ledger.ingestUserReport(report, sourceID: "report", goalRevision: "prepare-food", at: now.addingTimeInterval(1))
            XCTAssertNotNil(receipt.acceptedReport, report)
            XCTAssertEqual(receipt.acceptedReport?.sourceReport, report)
            XCTAssertNotEqual(receipt.acceptedReport?.kind, .sensorConfirmed)
            XCTAssertEqual(receipt.retiredSuggestionIDs, [suggestion.id])
            XCTAssertFalse(ledger.allowsProposal("Open the fridge door", goalRevision: "prepare-food"))
            XCTAssertTrue(ledger.allowsProposal("Open the bedroom door", goalRevision: "prepare-food"))
            XCTAssertTrue(ledger.contextFields(goalRevision: "prepare-food").first { $0.key == "actionSensorConfirmation" }!.values.joined().contains("no validated"))
        }
    }

    func testFridgeOlderClosedStateCannotUndoLaterCorrectionOrLeakAcrossGoals() throws {
        var ledger = CompanionActionProgressLedger()
        ledger.ingestUserReport("The fridge is open", sourceID: "new", goalRevision: "meal", at: now)
        ledger.ingestUserReport("The fridge is closed", sourceID: "old", goalRevision: "meal", at: now.addingTimeInterval(-10))
        XCTAssertEqual(ledger.latestReport(for: .refrigeratorDoor, goalRevision: "meal")?.reportedState, .open)
        XCTAssertFalse(ledger.allowsProposal("Open the fridge", goalRevision: "meal"))
        XCTAssertTrue(ledger.allowsProposal("Open the fridge", goalRevision: "different-place-and-goal"))
        ledger.ingestUserReport("The fridge is closed", sourceID: "latest", goalRevision: "meal", at: now.addingTimeInterval(1))
        XCTAssertEqual(ledger.latestReport(for: .refrigeratorDoor, goalRevision: "meal")?.reportedState, .closed)
        XCTAssertTrue(ledger.allowsProposal("Open the fridge", goalRevision: "meal"))
    }
}
