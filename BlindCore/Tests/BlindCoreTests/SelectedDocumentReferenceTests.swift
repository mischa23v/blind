import XCTest
@testable import BlindCore

/// Plain value fixtures, never XCTestCase construction.
private enum DocumentFixture {
    static func identity(media: CompanionReferenceIdentity.Media = .selectedDocument, model: String? = nil) -> CompanionReferenceIdentity {
        .init(sourceID: UUID(), revision: UUID(), sha256: String(repeating: "a", count: 64), media: media, exactModel: model)
    }
    static func selected() -> SelectedDocumentReference {
        var value = SelectedDocumentReference()
        _ = value.select(identity: identity(), pageCount: 3, generation: 7, now: 10)
        return value
    }
    static func requested() -> SelectedDocumentReference {
        var value = selected(); _ = value.beginPage(pageNumber: 2, requestID: UUID(), now: 20)
        return value
    }
    static func page(_ value: SelectedDocumentReference, text: String = "Never remove this warning. Do not use bleach.") -> SelectedDocumentReference.Page {
        .init(identity: value.selection!.identity, pageNumber: value.request!.pageNumber, pageLabel: "ii", text: text)
    }
    static func ready(text: String = "Never remove this warning. Do not use bleach.", arabic: Bool = false) -> SelectedDocumentReference {
        var value = requested()
        _ = value.install(page: page(value, text: text), for: value.request!, now: 21, arabic: arabic)
        return value
    }
    static func context(_ value: SelectedDocumentReference, now: Double = 22, generation: UInt64 = 7,
                        requestID: UUID? = nil, source: CompanionReferenceIdentity? = nil) -> SelectedDocumentReference.Context {
        .init(selection: value.selection!, request: value.request!, source: source ?? value.selection!.identity,
              generation: generation, requestID: requestID ?? value.request!.requestID, now: now)
    }
}

