import XCTest
@testable import BlindCore

final class BoardingPassReadingTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    func owner() -> BoardingReadingOwner { .init(session: UUID(), request: UUID(), perception: UUID(), source: UUID(), revision: UUID()) }
    func changed(_ a: BoardingReadingOwner) -> BoardingReadingOwner { .init(session: a.session, request: a.request, perception: a.perception, source: a.source, revision: UUID()) }
    func leg(_ flight: String = "00123", seat: String = "012A", optional: String = "") -> String {
        "       " + "RUH" + "JED" + "SV " + flight + "299" + "Y" + seat + "00001" + "1" + String(format: "%02X", optional.utf8.count) + optional
    }
    func pass(_ legs: [String]? = nil) -> String {
        let values = legs ?? [leg()]
        return "M\(values.count)" + String(repeating: " ", count: 20) + "E" + values.joined()
    }
    func text(_ a: BoardingReadingOwner, kind: BoardingTextKind = .airportSign, flight: String = "SV123", gate: String = "B12", at: Date? = nil) -> BoardingTextReading? {
        .read(lines: ["FLIGHT: \(flight)", "GATE: \(gate)"], confidence: 0.99, kind: kind, observedAt: at ?? now, observedMonotonic: 100, owner: a)
    }
    func setup(_ a: BoardingReadingOwner, payload: String? = nil) -> BoardingReadingController {
        var c = BoardingReadingController(); c.select(a)
        XCTAssertTrue(c.ingest(payloads: ["https://example.com", payload ?? pass()], owner: a, capturedAt: now, capturedMonotonic: 100, now: now, monotonicNow: 100))
        return c
    }
    func testMandatoryFieldsNoYearOrGateInvented() throws {
        let legs = try BoardingPassParser.parse(pass())
        XCTAssertEqual(legs.count, 1); XCTAssertEqual(legs[0].flight, "SV123")
        XCTAssertEqual(legs[0].seat, "12A"); XCTAssertEqual(legs[0].dayOfYear, 299)
        var c = setup(owner()); let a = owner(); c = setup(a)
        let result = try XCTUnwrap(c.prepare(legIndex: nil, expectedFlight: nil, currentOwner: a, now: now, monotonicNow: 100, privateOutputAllowed: true))
        XCTAssertTrue(result.speech.contains("year is unknown")); XCTAssertTrue(result.speech.contains("gate is unknown"))
        XCTAssertFalse(result.speech.contains("gate 12A")); XCTAssertTrue(result.speech.contains("2023-11-14T22:13:20Z"))
    }
    func testAllTruncationsReject() {
        let p = pass()
        for n in 0..<p.count { XCTAssertThrowsError(try BoardingPassParser.parse(String(p.prefix(n)))) }
    }
    func testMalformedOversizeUnicodeReject() {
        for p in [String(repeating: "M", count: 4097), pass().replacingOccurrences(of: "299", with: "٠٢٩"), pass().replacingOccurrences(of: "299", with: "000"), pass().replacingOccurrences(of: "299", with: "367"), pass() + "JUNK", "M0" + String(pass().dropFirst(2)), pass().replacingOccurrences(of: "012A", with: "GO!!")] {
            XCTAssertThrowsError(try BoardingPassParser.parse(p))
        }
    }
    func testOptionalAndSecuritySkippedStrictly() throws {
        let p = pass([leg(optional: "ABCDEF")]) + "^102OK"
        XCTAssertEqual(try BoardingPassParser.parse(p).first?.seat, "12A")
        XCTAssertThrowsError(try BoardingPassParser.parse(String(p.dropLast())))
        XCTAssertThrowsError(try BoardingPassParser.parse(p + "x"))
        XCTAssertThrowsError(try BoardingPassParser.parse(pass([leg(optional: "ABCDEF")]).replacingOccurrences(of: "06ABCDEF", with: "0GABCDEF")))
    }
    func testBlankSeatAndDayRemainUnknown() throws {
        let p = pass([leg(seat: "    ")]).replacingOccurrences(of: "299", with: "   ")
        let result = try XCTUnwrap(BoardingPassParser.parse(p).first)
        XCTAssertNil(result.seat); XCTAssertNil(result.dayOfYear)
    }
    func testMultipleLegRequiresExplicitSelection() throws {
        let a = owner(); var c = setup(a, payload: pass([leg(), leg("00456", seat: "003C")]))
        XCTAssertNil(c.prepare(legIndex: nil, expectedFlight: nil, currentOwner: a, now: now, monotonicNow: 100, privateOutputAllowed: true))
        XCTAssertNil(c.prepare(legIndex: 1, expectedFlight: nil, currentOwner: a, now: now, monotonicNow: 100, privateOutputAllowed: true))
        XCTAssertNil(c.prepare(legIndex: 1, expectedFlight: "SV123", currentOwner: a, now: now, monotonicNow: 100, privateOutputAllowed: true))
        let result = try XCTUnwrap(c.prepare(legIndex: 1, expectedFlight: "SV456", currentOwner: a, now: now, monotonicNow: 100, privateOutputAllowed: true))
        XCTAssertEqual(result.receipt.legIndex, 1); XCTAssertTrue(result.speech.contains("seat 3C"))
    }
    func testMultipleBarcodeAmbiguityAndBounds() {
        let a = owner(); var c = setup(a)
        for payloads in [[pass(), pass()], [pass(), "Mbroken"], Array(repeating: "url", count: 9), ["https://example.com"], [String(repeating: "x", count: 4097), pass()]] {
            XCTAssertFalse(c.ingest(payloads: payloads, owner: a, capturedAt: now, capturedMonotonic: 100, now: now, monotonicNow: 100))
            XCTAssertNil(c.prepare(legIndex: nil, expectedFlight: nil, currentOwner: a, now: now, monotonicNow: 100, privateOutputAllowed: true))
        }
    }
    func testOCRArabicDigitsAndNoSeatGateConflation() {
        let a = owner()
        let result = BoardingTextReading.read(lines: ["الرحلة: SV١٢٣", "البوابة: B١٢", "المقعد: ١٢A"], confidence: 1, kind: .printedPass, observedAt: now, observedMonotonic: 100, owner: a)
        XCTAssertEqual(result?.flight, "SV123"); XCTAssertEqual(result?.gate, "B12"); XCTAssertEqual(result?.seat, "12A")
        let seatOnly = BoardingTextReading.read(lines: ["FLIGHT: SV123", "SEAT: 12A"], confidence: 1, kind: .printedPass, observedAt: now, observedMonotonic: 100, owner: a)
        XCTAssertNil(seatOnly?.gate)
        XCTAssertNil(BoardingTextReading.read(lines: ["FLIGHT: SV123", "SEAT: 12A"], confidence: 1, kind: .airportSign, observedAt: now, observedMonotonic: 100, owner: a))
    }
    func testOCRAmbiguityRejectsNotGuesses() {
        let a = owner()
        for lines in [["GATE: B12"], ["FLIGHT: SV123", "GATE: B12", "GATE: B13"], ["FLIGHT: SV123", "GATE: B12/B13"], ["FLIGHT: SV123", "GATE: BI2"], ["FLIGHT: SV123", "GATE: 12", "FLIGHT: SV456"], ["FLIGHT SV123 GATE B12"], ["FLIGHT: SV123", "GATE: https://bad.invalid"]] {
            XCTAssertNil(BoardingTextReading.read(lines: lines, confidence: 1, kind: .airportSign, observedAt: now, observedMonotonic: 100, owner: a))
        }
        XCTAssertNil(BoardingTextReading.read(lines: ["FLIGHT: SV123", "GATE: B12"], confidence: 0.94, kind: .airportSign, observedAt: now, observedMonotonic: 100, owner: a))
    }
    func testWrongFlightStaleFutureGateRejected() {
        let a = owner(); var c = setup(a); c.selectTextSource(a, primaryOwner: a)
        for observation in [text(a, flight: "SV456"), text(a, at: now.addingTimeInterval(-30)), text(a, at: now.addingTimeInterval(1))] {
            XCTAssertNil(c.prepare(legIndex: nil, expectedFlight: nil, text: observation, currentOwner: a, now: now, monotonicNow: 100, privateOutputAllowed: true))
        }
    }
    func testPrintedSourceMustMatchAndSignTimeIsObservationNotCurrentAuthority() throws {
        let a = owner(); var c = setup(a); c.selectTextSource(a, primaryOwner: a)
        XCTAssertNil(c.prepare(legIndex: nil, expectedFlight: nil, text: text(changed(a), kind: .printedPass), currentOwner: a, now: now, monotonicNow: 100, privateOutputAllowed: true))
        let printed = try XCTUnwrap(c.prepare(legIndex: nil, expectedFlight: nil, text: text(a, kind: .printedPass), currentOwner: a, now: now, monotonicNow: 100, privateOutputAllowed: true))
        XCTAssertTrue(printed.speech.contains("may have changed"))
        let sign = try XCTUnwrap(c.prepare(legIndex: nil, expectedFlight: nil, text: text(a), currentOwner: a, now: now, monotonicNow: 100, privateOutputAllowed: true))
        XCTAssertTrue(sign.speech.contains("sign observed at")); XCTAssertTrue(sign.speech.contains("not verified"))
    }
    func testChangedSourceOwnershipPrivacyAndInterruptBlockQueuedDelivery() throws {
        for mode in 0..<6 {
            let a = owner(); var c = setup(a); c.selectTextSource(a, primaryOwner: a)
            let out = try XCTUnwrap(c.prepare(legIndex: nil, expectedFlight: nil, text: text(a), currentOwner: a, now: now, monotonicNow: 100, privateOutputAllowed: true))
            if mode == 0 { c.clear() }; if mode == 1 { c.interrupt() }
            XCTAssertNil(c.deliver(out, currentOwner: mode == 2 ? changed(a) : a,
                currentTextSource: mode == 3 ? changed(a) : a,
                now: mode == 4 ? now.addingTimeInterval(30) : now, monotonicNow: mode == 4 ? 130 : 100, privateOutputAllowed: mode != 5))
        }
    }
    func testExactDeliveryOnceAndFreshnessBoundaries() throws {
        let a = owner(); var c = setup(a)
        let out = try XCTUnwrap(c.prepare(legIndex: nil, expectedFlight: nil, currentOwner: a, now: now, monotonicNow: 100, privateOutputAllowed: true))
        XCTAssertEqual(c.deliver(out, currentOwner: a, currentTextSource: nil, now: now, monotonicNow: 100, privateOutputAllowed: true), out.speech)
        XCTAssertNil(c.deliver(out, currentOwner: a, currentTextSource: nil, now: now, monotonicNow: 100, privateOutputAllowed: true))
        XCTAssertNil(c.prepare(legIndex: nil, expectedFlight: nil, currentOwner: a, now: now.addingTimeInterval(120), monotonicNow: 220, privateOutputAllowed: true))
        XCTAssertNil(c.prepare(legIndex: nil, expectedFlight: nil, currentOwner: a, now: now, monotonicNow: 100, privateOutputAllowed: false))
        XCTAssertFalse(c.ingest(payloads: [pass()], owner: a, capturedAt: now.addingTimeInterval(-2), capturedMonotonic: 100, now: now, monotonicNow: 100))
        XCTAssertFalse(c.ingest(payloads: [pass()], owner: a, capturedAt: now.addingTimeInterval(1), capturedMonotonic: 100, now: now, monotonicNow: 100))
    }
    func testSeatConflictDoesNotBecomeGate() throws {
        let a = owner(); var c = setup(a); c.selectTextSource(a, primaryOwner: a)
        let t = BoardingTextReading.read(lines: ["FLIGHT: SV123", "SEAT: 14C"], confidence: 1, kind: .printedPass, observedAt: now, observedMonotonic: 100, owner: a)
        let out = try XCTUnwrap(c.prepare(legIndex: nil, expectedFlight: nil, text: t, currentOwner: a, now: now, monotonicNow: 100, privateOutputAllowed: true))
        XCTAssertTrue(out.speech.contains("seat differs: 14C")); XCTAssertTrue(out.speech.contains("gate is unknown"))
    }
    func testObservationOnlySignDoesNotClaimItineraryOrKnownDate() throws {
        let a = owner(); var c = BoardingReadingController(); c.select(a); c.selectTextSource(a, primaryOwner: a)
        let t = try XCTUnwrap(text(a))
        let out = try XCTUnwrap(c.prepareObservation(t, currentOwner: a, now: now, monotonicNow: 100, privateOutputAllowed: true))
        XCTAssertNil(out.receipt.legIndex); XCTAssertTrue(out.speech.contains("date and year are unknown"))
        XCTAssertTrue(out.speech.contains("Listed gate B12")); XCTAssertFalse(out.speech.contains("seat"))
        XCTAssertNotNil(c.deliver(out, currentOwner: a, currentTextSource: a, now: now, monotonicNow: 100, privateOutputAllowed: true))
        XCTAssertNil(c.prepareObservation(t, currentOwner: changed(a), now: now, monotonicNow: 100, privateOutputAllowed: true))
        XCTAssertNil(c.prepareObservation(t, currentOwner: a, now: now.addingTimeInterval(2), monotonicNow: 102, privateOutputAllowed: true))
        XCTAssertNil(c.prepareObservation(t, currentOwner: a, now: now, monotonicNow: 100, privateOutputAllowed: false))
    }
    func testArabicRenderingAndFourLegBound() throws {
        let a = owner(); var c = setup(a, payload: pass(Array(repeating: leg(), count: 4)))
        let out = try XCTUnwrap(c.prepare(legIndex: 3, expectedFlight: "SV123", currentOwner: a, now: now, monotonicNow: 100, privateOutputAllowed: true, arabic: true))
        XCTAssertTrue(out.speech.contains("السنة غير معروفة")); XCTAssertTrue(out.speech.contains("البوابة غير معروفة"))
        XCTAssertThrowsError(try BoardingPassParser.parse(pass(Array(repeating: leg(), count: 5))))
    }
    func testBoundedByteMutationCorpusDoesNotTrapOrLeakPrivatePayload() {
        let bytes = Array(pass().utf8)
        for i in bytes.indices {
            for byte in [UInt8(0), 31, 127, 255] {
                var changed = bytes; changed[i] = byte
                XCTAssertThrowsError(try BoardingPassParser.parse(String(decoding: changed, as: UTF8.self)))
            }
        }
        let a = owner(); var c = setup(a, payload: pass().replacingOccurrences(of: String(repeating: " ", count: 20), with: "SYNTHETIC/PRIVATE  X"))
        let out = c.prepare(legIndex: nil, expectedFlight: nil, currentOwner: a, now: now, monotonicNow: 100, privateOutputAllowed: true)
        XCTAssertNotNil(out); XCTAssertFalse(out?.speech.contains("SYNTHETIC") ?? true)
    }

    func testLatePriorOwnerCannotEraseCurrentOutput() throws {
        let a = owner(), b = owner(); var c = setup(a)
        let old = try XCTUnwrap(c.prepare(legIndex: nil, expectedFlight: nil, currentOwner: a, now: now, monotonicNow: 100, privateOutputAllowed: true))
        c.select(b)
        XCTAssertTrue(c.ingest(payloads: [pass()], owner: b, capturedAt: now, capturedMonotonic: 101, now: now, monotonicNow: 101))
        let current = try XCTUnwrap(c.prepare(legIndex: nil, expectedFlight: nil, currentOwner: b, now: now, monotonicNow: 101, privateOutputAllowed: true))
        XCTAssertFalse(c.ingest(payloads: [pass()], owner: a, capturedAt: now, capturedMonotonic: 100, now: now, monotonicNow: 102))
        XCTAssertNil(c.prepare(legIndex: nil, expectedFlight: nil, currentOwner: a, now: now, monotonicNow: 102, privateOutputAllowed: true))
        XCTAssertNil(c.prepareObservation(try XCTUnwrap(text(a)), currentOwner: a, now: now, monotonicNow: 102, privateOutputAllowed: true))
        XCTAssertNil(c.deliver(old, currentOwner: a, currentTextSource: nil, now: now, monotonicNow: 102, privateOutputAllowed: true))
        XCTAssertEqual(c.deliver(current, currentOwner: b, currentTextSource: nil, now: now, monotonicNow: 102, privateOutputAllowed: true), current.speech)
    }
    func testClockRollbackCannotReviveExpiredPassOrSign() throws {
        let a = owner(); var c = setup(a)
        let out = try XCTUnwrap(c.prepare(legIndex: nil, expectedFlight: nil, currentOwner: a, now: now, monotonicNow: 100, privateOutputAllowed: true))
        XCTAssertNil(c.deliver(out, currentOwner: a, currentTextSource: nil, now: now, monotonicNow: 220, privateOutputAllowed: true))
        XCTAssertNil(c.prepare(legIndex: nil, expectedFlight: nil, currentOwner: a, now: now, monotonicNow: 100, privateOutputAllowed: true))
        XCTAssertNil(c.prepare(legIndex: nil, expectedFlight: nil, currentOwner: a, now: now, monotonicNow: 221, privateOutputAllowed: true))
        var d = setup(a); d.selectTextSource(a, primaryOwner: a)
        let sign = try XCTUnwrap(d.prepare(legIndex: nil, expectedFlight: nil, text: text(a), currentOwner: a, now: now, monotonicNow: 100, privateOutputAllowed: true))
        XCTAssertNil(d.deliver(sign, currentOwner: a, currentTextSource: a, now: now, monotonicNow: 130, privateOutputAllowed: true))
        XCTAssertNil(d.prepare(legIndex: nil, expectedFlight: nil, text: text(a), currentOwner: a, now: now, monotonicNow: 100, privateOutputAllowed: true))
    }

    func testZeroOnlyAndZeroSuffixNeverBecomeDifferentLabels() throws {
        for flight in ["00000", "0000A"] { XCTAssertThrowsError(try BoardingPassParser.parse(pass([leg(flight)]))) }
        for seat in ["0000", "000A", "   0"] { XCTAssertThrowsError(try BoardingPassParser.parse(pass([leg(seat: seat)]))) }
        XCTAssertEqual(try BoardingPassParser.parse(pass([leg("0001A", seat: "001A")])).first?.flight, "SV1A")
        XCTAssertEqual(try BoardingPassParser.parse(pass([leg("0001A", seat: "001A")])).first?.seat, "1A")
    }

    func testSamePrimaryLatePrintedOCRPreservesCurrentPending() throws {
        let a = owner(); var c = setup(a); c.selectTextSource(a, primaryOwner: a)
        let current = try XCTUnwrap(c.prepare(legIndex: nil, expectedFlight: nil, text: text(a, kind: .printedPass), currentOwner: a, now: now, monotonicNow: 101, privateOutputAllowed: true))
        XCTAssertNil(c.prepare(legIndex: nil, expectedFlight: nil, text: text(changed(a), kind: .printedPass), currentOwner: a, now: now, monotonicNow: 999, privateOutputAllowed: true))
        XCTAssertEqual(c.deliver(current, currentOwner: a, currentTextSource: a, now: now, monotonicNow: 102, privateOutputAllowed: true), current.speech)
    }
    func testSamePrimaryLateSignOCRPreservesCurrentPending() throws {
        let a = owner(), b = changed(owner()); let selected = changed(a)
        let older = BoardingReadingOwner(session: a.session, request: a.request, perception: a.perception, source: b.source, revision: b.revision)
        var c = setup(a); c.selectTextSource(selected, primaryOwner: a)
        let current = try XCTUnwrap(c.prepare(legIndex: nil, expectedFlight: nil, text: text(selected, gate: "C14"), currentOwner: a, now: now, monotonicNow: 101, privateOutputAllowed: true))
        XCTAssertNil(c.prepare(legIndex: nil, expectedFlight: nil, text: text(older, gate: "B12"), currentOwner: a, now: now, monotonicNow: 102, privateOutputAllowed: true))
        XCTAssertEqual(c.deliver(current, currentOwner: a, currentTextSource: selected, now: now, monotonicNow: 102, privateOutputAllowed: true), current.speech)
    }

    func testSecondarySelectionRetirementNilFallbackAndLateDelivery() throws {
        let a = owner(), b = changed(a), selected = changed(a); var c = setup(a)
        XCTAssertTrue(c.selectTextSource(b, primaryOwner: a))
        let old = try XCTUnwrap(c.prepare(legIndex: nil, expectedFlight: nil, text: text(b), currentOwner: a, now: now, monotonicNow: 101, privateOutputAllowed: true))
        XCTAssertTrue(c.selectTextSource(selected, primaryOwner: a))
        XCTAssertNil(c.deliver(old, currentOwner: a, currentTextSource: b, now: now, monotonicNow: 999, privateOutputAllowed: true))
        let fresh = try XCTUnwrap(c.prepare(legIndex: nil, expectedFlight: nil, text: text(selected, gate: "C14"), currentOwner: a, now: now, monotonicNow: 102, privateOutputAllowed: true))
        XCTAssertFalse(c.selectTextSource(b, primaryOwner: changed(a)))
        XCTAssertNil(c.prepare(legIndex: nil, expectedFlight: nil, currentOwner: a, now: now, monotonicNow: 999, privateOutputAllowed: true))
        XCTAssertNil(c.deliver(fresh, currentOwner: a, currentTextSource: b, now: now, monotonicNow: 999, privateOutputAllowed: true))
        XCTAssertEqual(c.deliver(fresh, currentOwner: a, currentTextSource: selected, now: now, monotonicNow: 103, privateOutputAllowed: true), fresh.speech)
        c.clear()
        XCTAssertFalse(c.selectTextSource(selected, primaryOwner: a))
    }

}
