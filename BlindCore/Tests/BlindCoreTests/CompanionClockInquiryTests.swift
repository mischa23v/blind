import XCTest
@testable import BlindCore

final class CompanionClockInquiryTests: XCTestCase {
    private let wall = Date(timeIntervalSince1970: 1_700_000_000)
    private let utc = TimeZone(secondsFromGMT: 0)!
    private let monotonic = 100.0
    private let binding = CompanionClockReplyLease.Binding(requestID: UUID(), generation: 7, replyID: UUID())

    private func makeLease(arabic: Bool = false) throws -> CompanionClockReplyLease {
        try XCTUnwrap(CompanionClockReplyLease.read(binding: binding, now: wall,
            monotonicNow: monotonic, timeZone: utc, arabic: arabic))
    }
    private func check(_ lease: inout CompanionClockReplyLease, age: Double,
                       wallAge: Double? = nil, zone: TimeZone? = nil) -> Bool {
        let reply = lease.reply
        return lease.validates(reply: reply, binding: binding,
            now: wall.addingTimeInterval(wallAge ?? age), monotonicNow: monotonic + age,
            timeZone: zone ?? utc)
    }

    func testWholeEnglishAndArabicClockQuestionsRouteWithoutModelGuessing() {
        for question in ["what time is it", "What time is it?", "  Please tell me the time.  ",
                         "What's the time please?", "What’s the time now?", "what time is it right now",
                         "Can you tell me what time it is?", "could you tell me the time",
                         "what does the device clock say", "كم الساعة؟", "كم الساعه الحين",
                         "من فضلك كم السّاعة الآن؟", "الساعة كم لو سمحت", "ما هو الوقت الآن؟"] {
            XCTAssertTrue(CompanionClockInquiry.recognizes(question), question)
        }
    }

    func testReportedQuotedCompoundAmbiguousAndPhysicalRequestsDoNotEnterReadOnlyLane() {
        for question in ["", "time", "the time", "what time is lunch", "what time was it yesterday",
                         "where is my clock", "read the clock on the wall", "what time is it in London",
                         "what time is it and take me home", "stop and tell me the time",
                         "what time is it? Cancel my task.", "don't tell me the time", "she asked what time is it",
                         "\"what time is it\"", "‘what time is it’", "what\ntime is it", "what time is it\u{202E}",
                         "كم الساعة وامش إلى الباب", "قال كم الساعة", String(repeating: " ", count: 301) + "what time is it"] {
            XCTAssertFalse(CompanionClockInquiry.recognizes(question), question)
        }
    }

    func testClockInquiryDoesNotBypassCommandOriginBoundary() {
        for origin in CompanionCommandOrigin.allCases {
            XCTAssertEqual(CompanionClockInquiry.accepts("what time is it", origin: origin),
                           origin == .trustedInterface || origin == .unverifiedMicrophone)
            XCTAssertFalse(CompanionClockInquiry.accepts("go to the door", origin: origin))
        }
        XCTAssertFalse(CommandAuthority.permits(.changeGoal, from: .unverifiedMicrophone))
        XCTAssertFalse(CommandAuthority.permits(.cancelTaskOrNavigation, from: .unverifiedMicrophone))
        XCTAssertFalse(CommandAuthority.permits(.commitUserReport, from: .unverifiedMicrophone))
    }

    func testLeaseReusesCanonicalClockToolValueAndProvenance() throws {
        for arabic in [false, true] {
            var lease = try makeLease(arabic: arabic)
            let original = CompanionClock.read(now: wall, timeZone: utc, arabic: arabic)
            XCTAssertEqual(lease.reply, original.evidence[0].text)
            XCTAssertEqual(lease.result.source, original.source)
            XCTAssertEqual(lease.result.summary, original.summary)
            XCTAssertEqual(lease.evidence.kind, .measuredState)
            XCTAssertEqual(lease.evidence.observedAt, wall)
            XCTAssertEqual(lease.evidence.expiresAt, wall.addingTimeInterval(5))
            XCTAssertTrue(CompanionClock.isClockEvidence(lease.evidence))
            XCTAssertTrue(check(&lease, age: 0))
        }
    }

    func testOriginalMonotonicLeaseExpiresAtFiveSecondsNotFiveAfterLastCheck() throws {
        var lease = try makeLease()
        for age in [0.0, 1, 2, 3, 4, 4.999] { XCTAssertTrue(check(&lease, age: age)) }
        XCTAssertEqual(lease.issuedAt, monotonic)
        XCTAssertFalse(check(&lease, age: 5))
        XCTAssertTrue(lease.invalidated)
        XCTAssertFalse(check(&lease, age: 0))
    }

    func testWallClockRollbackCannotExtendMonotonicLease() throws {
        var lease = try makeLease()
        XCTAssertTrue(check(&lease, age: 4))
        XCTAssertFalse(check(&lease, age: 5.1, wallAge: 4.9))
        XCTAssertFalse(check(&lease, age: 5.2, wallAge: 4.95))
    }

    func testWallRollbackWithinLeaseRevokesPermanentlyEvenWithinSkewTolerance() throws {
        var lease = try makeLease()
        XCTAssertTrue(check(&lease, age: 2))
        XCTAssertFalse(check(&lease, age: 2.05, wallAge: 1.99))
        XCTAssertFalse(check(&lease, age: 2.1))
    }

    func testMonotonicRollbackRevokesRatherThanRestartingTheClock() throws {
        var lease = try makeLease()
        XCTAssertTrue(check(&lease, age: 2))
        XCTAssertFalse(check(&lease, age: 1.99, wallAge: 2.05))
        XCTAssertFalse(check(&lease, age: 2.1))
    }

