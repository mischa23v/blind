import Foundation
import XCTest
@testable import BlindCore

// Optional local replay target, not part of the ordinary source-only fixture set.
// The external fixture contains copyrighted extracted text and MUST NOT be copied
// into the repository. Assertions/logs intentionally do not print source strings.
private struct OfficialReferenceFixture: Decodable {
    struct Identity: Decodable { let sourceID: UUID; let revision: UUID; let sha256: String; let exactModel: String }
    struct Block: Decodable { let id: String; let text: String; let bodyOffsetUTF16: Int; let bodyLengthUTF16: Int; let locator: String }
    let provenance: String
    let url: String
    let identity: Identity
    let positive: Block
    let negative: Block
    let query: String
    let headingOnlyQuery: String
    static func load() throws -> Self {
        guard let path = ProcessInfo.processInfo.environment["BLIND_REFERENCE_REPLAY_INPUT"] else {
            throw NSError(domain: "OfficialReferenceReplay", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "External local reference fixture is required; not a skip or pass."])
        }
        return try JSONDecoder().decode(Self.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
    }
    var sourceIdentity: CompanionReferenceIdentity {
        .init(sourceID: identity.sourceID, revision: identity.revision, sha256: identity.sha256,
              media: .manual, exactModel: identity.exactModel)
    }
    func source(negative useNegative: Bool = false) -> CompanionReferenceSource {
        let block = useNegative ? negative : positive
        let evidence = CompanionEvidence(id: block.id, kind: .historicalMemory,
            text: block.text, source: sourceIdentity.evidenceSource)
        let result = CompanionToolResult(status: .success, source: sourceIdentity.evidenceSource,
            summary: "Complete local source quotation only; no current appliance or physical guidance authority.", evidence: [evidence])
        return .init(identity: sourceIdentity, toolResult: result, blocks: [
            .init(evidence: evidence, bodyUTF16Range: NSRange(location: block.bodyOffsetUTF16, length: block.bodyLengthUTF16), locator: block.locator)])
    }
}

final class OfficialManufacturerReferenceReplayTests: XCTestCase {
    private let binding = CompanionReferenceReading.Binding(requestID: UUID(), generation: 1)
    private func context(_ fixture: OfficialReferenceFixture, _ now: Double, hazard: Bool = false) -> CompanionReferenceReading.Context {
        .init(binding: binding, selectedSource: fixture.sourceIdentity, monotonicNow: now, hazard: hazard)
    }
    private func prepare(_ fixture: OfficialReferenceFixture) throws -> CompanionReferenceReading {
        try .prepare(request: .init(kind: .readText, query: fixture.query), binding: binding,
            selectedSource: fixture.sourceIdentity, source: fixture.source(), issuedAt: 100, monotonicNow: 100)
    }

