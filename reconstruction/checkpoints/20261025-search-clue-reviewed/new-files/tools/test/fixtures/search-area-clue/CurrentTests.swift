import XCTest
import BlindCore
@testable import SearchAreaReplay

final class SearchAreaCurrentTests: XCTestCase {
    func testArabicBareAnswerKeepsOriginalSourceAndNoLocationFact() throws {
        let c = SearchAreaReplay(); c.arabic = true
        c.receiveCompanionUtterance("وين الثلاجة")
        let goal = c.companionWorkingState.goal, revision = c.companionWorkingState.goalRevision
        c.receiveCompanionUtterance("المطبخ")
        let clue = try XCTUnwrap(c.companionWorkingState.searchAreaClue.clue)
        XCTAssertEqual(clue.originalInput, "المطبخ")
        XCTAssertEqual(c.companionWorkingState.reports.last?.sourceID, clue.sourceID)
        XCTAssertTrue(c.currentReply.contains("المطبخ")); XCTAssertTrue(c.modelInputs.isEmpty)
        XCTAssertEqual(c.companionWorkingState.goal, goal); XCTAssertEqual(c.companionWorkingState.goalRevision, revision)
        XCTAssertTrue(c.companionWorkingState.factBook.facts.isEmpty)
    }
    func testCorrectionKeepsOriginalExpiryAndParentWithoutReceiptReplay() throws {
        let c = SearchAreaReplay(); c.companionWorkingState.changeGoal("Get a drink")
        c.receiveCompanionUtterance("Find my fridge")
        let expiry = try XCTUnwrap(c.companionWorkingState.searchAreaClue.question?.expiresAt)
        c.receiveCompanionUtterance("kitchen")
        let before = try XCTUnwrap(c.companionWorkingState.searchAreaClue.clue)
        c.receiveCompanionUtterance("No, in the garage")
        let after = try XCTUnwrap(c.companionWorkingState.searchAreaClue.clue)
        XCTAssertEqual(after.answerWindowExpiresAt, expiry); XCTAssertEqual(after.supersededSourceID, before.sourceID)
        XCTAssertNotEqual(after.amendmentID, before.amendmentID)
        XCTAssertEqual(c.companionWorkingState.parentGoal?.goal, "Get a drink")
        XCTAssertTrue(c.companionWorkingState.reportedCompletedSteps.isEmpty)
    }
    func testUnrelatedQuestionAndControlRetireOldQuestion() {
        for turn in ["Tell me a joke", "What time is it", "Cancel the task", "quiet", "pause task"] {
            let c = SearchAreaReplay(); c.receiveCompanionUtterance("Find my fridge")
            c.receiveCompanionUtterance(turn)
            c.receiveCompanionUtterance("kitchen")
            XCTAssertNil(c.companionWorkingState.searchAreaClue.clue, turn)
            XCTAssertTrue(c.modelInputs.contains("kitchen"), turn)
            XCTAssertTrue(c.companionWorkingState.factBook.facts.isEmpty)
        }
    }
    func testNewGoalCannotInheritOldClueAndFullReportWins() {
        let c = SearchAreaReplay(); c.receiveCompanionUtterance("Find my fridge"); c.receiveCompanionUtterance("kitchen")
        c.receiveCompanionUtterance("Find my cup")
        XCTAssertNil(c.companionWorkingState.searchAreaClue.clue)
        c.receiveCompanionUtterance("It is on the table")
        XCTAssertNil(c.companionWorkingState.searchAreaClue.clue)
        XCTAssertEqual(c.companionWorkingState.factBook.facts.last?.object, "cup")
        XCTAssertEqual(c.companionWorkingState.factBook.facts.last?.place, "on the table")
    }
    func testUnknownAndAffirmationAreNotPlaceClues() {
        for answer in ["I don't know", "yes", "no", "لا أعرف", "نعم", "No, tell me a joke"] {
            let c = SearchAreaReplay(); c.receiveCompanionUtterance("Find my fridge"); c.receiveCompanionUtterance(answer)
            XCTAssertNil(c.companionWorkingState.searchAreaClue.clue, answer)
            XCTAssertEqual(c.modelInputs.last, answer)
        }
    }
    func testSpokenQuestionRequiresExactCompletedCallback() throws {
        for mode in 0..<3 {
            let c = SearchAreaReplay(); c.textOnly = false; c.receiveCompanionUtterance("Find my fridge")
            let speech = try XCTUnwrap(c.pendingSpeech)
            if mode != 0 {
                c.finishSearchAreaQuestion(speech.questionID, text: speech.text,
                    outcome: mode == 1 ? .interrupted : .completed, request: speech.request, generation: speech.generation)
            }
            c.receiveCompanionUtterance("kitchen")
            XCTAssertEqual(c.companionWorkingState.searchAreaClue.clue != nil, mode == 2)
            XCTAssertEqual(c.modelInputs.isEmpty, mode == 2)
        }
    }
    func testWrongCallbackAndSensorAlternativeCannotArmQuestion() throws {
        let c = SearchAreaReplay(); c.textOnly = false; c.receiveCompanionUtterance("Find my fridge")
        let speech = try XCTUnwrap(c.pendingSpeech)
        c.finishSearchAreaQuestion(speech.questionID, text: speech.text + " altered", outcome: .completed,
            request: speech.request, generation: speech.generation)
        c.receiveCompanionUtterance("kitchen"); XCTAssertNil(c.companionWorkingState.searchAreaClue.clue)
        let sensor = SearchAreaReplay(); sensor.sensorAnswers = true; sensor.receiveCompanionUtterance("Find my fridge")
        XCTAssertNil(sensor.companionWorkingState.searchAreaClue.question)
        sensor.receiveCompanionUtterance("kitchen"); XCTAssertEqual(sensor.modelInputs, ["kitchen"])
    }
    func testUnverifiedMicrophoneCannotConsumeTrustedQuestion() {
        let c = SearchAreaReplay(); c.receiveCompanionUtterance("Find my fridge")
        let id = c.companionWorkingState.searchAreaClue.question?.id
        c.receiveCompanionUtterance("garage", fromVoice: true)
        XCTAssertNil(c.companionWorkingState.searchAreaClue.clue)
        XCTAssertEqual(c.companionWorkingState.searchAreaClue.question?.id, id)
        c.receiveCompanionUtterance("kitchen")
        XCTAssertEqual(c.companionWorkingState.searchAreaClue.clue?.text, "kitchen")
    }
    func testRestartAndBackgroundCannotRestoreAnswerAuthority() throws {
        let c = SearchAreaReplay(); c.receiveCompanionUtterance("Find my fridge")
        let bytes = try JSONEncoder().encode(c.companionWorkingState)
        let restored = try JSONDecoder().decode(CompanionWorkingState.self, from: bytes)
        XCTAssertNil(restored.searchAreaClue.question); XCTAssertNil(restored.searchAreaClue.clue)
        c.assistantSession.enterBackground()
        c.receiveCompanionUtterance("kitchen")
        XCTAssertNil(c.companionWorkingState.searchAreaClue.clue)
    }
    func testExpiredOriginalQuestionCannotAcceptBareAnswer() throws {
        let c = SearchAreaReplay(); c.receiveCompanionUtterance("Find my fridge")
        let binding = c.searchAreaBinding(target: "fridge")
        let old = ProcessInfo.processInfo.systemUptime - 31
        let proposal = try XCTUnwrap(c.companionWorkingState.searchAreaClue.prepare(binding: binding, text: c.currentReply, now: old))
        XCTAssertTrue(c.companionWorkingState.searchAreaClue.presentTrustedText(questionID: proposal.id,
            text: proposal.text, binding: binding, origin: .trustedInterface, now: old + 0.1))
        c.receiveCompanionUtterance("kitchen")
        XCTAssertNil(c.companionWorkingState.searchAreaClue.clue)
        XCTAssertEqual(c.modelInputs, ["kitchen"])
    }
    func testSameTargetRephraseKeepsClueAndNeverRenewsExpiry() throws {
        let c = SearchAreaReplay(); c.receiveCompanionUtterance("Find my fridge"); c.receiveCompanionUtterance("kitchen")
        let before = try XCTUnwrap(c.companionWorkingState.searchAreaClue.clue)
        let goal = c.companionWorkingState.goal, revision = c.companionWorkingState.goalRevision
        c.receiveCompanionUtterance("Where is my fridge?")
        let after = try XCTUnwrap(c.companionWorkingState.searchAreaClue.clue)
        XCTAssertEqual(after, before)
        XCTAssertEqual(c.companionWorkingState.goal, goal); XCTAssertEqual(c.companionWorkingState.goalRevision, revision)
        XCTAssertTrue(c.currentReply.contains("kitchen")); XCTAssertTrue(c.modelInputs.isEmpty)
    }

