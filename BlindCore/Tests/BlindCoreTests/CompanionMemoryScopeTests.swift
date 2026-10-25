import XCTest
@testable import BlindCore

/// Authored ownership fixtures. No photos, detector accuracy, physical identity,
/// live localization, or safe mobility claims are established by these tests.
final class CompanionMemoryScopeTests: XCTestCase {
    let t = Date(timeIntervalSince1970: 1_700_000_000)
    func scope(_ house: String = "house-A", _ floor: String = "floor-1", _ fridge: String = "fridge-1", revision: String = "1", room: String = "kitchen") -> CompanionMemoryScope {
        CompanionMemoryScope(map: .init(mapID: "map-" + house, frameID: "frame-" + house, revision: revision),
            placeID: house, floorID: floor, roomID: room, objectInstanceID: fridge)!
    }
    func testPM002DistinctPhysicalOwnershipRetainsBothReports() throws {
        var book = CompanionFactBook()
        let a = scope(), b = scope("house-B", "floor-2", "fridge-2")
        book.record(object: "milk", place: "in the fridge", tense: .current, hedged: false, at: t, scope: a, sourceID: "PM-002-A")
        book.record(object: "milk", place: "on the table", tense: .current, hedged: false, at: t.addingTimeInterval(1), scope: b, sourceID: "PM-002-B")
        XCTAssertEqual(book.facts.count, 2)
        let restored = try JSONDecoder().decode(CompanionFactBook.self, from: JSONEncoder().encode(book))
        XCTAssertEqual(restored.latest(for: "milk", in: a)?.sourceID, "PM-002-A")
        XCTAssertEqual(restored.latest(for: "milk", in: a)?.at, t)
        XCTAssertEqual(restored.latest(for: "milk", in: b)?.place, "on the table")
        XCTAssertNil(restored.latest(for: "milk", in: nil))
        print("PM-002 PASS | Child A: My milk is in the fridge. | Child B: My milk is on the table. | Both source-owned historical reports survive restart.")
    }
    func testPM003FloorRoomRevisionAndInstanceNeverAlias() {
        var book = CompanionFactBook()
        let a = scope()
        book.record(object: "milk", place: "in the fridge", tense: .current, hedged: false, at: t, scope: a)
        for other in [scope("house-B"), scope("house-A", "floor-2"), scope("house-A", "floor-1", "fridge-2"), scope(revision: "2"), scope(room: "other-room")] {
            XCTAssertNil(book.latest(for: "milk", in: other))
        }
        let roomScope = CompanionMemoryScope(map: a.map, placeID: a.placeID, floorID: a.floorID, roomID: a.roomID)!
        XCTAssertNil(book.latest(for: "milk", in: roomScope))
        XCTAssertNil(CompanionMemoryScope(map: a.map, placeID: "", floorID: a.floorID, roomID: a.roomID))
    }
    func testPM004CorrectionRejectsOlderReplayAndDoesNotEraseOtherFridge() throws {
        var book = CompanionFactBook()
        let a = scope(), b = scope("house-B")
        book.record(object: "milk", place: "in the fridge", tense: .current, hedged: false, at: t, scope: a, sourceID: "old-A")
        book.record(object: "milk", place: "on the table", tense: .current, hedged: false, at: t, scope: b, sourceID: "B")
        book.record(object: "milk", place: "in the bag", tense: .current, hedged: false, at: t.addingTimeInterval(2), scope: a, sourceID: "correction-A")
        XCTAssertNil(book.record(object: "milk", place: "in the fridge", tense: .current, hedged: false, at: t, scope: a, sourceID: "old-A"))
        XCTAssertEqual(book.latest(for: "milk", in: a)?.place, "in the bag")
        XCTAssertEqual(book.latest(for: "milk", in: b)?.place, "on the table")
        XCTAssertTrue(book.forgetSource("correction-A"))
        XCTAssertNil(book.latest(for: "milk", in: a))
        XCTAssertNotNil(book.latest(for: "milk", in: b))
    }
    func testPM005FreshObservationWinsWithoutMutatingHistoryAndExpires() {
        let a = scope(), b = scope("house-B")
        var book = CompanionFactBook()
        let fact = book.record(object: "milk", place: "in the fridge", tense: .current, hedged: false, at: t, scope: a, sourceID: "PM-005-report")!
        let current = CompanionEvidence(id: "PM-005-camera", kind: .currentObservation,
            text: "Milk carton detected.", source: "authored gated detector fixture", observedAt: t.addingTimeInterval(10), expiresAt: t.addingTimeInterval(15))
        let observation = CompanionScopedObservation(scope: a, object: "milk", evidence: current)
        XCTAssertEqual(CompanionScopedRecall.select(object: "milk", scope: a, now: t.addingTimeInterval(11), observations: [observation], book: book), .observation(current))
        XCTAssertEqual(CompanionScopedRecall.select(object: "milk", scope: a, now: t.addingTimeInterval(15), observations: [observation], book: book), .reportedHistory(fact))
        XCTAssertEqual(CompanionScopedRecall.select(object: "milk", scope: b, now: t.addingTimeInterval(11), observations: [observation], book: book), .unknown)
        XCTAssertEqual(CompanionScopedRecall.select(object: "milk", scope: nil, now: t.addingTimeInterval(11), observations: [observation], book: book), .unknown)
        XCTAssertEqual(book.facts.first?.at, t)
        print("PM-005 PASS | Child: Where is my milk? | Fresh PM-005-camera selected instead of PM-005-report. After expiry: \(fact.recall(now: t.addingTimeInterval(15), arabic: false))")
    }
    func testPM006CorrectionNewerThanObservationWinsAndFutureObservationRejected() {
        let a = scope()
        var book = CompanionFactBook()
        let fact = book.record(object: "milk", place: "in the bag", tense: .current, hedged: false, at: t.addingTimeInterval(3), scope: a)!
        func observation(_ seconds: Double) -> CompanionScopedObservation {
            .init(scope: a, object: "milk", evidence: .init(id: "fixture", kind: .currentObservation, text: "Milk detected.", source: "fixture", observedAt: t.addingTimeInterval(seconds), expiresAt: t.addingTimeInterval(seconds + 5)))
        }
        XCTAssertEqual(CompanionScopedRecall.select(object: "milk", scope: a, now: t.addingTimeInterval(4), observations: [observation(2), observation(5)], book: book), .reportedHistory(fact))
    }
    func testPM011SavedItemsAreScopedAndCorrectionsStayLocal() throws {
        var memory = ItemMemory()
        let a = scope(), b = scope("house-B")
        let first = memory.remember(name: "milk", roomID: a.roomID, roomName: "kitchen", at: t, scope: a)!
        let second = memory.remember(name: "milk", roomID: b.roomID, roomName: "kitchen", at: t, scope: b)!
        XCTAssertNotEqual(first.id, second.id)
        XCTAssertTrue(memory.valid)
        XCTAssertFalse(memory.forget("milk"))
        XCTAssertFalse(memory.describe("milk", as: "red label"))
        XCTAssertNil(memory.find("milk", in: nil))
        XCTAssertNil(memory.remember(name: "milk", at: t.addingTimeInterval(-1), scope: a))
        let corrected = memory.remember(name: "milk", at: t.addingTimeInterval(1), scope: a)!
        XCTAssertEqual(corrected.id, first.id)
        memory = try JSONDecoder().decode(ItemMemory.self, from: JSONEncoder().encode(memory))
        XCTAssertEqual(memory.find("milk", in: b)?.savedAt, t)
        XCTAssertTrue(memory.forget(id: first.id))
        XCTAssertNotNil(memory.find("milk", in: b))
        XCTAssertNil(memory.find("milk", in: a))
    }
    func testPM012SavedScopeDoesNotAuthorizeMeasuredRelation() {
        var memory = ItemMemory()
        let a = scope()
        XCTAssertNil(memory.remember(name: "milk", roomID: "wrong-room", at: t, scope: a))
        let saved = memory.remember(name: "milk", position: .init(0,0,0), frameID: a.map.frameID, at: t, scope: a)!
        let answer = ItemMemory.answer(for: saved, asked: "milk", now: t, sameFrame: true, measuredRelation: "two metres left", arabic: false)
        XCTAssertFalse(answer.contains("two metres"))
        XCTAssertTrue(answer.contains("current position is not confirmed"))
    }
    func testPM014LegacyLookupCannotChooseScopedInstance() {
        var memory = ItemMemory()
        memory.remember(name: "milk", at: t, scope: scope())
        memory.remember(name: "milk", at: t, scope: scope("house-B"))
        XCTAssertNil(memory.find("milk"))
        XCTAssertNil(memory.find("my milk carton"))
    }
    func testPM015EmptyTargetCannotAdmitCurrentObservation() {
        let observation = CompanionScopedObservation(scope: scope(), object: "", evidence: .init(id: "fixture", kind: .currentObservation, text: "Milk detected.", source: "fixture", observedAt: t, expiresAt: t.addingTimeInterval(5)))
        XCTAssertEqual(CompanionScopedRecall.select(object: "", scope: scope(), now: t, observations: [observation], book: .init()), .unknown)
    }
    func testPM024SourceIDCannotMoveBetweenScopesOrAcquireNewDate() {
        var book = CompanionFactBook()
        let a = scope(), b = scope("house-B")
        let original = book.record(object: "milk", place: "in the fridge", tense: .current, hedged: false, at: t, scope: a, sourceID: "source-A")!
        XCTAssertNil(book.record(object: "milk", place: "in the fridge", tense: .current, hedged: false, at: t, scope: b, sourceID: "source-A"))
        XCTAssertNil(book.record(object: "milk", place: "in the fridge", tense: .current, hedged: false, at: t.addingTimeInterval(1), scope: a, sourceID: "source-A"))
        XCTAssertEqual(book.record(object: "milk", place: "in the fridge", tense: .current, hedged: false, at: t, scope: a, sourceID: "source-A"), original)
        XCTAssertEqual(book.facts, [original])
    }
    func testPM007LegacyRecordRemainsUnscopedHistoricalOnly() throws {
        var book = CompanionFactBook()
        book.record(object: "cup", place: "on the table", tense: .earlier, hedged: true, at: t)
        let restored = try JSONDecoder().decode(CompanionFactBook.self, from: JSONEncoder().encode(book))
        XCTAssertNil(restored.latest(for: "cup", in: scope()))
        XCTAssertNil(restored.latest(for: "cup", in: nil))
        XCTAssertTrue(restored.latest(for: "cup")!.recall(now: t, arabic: false).contains("I don't know where it is now"))
    }
}
