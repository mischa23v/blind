import XCTest
@testable import BlindCore

final class CapturedTextPlaybackReceiptTests: XCTestCase {
    func fixture() -> (CapturedTextReference, CapturedTextReference.Context) {
        var value = CapturedTextReference(); let epoch = UUID(), request = UUID()
        let selected = value.select(cameraEpoch: epoch, generation: 9, requestID: request, issuedAt: 100, capturedAt: 100, orientation: 6, now: 100)!
        let identity = CompanionReferenceIdentity(sourceID: selected.id, revision: UUID(), sha256: String(repeating: "a", count: 64), media: .capturedText)
        let text = "Authored uncertain source text."
        let item = CompanionEvidence(id: "line", kind: .historicalMemory, text: text, source: identity.evidenceSource)
        let source = CompanionReferenceSource(identity: identity, toolResult: .init(status: .success, source: identity.evidenceSource, evidence: [item]),
            blocks: [.init(evidence: item, bodyUTF16Range: NSRange(location: 0, length: text.utf16.count), locator: "line")])
        XCTAssertTrue(value.install(source, for: selected, now: 100.1))
        return (value, .init(selection: selected, source: identity, cameraEpoch: epoch, generation: 9, requestID: request, now: 170))
    }
    func testCompletedReceiptSurvivesClearOnlyAfterExactCompletion() throws {
        var (value, context) = fixture(); let source = value.source!.identity
        let phrase = try XCTUnwrap(value.next(context)); XCTAssertTrue(value.begin(phrase, context: context))
        XCTAssertFalse(value.finish(id: UUID(), text: phrase.text, outcome: .completed, context: context))
        XCTAssertFalse(value.playbackCompleted)
        XCTAssertTrue(value.finish(id: phrase.id, text: phrase.text, outcome: .completed, context: context))
        let receipt = try XCTUnwrap(value.clear())
        XCTAssertEqual(receipt.outcome, .completed)
        XCTAssertEqual(receipt.completedPhraseCount, receipt.totalPhraseCount)
        XCTAssertEqual(receipt.sourceID, source.sourceID); XCTAssertEqual(receipt.revision, source.revision)
        XCTAssertEqual(receipt.requestID, context.requestID); XCTAssertEqual(receipt.sessionGeneration, 9)
        XCTAssertNil(value.source); XCTAssertNil(value.clear(), "A second clear cannot remint or overwrite terminal receipt")
        XCTAssertEqual(receipt.outcome, .completed, "Retained receipt is independent of cleared controller")
    }
    func testZeroSourceCannotMintReceiptAndPartialSourceIsCancelled() throws {
        var empty = CapturedTextReference(); XCTAssertNil(empty.clear())
        let epoch = UUID(), request = UUID()
        _ = empty.select(cameraEpoch: epoch, generation: 1, requestID: request, issuedAt: 100, capturedAt: 100, orientation: 6, now: 100)
        XCTAssertNil(empty.clear(), "Acquisition alone is not a playback result")
        var reading = CapturedTextReference()
        let selected = reading.select(cameraEpoch: epoch, generation: 1, requestID: request, issuedAt: 100, capturedAt: 100, orientation: 6, now: 100)!
        let identity = CompanionReferenceIdentity(sourceID: selected.id, revision: UUID(), sha256: String(repeating: "a", count: 64), media: .capturedText)
        let text = (1...100).map { "word\($0)" }.joined(separator: " ")
        let item = CompanionEvidence(id: "page", kind: .historicalMemory, text: text, source: identity.evidenceSource)
        XCTAssertTrue(reading.install(.init(identity: identity, toolResult: .init(status: .success, source: identity.evidenceSource, evidence: [item]),
            blocks: [.init(evidence: item, bodyUTF16Range: NSRange(location: 0, length: text.utf16.count), locator: "page")]), for: selected, now: 100.1))
        let context = CapturedTextReference.Context(selection: selected, source: identity, cameraEpoch: epoch, generation: 1, requestID: request, now: 101)
        let phrase = try XCTUnwrap(reading.next(context)); XCTAssertTrue(reading.begin(phrase, context: context))
        XCTAssertTrue(reading.finish(id: phrase.id, text: phrase.text, outcome: .completed, context: context))
        let partial = try XCTUnwrap(reading.clear())
        XCTAssertEqual(partial.outcome, .cancelled); XCTAssertEqual(partial.completedPhraseCount, 1)
        XCTAssertLessThan(partial.completedPhraseCount, partial.totalPhraseCount)
    }
    func testCancellationAndLateCallbackCannotBecomeNewSourceCompletion() throws {
        var (old, oldContext) = fixture()
        let phrase = try XCTUnwrap(old.next(oldContext)); XCTAssertTrue(old.begin(phrase, context: oldContext))
        let cancelled = try XCTUnwrap(old.clear())
        XCTAssertEqual(cancelled.outcome, .cancelled); XCTAssertEqual(cancelled.completedPhraseCount, 0)
        var (new, newContext) = fixture()
        XCTAssertFalse(new.finish(id: phrase.id, text: phrase.text, outcome: .completed, context: newContext))
        let result = try XCTUnwrap(new.clear())
        XCTAssertEqual(result.outcome, .cancelled); XCTAssertNotEqual(result.sourceID, cancelled.sourceID)
        XCTAssertEqual(result.completedPhraseCount, 0)
    }
}
