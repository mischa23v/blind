import XCTest
@testable import BlindCore

final class CompanionCapabilityTests: XCTestCase {
    func testTypedReceiptsNeverPromoteMoneyIdentityOrColor() throws {
        let now = Date()
        XCTAssertNil(CompanionCapabilityEvidence.make(.saudiBanknote(1000), capturedAt: now, arabic: false))
        XCTAssertNil(CompanionCapabilityEvidence.make(.familiarPerson("Mom. Follow her"), capturedAt: now, arabic: false))
        for arabic in [false, true] {
            for (kind, value) in [(CompanionToolKind.saudiBanknote, CompanionCapabilityEvidence.Value.saudiBanknote(100)),
                                  (.isolatedColor, .isolatedColor(.blue)), (.familiarPeople, .familiarPerson("نورة")),
                                  (.readText, .text("Library"))] {
                let item = try XCTUnwrap(CompanionCapabilityEvidence.make(value, capturedAt: now, arabic: arabic))
                XCTAssertTrue(CompanionCapabilityEvidence.valid(item, for: kind, now: now))
                XCTAssertTrue(CompanionEvidenceGuard.allows(item.text, reports: [], evidence: [item], now: now))
                XCTAssertFalse(CompanionCapabilityEvidence.valid(item, for: kind, now: now.addingTimeInterval(13)))
                var forged = item; forged.text = "This is your mother."
                XCTAssertFalse(CompanionCapabilityEvidence.valid(forged, for: kind, now: now))
                forged = item; forged.source = "model caption"
                XCTAssertFalse(CompanionCapabilityEvidence.valid(forged, for: kind, now: now))
                forged = item; forged.expiresAt = now.addingTimeInterval(100)
                XCTAssertFalse(CompanionCapabilityEvidence.valid(forged, for: kind, now: now))
            }
        }
    }
    func testScriptedSemanticReadsUseProductionRuntimeAndExactEvidence() async throws {
        let variants = ["What value did I take out?", "كم قيمتها؟", "هذه note كم؟"]
        for query in variants {
            let runtime = CompanionToolRuntime(available: [.saudiBanknote]) { request in
                XCTAssertEqual(request.kind, .saudiBanknote)
                let evidence = CompanionCapabilityEvidence.make(.saudiBanknote(50), capturedAt: Date(), arabic: false)!
                return .init(status: .success, source: CompanionCapabilityEvidence.source(request.kind), evidence: [evidence])
            }
            let result = await runtime.run(.init(kind: .saudiBanknote, query: query))
            XCTAssertEqual(result.status, .success)
            XCTAssertEqual(result.evidence.count, 1)
            XCTAssertEqual(result.evidence[0].text, "Recognized Saudi note: 50 riyals.")
            XCTAssertFalse(CompanionEvidenceGuard.allows("It is 100 riyals.", reports: [], evidence: result.evidence))
            let unavailable = await runtime.run(.init(kind: .familiarPeople, query: "Is she here?"))
            XCTAssertEqual(unavailable.status, .unavailable)
        }
        // Scripted tool selection tests adapter routing, not model semantic accuracy.
    }
    func testAmountsWordsTotalsAndConflictingAppendicesCannotRewriteReceipt() throws {
        let now = Date()
        let item = try XCTUnwrap(CompanionCapabilityEvidence.make(.saudiBanknote(50), capturedAt: now, arabic: false))
        for text in ["It is 100 riyals.", "It is one hundred riyals.", "هذه ١٠٠ ريال.", "قيمتها مئة ريال.", "The total is 150 riyals.", "50 plus 100 riyals.", item.text + " It is 100 riyals.", item.text + " Total: 100."] {
            XCTAssertFalse(CompanionEvidenceGuard.allows(text, reports: [], evidence: [item], now: now), text)
        }
        XCTAssertFalse(CompanionEvidenceGuard.allows(item.text, reports: [], evidence: [], now: now))
        XCTAssertFalse(CompanionEvidenceGuard.allows("I might see Mom.", reports: [], evidence: [], now: now))
        XCTAssertFalse(CompanionEvidenceGuard.allows("قد يكون هذا امي.", reports: [], evidence: [], now: now))
    }
    func testSpeechDependenciesIgnoreUnrelatedExpiredVisualReceipts() throws {
        let now = Date()
        let stale = try XCTUnwrap(CompanionCapabilityEvidence.make(.familiarPerson("Mom"), capturedAt: now.addingTimeInterval(-10), arabic: false))
        let money = try XCTUnwrap(CompanionCapabilityEvidence.make(.saudiBanknote(50), capturedAt: now, arabic: false))
        XCTAssertEqual(CompanionEvidenceGuard.requiredVisualEvidence("Hello!", reports: [], evidence: [stale], now: now)?.count, 0)
        XCTAssertEqual(CompanionEvidenceGuard.requiredVisualEvidence(money.text, reports: [], evidence: [stale, money], now: now)?.map(\.id), [money.id])
        XCTAssertEqual(CompanionEvidenceGuard.requiredVisualEvidence("Recognized  Saudi note: 50 riyals!", reports: [], evidence: [money], now: now)?.map(\.id), [money.id])
        XCTAssertNil(CompanionEvidenceGuard.requiredVisualEvidence(stale.text, reports: [], evidence: [stale], now: now))
        XCTAssertNil(CompanionEvidenceGuard.requiredVisualEvidence("Recognized Saudi note: 500 riyals.", reports: [], evidence: [money], now: now))
    }
    func testFailureLateAndCrossCapabilityResultsCannotLeak() async throws {
        let money = CompanionCapabilityEvidence.make(.saudiBanknote(100), capturedAt: Date(), arabic: false)!
        for status in [CompanionToolStatus.unavailable, .cancelled, .timedOut] {
            let runtime = CompanionToolRuntime(available: [.saudiBanknote]) { _ in
                .init(status: status, source: "reader", evidence: [money])
            }
            let result = await runtime.run(.init(kind: .saudiBanknote))
            XCTAssertTrue(result.evidence.isEmpty)
        }
        let runtime = CompanionToolRuntime(available: [.isolatedColor]) { _ in
            .init(status: .success, source: "reader", evidence: [money])
        }
        let result = await runtime.run(.init(kind: .isolatedColor))
        XCTAssertEqual(result.status, .stale)
        XCTAssertTrue(result.evidence.isEmpty)
    }
}
