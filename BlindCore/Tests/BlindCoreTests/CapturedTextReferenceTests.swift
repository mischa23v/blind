import XCTest
@testable import BlindCore

final class CapturedTextReferenceTests: XCTestCase {
    let fixtures = CapturedTextReferenceFixtures()
    func testWholeSourceAndBoundedAttributedCompletion() {
        var value = CapturedTextReference(); let selected = fixtures.selection(&value)
        let text = (1...90).map { "word\($0)" }.joined(separator: " ") + " Do not enter."
        XCTAssertTrue(value.install(fixtures.source(selected, text: text), for: selected, now: 100.1))
        XCTAssertEqual(value.phrases.map(\.originalSlice).joined(), text)
        XCTAssertTrue(value.phrases.allSatisfy { $0.text.hasPrefix("Captured text (uncertain):") && CompanionReferenceReading.wordCount($0.text) <= 30 })
        while let phrase = value.next(fixtures.context(value)) {
            XCTAssertTrue(value.begin(phrase, context: fixtures.context(value)))
            XCTAssertFalse(value.finish(id: UUID(), text: phrase.text, outcome: .completed, context: fixtures.context(value)))
            XCTAssertFalse(value.finish(id: phrase.id, text: phrase.text + "changed", outcome: .completed, context: fixtures.context(value)))
            XCTAssertTrue(value.finish(id: phrase.id, text: phrase.text, outcome: .completed, context: fixtures.context(value)))
        }
        XCTAssertEqual(value.completed, value.phrases.count)
    }
    func testLongArabicPreservesAllTextWithinMinimumBudget() {
        var value = CapturedTextReference(); let selected = fixtures.selection(&value)
        let text = Array(repeating: "تحذير لا تدخل المكان", count: 30).joined(separator: " ")
        XCTAssertTrue(value.install(fixtures.source(selected, text: text), for: selected, now: 100.1, arabic: true))
        XCTAssertEqual(value.phrases.map(\.originalSlice).joined(), text)
        XCTAssertTrue(value.phrases.allSatisfy { CompanionReferenceReading.wordCount($0.text) <= 30 })
    }
    func testStaleFutureOrientationAndReplacedSelection() {
        for (captured, now, orientation) in [(99.0,100.0,UInt32(6)), (101,100,6), (100,100.5,6), (100,100,1)] {
            var value = CapturedTextReference()
            XCTAssertNil(value.select(cameraEpoch: fixtures.epoch, generation: 3, requestID: fixtures.request, issuedAt: 100, capturedAt: captured, orientation: orientation, now: now))
        }
        var value = CapturedTextReference(); let old = fixtures.selection(&value); _ = fixtures.selection(&value)
        XCTAssertFalse(value.install(fixtures.source(old), for: old, now: 100.1))
        let current = value.selection!
        XCTAssertFalse(value.install(fixtures.source(current), for: current, now: 100.5))
        XCTAssertFalse(value.install(fixtures.source(current, media: .selectedPhoto), for: current, now: 100.1))
        XCTAssertTrue(value.install(fixtures.source(current), for: current, now: 100.1))
        XCTAssertFalse(value.install(fixtures.source(current), for: current, now: 100.2))
    }
    func testLifecycleRevocationIsTerminal() {
        for mode in 1..<9 {
            var value = CapturedTextReference(); let selected = fixtures.selection(&value)
            XCTAssertTrue(value.install(fixtures.source(selected), for: selected, now: 100.1))
            let bad = fixtures.context(value, now: mode == 1 ? 99 : 100.2,
                epoch: mode == 2 ? UUID() : nil, request: mode == 3 ? UUID() : nil, generation: mode == 4 ? 4 : 3,
                foreground: mode != 5, quiet: mode == 6, hazard: mode == 7, privateAudio: mode == 8)
            XCTAssertFalse(value.revalidate(bad)); XCTAssertFalse(value.revalidate(fixtures.context(value, now: 100.3)))
        }
    }
    func testAcquisitionExpiryRemainsTerminalButInstalledSourceIsNotLiveAuthority() {
        var acquiring = CapturedTextReference(); let pending = fixtures.selection(&acquiring)
        XCTAssertTrue(acquiring.awaitingAcquisition)
        XCTAssertFalse(acquiring.owns(pending, cameraEpoch: fixtures.epoch, generation: 3, now: 160))
        XCTAssertFalse(acquiring.install(fixtures.source(pending), for: pending, now: 160))
        var installed = CapturedTextReference(); let selected = fixtures.selection(&installed)
        XCTAssertTrue(installed.install(fixtures.source(selected), for: selected, now: 100.1))
        XCTAssertFalse(installed.awaitingAcquisition)
        XCTAssertTrue(installed.revalidate(fixtures.context(installed, now: 300)))
        XCTAssertFalse(installed.playbackCompleted)
        XCTAssertEqual(installed.source?.identity.media, .capturedText)
        XCTAssertTrue(installed.source!.blocks.allSatisfy { $0.evidence.kind == .historicalMemory })
    }
    func testInterruptionAndClearNeverCompleteNewSpeech() {
        var value = CapturedTextReference(); let selected = fixtures.selection(&value)
        XCTAssertTrue(value.install(fixtures.source(selected), for: selected, now: 100.1))
        let phrase = value.next(fixtures.context(value))!
        XCTAssertTrue(value.begin(phrase, context: fixtures.context(value)))
        XCTAssertFalse(value.finish(id: phrase.id, text: phrase.text, outcome: .interrupted, context: fixtures.context(value)))
        XCTAssertEqual(value.completed, 0); XCTAssertNil(value.next(fixtures.context(value)))
        value.clear(); let replacement = fixtures.selection(&value)
        XCTAssertTrue(value.install(fixtures.source(replacement), for: replacement, now: 100.1))
        XCTAssertFalse(value.finish(id: phrase.id, text: phrase.text, outcome: .completed, context: fixtures.context(value)))
        XCTAssertEqual(value.completed, 0)
    }
    func testReplacedSourceIdentityAndAdmissionRetry() {
        var value = CapturedTextReference(); let selected = fixtures.selection(&value)
        XCTAssertTrue(value.install(fixtures.source(selected), for: selected, now: 100.1))
        let phrase = value.next(fixtures.context(value))!
        XCTAssertTrue(value.begin(phrase, context: fixtures.context(value))); value.admissionRejected(phrase.id)
        XCTAssertEqual(value.next(fixtures.context(value)), phrase)
        let replaced = CapturedTextReference.Context(selection: selected, source: fixtures.source(selected).identity, cameraEpoch: fixtures.epoch, generation: 3, requestID: fixtures.request, now: 100.2)
        XCTAssertFalse(value.revalidate(replaced))
    }
}
