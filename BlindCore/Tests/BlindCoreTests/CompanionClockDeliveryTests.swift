import XCTest
@testable import BlindCore

final class CompanionClockDeliveryTests: XCTestCase {
    let wall = Date(timeIntervalSince1970: 1_700_000_000)
    let zone = TimeZone(secondsFromGMT: 0)!
    let request = UUID()
    let generation: UInt64 = 2
    func read(age: Double = 0, request: UUID? = nil) throws -> CompanionClockReplyLease {
        try XCTUnwrap(CompanionClockReplyLease.read(binding: .init(requestID: request ?? self.request,
            generation: generation, replyID: UUID()), now: wall.addingTimeInterval(age),
            monotonicNow: 100 + age, timeZone: zone, arabic: false))
    }
    func admit(_ text: String, _ leases: inout [UUID: CompanionClockReplyLease], age: Double,
               wallAge: Double? = nil, zone: TimeZone? = nil, request: UUID? = nil) -> CompanionClockDeliveryReceipt? {
        CompanionClockDelivery.admit(text, leases: &leases, requestID: request ?? self.request,
            generation: generation, now: wall.addingTimeInterval(wallAge ?? age),
            monotonicNow: 100 + age, timeZone: zone ?? self.zone)
    }
    func testRollbackRegressionRejectsOriginalToolAfterFiveMonotonicSeconds() throws {
        let value = try read(); var leases = [value.binding.replyID: value]
        XCTAssertTrue(CompanionEvidenceGuard.allows(value.reply, reports: [], evidence: [value.evidence], now: wall.addingTimeInterval(4)))
        XCTAssertNil(admit(value.reply, &leases, age: 8, wallAge: 4))
    }
    func testChangedZoneRegressionRejectsEarlierZoneEvenWhenWallAgeIsFresh() throws {
        let value = try read(); var leases = [value.binding.replyID: value]
        XCTAssertNil(admit(value.reply, &leases, age: 1, zone: try XCTUnwrap(TimeZone(identifier: "Asia/Riyadh"))))
    }
    func testCodeOwnedClockCannotBypassPolicyAfterOriginalReadExpires() throws {
        let value = try read(); var leases = [value.binding.replyID: value]
        XCTAssertNil(admit(value.reply, &leases, age: 9))
    }
    func testFreshCanonicalClockGetsOriginalReplyIdentity() throws {
        let value = try read(); var leases = [value.binding.replyID: value]
        let receipt = try XCTUnwrap(admit(value.reply, &leases, age: 1))
        XCTAssertEqual(receipt.replyIDs, [value.binding.replyID])
        XCTAssertEqual(receipt.text, value.reply)
        XCTAssertEqual(leases[value.binding.replyID]?.issuedAt, 100)
    }
    func testOrdinaryArithmeticHistoryStoryAndQuestionsDoNotNeedClock() {
        for text in ["Two plus two is four.", "It is 5.", "A clock has twelve hours.",
                     "The time is 5 hours.", "The time is distance divided by speed.", "In the story, it is noon.",
                     "At five o'clock, the dragon woke up.", "Yesterday it was 3 pm when we arrived.",
                     "What time is it?", "هل تحب القصص؟", "خمسة زائد اثنين يساوي سبعة.",
                     "Earlier, the device clock showed 4:00."] {
            var leases: [UUID: CompanionClockReplyLease] = [:]
            XCTAssertNotNil(admit(text, &leases, age: 50), text)
        }
    }
    func testRecognizedUngroundedCurrentTimeStatementsCannotBeGuessedByModel() {
        for text in ["Device clock: 3:00 PM (GMT).", "The current time is 3:00.", "The time is 3 pm.", "Right now, it's 3:40 PM.", "The local time is 3:40 PM.", "الساعة الآن هي الثالثة مساءً.",
                     "It's 3:00.", "It is now 3 pm.", "I think it's five o'clock.", "It is noon.",
                     "ساعة الجهاز: ٣:٠٠ م.", "الساعة الآن ٣:٠٠.", "الساعة الحين خمسة."] {
            var leases: [UUID: CompanionClockReplyLease] = [:]
            XCTAssertNil(admit(text, &leases, age: 0), text)
        }
    }
    func testNoReceiptCanBeMintedFromDecodedCanonicalEvidenceAlone() throws {
        let evidenceOnly = CompanionClock.read(now: wall, timeZone: zone, arabic: false)
        let decoded = try JSONDecoder().decode(CompanionToolResult.self, from: JSONEncoder().encode(evidenceOnly))
        var leases: [UUID: CompanionClockReplyLease] = [:]
        XCTAssertNil(admit(decoded.evidence[0].text, &leases, age: 0))
        XCTAssertFalse(CompanionClockDelivery.validatesToolResult(decoded, leases: &leases, requestID: request,
            generation: generation, now: wall, monotonicNow: 100, timeZone: zone))
    }
    func testDelayedToolResultIsBoundToActualAcquisitionNotReturnTime() throws {
        let value = try read(); var leases = [value.binding.replyID: value]
        XCTAssertFalse(CompanionClockDelivery.validatesToolResult(value.result, leases: &leases, requestID: request,
            generation: generation, now: wall.addingTimeInterval(4), monotonicNow: 108, timeZone: zone))
        XCTAssertEqual(leases[value.binding.replyID]?.issuedAt, 100)
    }
    func testToolSourceEvidenceIDAndExactValueCannotBeChanged() throws {
        let value = try read()
        var wrongSource = value.result; wrongSource.source = "other device clock"
        var wrongID = value.result; wrongID.evidence[0].id = UUID().uuidString
        var wrongValue = value.result; wrongValue.evidence[0].text += " Walk forward."
        var wrongExpiry = value.result; wrongExpiry.evidence[0].expiresAt = wall.addingTimeInterval(60)
        var wrongSummary = value.result; wrongSummary.summary = "A different instruction instead of clock provenance."
        for result in [wrongSource, wrongID, wrongValue, wrongExpiry, wrongSummary] {
            var leases = [value.binding.replyID: value]
            XCTAssertFalse(CompanionClockDelivery.validatesToolResult(result, leases: &leases,
                requestID: request, generation: generation, now: wall, monotonicNow: 100, timeZone: zone))
        }
    }
    func testReceiptCannotAuthorizeAnotherSessionRequestOrChangedReply() throws {
        let value = try read(); var leases = [value.binding.replyID: value]
        let receipt = try XCTUnwrap(admit(value.reply, &leases, age: 0))
        for (id, gen, text) in [(UUID(), generation, value.reply), (request, generation + 1, value.reply),
                                 (request, generation, value.reply + " Walk forward.")] {
            XCTAssertFalse(CompanionClockDelivery.validates(receipt, text: text, leases: &leases, requestID: id,
                generation: gen, now: wall, monotonicNow: 100, timeZone: zone))
        }
    }
    func testRepeatedSameMinuteReadCannotRenewOldQueuedReceiptOrDisplayedText() throws {
        let old = try read(); var leases = [old.binding.replyID: old]
        let receipt = try XCTUnwrap(admit(old.reply, &leases, age: 0))
        let newer = try read(age: 4); leases[newer.binding.replyID] = newer
        XCTAssertEqual(old.reply, newer.reply)
        XCTAssertFalse(CompanionClockDelivery.validates(receipt, text: old.reply, leases: &leases,
            requestID: request, generation: generation, now: wall.addingTimeInterval(6), monotonicNow: 106, timeZone: zone))
        XCTAssertNil(admit(old.reply, &leases, age: 6), "Even re-admission must retain the expired oldest same-turn receipt")
        XCTAssertFalse(leases[newer.binding.replyID]!.invalidated)
    }
    func testExplicitNewTurnReadCanUseSameMinuteValueWithoutResurrectingOldTurn() throws {
        let old = try read(); let newRequest = UUID(); let newer = try read(age: 6, request: newRequest)
        var leases = [old.binding.replyID: old, newer.binding.replyID: newer]
        let receipt = try XCTUnwrap(admit(newer.reply, &leases, age: 6, request: newRequest))
        XCTAssertEqual(receipt.replyIDs, [newer.binding.replyID])
        XCTAssertEqual(newer.issuedAt, 106)
    }
    func testCompoundReplyKeepsClockIdentityAndExpiresAsAWhole() throws {
        let value = try read(); var leases = [value.binding.replyID: value]
        let text = "Two plus two is four. " + value.reply
        let receipt = try XCTUnwrap(admit(text, &leases, age: 1))
        XCTAssertEqual(receipt.replyIDs, [value.binding.replyID])
        XCTAssertFalse(CompanionClockDelivery.validates(receipt, text: text, leases: &leases, requestID: request,
            generation: generation, now: wall.addingTimeInterval(5), monotonicNow: 105, timeZone: zone))
        XCTAssertNotNil(admit("Two plus two is four.", &leases, age: 6))
    }
    func testClockOperationOutputIsCodeOwnedAndHasNoModelTextInput() throws {
        let original = try read(); var leases = [original.binding.replyID: original]
        let receipt = try XCTUnwrap(CompanionClockDelivery.replyForClockOperation(original.binding.replyID,
            leases: &leases, requestID: request, generation: generation,
            now: wall.addingTimeInterval(1), monotonicNow: 101, timeZone: zone))
        XCTAssertEqual(receipt.text, original.reply)
        XCTAssertEqual(receipt.replyIDs, [original.binding.replyID])
    }
    func testClockOperationCannotSwitchToLaterReadWhenOriginalExpires() throws {
        let original = try read(), newer = try read(age: 4)
        var leases = [original.binding.replyID: original, newer.binding.replyID: newer]
        XCTAssertNil(CompanionClockDelivery.replyForClockOperation(original.binding.replyID,
            leases: &leases, requestID: request, generation: generation,
            now: wall.addingTimeInterval(4), monotonicNow: 106, timeZone: zone))
        XCTAssertEqual(leases[original.binding.replyID]?.issuedAt, 100)
        XCTAssertFalse(leases[newer.binding.replyID]!.invalidated)
    }

}
