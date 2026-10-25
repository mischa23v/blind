import Foundation

/// Volatile, always-private literal quotation from one explicitly selected PDF.
/// Selection grants no reading, model-number, appliance or physical authority.
/// Native adapters own immutable PDF bytes and PDFKit work; this value owns only
/// bounded page text and exact speech receipts. Nothing here is Codable.
public struct SelectedDocumentReference: Sendable {
    public static let maximumEncodedBytes = 20 * 1024 * 1024
    public static let maximumPageUTF8Bytes = 64 * 1024
    public static let maximumPageCount = 10_000
    public static let acquisitionLifetime: Double = 60
    public static let phraseWordLimit = 30
    public let isPrivate = true

    public struct Selection: Equatable, Sendable {
        public let id: UUID
        public let identity: CompanionReferenceIdentity
        public let pageCount: Int
        public let generation: UInt64
    }
    public struct Request: Equatable, Sendable {
        public let id: UUID
        public let selectionID: UUID
        public let requestID: UUID
        public let pageNumber: Int
        public let generation: UInt64
        public let issuedAt: Double
    }
    public struct Page: Equatable, Sendable {
        public let identity: CompanionReferenceIdentity
        /// One-based requested page, not a PDF-supplied page label.
        public let pageNumber: Int
        /// Private metadata, never used as a command or trusted spoken prefix.
        public let pageLabel: String
        public let text: String
        public init(identity: CompanionReferenceIdentity, pageNumber: Int, pageLabel: String, text: String) {
            self.identity = identity; self.pageNumber = pageNumber; self.pageLabel = pageLabel; self.text = text
        }
    }
    public struct Phrase: Equatable, Sendable {
        public let id: UUID
        public let text: String
        public let originalSlice: String
    }
    public struct Context: Sendable {
        public let selection: Selection
        public let request: Request
        public let source: CompanionReferenceIdentity
        public let generation: UInt64
        public let requestID: UUID
        public let now: Double
        public var foreground: Bool
        public var quiet: Bool
        public var hazard: Bool
        public var privateAudioHeld: Bool
        public init(selection: Selection, request: Request, source: CompanionReferenceIdentity,
                    generation: UInt64, requestID: UUID, now: Double, foreground: Bool = true,
                    quiet: Bool = false, hazard: Bool = false, privateAudioHeld: Bool = false) {
            self.selection = selection; self.request = request; self.source = source
            self.generation = generation; self.requestID = requestID; self.now = now
            self.foreground = foreground; self.quiet = quiet; self.hazard = hazard
            self.privateAudioHeld = privateAudioHeld
        }
    }
    public private(set) var selection: Selection?
    public private(set) var request: Request?
    public private(set) var page: Page?
    public private(set) var phrases: [Phrase] = []
    public private(set) var pending: Phrase?
    public private(set) var completed = 0
    public private(set) var withdrawn = false
    public private(set) var lastStartedOrCompleted: Phrase?
    private var lastNow = 0.0
    public var awaitingAcquisition: Bool { request != nil && page == nil && !withdrawn }
    public var playbackCompleted: Bool { page != nil && !phrases.isEmpty && completed == phrases.count && !withdrawn }
    public var ownsAttention: Bool { request != nil && !withdrawn && !playbackCompleted }
    public init() {}

