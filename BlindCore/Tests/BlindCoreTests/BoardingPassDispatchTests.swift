import XCTest
@testable import BlindCore
final class BoardingPassDispatchTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1700000000)
    func owner() -> BoardingReadingOwner { .init(session: UUID(), request: UUID(), perception: UUID(), source: UUID(), revision: UUID()) }
    func pass(_ flight: String = "00123", seat: String = "012A") -> String {
        "M1" + String(repeating: " ", count: 20) + "E" + String(repeating: " ", count: 7) + "RUHJEDSV " + flight + "299Y" + seat + "00001100"
    }
    func codes(_ values: [String], flight: String? = nil, arabic: Bool = false, mono: Double = 100) -> BoardingPassDispatch.Result {
        BoardingPassDispatch.codes(values, owner: owner(), capturedAt: now, capturedMonotonic: 100, now: now, monotonicNow: mono, selectedFlight: flight, arabic: arabic)
    }
    func rows(_ values: [(String, Double)], flight: String? = nil, arabic: Bool = false) -> BoardingPassDispatch.Result {
        BoardingPassDispatch.textRows(values, owner: owner(), capturedAt: now, capturedMonotonic: 100, now: now, monotonicNow: 100, selectedFlight: flight, arabic: arabic)
    }
    func answer(_ result: BoardingPassDispatch.Result, file: StaticString = #filePath, line: UInt = #line) throws -> BoardingPassDispatch.Answer {
        guard case .answer(let answer) = result else { XCTFail("No answer", file: file, line: line); throw NSError(domain: "test", code: 1) }
        return answer
    }
    func testPrivateSinglePassBoundedAttributedUnknownGate() throws {
        for arabic in [false, true] {
            let a = try answer(codes(["https://example.com", pass()], arabic: arabic))
            XCTAssertLessThanOrEqual(a.text.split { !$0.isLetter && !$0.isNumber }.count, 30)
            XCTAssertEqual(a.receipt.legIndex, 0); XCTAssertEqual(a.receipt.capturedMonotonic, 100)
            XCTAssertTrue(a.text.contains("SV123")); XCTAssertTrue(a.text.contains("12A"))
            XCTAssertFalse(a.text.contains("https"))
        }
        let a = try answer(codes([pass()]))
        XCTAssertTrue(a.text.contains("Gate and year unknown")); XCTAssertFalse(a.text.contains("gate 12A"))
    }
    func testAmbiguityNoGenericRawFallback() {
        XCTAssertEqual(codes([pass(), pass()]), .withheld)
        XCTAssertEqual(codes([pass(), "Mbad"]), .withheld)
        XCTAssertEqual(codes(["Mbad"]), .withheld)
        XCTAssertEqual(codes([String(repeating: "x", count: 4097)]), .withheld)
        XCTAssertEqual(codes(Array(repeating: "url", count: 9)), .withheld)
        XCTAssertEqual(codes(["https://example.com"]), .unrelated)
        XCTAssertEqual(codes([pass()], flight: "SV999"), .withheld)
        XCTAssertEqual(codes([pass()], mono: 102), .withheld)
    }
    func testMultiLegExplicitFlightOnly() throws {
        let single = pass(); let two = "M2" + single.dropFirst(2) + pass("00456", seat: "003C").dropFirst(23)
        XCTAssertEqual(codes([String(two)]), .withheld)
        let a = try answer(codes([String(two)], flight: "SV456"))
        XCTAssertEqual(a.receipt.legIndex, 1); XCTAssertTrue(a.text.contains("seat 3C"))
    }
    func testOneRowOnlyNoCrossBoardAssociation() throws {
        XCTAssertEqual(rows([("FLIGHT: SV123", 1), ("GATE: B12", 1)]), .withheld)
        XCTAssertEqual(rows([("FLIGHT: SV123; GATE: B12", 1), ("FLIGHT: SV456; GATE: C9", 1)]), .withheld)
        XCTAssertEqual(rows([("FLIGHT: SV123; GATE: B12", 0.9)]), .withheld)
        XCTAssertEqual(rows([("FLIGHT: SV123; GATE: BI2", 1)]), .withheld)
        XCTAssertEqual(rows([("FLIGHT: SV123; SEAT: 12A", 1)], flight: "SV456"), .withheld)
        let a = try answer(rows([("FLIGHT: SV123; GATE: B12; SEAT: 12A", 1)]))
        XCTAssertTrue(a.text.contains("Captured text")); XCTAssertTrue(a.text.contains("gate B12")); XCTAssertTrue(a.text.contains("seat 12A"))
        XCTAssertTrue(a.text.contains("current gate unverified")); XCTAssertLessThanOrEqual(a.text.split { !$0.isLetter && !$0.isNumber }.count, 30)
        XCTAssertNil(a.receipt.legIndex); XCTAssertEqual(a.receipt.textSource, a.receipt.owner)
    }
    func testArabicRowAndSeatNotGate() throws {
        let a = try answer(rows([("الرحلة: SV١٢٣؛ المقعد: ١٢A", 1)], arabic: true))
        XCTAssertTrue(a.text.contains("المقعد 12A")); XCTAssertFalse(a.text.contains("البوابة 12A"))
        XCTAssertEqual(rows([("random text", 1)]), .unrelated)
    }
    func testExplicitFlightSelectionNeverInvents() {
        XCTAssertEqual(BoardingPassDispatch.selectedFlight(in: "read flight SV123"), "SV123")
        XCTAssertNil(BoardingPassDispatch.selectedFlight(in: "flight SV123 flight SV456"))
        XCTAssertNil(BoardingPassDispatch.selectedFlight(in: "my next flight"))
        XCTAssertNil(BoardingPassDispatch.selectedFlight(in: "gate 12 seat 4"))
    }
    func testMalformedCaseWhitespaceAndOversizedOCRNeverFallThrough() {
        XCTAssertEqual(codes([" " + pass()]), .withheld)
        XCTAssertEqual(codes([pass().lowercased()]), .withheld)
        XCTAssertEqual(codes(["\n" + pass()]), .withheld)
        XCTAssertTrue(BoardingPassDispatch.isBoardingPayload(" m1malformed"))
        XCTAssertEqual(rows([(String(repeating: "A", count: 481), 1)]), .withheld)
        XCTAssertTrue(BoardingPassDispatch.isTravelText("FLIGHT : SV123"))
        XCTAssertEqual(rows([("FLIGHT : SV123",1)]), .withheld)
        XCTAssertNil(BoardingPassDispatch.selectedFlight(in: "flight SV123456"))
    }

}
