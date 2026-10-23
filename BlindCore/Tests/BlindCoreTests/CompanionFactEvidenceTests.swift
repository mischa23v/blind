import XCTest
@testable import BlindCore

/// Same shared fixture as server/test/companion-guards.test.mjs, so Node and Swift cannot drift apart.
final class CompanionFactEvidenceTests: XCTestCase {
    private struct Expect: Decodable {
        let kind: String
        let object: String?
        let place: String?
        let tense: String?
        let hedged: Bool?
    }
    private struct Utterance: Decodable { let text: String; let expect: Expect? }
    private struct Claims: Decodable { let unsupported: [String]; let allowed: [String] }
    private struct Grounding: Decodable { let text: String; let frames: [VisualGrounding.Frame]; let expect: String }
    private struct Fixture: Decodable { let utterances: [Utterance]; let claims: Claims; let grounding: [Grounding] }

    private func fixture() throws -> Fixture {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "companion-evidence", withExtension: "json", subdirectory: "Fixtures"))
        return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
    }

    func testSharedUtteranceCases() throws {
        for item in try fixture().utterances {
            let parsed = CompanionUtterance.parse(item.text)
            guard let expect = item.expect else { XCTAssertNil(parsed, item.text); continue }
            switch parsed {
            case .find(let object)?:
                XCTAssertEqual(expect.kind, "find", item.text); XCTAssertEqual(object, expect.object, item.text)
            case .report(let object, let place, let tense, let hedged)?:
                XCTAssertEqual(expect.kind, "report", item.text)
                XCTAssertEqual(object, expect.object, item.text); XCTAssertEqual(place, expect.place, item.text)
                XCTAssertEqual(tense.rawValue, expect.tense, item.text); XCTAssertEqual(hedged, expect.hedged, item.text)
            case nil:
                XCTFail("Not parsed: \(item.text)")
            }
        }
    }

    func testSharedClaimCases() throws {
        let claims = try fixture().claims
        XCTAssertFalse(claims.unsupported.isEmpty)
        for text in claims.unsupported { XCTAssertTrue(ConversationClaimGuard.containsUnsupportedClaim(text), text) }
        for text in claims.allowed { XCTAssertFalse(ConversationClaimGuard.containsUnsupportedClaim(text), text) }
        XCTAssertEqual(ConversationClaimGuard.supportedText("Your cup is not found. Where did you last have it?"), "Where did you last have it?")
    }

    func testSharedGroundingCases() throws {
        for item in try fixture().grounding {
            XCTAssertEqual(VisualGrounding.groundedDescription(item.text, confirmed: VisualGrounding.agreedObjects(item.frames)), item.expect, item.text)
        }
    }

    /// The recorded 2026-10-22 failure: a historical report must never come back as the current location.
    func testHistoricalReportIsSpokenAsHistory() throws {
        var book = CompanionFactBook()
        let saidAt = Date(timeIntervalSince1970: 1_000_000)
        guard case .report(nil, let place, let tense, let hedged)? = CompanionUtterance.parse("I last left it on the kitchen table.") else {
            return XCTFail("Report not parsed")
        }
        let fact = try XCTUnwrap(book.record(object: "cup", place: place, tense: tense, hedged: hedged, at: saidAt))
        XCTAssertEqual(fact.acknowledgement(arabic: false), "Got it. You last had your cup on the kitchen table. I'll remember that.")
        let later = fact.recall(now: saidAt.addingTimeInterval(600), arabic: false)
        XCTAssertEqual(later, "You told me 10 minutes ago you last had your cup on the kitchen table. I don't know where it is now.")
        for text in [fact.acknowledgement(arabic: false), later, fact.acknowledgement(arabic: true), fact.recall(now: saidAt, arabic: true)] {
            XCTAssertFalse(ConversationClaimGuard.containsUnsupportedClaim(text), text)
            // Code-owned source-attributed history is separate from model output.
            // Its exact historical wording is asserted above, not a model-guard exemption.
        }
        XCTAssertEqual(book.latest(for: "my cup")?.place, "on the kitchen table")
        XCTAssertNil(book.latest(for: "backpack"))
        XCTAssertEqual(CompanionFact.unknown(object: "backpack", arabic: false), "I don't know where your backpack is yet. Where did you last have it?")
    }

    func testFactBookReplacesAndForgets() {
        var book = CompanionFactBook()
        book.record(object: "cup", place: "on the table", tense: .current, hedged: false)
        book.record(object: "my cup", place: "in the sink", tense: .earlier, hedged: false)
        XCTAssertEqual(book.facts.count, 1)
        XCTAssertEqual(book.latest(for: "cup")?.place, "in the sink")
        XCTAssertNil(book.record(object: "  ", place: "on the table", tense: .current, hedged: false))
        XCTAssertTrue(book.forget("cup"))
        XCTAssertTrue(book.facts.isEmpty)
    }
}