    func testAcceptedClueSurvivesUnrelatedConversationWithoutCorrectionAuthority() throws {
        let c = SearchAreaReplay(); c.receiveCompanionUtterance("Find my fridge"); c.receiveCompanionUtterance("kitchen")
        let clue = try XCTUnwrap(c.companionWorkingState.searchAreaClue.clue)
        c.receiveCompanionUtterance("Tell me a joke")
        XCTAssertEqual(c.companionWorkingState.searchAreaClue.clue, clue)
        c.receiveCompanionUtterance("No, in the garage")
        XCTAssertEqual(c.companionWorkingState.searchAreaClue.clue, clue)
        XCTAssertEqual(c.modelInputs, ["Tell me a joke", "No, in the garage"])
        c.receiveCompanionUtterance("Where is my fridge?")
        XCTAssertTrue(c.currentReply.contains("kitchen")); XCTAssertFalse(c.currentReply.contains("garage"))
        XCTAssertEqual(c.companionWorkingState.searchAreaClue.clue, clue)
    }
    func testAcceptedClueSurvivesExpiryWithoutLateCorrectionAuthority() throws {
        let c = SearchAreaReplay(); c.receiveCompanionUtterance("Find my fridge")
        let binding = c.searchAreaBinding(target: "fridge"), old = ProcessInfo.processInfo.systemUptime - 31
        // Seed an earlier delivered/accepted receipt; actual ingress below uses
        // its real monotonic sample, so no test sleeps or clock rewrites are used.
        let proposal = try XCTUnwrap(c.companionWorkingState.searchAreaClue.prepare(binding: binding, text: c.currentReply, now: old))
        XCTAssertTrue(c.companionWorkingState.searchAreaClue.presentTrustedText(questionID: proposal.id,
            text: proposal.text, binding: binding, origin: .trustedInterface, now: old + 0.1))
        XCTAssertNotNil(c.companionWorkingState.searchAreaClue.accept(text: "kitchen", sourceID: "earlier-clue", at: Date(),
            binding: binding, origin: .trustedInterface, now: old + 0.2))
        let clue = try XCTUnwrap(c.companionWorkingState.searchAreaClue.clue)
        c.receiveCompanionUtterance("Where is my fridge?")
        XCTAssertEqual(c.companionWorkingState.searchAreaClue.clue, clue)
        XCTAssertTrue(c.currentReply.contains("kitchen"))
        c.receiveCompanionUtterance("No, in the garage")
        XCTAssertEqual(c.companionWorkingState.searchAreaClue.clue, clue)
        XCTAssertEqual(c.modelInputs, ["No, in the garage"])
    }