    func testClockAdjustmentsForwardOrBackwardFailClosed() throws {
        for (age, wallAge) in [(1.0, 0.0), (1.0, 2.0), (0.0, -0.01), (-0.01, 0.0), (4.9, 5.0)] {
            var lease = try makeLease()
            XCTAssertFalse(check(&lease, age: age, wallAge: wallAge), "\(age), \(wallAge)")
        }
    }

    func testSmallSamplingSkewDoesNotExpandEitherExpiryBoundary() throws {
        var allowed = try makeLease()
        XCTAssertTrue(check(&allowed, age: 2, wallAge: 2.1))
        var wallExpired = try makeLease()
        XCTAssertFalse(check(&wallExpired, age: 4.9, wallAge: 5))
        var monotonicExpired = try makeLease()
        XCTAssertFalse(check(&monotonicExpired, age: 5, wallAge: 4.9))
    }

    func testTimeZoneChangeRejectsEvenWhenCurrentOffsetsAreEqual() throws {
        var lease = try makeLease()
        let abidjan = try XCTUnwrap(TimeZone(identifier: "Africa/Abidjan"))
        XCTAssertEqual(abidjan.secondsFromGMT(for: wall), utc.secondsFromGMT(for: wall))
        XCTAssertFalse(check(&lease, age: 1, zone: abidjan))
        XCTAssertFalse(check(&lease, age: 2))
    }

    func testDaylightSavingOffsetTransitionInvalidatesSameNamedZone() throws {
        let zone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let before = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-11-01T05:59:59Z"))
        var lease = try XCTUnwrap(CompanionClockReplyLease.read(binding: binding, now: before,
            monotonicNow: monotonic, timeZone: zone, arabic: false))
        let reply = lease.reply
        XCTAssertFalse(lease.validates(reply: reply, binding: binding, now: before.addingTimeInterval(2),
            monotonicNow: monotonic + 2, timeZone: zone))
    }

    func testLeaseBindsExactReplyNotModelParaphrasePrefixOrAppendedCommand() throws {
        let original = try makeLease()
        for text in ["It's 3 pm.", "Maybe " + original.reply, original.reply + " Walk forward.",
                     original.reply + " ", "The current time is unknown.", ""] {
            var lease = original
            XCTAssertFalse(lease.validates(reply: text, binding: binding, now: wall,
                monotonicNow: monotonic, timeZone: utc), text)
        }
    }

    func testLeaseBindsRequestSessionAndReplyIdentity() throws {
        for other in [
            CompanionClockReplyLease.Binding(requestID: UUID(), generation: binding.generation, replyID: binding.replyID),
            CompanionClockReplyLease.Binding(requestID: binding.requestID, generation: binding.generation + 1, replyID: binding.replyID),
            CompanionClockReplyLease.Binding(requestID: binding.requestID, generation: binding.generation, replyID: UUID())
        ] {
            var lease = try makeLease()
            let reply = lease.reply
            XCTAssertFalse(lease.validates(reply: reply, binding: other, now: wall,
                monotonicNow: monotonic, timeZone: utc))
            XCTAssertFalse(check(&lease, age: 1))
        }
    }

    func testInvalidNumbersFailClosedOnReadAndRevalidation() throws {
        for invalid in [Double.nan, .infinity, -.infinity, -0.01] {
            XCTAssertNil(CompanionClockReplyLease.read(binding: binding, now: wall,
                monotonicNow: invalid, timeZone: utc, arabic: false))
            var lease = try makeLease()
            let reply = lease.reply
            XCTAssertFalse(lease.validates(reply: reply, binding: binding, now: wall,
                monotonicNow: invalid, timeZone: utc))
        }
        for invalid in [Double.nan, .infinity, -.infinity, Double.greatestFiniteMagnitude] {
            let badDate = Date(timeIntervalSinceReferenceDate: invalid)
            XCTAssertNil(CompanionClockReplyLease.read(binding: binding, now: badDate,
                monotonicNow: monotonic, timeZone: utc, arabic: false))
            var lease = try makeLease()
            let reply = lease.reply
            XCTAssertFalse(lease.validates(reply: reply, binding: binding, now: badDate,
                monotonicNow: monotonic, timeZone: utc))
        }
    }

    func testExplicitInvalidationCannotBeUndoneBySameTextOrRestoredTimeZone() throws {
        var lease = try makeLease()
        lease.invalidate()
        XCTAssertFalse(check(&lease, age: 0))
    }

    func testOnlyANewReadCreatesANewLeaseEvenWhenMinuteTextIsIdentical() throws {
        var old = try makeLease()
        let oldReply = old.reply
        XCTAssertFalse(check(&old, age: 5))
        let newBinding = CompanionClockReplyLease.Binding(requestID: binding.requestID,
            generation: binding.generation, replyID: UUID())
        var fresh = try XCTUnwrap(CompanionClockReplyLease.read(binding: newBinding,
            now: wall.addingTimeInterval(6), monotonicNow: monotonic + 6, timeZone: utc, arabic: false))
        XCTAssertEqual(fresh.reply, oldReply)
        XCTAssertNotEqual(fresh.evidence.id, old.evidence.id)
        XCTAssertEqual(fresh.issuedAt, monotonic + 6)
        let freshReply = fresh.reply
        XCTAssertTrue(fresh.validates(reply: freshReply, binding: newBinding, now: wall.addingTimeInterval(6),
            monotonicNow: monotonic + 6, timeZone: utc))
        XCTAssertFalse(check(&old, age: 6))
    }
}