final class SelectedDocumentReferenceTests: XCTestCase {
    func testSelectionDoesNotReadOrOwnAttention() {
        let s = DocumentFixture.selected()
        XCTAssertTrue(s.isPrivate); XCTAssertNil(s.request); XCTAssertNil(s.page)
        XCTAssertFalse(s.ownsAttention); XCTAssertFalse(s.playbackCompleted)
    }
    func testSelectedDocumentRejectsManualModelAuthorityAndMalformedHash() {
        for identity in [DocumentFixture.identity(model: "washer-42"), DocumentFixture.identity(media: .manual, model: "washer-42"),
                         CompanionReferenceIdentity(sourceID: UUID(), revision: UUID(), sha256: "not-bytes", media: .selectedDocument)] {
            var s = SelectedDocumentReference()
            XCTAssertNil(s.select(identity: identity, pageCount: 1, generation: 7, now: 10))
        }
    }
    func testIdentityValidationRejectsModelOnDocumentEvenInOldReader() {
        XCTAssertFalse(DocumentFixture.identity(model: "ABC").isValid)
        XCTAssertTrue(DocumentFixture.identity().isValid)
        XCTAssertTrue(DocumentFixture.identity(media: .manual, model: "ABC").isValid)
    }
    func testPageCountAndNumberBounds() {
        for count in [0, -1, SelectedDocumentReference.maximumPageCount + 1] {
            var s = SelectedDocumentReference()
            XCTAssertNil(s.select(identity: DocumentFixture.identity(), pageCount: count, generation: 7, now: 10))
        }
        var s = DocumentFixture.selected()
        for n in [-1, 0, 4] { XCTAssertNil(s.beginPage(pageNumber: n, requestID: UUID(), now: 11)) }
        XCTAssertNil(s.request)
    }
    func testSelectionWaitDoesNotStartReadDeadline() {
        var s = DocumentFixture.selected()
        let request = s.beginPage(pageNumber: 1, requestID: UUID(), now: 1000)!
        XCTAssertEqual(request.issuedAt, 1000)
        XCTAssertTrue(s.install(page: DocumentFixture.page(s), for: request, now: 1059.99))
    }
    func testOriginalAcquisitionDeadlineIsStrictAndNeverRenews() {
        for time in [80.0, 80.01, 1000] {
            var s = DocumentFixture.requested(); let request = s.request!
            XCTAssertFalse(s.install(page: DocumentFixture.page(s), for: request, now: time))
            XCTAssertNil(s.page); XCTAssertTrue(s.phrases.isEmpty)
        }
        var s = DocumentFixture.requested()
        XCTAssertTrue(s.install(page: DocumentFixture.page(s), for: s.request!, now: 79.999))
        XCTAssertNotNil(s.next(DocumentFixture.context(s, now: 1000)))
    }
    func testLongBudgetWaitAndSlowCallbackDoNotExpireInstalledPage() {
        var s = DocumentFixture.ready(text: String(repeating: "Keep every qualifier and warning. ", count: 50))
        let originalCount = s.phrases.count
        var now = 22.0
        while !s.playbackCompleted {
            now += 61
            let c = DocumentFixture.context(s, now: now), p = s.next(DocumentFixture.context(s, now: now))!
            XCTAssertTrue(s.begin(p, context: c)); XCTAssertNil(s.next(c))
            XCTAssertTrue(s.finish(id: p.id, text: p.text, outcome: .completed, context: DocumentFixture.context(s, now: now + 30)))
            now += 30
        }
        XCTAssertEqual(s.completed, originalCount); XCTAssertFalse(s.ownsAttention)
    }
    func testEveryEnglishArabicSlicePreservesOriginalBytesAndMinimumBudget() {
        for (text, arabic) in [(String(repeating: "  Warning: never discard qualifiers.\n", count: 90) + "Do not bleach.", false),
                              (String(repeating: "تحذير: لا تحذف أي قيد مهم.\n", count: 90) + "لا تستخدم المبيض مطلقاً.", true)] {
            let s = DocumentFixture.ready(text: text, arabic: arabic)
            XCTAssertNotNil(s.page)
            XCTAssertTrue(s.phrases.map(\.originalSlice).joined().utf8.elementsEqual(text.utf8))
            XCTAssertTrue(s.phrases.allSatisfy { CompanionReferenceReading.wordCount($0.text) <= 30 })
            XCTAssertTrue(s.phrases.allSatisfy { $0.text.contains("2") })
        }
    }
    func testWholeOversizedEmptyAndOversizedLabelAreRejected() {
        var s = DocumentFixture.requested()
        for text in ["", " \n\t", String(repeating: "a", count: SelectedDocumentReference.maximumPageUTF8Bytes + 1)] {
            XCTAssertFalse(s.install(page: DocumentFixture.page(s, text: text), for: s.request!, now: 21))
        }
        let oversizedLabel = SelectedDocumentReference.Page(identity: s.selection!.identity, pageNumber: 2,
            pageLabel: String(repeating: "x", count: 129), text: "hello")
        XCTAssertFalse(s.install(page: oversizedLabel, for: s.request!, now: 21)); XCTAssertNil(s.page)
    }
    func testWrongSourcePageAndReinstallationRejected() {
        var s = DocumentFixture.requested()
        let wrongSource = SelectedDocumentReference.Page(identity: DocumentFixture.identity(), pageNumber: 2, pageLabel: "2", text: "wrong")
        let wrongPage = SelectedDocumentReference.Page(identity: s.selection!.identity, pageNumber: 1, pageLabel: "1", text: "wrong")
        XCTAssertFalse(s.install(page: wrongSource, for: s.request!, now: 21))
        XCTAssertFalse(s.install(page: wrongPage, for: s.request!, now: 21))
        XCTAssertTrue(s.install(page: DocumentFixture.page(s), for: s.request!, now: 21))
        XCTAssertFalse(s.install(page: DocumentFixture.page(s, text: "replacement"), for: s.request!, now: 22))
    }
    func testReplacementAndClearRejectLateNativeResult() {
        var s = DocumentFixture.requested(); let old = s.request!, page = DocumentFixture.page(s)
        _ = s.beginPage(pageNumber: 1, requestID: UUID(), now: 21)
        XCTAssertFalse(s.install(page: page, for: old, now: 22))
        s.clear(); XCTAssertFalse(s.install(page: page, for: old, now: 23)); XCTAssertNil(s.selection)
    }
    func testOnlyExactCallbacksAdvanceAndOnsetDoesNotComplete() {
        var s = DocumentFixture.ready(); let c = DocumentFixture.context(s), p = s.next(DocumentFixture.context(s))!
        XCTAssertFalse(s.finish(id: p.id, text: p.text, outcome: .completed, context: c))
        XCTAssertTrue(s.begin(p, context: c)); XCTAssertNil(s.lastStartedOrCompleted)
        XCTAssertFalse(s.started(id: UUID(), text: p.text, context: c))
        XCTAssertFalse(s.started(id: p.id, text: "other", context: c))
        XCTAssertTrue(s.started(id: p.id, text: p.text, context: c)); XCTAssertEqual(s.completed, 0)
        XCTAssertFalse(s.finish(id: UUID(), text: p.text, outcome: .completed, context: c))
        XCTAssertFalse(s.finish(id: p.id, text: "other", outcome: .completed, context: c))
        XCTAssertTrue(s.finish(id: p.id, text: p.text, outcome: .completed, context: c))
        XCTAssertFalse(s.finish(id: p.id, text: p.text, outcome: .completed, context: c)); XCTAssertEqual(s.completed, 1)
    }
    func testAdmissionRejectionPreservesUnreadCursor() {
        var s = DocumentFixture.ready(); let c = DocumentFixture.context(s), p = s.next(DocumentFixture.context(s))!
        XCTAssertTrue(s.begin(p, context: c)); s.admissionRejected(UUID()); XCTAssertNotNil(s.pending)
        s.admissionRejected(p.id); XCTAssertNil(s.pending); XCTAssertEqual(s.completed, 0)
        XCTAssertEqual(s.next(c), p); XCTAssertNil(s.lastStartedOrCompleted)
    }
    func testInterruptedCallbackTerminalAndNewRequestCannotReviveSelection() {
        var s = DocumentFixture.ready(); let c = DocumentFixture.context(s), p = s.next(DocumentFixture.context(s))!
        XCTAssertTrue(s.begin(p, context: c))
        XCTAssertFalse(s.finish(id: p.id, text: p.text, outcome: .interrupted, context: c))
        XCTAssertTrue(s.withdrawn); XCTAssertNil(s.next(c)); XCTAssertFalse(s.ownsAttention)
        XCTAssertNil(s.beginPage(pageNumber: 1, requestID: UUID(), now: 23))
        XCTAssertFalse(s.finish(id: p.id, text: p.text, outcome: .completed, context: c))
    }
    func testPrivacyForegroundQuietHazardSessionRequestAndSourceLossTerminal() {
        for flag in 0..<7 {
            var s = DocumentFixture.ready()
            var c = DocumentFixture.context(s, generation: flag == 4 ? 8 : 7,
                requestID: flag == 5 ? UUID() : nil, source: flag == 6 ? DocumentFixture.identity() : nil)
            switch flag { case 0: c.foreground = false; case 1: c.quiet = true; case 2: c.hazard = true; case 3: c.privateAudioHeld = true; default: break }
            XCTAssertNil(s.next(c)); XCTAssertTrue(s.withdrawn)
            XCTAssertNil(s.next(DocumentFixture.context(s, now: 23)))
        }
    }
    func testInvalidClockAndRollbackWithdraw() {
        for now in [20.0, Double.nan, Double.infinity, -1] {
            var s = DocumentFixture.ready(); XCTAssertFalse(s.revalidate(DocumentFixture.context(s, now: now)))
            XCTAssertTrue(s.withdrawn)
        }
    }
    func testExplicitNextPageGetsNewRequestAndNoAutomaticPage() {
        var s = DocumentFixture.ready(); let prior = s.request!, c = DocumentFixture.context(s)
        let p = s.next(c)!; XCTAssertTrue(s.begin(p, context: c))
        XCTAssertTrue(s.finish(id: p.id, text: p.text, outcome: .completed, context: c))
        XCTAssertNil(s.next(c)); XCTAssertEqual(s.request, prior)
        let next = s.beginPage(pageNumber: 3, requestID: UUID(), now: 90)!
        XCTAssertNotEqual(next.id, prior.id); XCTAssertEqual(next.issuedAt, 90)
        XCTAssertNil(s.page); XCTAssertEqual(s.completed, 0); XCTAssertTrue(s.awaitingAcquisition)
    }
    func testPurePlannerDoesNotAcceptUnboundedTextOrGrantOwner() {
        XCTAssertNil(BoundedReferenceChunkPlan.make(text: "abc", prefix: "", maximumUTF8Bytes: 2))
        XCTAssertNil(BoundedReferenceChunkPlan.make(text: "abc", prefix: "", maximumUTF8Bytes: Int.max))
        XCTAssertNil(BoundedReferenceChunkPlan.make(text: "abc", prefix: String(repeating: "x", count: 257), maximumUTF8Bytes: 10))
        let plan = BoundedReferenceChunkPlan.make(text: "a\n b\t c", prefix: "PDF: «", maximumUTF8Bytes: 100)!
        XCTAssertEqual(plan.map(\.original).joined(), "a\n b\t c")
    }
    func testStrictWholeCommandAndArabicDigits() {
        for text in ["choose a PDF", "اختر ملف PDF", " CHOOSE A PDF \n"] { XCTAssertEqual(SelectedDocumentCommand.parse(text), .choose) }
        XCTAssertEqual(SelectedDocumentCommand.parse("read PDF page 2"), .readPage(2))
        XCTAssertEqual(SelectedDocumentCommand.parse("اقرأ صفحة PDF ٢"), .readPage(2))
        XCTAssertEqual(SelectedDocumentCommand.parse("forget PDF"), .forget)
        for text in ["read PDF page 0", "read PDF page 9999999", "read PDF page 10001"] { XCTAssertEqual(SelectedDocumentCommand.parse(text), .invalidPage) }
        for text in ["don't choose a PDF", "\"choose a PDF\"", "read PDF page 2 and go", "if I choose a PDF", "read PDF page -1", "read PDF page 1.2", "read PDF page ²", "read PDF page ⑫", "repeat", "read PDF page"] { XCTAssertNil(SelectedDocumentCommand.parse(text), text) }
    }
}