    func testDeletingExactClueAfterReportEvictionCannotResurrectIt() throws {
        let c = SearchAreaReplay(); c.receiveCompanionUtterance("Find my fridge"); c.receiveCompanionUtterance("kitchen")
        XCTAssertNotNil(c.companionWorkingState.searchAreaClue.clue)
        for i in 0..<14 { c.companionWorkingState.record("Unrelated report \(i)") }
        XCTAssertFalse(c.companionWorkingState.reports.contains { $0.text == "kitchen" })
        XCTAssertTrue(c.companionWorkingState.removeReport("kitchen"))
        XCTAssertNil(c.companionWorkingState.searchAreaClue.clue)
        c.receiveCompanionUtterance("Where is my fridge?")
        XCTAssertFalse(c.currentReply.contains("kitchen")); XCTAssertNil(c.companionWorkingState.searchAreaClue.clue)
    }
    func testScopedSourceEditRetiresAcceptedClueWithoutMakingLocationFact() throws {
        let c = SearchAreaReplay()
        let scope = try XCTUnwrap(CompanionMemoryScope(map: SpatialMapBinding(mapID: "map", frameID: "frame", revision: "1"),
            placeID: "home", floorID: "floor", roomID: "room"))
        c.companionWorkingState.transitionMemoryScope(scope)
        c.receiveCompanionUtterance("Find my fridge"); c.receiveCompanionUtterance("kitchen")
        let clue = try XCTUnwrap(c.companionWorkingState.searchAreaClue.clue)
        let selection = try XCTUnwrap(c.companionWorkingState.reviewSelections.first { $0.sourceID == clue.sourceID })
        XCTAssertTrue(c.companionWorkingState.reviseReviewedSource(selection, replacement: "garage"))
        XCTAssertNil(c.companionWorkingState.searchAreaClue.clue)
        c.receiveCompanionUtterance("Where is my fridge?")
        XCTAssertFalse(c.currentReply.contains("kitchen")); XCTAssertFalse(c.currentReply.contains("garage"))
        XCTAssertTrue(c.companionWorkingState.factBook.facts.isEmpty)
    }
    func testUnrelatedLegacySourceDeletionKeepsClue() throws {
        let c = SearchAreaReplay(); c.receiveCompanionUtterance("Find my fridge"); c.receiveCompanionUtterance("kitchen")
        let clue = try XCTUnwrap(c.companionWorkingState.searchAreaClue.clue)
        c.companionWorkingState.record("Dinosaurs are interesting")
        XCTAssertTrue(c.companionWorkingState.removeReport("Dinosaurs are interesting"))
        XCTAssertEqual(c.companionWorkingState.searchAreaClue.clue, clue)
        c.receiveCompanionUtterance("Where is my fridge?")
        XCTAssertTrue(c.currentReply.contains("kitchen")); XCTAssertEqual(c.companionWorkingState.searchAreaClue.clue, clue)
    }

