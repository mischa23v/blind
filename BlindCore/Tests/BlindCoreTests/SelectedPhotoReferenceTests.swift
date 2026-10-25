import XCTest
@testable import BlindCore

final class SelectedPhotoReferenceTests: XCTestCase {
    let view = UUID()
    func selected(_ state: inout SelectedPhotoReference, question: String = "Read this photo", now: Double = 10) -> SelectedPhotoReference.Selection {
        state.select(viewID: view, generation: 2, question: question, now: now)!
    }
    func source(_ selection: SelectedPhotoReference.Selection, texts: [String] = ["Do not wash above 30 degrees. Never bleach. Keep all warnings."]) -> CompanionReferenceSource {
        let identity = CompanionReferenceIdentity(sourceID: selection.id, revision: UUID(), sha256: String(repeating: "a", count: 64), media: .selectedPhoto)
        let evidence = texts.enumerated().map { CompanionEvidence(id: "block-\($0.offset)", kind: .historicalMemory, text: $0.element, source: identity.evidenceSource) }
        return .init(identity: identity, toolResult: .init(status: .success, source: identity.evidenceSource, evidence: evidence),
            blocks: evidence.enumerated().map { .init(evidence: $0.element, bodyUTF16Range: NSRange(location: 0, length: $0.element.text.utf16.count), locator: "block \($0.offset)") })
    }
    func context(_ state: SelectedPhotoReference, now: Double = 11) -> SelectedPhotoReference.Context {
        .init(selection: state.selection!, source: state.source?.identity, viewID: view, generation: 2, question: state.selection!.question, now: now)
    }
    func ready(_ text: String = "Do not wash above 30 degrees. Never bleach. Keep all warnings.") -> SelectedPhotoReference {
        var state = SelectedPhotoReference(); let selection = selected(&state)
        XCTAssertTrue(state.install(source(selection, texts: [text]), for: selection, now: 11)); return state
    }
    func testPhotoQuestionWinsBeforeMovementInterpretation() {
        for q in ["Where is my bag in this picture?", "Describe a photo from my library", "Is the cooker in the selected photo hot?", "What does this image say?", "ما النص في هذه الصورة؟"] { XCTAssertTrue(SelectedPhotoIntent.matches(q), q) }
        for q in ["Where is my bag?", "Take me to the kitchen", "Read the sign in front of me", "What time is it?"] { XCTAssertFalse(SelectedPhotoIntent.matches(q), q) }
    }
    func testOwnershipStartsBeforeExtraction() {
        var s = SelectedPhotoReference(); let selection = selected(&s)
        XCTAssertNil(s.source); XCTAssertTrue(s.owns(selection, viewID: view, generation: 2, now: 10)); XCTAssertNil(s.next(context(s)))
    }
    func testLateLoadCannotReplaceNewPhoto() {
        var s = SelectedPhotoReference(); let old = selected(&s); let new = selected(&s, now: 11)
        XCTAssertFalse(s.install(source(old), for: old, now: 12)); XCTAssertTrue(s.install(source(new), for: new, now: 12)); XCTAssertEqual(s.source?.identity.sourceID, new.id)
    }
    func testDismissAndPrivacyClearRejectLateLoad() {
        for _ in 0..<2 { var s = SelectedPhotoReference(); let old = selected(&s); s.clear(); XCTAssertFalse(s.install(source(old), for: old, now: 11)) }
    }
    func testWrongViewAndSessionCannotOwnLoad() {
        var s = SelectedPhotoReference(); let selection = selected(&s)
        XCTAssertFalse(s.owns(selection, viewID: nil, generation: 2, now: 11)); XCTAssertFalse(s.owns(selection, viewID: UUID(), generation: 2, now: 11)); XCTAssertFalse(s.owns(selection, viewID: view, generation: 3, now: 11))
    }
    func testFullOCRIncludingFourthLineAndLateQualifierPreserved() {
        var s = SelectedPhotoReference(); let selection = selected(&s)
        let texts = ["First line", "Second line", "Third line", String(repeating: "carefully read all instructions ", count: 80) + "DO NOT use on silk. Never mix bleach."]
        XCTAssertTrue(s.install(source(selection, texts: texts), for: selection, now: 11))
        XCTAssertEqual(s.phrases.map(\.originalSlice).joined(), texts.joined())
        XCTAssertTrue(s.phrases.last!.text.contains("Never mix bleach"))
        XCTAssertTrue(s.phrases.allSatisfy { CompanionReferenceReading.wordCount($0.text) <= 35 && $0.text.hasPrefix("Photo reference (uncertain):") })
        XCTAssertTrue(s.source!.toolResult.evidence.allSatisfy { $0.kind == .historicalMemory && !$0.isCurrent(at: Date()) })
    }
    func testArabicQualifiersAreNotClipped() {
        var s = SelectedPhotoReference(); let selection = selected(&s)
        let text = String(repeating: "تحذير لا تستخدم هذا المنتج ", count: 50) + "ولا تخلطه بالمبيض مطلقاً."
        XCTAssertTrue(s.install(source(selection, texts: [text]), for: selection, now: 11, arabic: true))
        XCTAssertEqual(s.phrases.map(\.originalSlice).joined(), text)
        XCTAssertTrue(s.phrases.allSatisfy { CompanionReferenceReading.wordCount($0.text) <= 35 })
    }
    func testOversizedCompleteSourceRejectedNotTrimmed() {
        var s = SelectedPhotoReference(); let selection = selected(&s)
        XCTAssertFalse(s.install(source(selection, texts: [String(repeating: "warning ", count: 40_000)]), for: selection, now: 11)); XCTAssertTrue(s.phrases.isEmpty)
    }
    func testWrongSourceIdentifierRejected() {
        var s = SelectedPhotoReference(); let selection = selected(&s)
        var other = SelectedPhotoReference(); let foreign = selected(&other)
        XCTAssertFalse(s.install(source(foreign), for: selection, now: 11))
    }
    func testOriginalDeadlineIncludesTransferAndDoesNotRenew() {
        var s = SelectedPhotoReference(); let selection = selected(&s)
        XCTAssertTrue(s.install(source(selection), for: selection, now: 69.99)); XCTAssertNil(s.next(context(s, now: 70))); XCTAssertTrue(s.withdrawn)
        XCTAssertFalse(s.install(source(selection), for: selection, now: 71))
    }
    func testRollbackAndNonfiniteClocksRejected() {
        for now in [9.0, .nan, .infinity] { var s = ready(); XCTAssertNil(s.next(context(s, now: now))); XCTAssertTrue(s.withdrawn) }
    }
    func testEveryDeliveryRechecksViewQuestionSessionAndSource() {
        let variants: [(SelectedPhotoReference.Context) -> SelectedPhotoReference.Context] = [
            { .init(selection: $0.selection, source: $0.source, viewID: nil, generation: 2, question: $0.question, now: 12) },
            { .init(selection: $0.selection, source: $0.source, viewID: $0.viewID, generation: 3, question: $0.question, now: 12) },
            { .init(selection: $0.selection, source: $0.source, viewID: $0.viewID, generation: 2, question: "Where is it now?", now: 12) },
            { .init(selection: $0.selection, source: nil, viewID: $0.viewID, generation: 2, question: $0.question, now: 12) }
        ]
        for change in variants { var s = ready(); XCTAssertNil(s.next(change(context(s)))); XCTAssertTrue(s.withdrawn) }
    }
    func testQuietHazardBackgroundAndAudioLossWithdrawCannotResume() {
        for flag in 0..<4 {
            var s = ready(); var c = context(s)
            switch flag { case 0: c.quiet = true; case 1: c.hazard = true; case 2: c.foreground = false; default: c.privateAudioHeld = true }
            XCTAssertNil(s.next(c)); XCTAssertNil(s.next(context(s, now: 12))); XCTAssertTrue(s.withdrawn)
        }
    }
    func testActualCompletionRequiredBeforeNextPhrase() {
        var s = ready(String(repeating: "Never remove any warning ", count: 30)); let c = context(s); let p = s.next(c)!
        XCTAssertTrue(s.begin(p, context: c)); XCTAssertNil(s.next(c)); XCTAssertEqual(s.completed, 0)
        XCTAssertFalse(s.finish(id: UUID(), text: p.text, outcome: .completed, context: c)); XCTAssertEqual(s.completed, 0)
        XCTAssertFalse(s.finish(id: p.id, text: "different", outcome: .completed, context: c)); XCTAssertEqual(s.completed, 0)
        XCTAssertTrue(s.finish(id: p.id, text: p.text, outcome: .completed, context: c)); XCTAssertEqual(s.completed, 1); XCTAssertNotEqual(s.next(c)?.id, p.id)
    }
    func testInterruptedCallbackAndLateCompletionCannotResume() {
        var s = ready(); let c = context(s); let p = s.next(c)!; XCTAssertTrue(s.begin(p, context: c))
        XCTAssertFalse(s.finish(id: p.id, text: p.text, outcome: .interrupted, context: c)); XCTAssertNil(s.next(c))
        XCTAssertFalse(s.finish(id: p.id, text: p.text, outcome: .completed, context: c)); XCTAssertEqual(s.completed, 0)
    }
    func testSourceReplacementCannotCompleteOldSpeech() {
        var s = ready(); let oldContext = context(s); let phrase = s.next(oldContext)!; XCTAssertTrue(s.begin(phrase, context: oldContext))
        let replacement = selected(&s, now: 12); XCTAssertTrue(s.install(source(replacement), for: replacement, now: 12))
        XCTAssertFalse(s.finish(id: phrase.id, text: phrase.text, outcome: .completed, context: context(s, now: 12))); XCTAssertEqual(s.completed, 0)
    }
    func testGenericLabelsNeverProduceHeatIdentityCurrencyOwnershipOrDirections() {
        XCTAssertEqual(SelectedPhotoReference.neutralCategories(["cat", "hot", "mother", "100 riyals", "your bag", "turn left", "bedroom", "cat", "dog"]), ["cat", "dog"])
    }
    func testAdmissionRejectionIsNotCompletionAndDoesNotRenewDeadline() {
        var s = ready(); let c = context(s); let p = s.next(c)!; XCTAssertTrue(s.begin(p, context: c)); s.admissionRejected(p.id)
        XCTAssertEqual(s.next(c), p); XCTAssertEqual(s.completed, 0); XCTAssertNil(s.next(context(s, now: 70)))
    }
}
