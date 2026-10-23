import XCTest
@testable import BlindCore

final class CompanionActionProgressTests: XCTestCase {
    private let time = Date(timeIntervalSince1970: 1_700_000_000)
    private let revision = "goal-fridge-1"

    private func step(_ text: String = "Open the fridge door", issued: Bool = true,
                      revision: String = "goal-fridge-1") -> CompanionActionProgressLedger {
        var ledger = CompanionActionProgressLedger()
        let suggestion = ledger.recordProposedSuggestion(text, goalRevision: revision, sourceID: "assistant-step", at: time)!
        if issued { XCTAssertTrue(ledger.markIssued(suggestionID: suggestion.id, goalRevision: revision, at: time)) }
        return ledger
    }
    private func ingest(_ text: String, into ledger: inout CompanionActionProgressLedger,
                        source: String = "user-1", offset: TimeInterval = 1,
                        revision: String = "goal-fridge-1") -> CompanionActionProgressLedger.Reduction {
        ledger.ingestUserReport(text, sourceID: source, goalRevision: revision, at: time.addingTimeInterval(offset))
    }
    private func encodedObject(_ ledger: CompanionActionProgressLedger) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(ledger)) as? [String: Any])
    }
    private func decode(_ object: [String: Any]) throws -> CompanionActionProgressLedger {
        try JSONDecoder().decode(CompanionActionProgressLedger.self, from: JSONSerialization.data(withJSONObject: object))
    }

    func testProposedAndIssuedWordsAreNeverCompletion() {
        var ledger = step(issued: false)
        XCTAssertEqual(ledger.suggestions.first?.kind, .proposed)
        XCTAssertTrue(ledger.reports.isEmpty)
        XCTAssertTrue(ledger.markIssued(suggestionID: ledger.suggestions[0].id, goalRevision: revision, at: time))
        XCTAssertEqual(ledger.suggestions.first?.kind, .issuedSuggestion)
        XCTAssertTrue(ledger.reports.isEmpty)
        XCTAssertTrue(ledger.allowsProposal("Open the fridge", goalRevision: revision))
    }

    func testFridgeCorrectionRetiresStepBeforeAnyGeneration() throws {
        var ledger = step()
        let result = ingest("I already opened the fridge door.", into: &ledger)
        let report = try XCTUnwrap(result.acceptedReport)
        XCTAssertEqual(report.kind, .userReportedCompleted)
        XCTAssertEqual(report.target, .refrigeratorDoor)
        XCTAssertEqual(report.action, .open)
        XCTAssertEqual(report.reportedState, .open)
        XCTAssertEqual(report.sourceReport, "I already opened the fridge door.")
        XCTAssertEqual(report.sourceID, "user-1")
        XCTAssertEqual(report.at, time.addingTimeInterval(1))
        XCTAssertEqual(report.goalRevision, revision)
        XCTAssertEqual(result.retiredSuggestionIDs, [ledger.suggestions[0].id])
        XCTAssertEqual(result.reportedCompletedSuggestionID, ledger.suggestions[0].id)
        XCTAssertFalse(ledger.allowsProposal("Open the refrigerator", goalRevision: revision))
        XCTAssertNil(ledger.recordProposedSuggestion("Try opening the fridge", goalRevision: revision, sourceID: "repeat", at: time.addingTimeInterval(2)))
        XCTAssertTrue(ledger.allowsProposal("Close the fridge", goalRevision: revision))
    }

    func testNamedStateRetiresEvenAnUnissuedSuggestionWithoutCompletingGoal() {
        var ledger = step(issued: false)
        let result = ingest("The fridge door is open", into: &ledger)
        XCTAssertEqual(result.acceptedReport?.kind, .userReportedState)
        XCTAssertNil(result.acceptedReport?.action)
        XCTAssertEqual(result.retiredSuggestionIDs.count, 1)
        XCTAssertNil(result.reportedCompletedSuggestionID)
        XCTAssertNil(ledger.suggestions.first?.issuedAt)
    }

    func testEnglishArabicAndMixedCompletedReports() {
        for source in ["I opened the refrigerator.", "I've opened the fridge", "I have just opened the fridge door",
                       "Opened the fridge already", "No, I already opened the fridge", "فتحت الثلاجة", "أنا فتحت باب الثلاجة خلاص",
                       "لقد فتحت الثلاجة", "I opened الثلاجة", "فتحت the fridge"] {
            var ledger = step()
            let result = ingest(source, into: &ledger)
            XCTAssertEqual(result.acceptedReport?.kind, .userReportedCompleted, source)
            XCTAssertEqual(result.acceptedReport?.target, .refrigeratorDoor, source)
            XCTAssertEqual(result.retiredSuggestionIDs.count, 1, source)
        }
    }

    func testEnglishArabicAndMixedStates() {
        for source in ["The fridge is open", "The fridge door is already open", "الثلاجة مفتوحة", "باب الثلاجة مفتوح",
                       "الثلاجة is open", "the fridge مفتوحة", "The fridge is open now"] {
            var ledger = step()
            let result = ingest(source, into: &ledger)
            XCTAssertEqual(result.acceptedReport?.kind, .userReportedState, source)
            XCTAssertEqual(result.acceptedReport?.reportedState, .open, source)
            XCTAssertEqual(result.retiredSuggestionIDs.count, 1, source)
        }
    }

    func testNegatedFutureHypotheticalQuestionsQuotesGamesNeverComplete() {
        for source in ["I didn't open the fridge", "I did not open the fridge", "I haven't opened the fridge", "I never opened the fridge",
                       "I will open the fridge", "I'll open the fridge", "I am going to open the fridge", "I might have opened the fridge",
                       "If I opened the fridge", "When I opened the fridge", "I opened the fridge?", "Did I open the fridge",
                       "Is the fridge open", "I think the fridge is open", "Maybe the fridge is open", "\"I opened the fridge\"",
                       "He said I opened the fridge", "I said 'I opened the fridge'", "In the game I opened the fridge",
                       "I opened the fridge in the game", "I pretended I opened the fridge", "I dreamed I opened the fridge",
                       "I opened the fridge yesterday", "Yesterday I opened the fridge", "I opened the fridge. Not really.",
                       "ما فتحت الثلاجة", "لم أفتح الثلاجة", "لن افتح الثلاجة", "راح افتح الثلاجة", "لو فتحت الثلاجة",
                       "هل فتحت الثلاجة؟", "فتحت الثلاجة؟", "قال فتحت الثلاجة", "في اللعبة فتحت الثلاجة",
                       "فتحت الثلاجة في اللعبة", "يمكن الثلاجة مفتوحة", "حلمت فتحت الثلاجة", "فتحت الثلاجة أمس"] {
            var ledger = step()
            XCTAssertNil(ingest(source, into: &ledger).acceptedReport, source)
            XCTAssertFalse(ledger.suggestions[0].isRetired, source)
            XCTAssertTrue(ledger.reports.isEmpty, source)
        }
    }

    func testModelCaptionAndPhotoGuessAreNotReports() {
        for source in ["The photo shows the fridge is open", "The model says the fridge is open", "Camera: the fridge is open",
                       "According to this image the fridge is open", "It looks like the fridge is open", "The fridge seems open",
                       "الصورة تظهر الثلاجة مفتوحة", "الكاميرا تقول الثلاجة مفتوحة"] {
            var ledger = step()
            XCTAssertNil(ingest(source, into: &ledger).acceptedReport, source)
            XCTAssertFalse(ledger.suggestions[0].isRetired, source)
        }
    }

    func testBareDoneNeedsExactlyOneActuallyIssuedCurrentStep() {
        for source in ["done", "I'm done", "I did it", "خلصت", "انتهيت"] {
            var issued = step()
            XCTAssertEqual(ingest(source, into: &issued).reportedCompletedSuggestionID, issued.suggestions[0].id, source)
            var proposed = step(issued: false)
            XCTAssertNil(ingest(source, into: &proposed).acceptedReport, source)
            var absent = CompanionActionProgressLedger()
            XCTAssertNil(ingest(source, into: &absent).acceptedReport, source)
            var multiple = step()
            _ = multiple.recordProposedSuggestion("Close the cupboard", goalRevision: revision, sourceID: "another-step", at: time)
            XCTAssertNil(ingest(source, into: &multiple).acceptedReport, source)
        }
    }

    func testPronounsNeedAnUnambiguousIssuedTarget() {
        for source in ["I opened it", "It's open", "فتحته", "فتحتها", "هو مفتوح"] {
            var ledger = step()
            XCTAssertEqual(ingest(source, into: &ledger).acceptedReport?.target, .refrigeratorDoor, source)
            var absent = CompanionActionProgressLedger()
            XCTAssertNil(ingest(source, into: &absent).acceptedReport, source)
            var proposed = step(issued: false)
            XCTAssertNil(ingest(source, into: &proposed).acceptedReport, source)
            var ambiguous = step()
            _ = ambiguous.recordProposedSuggestion("Open the cupboard", goalRevision: revision, sourceID: "second", at: time)
            XCTAssertNil(ingest(source, into: &ambiguous).acceptedReport, source)
        }
    }

    func testNamedDoorCanBindOnlyOneCurrentDoorTarget() {
        var ledger = step(issued: false)
        XCTAssertEqual(ingest("The door is open", into: &ledger).acceptedReport?.target, .refrigeratorDoor)
        XCTAssertTrue(ledger.suggestions[0].isRetired)
        var ambiguous = step()
        _ = ambiguous.recordProposedSuggestion("Open the cupboard door", goalRevision: revision, sourceID: "second", at: time)
        XCTAssertNil(ingest("I opened the door", into: &ambiguous).acceptedReport)
        XCTAssertFalse(ambiguous.suggestions.contains(where: \.isRetired))
    }

    func testWrongTargetCannotCompleteOrRetireCurrentStep() {
        var ledger = step()
        let report = ingest("I opened the cupboard", into: &ledger)
        XCTAssertEqual(report.acceptedReport?.target, .cupboardDoor)
        XCTAssertNil(report.reportedCompletedSuggestionID)
        XCTAssertTrue(report.retiredSuggestionIDs.isEmpty)
        XCTAssertFalse(ledger.suggestions[0].isRetired)
        XCTAssertTrue(ledger.allowsProposal("Open the fridge", goalRevision: revision))
    }

    func testNamedReportWithoutCurrentStepIsPreservedNotTaskCompletion() {
        var ledger = CompanionActionProgressLedger()
        let result = ingest("I opened the fridge", into: &ledger)
        XCTAssertEqual(result.acceptedReport?.kind, .userReportedCompleted)
        XCTAssertNil(result.reportedCompletedSuggestionID)
        XCTAssertTrue(result.retiredSuggestionIDs.isEmpty)
        XCTAssertTrue(ledger.suggestions.isEmpty)
        XCTAssertFalse(ledger.allowsProposal("Open the fridge", goalRevision: revision))
    }

    func testChangedGoalDoesNotBorrowOldStepOrBlockNewGoal() {
        var ledger = step()
        XCTAssertNil(ingest("done", into: &ledger, revision: "new-goal").acceptedReport)
        _ = ingest("The fridge is open", into: &ledger)
        XCTAssertTrue(ledger.allowsProposal("Open the fridge", goalRevision: "new-goal"))
        XCTAssertFalse(ledger.allowsProposal("Open the fridge", goalRevision: revision))
        XCTAssertTrue(ledger.contextFields(goalRevision: "new-goal")[0].values.isEmpty)
    }

    func testNewReportedStateSupersedesOldWithoutBecomingSensorProof() {
        var ledger = step()
        _ = ingest("The fridge is open", into: &ledger)
        _ = ingest("The fridge is closed", into: &ledger, source: "user-2", offset: 2)
        XCTAssertEqual(ledger.latestReport(for: .refrigeratorDoor, goalRevision: revision)?.reportedState, .closed)
        XCTAssertNotNil(ledger.reports[0].supersededByReportID)
        XCTAssertTrue(ledger.allowsProposal("Open the fridge", goalRevision: revision))
        XCTAssertFalse(ledger.allowsProposal("Close the fridge", goalRevision: revision))
        XCTAssertFalse(ledger.reports.contains { $0.kind == .sensorConfirmed })
        XCTAssertEqual(ledger.contextFields(goalRevision: revision)[0].values.count, 1)
    }

    func testNegativeStateDoesNotInferTheOppositeStateOrCompletion() {
        for (source, expected) in [("The fridge is not open", CompanionActionProgressLedger.ReportedState.notOpen),
                                   ("الثلاجة مو مفتوحة", .notOpen), ("The fridge is not closed", .notClosed)] {
            var ledger = step()
            _ = ingest("The fridge is open", into: &ledger)
            let result = ingest(source, into: &ledger, source: "negative", offset: 2)
            XCTAssertEqual(result.acceptedReport?.reportedState, expected, source)
            XCTAssertEqual(result.acceptedReport?.kind, .userReportedState, source)
            XCTAssertNil(result.reportedCompletedSuggestionID, source)
            XCTAssertTrue(ledger.allowsProposal("Open the fridge", goalRevision: revision), source)
            XCTAssertTrue(ledger.allowsProposal("Close the fridge", goalRevision: revision), source)
        }
    }

    func testOutOfOrderReportDoesNotOverwriteNewerState() {
        var ledger = step()
        _ = ingest("The fridge is closed", into: &ledger, source: "newer", offset: 20)
        let late = ingest("The fridge is open", into: &ledger, source: "older", offset: 10)
        XCTAssertNotNil(late.acceptedReport)
        XCTAssertTrue(late.retiredSuggestionIDs.isEmpty)
        XCTAssertNotNil(late.acceptedReport?.supersededByReportID)
        XCTAssertEqual(ledger.latestReport(for: .refrigeratorDoor, goalRevision: revision)?.sourceID, "newer")
    }

    func testReplaySourceCannotChangeItsMeaning() {
        var ledger = step()
        _ = ingest("The fridge is open", into: &ledger)
        XCTAssertNil(ingest("The fridge is closed", into: &ledger, offset: 2).acceptedReport)
        XCTAssertEqual(ledger.reports.count, 1)
        XCTAssertEqual(ledger.reports[0].reportedState, .open)
    }

    func testContextIsAttributedAndContainsNoIndependentConfirmation() {
        var ledger = step()
        _ = ingest("I opened the fridge", into: &ledger)
        let fields = ledger.contextFields(goalRevision: revision)
        let report = fields[0].values[0]
        XCTAssertTrue(report.contains("User reported"))
        XCTAssertTrue(report.contains("source=user-1"))
        XCTAssertTrue(report.contains("goalRevision=" + revision))
        XCTAssertTrue(report.contains("«I opened the fridge»"))
        XCTAssertTrue(report.contains("Not independently confirmed"))
        XCTAssertTrue(fields[1].values.isEmpty)
        XCTAssertTrue(fields[2].values[0].hasPrefix("Unavailable"))
    }

    func testContextKeepsNewestTwoCompleteSourcesWithinItsByteBudget() throws {
        var ledger = CompanionActionProgressLedger()
        _ = ingest("The fridge is open", into: &ledger, source: "oldest", offset: 1)
        _ = ingest("The cupboard is closed", into: &ledger, source: "middle", offset: 2)
        _ = ingest("The window is open", into: &ledger, source: "newest", offset: 3)
        let fields = ledger.contextFields(goalRevision: revision)
        XCTAssertEqual(fields[0].values.count, 2)
        XCTAssertTrue(fields[0].values[0].contains("source=newest"))
        XCTAssertTrue(fields[0].values[1].contains("source=middle"))
        XCTAssertFalse(fields[3].values.isEmpty)
        let dictionary = Dictionary(uniqueKeysWithValues: fields.map { ($0.key, $0.values) })
        XCTAssertLessThanOrEqual(try JSONEncoder().encode(dictionary).count, CompanionActionProgressLedger.maximumContextUTF8Bytes)
    }

    func testContextDoesNotClipAnOversizedSourceOrSubstituteOlderState() throws {
        var ledger = CompanionActionProgressLedger()
        _ = ingest("The window is open", into: &ledger, source: "old", offset: 1)
        let source = "The" + String(repeating: "\t", count: 550) + " fridge is not open"
        _ = ingest(source, into: &ledger, source: String(repeating: "a", count: 120), offset: 2)
        XCTAssertEqual(ledger.reports.last?.sourceReport, source)
        let fields = ledger.contextFields(goalRevision: revision)
        XCTAssertTrue(fields[0].values.isEmpty)
        XCTAssertFalse(fields[3].values.isEmpty)
        let dictionary = Dictionary(uniqueKeysWithValues: fields.map { ($0.key, $0.values) })
        XCTAssertLessThanOrEqual(try JSONEncoder().encode(dictionary).count, CompanionActionProgressLedger.maximumContextUTF8Bytes)
    }

    func testDeletionDoesNotResurrectAnOlderContradictoryReport() throws {
        var ledger = step()
        _ = ingest("The fridge is open", into: &ledger)
        _ = ingest("The fridge is closed", into: &ledger, source: "newer", offset: 2)
        ledger.removeSource("newer")
        XCTAssertNil(ledger.latestReport(for: .refrigeratorDoor, goalRevision: revision))
        XCTAssertTrue(ledger.contextFields(goalRevision: revision)[0].values.isEmpty)
        let restored = try JSONDecoder().decode(CompanionActionProgressLedger.self, from: JSONEncoder().encode(ledger))
        XCTAssertNil(restored.latestReport(for: .refrigeratorDoor, goalRevision: revision))
    }

    func testSourceDeletionRemovesReportAndRetiredSuggestionWithoutResurrection() {
        var ledger = step()
        _ = ingest("The fridge is open", into: &ledger)
        ledger.removeReport(exactText: "The fridge is open")
        XCTAssertTrue(ledger.reports.isEmpty)
        XCTAssertTrue(ledger.suggestions.isEmpty)
        XCTAssertTrue(ledger.allowsProposal("Open the fridge", goalRevision: revision))
    }

    func testDeletingSuggestionSourceDropsAnaphoraButPreservesIndependentNamedReport() {
        var anaphoric = step()
        _ = ingest("done", into: &anaphoric)
        anaphoric.removeSource("assistant-step")
        XCTAssertTrue(anaphoric.reports.isEmpty)
        var named = step()
        _ = ingest("The fridge is open", into: &named)
        named.removeSource("assistant-step")
        XCTAssertEqual(named.reports.count, 1)
        XCTAssertNil(named.reports[0].relatedSuggestionID)
    }

    func testGoalRetirementDoesNotEraseIndependentReportOrRestorePendingStep() throws {
        var ledger = step()
        _ = ingest("The fridge is open", into: &ledger)
        ledger.retireSuggestions(forGoalRevision: revision)
        XCTAssertTrue(ledger.suggestions.isEmpty)
        XCTAssertEqual(ledger.reports.count, 1)
        let restored = try JSONDecoder().decode(CompanionActionProgressLedger.self, from: JSONEncoder().encode(ledger))
        XCTAssertEqual(restored, ledger)
    }

    func testRoundTripRetainsSourcesBindingAndUserOnlyAuthority() throws {
        for source in ["done", "The door is open", "I opened the fridge", "الثلاجة مفتوحة"] {
            var ledger = step()
            _ = ingest(source, into: &ledger)
            let restored = try JSONDecoder().decode(CompanionActionProgressLedger.self, from: JSONEncoder().encode(ledger))
            XCTAssertEqual(restored, ledger, source)
            XCTAssertFalse(restored.allowsProposal("Open the fridge", goalRevision: revision), source)
            XCTAssertFalse(restored.reports.contains { $0.kind == .sensorConfirmed }, source)
        }
    }

    func testDecodeRejectsForgedSensorProofPositiveSubstringsAndWrongBindings() throws {
        var ledger = step()
        _ = ingest("I opened the fridge", into: &ledger)
        for mutation in ["sensor", "negation", "target", "action", "goal", "source", "date"] {
            var object = try encodedObject(ledger)
            var reports = try XCTUnwrap(object["reports"] as? [[String: Any]])
            switch mutation {
            case "sensor": reports[0]["kind"] = "sensorConfirmed"
            case "negation": reports[0]["sourceReport"] = "I did not open the fridge"
            case "target": reports[0]["target"] = "cupboardDoor"
            case "action": reports[0]["action"] = "close"
            case "goal": reports[0]["goalRevision"] = "unrelated-goal"
            case "source": reports[0]["sourceID"] = String(repeating: "x", count: 121)
            default: reports[0]["at"] = -99_999_999_999.0
            }
            object["reports"] = reports
            let restored = try decode(object)
            XCTAssertTrue(restored.reports.isEmpty, mutation)
            XCTAssertTrue(restored.suggestions.isEmpty, mutation)
        }
    }

    func testInputAndPersistedCollectionBounds() throws {
        var ledger = CompanionActionProgressLedger()
        XCTAssertNil(ingest(String(repeating: "x", count: 601), into: &ledger).acceptedReport)
        XCTAssertNil(ledger.recordProposedSuggestion("Open the fridge", goalRevision: "", sourceID: "s", at: time))
        XCTAssertNil(ledger.recordProposedSuggestion("Open the fridge", goalRevision: revision, sourceID: "s\nuser", at: time))
        for index in 0..<60 {
            _ = ingest(index.isMultiple(of: 2) ? "The fridge is open" : "The fridge is closed", into: &ledger,
                       source: "source-\(index)", offset: TimeInterval(index))
            _ = ledger.recordProposedSuggestion("Open the window", goalRevision: "goal-\(index)", sourceID: "step-\(index)", at: time)
        }
        XCTAssertLessThanOrEqual(ledger.reports.count, CompanionActionProgressLedger.maximumReports)
        XCTAssertLessThanOrEqual(ledger.suggestions.count, CompanionActionProgressLedger.maximumSuggestions)
        let restored = try JSONDecoder().decode(CompanionActionProgressLedger.self, from: JSONEncoder().encode(ledger))
        XCTAssertEqual(restored, ledger)
    }

    func testIssuedCallbackCannotReviveRetiredOrChangedGoalStep() {
        var ledger = step(issued: false)
        let id = ledger.suggestions[0].id
        XCTAssertFalse(ledger.markIssued(suggestionID: id, goalRevision: "new-goal", at: time))
        XCTAssertFalse(ledger.markIssued(suggestionID: id, goalRevision: revision, at: time.addingTimeInterval(-1)))
        _ = ingest("The fridge is open", into: &ledger)
        XCTAssertFalse(ledger.markIssued(suggestionID: id, goalRevision: revision, at: time.addingTimeInterval(2)))
    }

    func testEarlierReportCannotUseALaterIssuedReceipt() {
        var ledger = step(issued: false)
        let id = ledger.suggestions[0].id
        XCTAssertTrue(ledger.markIssued(suggestionID: id, goalRevision: revision, at: time.addingTimeInterval(10)))
        XCTAssertNil(ingest("done", into: &ledger, offset: 1).acceptedReport)
        XCTAssertNotNil(ingest("The fridge is open", into: &ledger, source: "named", offset: 2).acceptedReport)
    }

    func testBoundedProposalAliasesAndUnknownActionsDoNotExpandCapability() {
        XCTAssertEqual(CompanionActionProgressLedger.parseProposal("افتح باب الثلاجة")?.target, .refrigeratorDoor)
        XCTAssertEqual(CompanionActionProgressLedger.parseProposal("Close the cupboard")?.action, .close)
        XCTAssertNil(CompanionActionProgressLedger.parseProposal("Find my cup"))
        var ledger = step()
        _ = ingest("The fridge is open", into: &ledger)
        for proposal in ["Please open the fridge", "Try opening the fridge door", "You could open the refrigerator", "Open it", "افتح الثلاجة"] {
            XCTAssertFalse(ledger.allowsProposal(proposal, goalRevision: revision), proposal)
        }
    }
}
