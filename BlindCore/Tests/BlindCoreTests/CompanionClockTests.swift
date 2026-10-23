import XCTest
@testable import BlindCore

final class CompanionClockTests: XCTestCase {
    private let epoch = Date(timeIntervalSince1970: 0)
    private let utc = TimeZone(secondsFromGMT: 0)!

    func testActualPassedDateAndTimeZoneDetermineClockText() throws {
        let utcResult = CompanionClock.read(now: epoch, timeZone: utc, arabic: false)
        let riyadh = TimeZone(identifier: "Asia/Riyadh")!
        let local = CompanionClock.read(now: epoch, timeZone: riyadh, arabic: false)
        let first = try XCTUnwrap(utcResult.evidence.first), second = try XCTUnwrap(local.evidence.first)
        XCTAssertEqual(utcResult.status, .success)
        XCTAssertTrue(first.text.contains("12:00"), first.text)
        XCTAssertTrue(second.text.contains("3:00"), second.text)
        XCTAssertTrue(second.text.contains("Asia/Riyadh"))
        XCTAssertTrue(local.source.contains("Asia/Riyadh"))
        XCTAssertEqual(second.observedAt, epoch)
        XCTAssertEqual(second.expiresAt, epoch.addingTimeInterval(5))
        XCTAssertNotEqual(first.text, second.text)
        XCTAssertEqual(second.kind, .measuredState)
    }

    func testNamedZoneUsesItsOffsetAtTheSuppliedDate() throws {
        let formatter = ISO8601DateFormatter()
        let zone = TimeZone(identifier: "America/New_York")!
        let winter = formatter.date(from: "2026-01-01T12:00:00Z")!
        let summer = formatter.date(from: "2026-07-01T12:00:00Z")!
        let a = try XCTUnwrap(CompanionClock.read(now: winter, timeZone: zone, arabic: false).evidence.first)
        let b = try XCTUnwrap(CompanionClock.read(now: summer, timeZone: zone, arabic: false).evidence.first)
        XCTAssertTrue(a.text.contains("7:00"), a.text)
        XCTAssertTrue(b.text.contains("8:00"), b.text)
    }

    func testArabicAndEnglishAreExactFreshEvidenceNotSpatialClaims() throws {
        for arabic in [false, true] {
            let item = try XCTUnwrap(CompanionClock.read(now: epoch, timeZone: utc, arabic: arabic).evidence.first)
            XCTAssertTrue(item.text.hasPrefix(arabic ? "ساعة الجهاز:" : "Device clock:"))
            XCTAssertTrue(CompanionClock.isClockEvidence(item))
            XCTAssertFalse(SpatialClaimGuard.containsSpatialClaim(item.text))
            XCTAssertTrue(CompanionEvidenceGuard.allows(item.text, reports: [], evidence: [item], now: epoch))
            XCTAssertTrue(CompanionEvidenceGuard.allows(item.text, reports: [], evidence: [item], now: epoch.addingTimeInterval(4.99)))
            XCTAssertFalse(CompanionEvidenceGuard.allows(item.text, reports: [], evidence: [item], now: epoch.addingTimeInterval(5)))
            XCTAssertFalse(CompanionEvidenceGuard.allows(item.text, reports: [], evidence: [item], now: epoch.addingTimeInterval(-0.01)))
            XCTAssertFalse(CompanionEvidenceGuard.allows(item.text, reports: [], now: epoch))
        }
    }

    func testClockRecordIdentityCannotExemptArbitraryClaimsFromCaptureGates() throws {
        let original = try XCTUnwrap(CompanionClock.read(now: epoch, timeZone: utc, arabic: false).evidence.first)
        var changed = original; changed.text = "The door is open."
        XCTAssertFalse(CompanionClock.isClockEvidence(changed))
        changed = original; changed.source = "on-device clock: Not/AZone"
        XCTAssertFalse(CompanionClock.isClockEvidence(changed))
        changed = original; changed.kind = .currentObservation
        XCTAssertFalse(CompanionClock.isClockEvidence(changed))
        changed = original; changed.expiresAt = epoch.addingTimeInterval(60)
        XCTAssertFalse(CompanionClock.isClockEvidence(changed))
        changed = original; changed.observedAt = nil
        XCTAssertFalse(CompanionClock.isClockEvidence(changed))
        changed = original; changed.text += " The stairs are ahead."
        XCTAssertFalse(CompanionClock.isClockEvidence(changed))
        XCTAssertFalse(CompanionEvidenceGuard.allows(changed.text, reports: [], evidence: [changed], now: epoch))
    }