extension SelectedDocumentReferenceTests {
    func testOldCallbackCannotWithdrawNewPendingRequest() {
        var s = DocumentFixture.ready(); let oldContext = DocumentFixture.context(s), old = s.next(DocumentFixture.context(s))!
        XCTAssertTrue(s.begin(old, context: oldContext))
        let request = s.beginPage(pageNumber: 3, requestID: UUID(), now: 23)!
        XCTAssertTrue(s.install(page: DocumentFixture.page(s), for: request, now: 24))
        let c = DocumentFixture.context(s, now: 25), new = s.next(DocumentFixture.context(s, now: 25))!
        XCTAssertTrue(s.begin(new, context: c))
        XCTAssertFalse(s.finish(id: old.id, text: old.text, outcome: .completed, context: oldContext))
        XCTAssertFalse(s.withdrawn); XCTAssertEqual(s.pending, new)
    }
    func testOldManualAndSelectedPhotoStillExpireInstalledTextAtOriginalSixtySeconds() throws {
        func source(_ identity: CompanionReferenceIdentity) -> CompanionReferenceSource {
            let e = CompanionEvidence(id: "block", kind: .historicalMemory, text: "Keep every warning.", source: identity.evidenceSource)
            return .init(identity: identity, toolResult: .init(status: .success, source: identity.evidenceSource, evidence: [e]),
                blocks: [.init(evidence: e, bodyUTF16Range: NSRange(location: 0, length: e.text.utf16.count), locator: "page 1")])
        }
        let identity = DocumentFixture.identity(media: .manual, model: "exact ABC")
        let binding = CompanionReferenceReading.Binding(requestID: UUID(), generation: 7)
        var manual = try CompanionReferenceReading.prepare(request: .init(kind: .readText, query: "Keep"),
            binding: binding, selectedSource: identity, source: source(identity), issuedAt: 10, monotonicNow: 69.99)
        XCTAssertFalse(manual.revalidate(.init(binding: binding, selectedSource: identity, monotonicNow: 70)))
        XCTAssertEqual(manual.state, .withdrawn(.expired))
        var photo = SelectedPhotoReference(); let view = UUID()
        let selection = photo.select(viewID: view, generation: 7, question: "read photo", now: 10)!
        let photoIdentity = CompanionReferenceIdentity(sourceID: selection.id, revision: UUID(), sha256: String(repeating: "b", count: 64), media: .selectedPhoto)
        XCTAssertTrue(photo.install(source(photoIdentity), for: selection, now: 69.99))
        XCTAssertFalse(photo.revalidate(.init(selection: selection, source: photoIdentity, viewID: view, generation: 7, question: "read photo", now: 70)))
        XCTAssertTrue(photo.withdrawn)
    }
}