    func testFiveWordCluesQueueExactShortAcknowledgment() throws {
        for (arabic, query, answer, expected) in [
            (false, "Find my fridge", "in the large upstairs kitchen", "I'll use «in the large upstairs kitchen» as a search clue."),
            (true, "وين الثلاجة", "في المطبخ الكبير في الأعلى", "سأستخدم «في المطبخ الكبير في الأعلى» كتلميح للبحث.")
        ] {
            let c = SearchAreaReplay(); c.arabic = arabic; c.textOnly = false
            c.receiveCompanionUtterance(query)
            let question = try XCTUnwrap(c.pendingSpeech)
            c.finishSearchAreaQuestion(question.questionID, text: question.text, outcome: .completed,
                request: question.request, generation: question.generation)
            c.receiveCompanionUtterance(answer)
            XCTAssertNotNil(c.companionWorkingState.searchAreaClue.clue)
            XCTAssertEqual(c.pendingSpeech?.text, expected)
            XCTAssertEqual(c.currentReply, expected)
            XCTAssertTrue(c.modelInputs.isEmpty)
            XCTAssertTrue(c.companionWorkingState.factBook.facts.isEmpty)
        }
    }
    func testOverBudgetTokenizerResultRejectsBeforeInstallingClue() {
        let c = SearchAreaReplay(); c.receiveCompanionUtterance("Find my fridge")
        let replay = SearchAreaReplay(); replay.receiveCompanionUtterance("Find my fridge")
        replay.receiveCompanionUtterance("kitchen")
        let accepted = replay.companionWorkingState.searchAreaClue.clue
        SearchAreaReplay.wordCountOverride = 31
        defer { SearchAreaReplay.wordCountOverride = nil }
        c.receiveCompanionUtterance("kitchen")
        XCTAssertNil(c.companionWorkingState.searchAreaClue.clue)
        XCTAssertEqual(c.modelInputs, ["kitchen"])
        XCTAssertTrue(c.companionWorkingState.factBook.facts.isEmpty)
        replay.receiveCompanionUtterance("Where is my fridge?")
        XCTAssertEqual(replay.currentReply, "I still have your search clue.")
        XCTAssertEqual(replay.companionWorkingState.searchAreaClue.clue, accepted)
        XCTAssertTrue(replay.modelInputs.isEmpty)
        replay.arabic = true
        replay.receiveCompanionUtterance("Where is my fridge?")
        XCTAssertEqual(replay.currentReply, "ما زلت أحتفظ بتلميح البحث الذي قدمته.")
        XCTAssertEqual(replay.companionWorkingState.searchAreaClue.clue, accepted)
    }
}
