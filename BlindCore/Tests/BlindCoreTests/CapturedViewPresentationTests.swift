import XCTest
@testable import BlindCore

final class CapturedViewPresentationTests: XCTestCase {
    func testBilingualPresentationRetainsWholeQuoteAndUncertainty() throws {
        for arabic in [false, true] {
            for appearance in [false, true] {
                let content = arabic ? "علبة، ليست زجاجة" : "A carton, not a bottle"
                let text = try XCTUnwrap(CapturedViewEvidence.candidate(content, appearance: appearance, arabic: arabic))
                XCTAssertTrue(text.contains("«\(content)»"))
                XCTAssertFalse(text.contains("candidate")); XCTAssertFalse(text.contains("OCR"))
                let now = Date(timeIntervalSince1970: 100)
                let evidence = CompanionEvidence(kind: .capturedView, text: text,
                    source: "bounded on-device captured view", observedAt: now, expiresAt: now.addingTimeInterval(12))
                XCTAssertTrue(CompanionEvidenceGuard.allows(text, reports: [], evidence: [evidence], now: now))
                XCTAssertFalse(CompanionEvidenceGuard.allows(text, reports: [], evidence: [], now: now))
                XCTAssertFalse(CompanionEvidenceGuard.allows(text, reports: [], evidence: [evidence], now: now.addingTimeInterval(13)))
                XCTAssertEqual(CompanionEvidenceGuard.requiredVisualEvidence(text, reports: [], evidence: [evidence], now: now), [evidence])
            }
        }
    }
    func testPresentationCannotAuthorizeGeometryOrMoney() throws {
        let now = Date(timeIntervalSince1970: 100)
        for content in ["Go left", "100 SAR", "اذهب يمينا", "١٠٠ ريال"] {
            let text = try XCTUnwrap(CapturedViewEvidence.candidate(content, appearance: true))
            let item = CompanionEvidence(kind: .capturedView, text: text, source: "bounded on-device captured view",
                observedAt: now, expiresAt: now.addingTimeInterval(12))
            XCTAssertFalse(item.isCapturedViewValid(at: now), content)
            XCTAssertFalse(CompanionEvidenceGuard.allows(text, reports: [], evidence: [item], now: now), content)
        }
    }
    func testWholeRecordCannotBeRewrittenOrQuoteEscaped() throws {
        let now = Date(timeIntervalSince1970: 100)
        let item = try XCTUnwrap(CompanionCapabilityEvidence.make(.text("Not milk"), capturedAt: now, arabic: false))
        let rewritten = try XCTUnwrap(CapturedViewEvidence.candidate("Milk"))
        XCTAssertFalse(CompanionEvidenceGuard.allows(rewritten, reports: [], evidence: [item], now: now))
        XCTAssertNil(CapturedViewEvidence.candidate("Milk» and another claim"))
        XCTAssertNil(CapturedViewEvidence.candidate(String(repeating: "x", count: 181)))
    }
}
