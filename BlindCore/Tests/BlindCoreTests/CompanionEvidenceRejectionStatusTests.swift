import XCTest
@testable import BlindCore

final class CompanionEvidenceRejectionStatusTests: XCTestCase {
    private func captured(_ text: String = "Library", age: TimeInterval = 1) throws -> CompanionEvidence {
        try XCTUnwrap(CompanionCapabilityEvidence.make(.text(text),
            capturedAt: Date().addingTimeInterval(-age), arabic: false))
    }

    private func read(_ evidence: [CompanionEvidence], kind: CompanionToolKind = .currentObservation,
                      status: CompanionToolStatus = .success, source: String = "test local reader",
                      summary: String = "") async -> (CompanionToolResult, [CompanionEvidence]) {
        let runtime = CompanionToolRuntime(available: [kind]) { _ in
            CompanionToolResult(status: status, source: source, summary: summary, evidence: evidence)
        }
        let result = await runtime.run(.init(kind: kind))
        return (result, await runtime.currentEvidence())
    }

    private func assertRejected(_ evidence: [CompanionEvidence], kind: CompanionToolKind = .currentObservation,
                                expected: CompanionToolStatus = .rejectedEvidence,
                                file: StaticString = #filePath, line: UInt = #line) async {
        let (result, ledger) = await read(evidence, kind: kind)
        XCTAssertEqual(result.status, expected, file: file, line: line)
        XCTAssertTrue(result.evidence.isEmpty, file: file, line: line)
        XCTAssertTrue(ledger.isEmpty, file: file, line: line)
        XCTAssertEqual(result.source, kind.rawValue, file: file, line: line)
        XCTAssertEqual(result.summary, "No observation was obtained. Do not infer absence, clearance, or completion.",
                       file: file, line: line)
    }

    func testFreshSpatialAndMoneyCandidatesAreRejectedNotStale() async throws {
        for text in ["Cup beside plate", "Reach clearance unmeasured", "100 SAR"] {
            let item = try captured(text)
            for kind: CompanionToolKind in [.currentObservation, .readText] {
                await assertRejected([item], kind: kind)
            }
        }
    }

    func testMalformedProvenanceShapeKindAndTimeAreRejectedNotStale() async throws {
        let valid = try captured()
        var variants: [CompanionEvidence] = []
        var item = valid; item.id = ""; variants.append(item)
        item = valid; item.id = String(repeating: "a", count: 81); variants.append(item)
        item = valid; item.text = ""; variants.append(item)
        item = valid; item.text = String(repeating: "a", count: 501); variants.append(item)
        item = valid; item.source = "model asserted snapshot"; variants.append(item)
        item = valid; item.source = ""; variants.append(item)
        item = valid; item.kind = .historicalMemory; variants.append(item)
        item = valid; item.observedAt = nil; variants.append(item)
        item = valid; item.expiresAt = nil; variants.append(item)
        item = valid; item.expiresAt = item.observedAt; variants.append(item)
        item = valid; item.expiresAt = item.observedAt?.addingTimeInterval(60); variants.append(item)
        item = valid; item.observedAt = Date().addingTimeInterval(60)
        item.expiresAt = item.observedAt?.addingTimeInterval(12); variants.append(item)
        for variant in variants { await assertRejected([variant]) }
    }

    func testOnlyOtherwiseValidExpiredReceiptsAreStale() async throws {
        let snapshot = try captured(age: 60)
        await assertRejected([snapshot], expected: .stale)
        await assertRejected([snapshot], kind: .readText, expected: .stale)
        let at = Date().addingTimeInterval(-60)
        let current = CompanionEvidence(kind: .currentObservation, text: "Door is open.", source: "test gated camera",
            observedAt: at, expiresAt: at.addingTimeInterval(2))
        await assertRejected([current], expected: .stale)
        let note = try XCTUnwrap(CompanionCapabilityEvidence.make(.saudiBanknote(500), capturedAt: at, arabic: false))
        await assertRejected([note], kind: .saudiBanknote, expected: .stale)
        let person = try XCTUnwrap(CompanionCapabilityEvidence.make(.familiarPerson("Mum"), capturedAt: at, arabic: false))
        await assertRejected([person], kind: .familiarPeople, expected: .stale)
    }

    func testOldPolicyInvalidOrMalformedReceiptsDoNotBecomeStale() async throws {
        for text in ["Cup beside plate", "100 SAR"] {
            await assertRejected([try captured(text, age: 60)])
        }
        var invalid = try captured(age: 60)
        invalid.source = "model asserted snapshot"
        await assertRejected([invalid])
        invalid = try captured(age: 60)
        invalid.expiresAt = invalid.observedAt?.addingTimeInterval(30)
        await assertRejected([invalid])
    }

    func testMixedValidAndInvalidKeepsOnlyValidEvidence() async throws {
        let valid = try captured()
        let invalid = try captured("Cup beside plate")
        let expired = try captured("Museum", age: 60)
        let (result, ledger) = await read([invalid, valid, expired])
        XCTAssertEqual(result.status, .success)
        XCTAssertEqual(result.evidence, [valid])
        XCTAssertEqual(ledger, [valid])
    }

    func testMixedExpiredAndPolicyInvalidIsRejectedEvidence() async throws {
        let expired = try captured(age: 60)
        let invalid = try captured("Cup beside plate")
        await assertRejected([expired, invalid])
        await assertRejected([invalid, expired])
        await assertRejected([expired, try captured("Museum", age: 60)], expected: .stale)
    }

    func testMalformedResultEnvelopeHasNoPayload() async throws {
        let valid = try captured()
        for (source, summary) in [("", ""), (String(repeating: "s", count: 121), ""),
                                  ("test reader", String(repeating: "s", count: 601))] {
            let (result, ledger) = await read([valid], source: source, summary: summary)
            XCTAssertEqual(result.status, .rejectedEvidence)
            XCTAssertTrue(result.evidence.isEmpty)
            XCTAssertTrue(ledger.isEmpty)
        }
    }

    func testExplicitFailureCannotSmuggleEvidence() async throws {
        let valid = try captured()
        for status: CompanionToolStatus in [.rejectedEvidence, .stale, .unavailable, .offline] {
            let (result, ledger) = await read([valid], status: status)
            XCTAssertEqual(result.status, status)
            XCTAssertTrue(result.evidence.isEmpty)
            XCTAssertTrue(ledger.isEmpty)
        }
    }

    func testEmptySuccessfulReadRemainsUnknownNotRejected() async {
        let (result, ledger) = await read([])
        XCTAssertEqual(result.status, .success)
        XCTAssertTrue(result.evidence.isEmpty)
        XCTAssertTrue(ledger.isEmpty)
    }
}
