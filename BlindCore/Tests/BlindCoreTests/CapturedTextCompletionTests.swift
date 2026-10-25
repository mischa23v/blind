import XCTest
@testable import BlindCore

/// Authored text and simulated real-callback outcomes; no OCR/audio accuracy claim.
final class CapturedTextCompletionTests: XCTestCase {
    let epoch = UUID(), request = UUID()
    func installed(words: Int = 100) -> CapturedTextReference {
        var value = CapturedTextReference()
        let selection = value.select(cameraEpoch: epoch, generation: 1, requestID: request,
            issuedAt: 100, capturedAt: 100, orientation: 6, now: 100)!
        let identity = CompanionReferenceIdentity(sourceID: selection.id, revision: UUID(), sha256: String(repeating: "a", count: 64), media: .capturedText)
        let text = (1...words).map { "word\($0)" }.joined(separator: " ")
        let evidence = CompanionEvidence(id: "page", kind: .historicalMemory, text: text, source: identity.evidenceSource)
        let source = CompanionReferenceSource(identity: identity,
            toolResult: .init(status: .success, source: identity.evidenceSource, evidence: [evidence]),
            blocks: [.init(evidence: evidence, bodyUTF16Range: NSRange(location: 0, length: text.utf16.count), locator: "page")])
        XCTAssertTrue(value.install(source, for: selection, now: 100.1))
        return value
    }
    func context(_ value: CapturedTextReference, now: Double, epoch other: UUID? = nil,
                 foreground: Bool = true, hazard: Bool = false, privateAudio: Bool = false) -> CapturedTextReference.Context {
        .init(selection: value.selection!, source: value.source?.identity, cameraEpoch: other ?? epoch,
            generation: 1, requestID: request, now: now, foreground: foreground,
            hazard: hazard, privateAudioHeld: privateAudio)
    }
    func testHundredWordPageCompletesAtMinimumBudgetWithoutExpiringUnreadSource() throws {
        var reading = installed(), budget = NarrationBudget()
        var now = 100.2, spoken = "", iterations = 0
        while reading.completed < reading.phrases.count && iterations < 20 {
            iterations += 1
            let phrase = try XCTUnwrap(reading.next(context(reading, now: now)), "Unread immutable source must survive budget waiting")
            let words = CompanionReferenceReading.wordCount(phrase.text)
            if budget.allowance(limit: 30, now: now) < words { now += 60; continue }
            XCTAssertTrue(budget.charge(words: words, limit: 30, now: now))
            XCTAssertTrue(reading.begin(phrase, context: context(reading, now: now)))
            now += 1
            XCTAssertTrue(reading.finish(id: phrase.id, text: phrase.text, outcome: .completed, context: context(reading, now: now)))
            spoken += phrase.originalSlice
        }
        XCTAssertGreaterThan(now, 160)
        XCTAssertEqual(reading.completed, reading.phrases.count)
        XCTAssertEqual(spoken, (1...100).map { "word\($0)" }.joined(separator: " "))
    }
    func testSlowExactSpeechCallbackAfterSixtySecondsCompletesOnlyItsPhrase() throws {
        var reading = installed(words: 12)
        let phrase = try XCTUnwrap(reading.next(context(reading, now: 100.2)))
        XCTAssertTrue(reading.begin(phrase, context: context(reading, now: 100.2)))
        XCTAssertEqual(reading.completed, 0)
        XCTAssertTrue(reading.revalidate(context(reading, now: 170)))
        XCTAssertEqual(reading.completed, 0, "Time passing is not playback completion")
        XCTAssertFalse(reading.finish(id: UUID(), text: phrase.text, outcome: .completed, context: context(reading, now: 170)))
        XCTAssertFalse(reading.finish(id: phrase.id, text: phrase.text + " changed", outcome: .completed, context: context(reading, now: 170)))
        XCTAssertTrue(reading.finish(id: phrase.id, text: phrase.text, outcome: .completed, context: context(reading, now: 170)))
        XCTAssertEqual(reading.completed, reading.phrases.count)
    }
    func testInstalledSourceStillWithdrawsOnExplicitLifecycleLoss() throws {
        for mode in 0..<5 {
            var reading = installed(words: 12)
            let phrase = try XCTUnwrap(reading.next(context(reading, now: 100.2)))
            XCTAssertTrue(reading.begin(phrase, context: context(reading, now: 100.2)))
            let bad = context(reading, now: 170, epoch: mode == 0 ? UUID() : nil,
                foreground: mode != 1, hazard: mode == 2, privateAudio: mode == 3)
            if mode == 4 {
                XCTAssertFalse(reading.finish(id: phrase.id, text: phrase.text, outcome: .interrupted, context: bad))
            } else { XCTAssertFalse(reading.revalidate(bad)) }
            XCTAssertEqual(reading.completed, 0)
            XCTAssertFalse(reading.finish(id: phrase.id, text: phrase.text, outcome: .completed, context: context(reading, now: 171)))
        }
    }
}