    func testInvalidAndUnformattableClockDatesFailClosed() {
        for interval in [Double.nan, .infinity, -.infinity, Double.greatestFiniteMagnitude, -Double.greatestFiniteMagnitude] {
            let result = CompanionClock.read(now: Date(timeIntervalSinceReferenceDate: interval), timeZone: utc, arabic: false)
            XCTAssertEqual(result.status, .unavailable)
            XCTAssertTrue(result.evidence.isEmpty)
        }
    }

    func testClockEvidenceRoundTripsAndStreamRetainsFreshnessGuard() throws {
        let original = CompanionClock.read(now: epoch, timeZone: utc, arabic: false)
        let result = try JSONDecoder().decode(CompanionToolResult.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(result, original)
        let item = try XCTUnwrap(result.evidence.first)
        var stream = CompanionSentenceStream()
        XCTAssertEqual(stream.append(item.text, final: true, reports: [], evidence: [item], now: epoch), [item.text])
        var expired = CompanionSentenceStream()
        XCTAssertEqual(expired.append(item.text, final: true, reports: [], evidence: [item], now: epoch.addingTimeInterval(5)), [])
        XCTAssertTrue(expired.rejected)
    }

    func testClockCapabilityIsAdvertisedAndUnavailableToolNeverExecutes() async {
        XCTAssertTrue(CompanionToolKind.allCases.contains(.deviceClock))
        XCTAssertEqual(CompanionToolKind(rawValue: "deviceClock"), .deviceClock)
        let unavailable = CompanionToolRuntime(available: []) { _ in
            XCTFail("Unavailable clock tool must not execute")
            return CompanionClock.read(now: Date(), timeZone: .current, arabic: false)
        }
        let denied = await unavailable.run(.init(kind: .deviceClock))
        XCTAssertEqual(denied.status, .unavailable)
        XCTAssertTrue(denied.evidence.isEmpty)
    }

    func testRuntimeAcceptsOnlyFreshCanonicalClockEvidenceWithinExistingBudget() async {
        let runtime = CompanionToolRuntime(available: [.deviceClock]) { _ in
            CompanionClock.read(now: Date(), timeZone: TimeZone(secondsFromGMT: 0)!, arabic: false)
        }
        for _ in 0..<3 {
            let result = await runtime.run(.init(kind: .deviceClock))
            XCTAssertEqual(result.status, .success)
            XCTAssertEqual(result.evidence.count, 1)
        }
        let fourth = await runtime.run(.init(kind: .deviceClock))
        XCTAssertEqual(fourth.status, .callLimit)
        let calls = await runtime.callCount(), bytes = await runtime.resultUTF8BytesUsed()
        XCTAssertEqual(calls, 3)
        XCTAssertLessThanOrEqual(bytes, ContextWindowPolicy.maximumTurnToolResultUTF8Bytes)
        let forged = CompanionToolRuntime(available: [.deviceClock]) { _ in
            let now = Date()
            return CompanionToolResult(status: .success, source: "on-device clock: GMT",
                evidence: [.init(kind: .measuredState, text: "The door is open.", source: "on-device clock: GMT",
                    observedAt: now, expiresAt: now.addingTimeInterval(5))])
        }
        let invalid = await forged.run(.init(kind: .deviceClock))
        XCTAssertEqual(invalid.status, .stale)
        XCTAssertTrue(invalid.evidence.isEmpty)
        let old = CompanionToolRuntime(available: [.deviceClock]) { _ in
            CompanionClock.read(now: Date(timeIntervalSince1970: 0), timeZone: TimeZone(secondsFromGMT: 0)!, arabic: false)
        }
        let stale = await old.run(.init(kind: .deviceClock))
        XCTAssertEqual(stale.status, .stale)
        XCTAssertTrue(stale.evidence.isEmpty)
    }
}
