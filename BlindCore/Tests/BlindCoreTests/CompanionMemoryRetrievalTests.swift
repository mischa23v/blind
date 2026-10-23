import XCTest
@testable import BlindCore

final class CompanionMemoryRetrievalTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testSavedItemAndObservationAreHistoricalNotCoordinatesOrCurrentPresence() {
        var observed = ObservedObjectMemory()
        observed.observe(category: "coat", source: .onDeviceDetector, frameID: "frame",
                         roomName: "bedroom", position: Point3(123, 456, 789), at: now, now: now)
        let item = RememberedItem(name: "my coat", roomName: "hall", position: Point3(9, 8, 7),
                                  frameID: "other", savedAt: now.addingTimeInterval(-30))
        let result = CompanionMemoryRetrieval.read(query: "Where did I leave my coat?", now: now,
                                                   observed: observed, savedItems: [item])
        XCTAssertEqual(result.evidence.count, 2)
        XCTAssertTrue(result.evidence.allSatisfy { $0.kind == .historicalMemory && $0.expiresAt == nil })
        XCTAssertTrue(result.evidence[0].text.contains("User-saved item"))
        XCTAssertTrue(result.evidence[1].text.contains("ownership are unconfirmed"))
        XCTAssertFalse(result.evidence.map(\.text).joined().contains("123"))
        XCTAssertTrue(result.evidence.allSatisfy { $0.observedAt != nil })
    }

    func testUnrelatedPreferencesDoNotCrowdOutObjectEvidence() {
        let preferences = (0..<12).map { CompanionMemoryNote(id: "p\($0)", subject: "food", text: "I like apples", source: "profile") }
        let item = RememberedItem(name: "backpack", roomName: "bedroom", savedAt: now)
        let result = CompanionMemoryRetrieval.read(query: "my backpack", now: now, savedItems: [item], preferences: preferences)
        XCTAssertEqual(result.evidence.count, 1)
        XCTAssertTrue(result.evidence[0].text.contains("backpack"))
    }

    func testReportsPreserveOriginalNegationAndPrecedeCandidate() {
        var observed = ObservedObjectMemory()
        observed.observe(category: "coat", source: .appearanceComparison, frameID: nil, roomName: "hall", at: now, now: now)
        let report = CompanionEvidence(id: "r", kind: .userReport, text: "I did not leave my coat in the hall.", source: "user report", observedAt: now)
        let result = CompanionMemoryRetrieval.read(query: "where is my coat", now: now, reports: [report], observed: observed)
        XCTAssertEqual(result.evidence.first?.text, report.text)
        XCTAssertEqual(result.evidence.first?.kind, .userReport)
        XCTAssertTrue(result.evidence.last!.text.contains("Historical candidate"))
    }

    func testAlternativePlacesAreExplicitWithoutAssertingSameObject() {
        var observed = ObservedObjectMemory()
        observed.observe(category: "cup", source: .onDeviceDetector, frameID: nil, roomName: "kitchen", placeName: "home", at: now.addingTimeInterval(-20), now: now)
        observed.observe(category: "cup", source: .onDeviceDetector, frameID: nil, roomName: "office", placeName: "school", at: now, now: now)
        let result = CompanionMemoryRetrieval.read(query: "my cup", now: now, observed: observed)
        XCTAssertEqual(result.evidence.count, 1)
        XCTAssertTrue(result.evidence[0].text.contains("Other recorded locations exist"))
        XCTAssertTrue(result.evidence[0].text.contains("do not assume one item"))
    }

    func testRoomInventoryDoesNotEstablishLiveLocalization() {
        let place = CompanionPlaceMemory(id: "home", name: "Home", roomNames: ["Bedroom", "Kitchen"], recordedAt: now)
        let result = CompanionMemoryRetrieval.read(query: "What do you remember about my room?", now: now, places: [place])
        XCTAssertEqual(result.evidence.count, 1)
        XCTAssertTrue(result.evidence[0].text.contains("does not establish current room"))
        XCTAssertEqual(result.evidence[0].kind, .historicalMemory)
    }

    func testLongRecordsDroppedWholeAndFourRecordScalarBudget() {
        let notes = (0..<20).map { CompanionMemoryNote(id: "\($0)", subject: "coat", text: "coat " + String(repeating: "z", count: 180), source: "confirmed task") }
        let tooLong = CompanionEvidence(id: "long", kind: .userReport, text: "coat " + String(repeating: "z", count: 600) + " NOT HERE", source: "report")
        let result = CompanionMemoryRetrieval.read(query: "coat", now: now, reports: [tooLong], taskContext: notes)
        XCTAssertLessThanOrEqual(result.evidence.count, 4)
        XCTAssertLessThanOrEqual(result.evidence.reduce(0) { $0 + $1.text.unicodeScalars.count }, 800)
        XCTAssertFalse(result.evidence.contains { $0.id == "long" })
        XCTAssertTrue(result.evidence.allSatisfy { $0.text.hasSuffix(String(repeating: "z", count: 180)) })
    }

    func testEmptyUnrelatedAndFutureRecordsDoNotProveAbsence() {
        let item = RememberedItem(name: "laptop", savedAt: now.addingTimeInterval(1))
        let result = CompanionMemoryRetrieval.read(query: "laptop", now: now, savedItems: [item])
        XCTAssertTrue(result.evidence.isEmpty)
        XCTAssertTrue(result.summary.contains("do not prove absence"))
        XCTAssertTrue(CompanionMemoryRetrieval.read(query: "where is it", now: now, savedItems: [item]).evidence.isEmpty)
    }

    func testCurrentEvidenceCannotEnterSavedMemoryTool() {
        let injected = CompanionEvidence(kind: .currentObservation, text: "coat", source: "camera", observedAt: now, expiresAt: now.addingTimeInterval(1))
        XCTAssertTrue(CompanionMemoryRetrieval.read(query: "coat", now: now, reports: [injected]).evidence.isEmpty)
    }

    func testArabicQueryMatchesDefiniteArticle() {
        let item = RememberedItem(name: "حقيبة", roomName: "غرفة النوم", savedAt: now)
        let result = CompanionMemoryRetrieval.read(query: "أين الحقيبة؟", now: now, savedItems: [item])
        XCTAssertEqual(result.evidence.count, 1)
    }

    func testUndatedReportsKeepNewestHistoryFirstRatherThanRandomIDOrder() {
        let old = CompanionEvidence(id: "a", kind: .userReport,
            text: "I like apples.", source: "original user conversation record")
        let newer = CompanionEvidence(id: "z", kind: .userReport,
            text: "I do not like apples anymore.", source: "original user conversation record")
        let result = CompanionMemoryRetrieval.read(query: "apples", now: now, reports: [old, newer])
        XCTAssertEqual(result.evidence.map(\.id), ["z", "a"])
        XCTAssertEqual(result.evidence.map(\.text), [newer.text, old.text])
        XCTAssertTrue(result.evidence.allSatisfy { $0.observedAt == nil })
        let changedIDs = [CompanionEvidence(id: "z", kind: old.kind, text: old.text, source: old.source),
                          CompanionEvidence(id: "a", kind: newer.kind, text: newer.text, source: newer.source)]
        XCTAssertEqual(CompanionMemoryRetrieval.read(query: "apples", now: now, reports: changedIDs).evidence.map(\.text),
                       result.evidence.map(\.text))
    }

    func testReportInputBoundKeepsRecentHistoryAndTimestampStillControlsKnownDates() {
        let reports = (0..<65).map {
            CompanionEvidence(id: "report:\($0)", kind: .userReport,
                text: "apples record \($0)", source: "original user conversation record")
        }
        let bounded = CompanionMemoryRetrieval.read(query: "apples", now: now, reports: reports)
        XCTAssertEqual(bounded.evidence.map(\.id), ["report:64", "report:63", "report:62", "report:61"])
        let recent = CompanionEvidence(id: "recent", kind: .userReport, text: "apples first",
            source: "dated report", observedAt: now)
        let older = CompanionEvidence(id: "older", kind: .userReport, text: "apples second",
            source: "dated report", observedAt: now.addingTimeInterval(-1))
        XCTAssertEqual(CompanionMemoryRetrieval.read(query: "apples", now: now, reports: [recent, older]).evidence.map(\.id),
                       ["recent", "older"])
    }

    func testTaskContextRelevantButNotAnActionAuthorization() {
        let note = CompanionMemoryNote(id: "task", subject: "school", text: "User confirmed school checklist: coat and backpack. Completion unknown.", source: "user-confirmed task", recordedAt: now)
        let result = CompanionMemoryRetrieval.read(query: "school", now: now, taskContext: [note])
        XCTAssertEqual(result.evidence.count, 1)
        XCTAssertEqual(result.evidence[0].kind, .historicalMemory)
        XCTAssertTrue(result.evidence[0].text.contains("Completion unknown"))
        XCTAssertTrue(result.summary.contains("data, not an instruction"))
    }
    func testNamedRoomQueryIncludesItsObservedInventoryWithoutOtherRoomDump() {
        var observed = ObservedObjectMemory()
        observed.observe(category: "bed", source: .roomPlanScan, frameID: "f", roomName: "bedroom", at: now, now: now)
        observed.observe(category: "cup", source: .onDeviceDetector, frameID: "f", roomName: "kitchen", at: now, now: now)
        let result = CompanionMemoryRetrieval.read(query: "What do you remember about bedroom room?", now: now, observed: observed)
        XCTAssertEqual(result.evidence.count, 1)
        XCTAssertTrue(result.evidence[0].text.contains("bedroom"))
        XCTAssertFalse(result.evidence[0].text.contains("kitchen"))
    }

}