extension SelectedDocumentReferenceTests {
    func testExplicitPageRetirementPreservesOnlySelectionForCorrection() {
        for phase in 0..<4 {
            var s = phase == 0 ? DocumentFixture.requested() : DocumentFixture.ready()
            let selection = s.selection, old = s.request!
            if phase >= 2 {
                let c = DocumentFixture.context(s), p = s.next(DocumentFixture.context(s))!
                XCTAssertTrue(s.begin(p, context: c))
                if phase == 3 { XCTAssertTrue(s.finish(id: p.id, text: p.text, outcome: .completed, context: c)) }
            }
            XCTAssertTrue(s.retirePage(now: 100))
            XCTAssertEqual(s.selection, selection); XCTAssertNil(s.request); XCTAssertNil(s.page)
            XCTAssertNil(s.pending); XCTAssertNil(s.lastStartedOrCompleted); XCTAssertTrue(s.phrases.isEmpty)
            XCTAssertEqual(s.completed, 0); XCTAssertFalse(s.ownsAttention); XCTAssertFalse(s.playbackCompleted)
            let next = s.beginPage(pageNumber: 1, requestID: UUID(), now: 101)!
            XCTAssertNotEqual(next.id, old.id); XCTAssertEqual(next.issuedAt, 101)
            XCTAssertTrue(s.install(page: DocumentFixture.page(s), for: next, now: 160.99))
        }
    }
    func testRetiredPageLateCallbackDoesNotAffectNewPage() {
        var s = DocumentFixture.ready(); let c = DocumentFixture.context(s), old = s.next(DocumentFixture.context(s))!
        XCTAssertTrue(s.begin(old, context: c)); XCTAssertTrue(s.retirePage(now: 23))
        let request = s.beginPage(pageNumber: 3, requestID: UUID(), now: 24)!
        XCTAssertTrue(s.install(page: DocumentFixture.page(s), for: request, now: 25))
        XCTAssertFalse(s.finish(id: old.id, text: old.text, outcome: .completed, context: c))
        XCTAssertFalse(s.withdrawn); XCTAssertEqual(s.completed, 0); XCTAssertEqual(s.request, request)
    }
    func testRetirementDoesNotReviveWithdrawnOrAcceptInvalidClock() {
        var s = DocumentFixture.ready(); var c = DocumentFixture.context(s); c.privateAudioHeld = true
        XCTAssertFalse(s.revalidate(c)); XCTAssertFalse(s.retirePage(now: 30)); XCTAssertTrue(s.withdrawn)
        XCTAssertNil(s.beginPage(pageNumber: 1, requestID: UUID(), now: 31))
        for now in [20.0, Double.nan, Double.infinity] {
            var fresh = DocumentFixture.ready(); let request = fresh.request
            XCTAssertFalse(fresh.retirePage(now: now)); XCTAssertEqual(fresh.request, request)
        }
        var empty = SelectedDocumentReference(); XCTAssertFalse(empty.retirePage(now: 1))
    }
}