    @discardableResult public mutating func select(identity: CompanionReferenceIdentity, pageCount: Int,
                                                    generation: UInt64, now: Double) -> Selection? {
        clear()
        guard identity.media == .selectedDocument, identity.exactModel == nil, identity.isValid,
              (1...Self.maximumPageCount).contains(pageCount), now.isFinite, now >= 0 else { return nil }
        let value = Selection(id: UUID(), identity: identity, pageCount: pageCount, generation: generation)
        selection = value; lastNow = now
        return value
    }
    /// Each explicit page request gets a new owner. This does not renew a prior
    /// request; a withdrawn selection requires a new explicit file selection.
    @discardableResult public mutating func beginPage(pageNumber: Int, requestID: UUID, now: Double) -> Request? {
        guard let selection, !withdrawn, (1...selection.pageCount).contains(pageNumber),
              now.isFinite, now >= lastNow else { return nil }
        let value = Request(id: UUID(), selectionID: selection.id, requestID: requestID,
                            pageNumber: pageNumber, generation: selection.generation, issuedAt: now)
        request = value; page = nil; phrases = []; pending = nil; completed = 0
        lastStartedOrCompleted = nil; lastNow = now
        return value
    }
    /// Retire only the page request for an explicit correction. This is not a
    /// pause/resume and grants no reading: a later explicit beginPage must mint
    /// a new request. Native caller validates lifecycle first, captures pending
    /// speech, calls this before stopping it, and retains the native work lease.
    @discardableResult public mutating func retirePage(now: Double) -> Bool {
        guard selection != nil, !withdrawn, now.isFinite, now >= lastNow else { return false }
        request = nil; page = nil; phrases = []; pending = nil; completed = 0
        lastStartedOrCompleted = nil; lastNow = now
        return true
    }
    public func owns(_ value: Request, now: Double) -> Bool {
        guard let selection else { return false }
        return !withdrawn && request == value && selection.id == value.selectionID &&
            selection.generation == value.generation && now.isFinite && now >= lastNow && now >= value.issuedAt &&
            (page != nil || now - value.issuedAt < Self.acquisitionLifetime)
    }
    /// Installation cannot refresh or bypass the ORIGINAL acquisition deadline,
    /// even if native PDFKit work completed before its callback reached the owner.
    @discardableResult public mutating func install(page: Page, for value: Request, now: Double, arabic: Bool = false) -> Bool {
        guard owns(value, now: now), self.page == nil, now - value.issuedAt < Self.acquisitionLifetime,
              let selection, page.identity == selection.identity,
              page.identity.media == .selectedDocument, page.identity.exactModel == nil,
              page.identity.isValid, page.pageNumber == value.pageNumber,
              page.pageLabel.utf8.count <= 128 else { return false }
        let prefix = arabic ? "نص صفحة PDF \(page.pageNumber): «" : "PDF page \(page.pageNumber) text: «"
        guard let plan = BoundedReferenceChunkPlan.make(text: page.text, prefix: prefix,
                maximumUTF8Bytes: Self.maximumPageUTF8Bytes, phraseWordLimit: Self.phraseWordLimit) else { return false }
        self.page = page
        phrases = plan.map { Phrase(id: UUID(), text: $0.attributed, originalSlice: $0.original) }
        lastNow = now
        return true
    }
    @discardableResult public mutating func revalidate(_ context: Context) -> Bool {
        guard selection == context.selection, request == context.request,
              context.source == selection?.identity, context.generation == context.selection.generation,
              context.requestID == context.request.requestID, owns(context.request, now: context.now),
              context.foreground, !context.quiet, !context.hazard, !context.privateAudioHeld else {
            withdrawn = true; return false
        }
        lastNow = context.now
        return true
    }
    public mutating func next(_ context: Context) -> Phrase? {
        guard revalidate(context), page != nil, pending == nil, completed < phrases.count else { return nil }
        return phrases[completed]
    }
    /// Reserve before native dispatch, which can synchronously invoke callbacks.
    public mutating func begin(_ phrase: Phrase, context: Context) -> Bool {
        guard next(context) == phrase else { return false }
        pending = phrase; return true
    }
    public mutating func admissionRejected(_ id: UUID) {
        if pending?.id == id { pending = nil }
    }
    @discardableResult public mutating func started(id: UUID, text: String, context: Context) -> Bool {
        guard let pending, pending.id == id, pending.text.utf8.elementsEqual(text.utf8),
              revalidate(context) else { return false }
        lastStartedOrCompleted = pending; return true
    }
    /// A queued phrase is not completed. Feed only real native completion events.
    @discardableResult public mutating func finish(id: UUID, text: String, outcome: NarrationDelivery, context: Context) -> Bool {
        guard let pending, pending.id == id, pending.text.utf8.elementsEqual(text.utf8),
              request == context.request, selection == context.selection, revalidate(context) else { return false }
        guard outcome == .completed else { withdrawn = true; self.pending = nil; return false }
        lastStartedOrCompleted = pending; self.pending = nil; completed += 1
        return true
    }
    public mutating func clear() { self = Self() }
}

/// Whole trusted-interface command syntax only. Parsing is not authorization;
/// callers must reject unverified microphone, PDF content and model output.
public enum SelectedDocumentCommand: Equatable, Sendable {
    case choose, readPage(Int), invalidPage, forget
    public static func parse(_ text: String) -> Self? {
        guard text.utf8.count <= 160 else { return nil }
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // Exactly one attached sentence terminator; never strip a punctuation
        // run, quotes, internal punctuation, or text following the command.
        let sentenceTerminators: Set<Character> = [".", "!", "?", "؟"]
        if let last = value.last, sentenceTerminators.contains(last) { value.removeLast() }
        // One closed, language-specific wrapper only. Do not recursively strip
        // prefixes: reported, negated, conditional and chained requests stay out.
        let english = ["can you please ", "could you please ", "please ", "can you ", "could you "]
        if let prefix = english.first(where: { value.hasPrefix($0) }) {
            return parseBase(String(value.dropFirst(prefix.count)), arabic: false)
        }
        let arabicQuestion = ["هل يمكنك من فضلك ", "هل يمكنك "]
        if let prefix = arabicQuestion.first(where: { value.hasPrefix($0) }) {
            return parseBase(String(value.dropFirst(prefix.count)), arabic: true, nominal: true)
        }
        if let prefix = ["من فضلك ", "لو سمحت "].first(where: { value.hasPrefix($0) }) {
            return parseBase(String(value.dropFirst(prefix.count)), arabic: true)
        }
        return parseBase(value, arabic: false) ?? parseBase(value, arabic: true)
    }
    private static func parseBase(_ value: String, arabic: Bool, nominal: Bool = false) -> Self? {
        if value == (arabic ? (nominal ? "اختيار ملف pdf" : "اختر ملف pdf") : "choose a pdf") { return .choose }
        if value == (arabic ? (nominal ? "نسيان ملف pdf" : "انس ملف pdf") : "forget pdf") { return .forget }
        let prefix = arabic ? (nominal ? "قراءة صفحة pdf " : "اقرأ صفحة pdf ") : "read pdf page "
        guard value.hasPrefix(prefix) else { return nil }
        let digits = value.dropFirst(prefix.count)
        guard !digits.isEmpty, digits.allSatisfy({ character in
            character.unicodeScalars.count == 1 && character.unicodeScalars.allSatisfy { $0.properties.generalCategory == .decimalNumber } &&
                character.wholeNumberValue.map { (0...9).contains($0) } == true
        }) else { return nil }
        guard digits.count <= 6 else { return .invalidPage }
        let number = digits.reduce(0) { $0 * 10 + $1.wholeNumberValue! }
        return number > 0 && number <= maximumPageNumber ? .readPage(number) : .invalidPage
    }
    private static let maximumPageNumber = SelectedDocumentReference.maximumPageCount
}