    func testActualExtractedSectionRetainsAllBytesThroughCoreLedgerReplay() throws {
        let fixture = try OfficialReferenceFixture.load()
        var reading = try prepare(fixture), ledger = SpeechDeliveryLedger()
        let bytes = try JSONEncoder().encode(fixture.source().toolResult).count
        XCTAssertGreaterThan(bytes, ContextWindowPolicy.maximumToolResultUTF8Bytes)
        var now = 100.0, chunks: [[String: Any]] = []
        while reading.state != .completed {
            now += 1
            let dispatch = try XCTUnwrap(reading.beginNext(ledger: &ledger, context: context(fixture, now)))
            let count = CompanionReferenceReading.wordCount(dispatch.chunk.spokenText)
            XCTAssertLessThanOrEqual(count, 35)
            XCTAssertEqual(dispatch.attempt.priority, .information)
            XCTAssertFalse(dispatch.attempt.independentAlert)
            chunks.append(["index": dispatch.chunk.index, "words": count,
                "originalSlice": dispatch.chunk.originalSlice, "spokenText": dispatch.chunk.spokenText,
                "locator": dispatch.chunk.locator])
            now += 1
            let completion = try XCTUnwrap(ledger.finish(token: dispatch.attempt.token, outcome: .completed, now: now))
            XCTAssertTrue(reading.complete(completion, context: context(fixture, now)))
        }
        let original = reading.chunks.map(\.originalSlice).joined()
        XCTAssertTrue(original.utf8.elementsEqual(fixture.positive.text.utf8), "Original extracted bytes must survive; source text intentionally not printed.")
        XCTAssertEqual(reading.completedChunkCount, reading.chunks.count)
        guard let output = ProcessInfo.processInfo.environment["BLIND_REFERENCE_REPLAY_OUTPUT"] else {
            XCTFail("Private local replay output path is required."); return
        }
        let record: [String: Any] = ["chunks": chunks, "completed": reading.state == .completed,
            "completedChunkCount": reading.completedChunkCount, "issuedAt": reading.issuedAt,
            "deadline": reading.deadline, "toolResultEncodedBytes": bytes,
            "modelResultBudgetBytes": ContextWindowPolicy.maximumToolResultUTF8Bytes]
        try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys, .prettyPrinted])
            .write(to: URL(fileURLWithPath: output), options: .atomic)
    }

    func testActualPDFSectionHeadingAloneCannotEstablishBodyRelevance() throws {
        let fixture = try OfficialReferenceFixture.load()
        XCTAssertThrowsError(try CompanionReferenceReading.prepare(request: .init(kind: .readText, query: fixture.headingOnlyQuery),
            binding: binding, selectedSource: fixture.sourceIdentity, source: fixture.source(negative: true),
            issuedAt: 100, monotonicNow: 100)) { error in
            XCTAssertEqual(error as? CompanionReferenceReading.Rejection, .noRelevantBody)
        }
    }

    func testRealSourceRejectsMismatchedSelectedModel() throws {
        let fixture = try OfficialReferenceFixture.load(), original = fixture.sourceIdentity
        let wrong = CompanionReferenceIdentity(sourceID: original.sourceID, revision: original.revision,
            sha256: original.sha256, media: .manual, exactModel: "AUTHORED-WRONG-MODEL")
        XCTAssertThrowsError(try CompanionReferenceReading.prepare(request: .init(kind: .readText, query: fixture.query),
            binding: binding, selectedSource: wrong, source: fixture.source(), issuedAt: 100, monotonicNow: 100)) { error in
            XCTAssertEqual(error as? CompanionReferenceReading.Rejection, .wrongSource)
        }
    }

    func testRealSourceInterruptedReplayNeverResumesOrRenews() throws {
        let fixture = try OfficialReferenceFixture.load()
        var reading = try prepare(fixture), ledger = SpeechDeliveryLedger()
        let dispatch = try XCTUnwrap(reading.beginNext(ledger: &ledger, context: context(fixture, 101)))
        let cancelled = try XCTUnwrap(ledger.finish(token: dispatch.attempt.token, outcome: .interrupted, now: 102))
        XCTAssertFalse(reading.complete(cancelled, context: context(fixture, 102)))
        XCTAssertTrue(reading.beginNext(ledger: &ledger, context: context(fixture, 103)) == nil, "Interrupted reference must stay withdrawn; source text intentionally not printed.")
        XCTAssertEqual(reading.state, .withdrawn(.interruption))
        XCTAssertEqual(reading.completedChunkCount, 0)
        XCTAssertEqual(reading.deadline, 160)
    }

    func testRealSourceExpiryAndHazardRequireWithdrawalBeforeProgress() throws {
        let fixture = try OfficialReferenceFixture.load()
        for hazard in [false, true] {
            var reading = try prepare(fixture), ledger = SpeechDeliveryLedger()
            let dispatch = try XCTUnwrap(reading.beginNext(ledger: &ledger, context: context(fixture, 101)))
            let now = hazard ? 102.0 : 160.0
            let completion = try XCTUnwrap(ledger.finish(token: dispatch.attempt.token, outcome: .completed, now: now))
            XCTAssertFalse(reading.complete(completion, context: context(fixture, now, hazard: hazard)))
            XCTAssertEqual(reading.completedChunkCount, 0)
            XCTAssertEqual(reading.state, .withdrawn(hazard ? .hazard : .expired))
            XCTAssertTrue(reading.source.toolResult.evidence[0].text.utf8.elementsEqual(fixture.positive.text.utf8))
        }
    }
}
