import XCTest
@testable import BlindCore

final class CapturedTextReferenceTests: XCTestCase {
    let epoch = UUID(), request = UUID()
    func selection(_ value: inout CapturedTextReference, now: Double = 100) -> CapturedTextReference.Selection {
        value.select(cameraEpoch: epoch, generation: 3, requestID: request,
            issuedAt: 100, capturedAt: 100, orientation: 6, now: now)!
    }
    func source(_ selected: CapturedTextReference.Selection, text: String = "Do not enter. Warning: keep away from the machinery.", media: CompanionReferenceIdentity.Media = .capturedText) -> CompanionReferenceSource {
        let identity = CompanionReferenceIdentity(sourceID: selected.id, revision: UUID(), sha256: String(repeating: "a", count: 64), media: media)
        let evidence = CompanionEvidence(id: "line", kind: .historicalMemory, text: text, source: identity.evidenceSource)
        return .init(identity: identity, toolResult: .init(status: .success, source: identity.evidenceSource, evidence: [evidence]),
            blocks: [.init(evidence: evidence, bodyUTF16Range: NSRange(location: 0, length: text.utf16.count), locator: "line-1")])
    }
    func context(_ value: CapturedTextReference, now: Double = 100.1, epoch other: UUID? = nil, request otherRequest: UUID? = nil, generation: UInt64 = 3,
                 foreground: Bool = true, quiet: Bool = false, hazard: Bool = false, privateAudio: Bool = false) -> CapturedTextReference.Context {
        .init(selection: value.selection!, source: value.source?.identity, cameraEpoch: other ?? epoch, generation: generation,
            requestID: otherRequest ?? request, now: now, foreground: foreground, quiet: quiet, hazard: hazard, privateAudioHeld: privateAudio)
    }
    func testWholeSourceAndBoundedAttributedCompletion() {
        var value = CapturedTextReference(); let selected = selection(&value)
        let text = (1...90).map { "word\($0)" }.joined(separator: " ") + " Do not enter."
        XCTAssertTrue(value.install(source(selected, text: text), for: selected, now: 100.1))
        XCTAssertEqual(value.phrases.map(\.originalSlice).joined(), text)
        XCTAssertTrue(value.phrases.allSatisfy { $0.text.hasPrefix("Captured text (uncertain):") && CompanionReferenceReading.wordCount($0.text) <= 30 })
        while let phrase = value.next(context(value)) {
            XCTAssertTrue(value.begin(phrase, context: context(value)))
            XCTAssertFalse(value.finish(id: UUID(), text: phrase.text, outcome: .completed, context: context(value)))
            XCTAssertFalse(value.finish(id: phrase.id, text: phrase.text + "changed", outcome: .completed, context: context(value)))
            XCTAssertTrue(value.finish(id: phrase.id, text: phrase.text, outcome: .completed, context: context(value)))
        }
        XCTAssertEqual(value.completed, value.phrases.count)
    }
    func testLongArabicPreservesAllTextWithinMinimumBudget() {
        var value = CapturedTextReference(); let selected = selection(&value)
        let text = Array(repeating: "تحذير لا تدخل المكان", count: 30).joined(separator: " ")
        XCTAssertTrue(value.install(source(selected, text: text), for: selected, now: 100.1, arabic: true))
        XCTAssertEqual(value.phrases.map(\.originalSlice).joined(), text)
        XCTAssertTrue(value.phrases.allSatisfy { CompanionReferenceReading.wordCount($0.text) <= 30 })
    }
    func testStaleFutureOrientationAndReplacedSelection() {
        for (captured, now, orientation) in [(99.0,100.0,UInt32(6)), (101,100,6), (100,100.5,6), (100,100,1)] {
            var value = CapturedTextReference()
            XCTAssertNil(value.select(cameraEpoch: epoch, generation: 3, requestID: request, issuedAt: 100, capturedAt: captured, orientation: orientation, now: now))
        }
        var value = CapturedTextReference(); let old = selection(&value); _ = selection(&value)
        XCTAssertFalse(value.install(source(old), for: old, now: 100.1))
        let current = value.selection!
        XCTAssertFalse(value.install(source(current), for: current, now: 100.5))
        XCTAssertFalse(value.install(source(current, media: .selectedPhoto), for: current, now: 100.1))
        XCTAssertTrue(value.install(source(current), for: current, now: 100.1))
        XCTAssertFalse(value.install(source(current), for: current, now: 100.2))
    }
    func testLifecycleRevocationIsTerminal() {
        for mode in 1..<9 {
            var value = CapturedTextReference(); let selected = selection(&value)
            XCTAssertTrue(value.install(source(selected), for: selected, now: 100.1))
            let bad = context(value, now: mode == 1 ? 99 : 100.2,
                epoch: mode == 2 ? UUID() : nil, request: mode == 3 ? UUID() : nil, generation: mode == 4 ? 4 : 3,
                foreground: mode != 5, quiet: mode == 6, hazard: mode == 7, privateAudio: mode == 8)
            XCTAssertFalse(value.revalidate(bad)); XCTAssertFalse(value.revalidate(context(value, now: 100.3)))
        }
    }
    func testAcquisitionExpiryRemainsTerminalButInstalledSourceIsNotLiveAuthority() {
        var acquiring = CapturedTextReference(); let pending = selection(&acquiring)
        XCTAssertTrue(acquiring.awaitingAcquisition)
        XCTAssertFalse(acquiring.owns(pending, cameraEpoch: epoch, generation: 3, now: 160))
        XCTAssertFalse(acquiring.install(source(pending), for: pending, now: 160))
        var installed = CapturedTextReference(); let selected = selection(&installed)
        XCTAssertTrue(installed.install(source(selected), for: selected, now: 100.1))
        XCTAssertFalse(installed.awaitingAcquisition)
        XCTAssertTrue(installed.revalidate(context(installed, now: 300)))
        XCTAssertFalse(installed.playbackCompleted)
        XCTAssertEqual(installed.source?.identity.media, .capturedText)
        XCTAssertTrue(installed.source!.blocks.allSatisfy { $0.evidence.kind == .historicalMemory })
    }
    func testInterruptionAndClearNeverCompleteNewSpeech() {
        var value = CapturedTextReference(); let selected = selection(&value)
        XCTAssertTrue(value.install(source(selected), for: selected, now: 100.1))
        let phrase = value.next(context(value))!
        XCTAssertTrue(value.begin(phrase, context: context(value)))
        XCTAssertFalse(value.finish(id: phrase.id, text: phrase.text, outcome: .interrupted, context: context(value)))
        XCTAssertEqual(value.completed, 0); XCTAssertNil(value.next(context(value)))
        value.clear(); let replacement = selection(&value)
        XCTAssertTrue(value.install(source(replacement), for: replacement, now: 100.1))
        XCTAssertFalse(value.finish(id: phrase.id, text: phrase.text, outcome: .completed, context: context(value)))
        XCTAssertEqual(value.completed, 0)
    }
    func testReplacedSourceIdentityAndAdmissionRetry() {
        var value = CapturedTextReference(); let selected = selection(&value)
        XCTAssertTrue(value.install(source(selected), for: selected, now: 100.1))
        let phrase = value.next(context(value))!
        XCTAssertTrue(value.begin(phrase, context: context(value))); value.admissionRejected(phrase.id)
        XCTAssertEqual(value.next(context(value)), phrase)
        let replaced = CapturedTextReference.Context(selection: selected, source: source(selected).identity, cameraEpoch: epoch, generation: 3, requestID: request, now: 100.2)
        XCTAssertFalse(value.revalidate(replaced))
    }
}