extension SelectedDocumentReferenceTests {
    func testClosedEnglishPoliteCommandsAndOneSentenceTerminator() {
        let bases: [(String, SelectedDocumentCommand)] = [("choose a PDF", .choose), ("read PDF page 2", .readPage(2)), ("forget PDF", .forget)]
        let wrappers = ["", "please ", "can you ", "could you ", "can you please ", "could you please "]
        for (base, expected) in bases {
            for prefix in wrappers {
                for ending in ["", ".", "!", "?", "؟"] {
                    let text = prefix + base + ending
                    XCTAssertEqual(SelectedDocumentCommand.parse(text), expected, text)
                    XCTAssertEqual(SelectedDocumentCommand.parse(" \n" + text.uppercased() + "\t"), expected, text)
                }
            }
        }
    }
    func testClosedArabicPoliteImperativesAndNaturalQuestionNominals() {
        let imperatives: [(String, SelectedDocumentCommand)] = [("اختر ملف PDF", .choose), ("اقرأ صفحة PDF ٢", .readPage(2)), ("انس ملف PDF", .forget)]
        let nominals: [(String, SelectedDocumentCommand)] = [("اختيار ملف PDF", .choose), ("قراءة صفحة PDF ٢", .readPage(2)), ("نسيان ملف PDF", .forget)]
        for (bases, wrappers) in [(imperatives, ["", "من فضلك ", "لو سمحت "]), (nominals, ["هل يمكنك ", "هل يمكنك من فضلك "])] {
            for (base, expected) in bases {
                for prefix in wrappers {
                    for ending in ["", ".", "!", "?", "؟"] {
                        let text = prefix + base + ending
                        XCTAssertEqual(SelectedDocumentCommand.parse(text), expected, text)
                    }
                }
            }
        }
    }
    func testPoliteInvalidNumbersStayRecognizableWithoutGuessing() {
        for prefix in ["read PDF page ", "please read PDF page ", "can you please read PDF page ", "could you read PDF page ",
                       "اقرأ صفحة PDF ", "من فضلك اقرأ صفحة PDF ", "لو سمحت اقرأ صفحة PDF ", "هل يمكنك قراءة صفحة PDF ", "هل يمكنك من فضلك قراءة صفحة PDF "] {
            for digits in ["0", "٠", "10001", "١٠٠٠١", "9999999"] {
                for ending in ["", ".", "!", "?", "؟"] {
                    let text = prefix + digits + ending
                    XCTAssertEqual(SelectedDocumentCommand.parse(text), .invalidPage, text)
                }
            }
        }
    }
    func testPoliteGrammarRejectsQuotedNegativeConditionalAndExtraClauses() {
        let rejected = [
            "please don't choose a PDF", "can you not choose a PDF?", "could you never forget PDF?",
            "if you can choose a PDF", "can you choose a PDF if I ask?", "please read PDF page 2 then page 3",
            "please choose a PDF and read it", "she said please choose a PDF", "I wonder if you could choose a PDF",
            "\"please choose a PDF\"", "‘can you choose a PDF?’", "can you ‘choose a PDF’?",
            "please please choose a PDF", "can you could you choose a PDF", "please can you choose a PDF",
            "can you please please choose a PDF", "please choose a PDF please", "can you choose a PDF, please?",
            "please choose a PDF..", "can you choose a PDF?!", "choose a PDF؟؟", "choose a PDF!!", "choose a PDF !",
            "please choose. a PDF", "can you choose a PDF;", "can you choose a PDF: next", "can you choose a PDF\nnow",
            "please  choose a PDF", "can  you choose a PDF", "can you\nchoose a PDF", "please\tchoose a PDF",
            "please read PDF page two", "could you read PDF page -2?", "can you read PDF page +2?", "please read PDF page 2.5",
            "please read PDF page ٢٫٥", "please read PDF page ²", "please read PDF page ⑫", "please read PDF page 2 3",
            "من فضلك لا تختر ملف PDF", "لو لم تختر ملف PDF", "إذا أمكن اختر ملف PDF", "إن استطعت اقرأ صفحة PDF ٢",
            "هل يمكنك قراءة صفحة PDF ٢ ثم ٣؟", "من فضلك اختر ملف PDF واقرأه", "قال اختر ملف PDF", "«من فضلك اختر ملف PDF»",
            "من فضلك من فضلك اختر ملف PDF", "لو سمحت لو سمحت اختر ملف PDF", "هل يمكنك هل يمكنك قراءة صفحة PDF ٢",
            "هل يمكنك من فضلك من فضلك قراءة صفحة PDF ٢", "لو سمحت هل يمكنك قراءة صفحة PDF ٢", "من فضلك هل يمكنك قراءة صفحة PDF ٢",
            "هل يمكنك اقرأ صفحة PDF ٢", "هل يمكنك اختر ملف PDF", "هل يمكنك انس ملف PDF", "من فضلك قراءة صفحة PDF ٢",
            "لو سمحت اختيار ملف PDF", "قراءة صفحة PDF ٢", "اختيار ملف PDF", "نسيان ملف PDF",
            "هل يمكنك قراءة صفحة PDF اثنين؟", "هل يمكنك قراءة صفحة PDF -٢؟", "هل يمكنك قراءة صفحة PDF ٢؟؟",
            "please اختر ملف PDF", "من فضلك choose a PDF", "هل يمكنك read PDF page 2", "can you قراءة صفحة PDF ٢",
            "هل تستطيع قراءة صفحة PDF ٢", "would you choose a PDF", "kindly choose a PDF", "please select a PDF"
        ]
        for text in rejected { XCTAssertNil(SelectedDocumentCommand.parse(text), text) }
    }
}
