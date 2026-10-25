import Foundation
import XCTest
@testable import BlindCore

/// Authored synthetic Core tests. Real ledger methods receive simulated outcomes;
/// these are not AVSpeechSynthesizer, VoiceOver or audible-device validations.
final class CompanionReferenceReadingTests: XCTestCase {
    private struct Fixture: Decodable {
        let provenance: String
        let model: String
        let searchPhrase: String
        let blocks: [Block]
        struct Block: Decodable { let id: String; let text: String; let body: String; let locator: String }
    }
    private let binding = CompanionReferenceReading.Binding(requestID: UUID(), generation: 7)
    private let issuedAt = 100.0
    private var identity: CompanionReferenceIdentity {
        CompanionReferenceIdentity(sourceID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            revision: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            sha256: String(repeating: "a", count: 64), media: .manual, exactModel: "AUTHORED-WASHER-A")
    }
    private func fixture() throws -> Fixture {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "reference-reading-authored", withExtension: "json", subdirectory: "Fixtures"))
        return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
    }
    private func source(_ blocks: [(String, String)]? = nil, identity other: CompanionReferenceIdentity? = nil) throws -> CompanionReferenceSource {
        let id = other ?? identity
        let values: [CompanionReferenceBlock]
        if let blocks {
            values = blocks.enumerated().map { index, pair in
                CompanionReferenceBlock(evidence: CompanionEvidence(id: "block-\(index)", kind: .historicalMemory,
                    text: pair.0, source: id.evidenceSource), bodyUTF16Range: (pair.0 as NSString).range(of: pair.1), locator: "authored \(index)")
            }
        } else {
            values = try fixture().blocks.map { block in
                CompanionReferenceBlock(evidence: CompanionEvidence(id: block.id, kind: .historicalMemory,
                    text: block.text, source: id.evidenceSource), bodyUTF16Range: (block.text as NSString).range(of: block.body), locator: block.locator)
            }
        }
        return CompanionReferenceSource(identity: id,
            toolResult: CompanionToolResult(status: .success, source: id.evidenceSource, evidence: values.map(\.evidence)), blocks: values)
    }
    private func reading(source supplied: CompanionReferenceSource? = nil, query: String = "delay start",
                         at now: Double = 100, issued: Double = 100, arabic: Bool = false) throws -> CompanionReferenceReading {
        try CompanionReferenceReading.prepare(request: CompanionToolRequest(kind: .readText, query: query), binding: binding,
            selectedSource: identity, source: supplied ?? source(), issuedAt: issued, monotonicNow: now, arabic: arabic)
    }
    private func context(_ now: Double, binding other: CompanionReferenceReading.Binding? = nil,
                         selectedSource: CompanionReferenceIdentity? = nil, foreground: Bool = true,
                         quiet: Bool = false, hazard: Bool = false) -> CompanionReferenceReading.Context {
        CompanionReferenceReading.Context(binding: other ?? binding, selectedSource: selectedSource ?? identity,
            monotonicNow: now, foreground: foreground, quiet: quiet, hazard: hazard)
    }
    private func assertRejection(_ expected: CompanionReferenceReading.Rejection,
                                 _ work: () throws -> CompanionReferenceReading, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try work(), file: file, line: line) { error in
            XCTAssertEqual(error as? CompanionReferenceReading.Rejection, expected, file: file, line: line)
        }
    }

    func testAuthoredFixtureIsExplicitlyNotManufacturerOrHistoricalEvidence() throws {
        let value = try fixture()
        XCTAssertTrue(value.provenance.contains("Authored synthetic fixture"))
        XCTAssertTrue(value.model == identity.exactModel)
        XCTAssertTrue(value.searchPhrase == "delay start")
    }

    func testHeadingOnlyMatchFailsRatherThanReturningIrrelevantBody() throws {
        let text = "Delay start\nOnly warranty contact details appear in this body."
        let supplied = try source([(text, "Only warranty contact details appear in this body.")])
        assertRejection(.noRelevantBody) { try reading(source: supplied) }
    }

    func testBodyMatchingCannotAssemblePhraseAcrossBlocksOrHeadingBoundary() throws {
        assertRejection(.noRelevantBody) {
            try reading(source: source([("A\nThere is delay", "There is delay"), ("B\nstart is only a heading fragment", "start is only a heading fragment")]))
        }
        assertRejection(.noRelevantBody) {
            try reading(source: source([("Delay\nstart information", "start information")]))
        }
    }

    func testExactSelectedIdentityRejectsSameTitleDifferentBytesRevisionSourceOrModel() throws {
        let same = identity
        let others = [
            CompanionReferenceIdentity(sourceID: UUID(), revision: same.revision, sha256: same.sha256, media: .manual, exactModel: same.exactModel),
            CompanionReferenceIdentity(sourceID: same.sourceID, revision: UUID(), sha256: same.sha256, media: .manual, exactModel: same.exactModel),
            CompanionReferenceIdentity(sourceID: same.sourceID, revision: same.revision, sha256: String(repeating: "b", count: 64), media: .manual, exactModel: same.exactModel),
            CompanionReferenceIdentity(sourceID: same.sourceID, revision: same.revision, sha256: same.sha256, media: .manual, exactModel: "AUTHORED-WASHER-B"),
            CompanionReferenceIdentity(sourceID: same.sourceID, revision: same.revision, sha256: same.sha256, media: .selectedPhoto)
        ]
        for other in others { assertRejection(.wrongSource) { try reading(source: source(identity: other)) } }
    }

    func testLongSourceSurvivesOutsideModelBudgetWithAllQualifiersAndOriginalBytes() throws {
        let original = try source(), value = try reading(source: original)
        XCTAssertGreaterThan(try JSONEncoder().encode(original.toolResult).count, ContextWindowPolicy.maximumToolResultUTF8Bytes)
        XCTAssertTrue(value.source.toolResult == original.toolResult, "Complete source records must remain unchanged; values intentionally withheld.")
        XCTAssertGreaterThan(value.chunks.count, 4)
        for block in original.blocks {
            let recovered = value.chunks.filter { $0.blockID == block.evidence.id }.map(\.originalSlice).joined()
            XCTAssertTrue(recovered.utf8.elementsEqual(block.evidence.text.utf8))
        }
        XCTAssertEqual(value.chunks.map(\.index), Array(value.chunks.indices))
        XCTAssertTrue(value.chunks.last!.originalSlice.contains("current machine status"))
        XCTAssertTrue(value.chunks.allSatisfy { $0.source == identity && !$0.locator.isEmpty })
    }

    func testEveryEnglishAndArabicChunkIncludesAttributionWithinThirtyFiveWords() throws {
        for arabic in [false, true] {
            let value = try reading(arabic: arabic)
            for chunk in value.chunks {
                XCTAssertLessThanOrEqual(CompanionReferenceReading.wordCount(chunk.spokenText), 35)
                XCTAssertTrue(chunk.spokenText.hasPrefix(arabic ? "يقول المصدر المحدد: «" : "The selected source says: «"))
                XCTAssertTrue(chunk.spokenText.hasSuffix("»"))
            }
        }
    }

    func testPunctuationWhitespaceNegationsHyphensAndArabicRemainByteExact() throws {
        let body = "  delay start: not-ready, not-safe; don't omit ‘unless’.\n\n  "
            + String(repeating: "لا تحذف الشرط-الأخير؛ ", count: 40) + "\tEND\n"
        let value = try reading(source: source([(body, body)]))
        XCTAssertTrue(value.chunks.map(\.originalSlice).joined().utf8.elementsEqual(body.utf8))
        XCTAssertTrue(value.chunks.allSatisfy { CompanionReferenceReading.wordCount($0.spokenText) <= 35 })
    }

    func testNoModelParaphraseAndNoCurrentOrPhysicalEvidenceAuthority() throws {
        var value = try reading()
        var ledger = SpeechDeliveryLedger()
        let dispatched = try XCTUnwrap(value.beginNext(ledger: &ledger, context: context(101)))
        XCTAssertTrue(dispatched.attempt.text.utf8.elementsEqual(dispatched.chunk.spokenText.utf8), "Exact admitted speech must match; text intentionally withheld.")
        XCTAssertEqual(dispatched.attempt.priority, .information)
        XCTAssertEqual(dispatched.attempt.transport, .synthesized)
        XCTAssertFalse(dispatched.attempt.independentAlert)
        XCTAssertTrue(value.source.toolResult.evidence.allSatisfy { $0.kind == .historicalMemory && !$0.isCurrent(at: Date()) })
    }

    func testOnlyMatchingCoreLedgerCompletionAdvancesOneChunkAfterRevalidation() throws {
        var value = try reading(), ledger = SpeechDeliveryLedger()
        let first = try XCTUnwrap(value.beginNext(ledger: &ledger, context: context(101)))
        XCTAssertTrue(value.beginNext(ledger: &ledger, context: context(102)) == nil, "No speech/result expected; any value intentionally withheld.")
        XCTAssertEqual(value.completedChunkCount, 0)
        XCTAssertTrue(ledger.finish(token: UUID(), outcome: .completed, now: 102) == nil, "No speech/result expected; any value intentionally withheld.")
        let completed = try XCTUnwrap(ledger.finish(token: first.attempt.token, outcome: .completed, now: 103))
        XCTAssertTrue(value.complete(completed, context: context(103)))
        XCTAssertEqual(value.completedChunkCount, 1)
        XCTAssertFalse(value.complete(completed, context: context(104)))
        let second = try XCTUnwrap(value.beginNext(ledger: &ledger, context: context(104)))
        XCTAssertEqual(second.chunk.index, 1)
        XCTAssertFalse(value.complete(completed, context: context(105)))
        XCTAssertEqual(value.completedChunkCount, 1)
    }

    func testForeignValidSpeechCompletionDoesNotAdvanceReference() throws {
        var value = try reading(), own = SpeechDeliveryLedger(), other = SpeechDeliveryLedger()
        _ = try XCTUnwrap(value.beginNext(ledger: &own, context: context(101)))
        let unrelated = try XCTUnwrap(other.begin(text: value.chunks[0].spokenText, priority: .information,
            destination: .requested(value.chunks[0].id), transport: .synthesized))
        let completed = try XCTUnwrap(other.finish(token: unrelated.token, outcome: .completed, now: 102))
        XCTAssertFalse(value.complete(completed, context: context(102)))
        XCTAssertEqual(value.completedChunkCount, 0)
    }

    func testCompleteWholeAuthoredSequenceThroughCoreLedgerCompletions() throws {
        var value = try reading(), ledger = SpeechDeliveryLedger(), now = 100.0
        var spoken: [String] = []
        while value.state != .completed {
            now += 1
            let dispatched = try XCTUnwrap(value.beginNext(ledger: &ledger, context: context(now)))
            spoken.append(dispatched.chunk.originalSlice)
            now += 1
            let completed = try XCTUnwrap(ledger.finish(token: dispatched.attempt.token, outcome: .completed, now: now))
            XCTAssertTrue(value.complete(completed, context: context(now)))
        }
        XCTAssertEqual(value.completedChunkCount, value.chunks.count)
        XCTAssertTrue(spoken.joined().utf8.elementsEqual(value.source.blocks.map { $0.evidence.text }.joined().utf8), "Original source bytes must remain complete and ordered; text intentionally withheld.")
        XCTAssertTrue(value.beginNext(ledger: &ledger, context: context(now)) == nil, "No speech/result expected; any value intentionally withheld.")
    }

    func testUnknownOrInterruptedCompletionWithdrawsPermanently() throws {
        for outcome in [NarrationDelivery.unknown, .interrupted] {
            var value = try reading(), ledger = SpeechDeliveryLedger()
            let dispatched = try XCTUnwrap(value.beginNext(ledger: &ledger, context: context(101)))
            let completed = try XCTUnwrap(ledger.finish(token: dispatched.attempt.token, outcome: outcome, now: 102))
            XCTAssertFalse(value.complete(completed, context: context(102)))
            XCTAssertEqual(value.state, .withdrawn(.interruption))
            XCTAssertEqual(value.withdrawnSpeechID, dispatched.chunk.id)
            XCTAssertTrue(value.beginNext(ledger: &ledger, context: context(103)) == nil, "No speech/result expected; any value intentionally withheld.")
            XCTAssertEqual(value.completedChunkCount, 0)
        }
    }

    func testQuietHazardBackgroundNewQuestionAndSourceReplacementNeverResume() throws {
        let changed = CompanionReferenceIdentity(sourceID: identity.sourceID, revision: UUID(), sha256: identity.sha256,
            media: .manual, exactModel: identity.exactModel)
        let cases: [(CompanionReferenceReading.Context, CompanionReferenceReading.Withdrawal)] = [
            (context(102, quiet: true), .quiet), (context(102, hazard: true), .hazard),
            (context(102, foreground: false), .background),
            (context(102, binding: .init(requestID: UUID(), generation: 7)), .newQuestion),
            (context(102, binding: .init(requestID: binding.requestID, generation: 8)), .newQuestion),
            (context(102, selectedSource: changed), .sourceReplacement)
        ]
        for (invalid, reason) in cases {
            var value = try reading(), ledger = SpeechDeliveryLedger()
            let dispatched = try XCTUnwrap(value.beginNext(ledger: &ledger, context: context(101)))
            XCTAssertFalse(value.revalidate(invalid))
            XCTAssertEqual(value.state, .withdrawn(reason))
            XCTAssertEqual(value.withdrawnSpeechID, dispatched.chunk.id)
            _ = ledger.finish(token: dispatched.attempt.token, outcome: .interrupted, now: 102)
            XCTAssertTrue(value.beginNext(ledger: &ledger, context: context(103)) == nil, "No speech/result expected; any value intentionally withheld.")
        }
    }

    func testCompletionAfterHazardDoesNotAdvanceOrCancelIndependentAlert() throws {
        var value = try reading(), ledger = SpeechDeliveryLedger()
        let dispatched = try XCTUnwrap(value.beginNext(ledger: &ledger, context: context(101)))
        let old = try XCTUnwrap(ledger.finish(token: dispatched.attempt.token, outcome: .completed, now: 102))
        let hazard = try XCTUnwrap(ledger.begin(text: "Independent sensor warning.", priority: .danger,
            transport: .accessibility, independentAlert: true))
        XCTAssertFalse(value.complete(old, context: context(102, hazard: true)))
        XCTAssertEqual(value.completedChunkCount, 0)
        XCTAssertEqual(ledger.active?.token, hazard.token)
        XCTAssertTrue(ledger.mayContinueAfterPrivateRouteLoss)
    }

    func testOriginalDeadlineNotExtractionOrQueueTimeAndNoRenewalOnNextChunk() throws {
        var value = try reading(at: 149), ledger = SpeechDeliveryLedger()
        XCTAssertEqual(value.issuedAt, 100)
        XCTAssertEqual(value.deadline, 160)
        let first = try XCTUnwrap(value.beginNext(ledger: &ledger, context: context(150)))
        let completed = try XCTUnwrap(ledger.finish(token: first.attempt.token, outcome: .completed, now: 159.9))
        XCTAssertTrue(value.complete(completed, context: context(159.9)))
        XCTAssertTrue(value.beginNext(ledger: &ledger, context: context(160)) == nil, "No speech/result expected; any value intentionally withheld.")
        XCTAssertEqual(value.state, .withdrawn(.expired))
        XCTAssertEqual(value.completedChunkCount, 1)
        XCTAssertEqual(value.deadline, 160)
        XCTAssertTrue(value.beginNext(ledger: &ledger, context: context(161)) == nil, "No speech/result expected; any value intentionally withheld.")
    }

    func testDeadlineDuringSpeechRequiresWithdrawalRatherThanSuccessfulDelivery() throws {
        var value = try reading(), ledger = SpeechDeliveryLedger()
        let first = try XCTUnwrap(value.beginNext(ledger: &ledger, context: context(159)))
        let completed = try XCTUnwrap(ledger.finish(token: first.attempt.token, outcome: .completed, now: 160))
        XCTAssertFalse(value.complete(completed, context: context(160)))
        XCTAssertEqual(value.state, .withdrawn(.expired))
        XCTAssertEqual(value.completedChunkCount, 0)
        XCTAssertEqual(value.withdrawnSpeechID, first.chunk.id)
    }

    func testInvalidAndBackwardMonotonicClocksNeverReviveSequence() throws {
        for bad in [Double.nan, .infinity, -1, 99] {
            assertRejection(.invalidClock) { try reading(at: bad) }
        }
        assertRejection(.expired) { try reading(at: 160) }
        for bad in [Double.nan, .infinity, 100.5] {
            var value = try reading()
            XCTAssertTrue(value.revalidate(context(101)))
            XCTAssertFalse(value.revalidate(context(bad)))
            XCTAssertEqual(value.state, .withdrawn(.invalidClock))
            XCTAssertFalse(value.revalidate(context(102)))
        }
    }

    func testBusyLedgerDoesNotSkipChunkOrPreemptExistingSpeech() throws {
        var value = try reading(), ledger = SpeechDeliveryLedger()
        let other = try XCTUnwrap(ledger.begin(text: "Another admitted phrase.", priority: .information, transport: .synthesized))
        XCTAssertTrue(value.beginNext(ledger: &ledger, context: context(101)) == nil, "No speech/result expected; any value intentionally withheld.")
        XCTAssertEqual(ledger.active?.token, other.token)
        XCTAssertEqual(value.completedChunkCount, 0)
        _ = ledger.finish(token: other.token, outcome: .completed, now: 102)
        XCTAssertEqual(value.beginNext(ledger: &ledger, context: context(102))?.chunk.index, 0)
    }

    func testMalformedUnmatchedOrCurrentEvidenceCannotBecomeReference() throws {
        let good = try source()
        var item = good.blocks[0].evidence
        item.kind = .currentObservation
        let block = CompanionReferenceBlock(evidence: item, bodyUTF16Range: good.blocks[0].bodyUTF16Range, locator: "authored")
        let bad = CompanionReferenceSource(identity: identity, toolResult: CompanionToolResult(status: .success,
            source: identity.evidenceSource, evidence: [item]), blocks: [block])
        assertRejection(.malformedBlock) { try reading(source: bad) }
        let mismatched = CompanionReferenceSource(identity: identity, toolResult: good.toolResult, blocks: Array(good.blocks.dropLast()))
        assertRejection(.malformedBlock) { try reading(source: mismatched) }
        let unreadable = CompanionReferenceSource(identity: identity, toolResult: CompanionToolResult(status: .unavailable,
            source: identity.evidenceSource), blocks: good.blocks)
        assertRejection(.unreadable) { try reading(source: unreadable) }
    }

    func testBodyRangeMustBeValidAndCannotSplitUnicodeScalar() throws {
        let text = "😀 delay start body"
        for range in [NSRange(location: NSNotFound, length: 1), NSRange(location: 0, length: 0),
                      NSRange(location: 1000, length: 10), NSRange(location: 1, length: 2),
                      NSRange(location: 0, length: 1),
                      NSRange(location: 1, length: text.utf16.count - 1),
                      NSRange(location: 1, length: Int.max)] {
            let item = CompanionEvidence(kind: .historicalMemory, text: text, source: identity.evidenceSource)
            let bad = CompanionReferenceSource(identity: identity, toolResult: CompanionToolResult(status: .success,
                source: identity.evidenceSource, evidence: [item]), blocks: [CompanionReferenceBlock(evidence: item,
                    bodyUTF16Range: range, locator: "authored")])
            assertRejection(.malformedBlock) { try reading(source: bad) }
        }
    }

    func testCompleteUnicodeScalarBodyKeepsOriginalSourceBytes() throws {
        let text = "😀 delay start e\u{301} body"
        let item = CompanionEvidence(kind: .historicalMemory, text: text, source: identity.evidenceSource)
        for range in [NSRange(location: 0, length: text.utf16.count),
                      NSRange(location: 2, length: text.utf16.count - 2)] {
            let selected = CompanionReferenceSource(identity: identity, toolResult: CompanionToolResult(status: .success,
                source: identity.evidenceSource, evidence: [item]), blocks: [CompanionReferenceBlock(evidence: item,
                    bodyUTF16Range: range, locator: "authored")])
            let prepared = try reading(source: selected)
            XCTAssertTrue(prepared.source.blocks[0].evidence.text.utf8.elementsEqual(text.utf8),
                          "Validated body selection must preserve the complete original record.")
        }
    }

    func testWholeResourceRejectionIsExplicitNotSilentTruncation() throws {
        let huge = "delay start " + String(repeating: "authored ", count: 40_000)
        assertRejection(.resourceLimit) { try reading(source: source([(huge, huge)])) }
        assertRejection(.noRelevantBody) { try reading(query: "!!!") }
    }

    func testOversizedRetainedMetadataRejectsWholeSelection() throws {
        let good = try source()
        for field in ["summary", "locator", "id"] {
            var item = good.blocks[0].evidence
            if field == "id" { item.id = String(repeating: "x", count: 10_000) }
            let block = CompanionReferenceBlock(evidence: item, bodyUTF16Range: good.blocks[0].bodyUTF16Range,
                locator: field == "locator" ? String(repeating: "x", count: 10_000) : "authored")
            let result = CompanionToolResult(status: .success, source: identity.evidenceSource,
                summary: field == "summary" ? String(repeating: "x", count: 10_000) : "", evidence: [item])
            let bad = CompanionReferenceSource(identity: identity, toolResult: result, blocks: [block])
            assertRejection(.resourceLimit) { try reading(source: bad) }
        }
    }


    func testExactModelMustBeNonemptyPrintableBoundedAndDigestWellFormed() throws {
        for model in [nil, "", "   ", "\n\t", "\u{200B}", "M\u{0000}A", String(repeating: "M", count: 481)] as [String?] {
            let invalid = CompanionReferenceIdentity(sourceID: identity.sourceID, revision: identity.revision,
                sha256: identity.sha256, media: .manual, exactModel: model)
            assertRejection(.invalidIdentity) {
                try CompanionReferenceReading.prepare(request: .init(kind: .readText, query: "delay start"),
                    binding: binding, selectedSource: invalid, source: source(identity: invalid),
                    issuedAt: 100, monotonicNow: 100)
            }
        }
        for digest in ["", "a", String(repeating: "z", count: 64), String(repeating: "A", count: 64)] {
            let invalid = CompanionReferenceIdentity(sourceID: identity.sourceID, revision: identity.revision,
                sha256: digest, media: .manual, exactModel: "AUTHORED-WASHER-A")
            assertRejection(.invalidIdentity) {
                try CompanionReferenceReading.prepare(request: .init(kind: .readText, query: "delay start"),
                    binding: binding, selectedSource: invalid, source: source(identity: invalid),
                    issuedAt: 100, monotonicNow: 100)
            }
        }
    }

}
