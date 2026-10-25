import Foundation

// Explicit substitutes. Actual controller extension and Core policy are appended
// verbatim (visibility changes only). These sinks are NOT PDFKit/Feedback/stores.
struct ProjectedSession { var generation: UInt64 = 7; var foregroundActive = true; var mayRespond = true; var privateAudioHeld = false }
struct ProjectedHazard { var isUrgent = false }
struct ProjectedDetection { var hazard = ProjectedHazard() }
struct ProjectedVoice { var awaitingUtterance = false }
struct ProjectedBudget {
    var release = 0.0
    mutating func nextInformationBudgetTime(words: Int, settings: Int, now: Double) -> Double? {
        words <= settings ? max(now, release) : nil
    }
}
enum InformationCandidate { enum Kind { case answer } }
@MainActor final class ProjectedFeedback {
    var speechPriority: SpeechPriority?
    var stopped: [UUID] = []
    var onStop: ((UUID) -> Void)?
    func stopRequestedSpeech(_ id: UUID) { stopped.append(id); onStop?(id) }
}

/// Controllable noncancellable native-work substitute. Never used to claim real
/// PDF extraction; separate SelectedDocumentPDFTests executes actual PDFKit bytes.
final class BlockingPDFWork: @unchecked Sendable {
    private let condition = NSCondition()
    private var held = false
    private var count = 0
    private var active = 0
    private var maximumActive = 0
    func reset(hold: Bool) {
        condition.lock(); held = hold; count = 0; active = 0; maximumActive = 0; condition.unlock()
    }
    func enter() {
        condition.lock(); count += 1; active += 1; maximumActive = max(maximumActive, active)
        while held { condition.wait() }
        active -= 1; condition.unlock()
    }
    func release() { condition.lock(); held = false; condition.broadcast(); condition.unlock() }
    var calls: Int { condition.lock(); defer { condition.unlock() }; return count }
    var peak: Int { condition.lock(); defer { condition.unlock() }; return maximumActive }
}
enum SelectedDocumentPDFAdapter {
    enum Failure: Error { case filePermissionDenied, malformed, locked, accessibilityPermissionDenied, oversizedInput, oversizedPage, invalidPage, noReadableTextLayer }
    struct Selection: Sendable { let bytes: Data; let sha256: String; let pageCount: Int }
    struct Page: Sendable { let text: String; let pageNumber: Int; let pageLabel: String; let sha256: String }
    static let work = BlockingPDFWork()
    static let sentinel = "PRIVATE_PDF_SENTINEL"
    static func loadSelectedURL(_ url: URL) throws -> Selection {
        work.enter()
        return Selection(bytes: Data(sentinel.utf8), sha256: String(repeating: "b", count: 64), pageCount: 2)
    }
    static func readPage(_ number: Int, from selection: Selection) throws -> Page {
        work.enter()
        return Page(text: sentinel + " " + (1...70).map { "word\($0)" }.joined(separator: " "),
                    pageNumber: number, pageLabel: "PRIVATE_LABEL_SENTINEL", sha256: selection.sha256)
    }
}

@MainActor final class NavigationModel {
    struct DocumentPickerPresentation: Identifiable { let id: UUID; let generation: UInt64 }
    var selectedDocumentPickerRequest: DocumentPickerPresentation?
    var selectedDocument = SelectedDocumentReference()
    var selectedPDF: SelectedDocumentPDFAdapter.Selection?
    var selectedDocumentImportOwner: DocumentPickerPresentation?
    var selectedDocumentRequestID: UUID?
    var selectedDocumentNativeLease: UUID?
    var selectedDocumentTask: Task<Void, Never>?
    var selectedDocumentExpiry: Task<Void, Never>?
    var selectedDocumentBudgetWake: Task<Void, Never>?
    var selectedDocumentBudgetWakeAt: Double?
    var selectedDocumentSpeechIDs = Set<UUID>()
    var selectedPhotoSpeechIDs = Set<UUID>(), boardingSpeechIDs = Set<UUID>(), capturedTextSpeechIDs = Set<UUID>()
    var selectedDocumentDisplay: String?
    var selectedDocumentDisplayRevisions: (reply: UUID, scene: UUID)?
    var assistantSession = ProjectedSession(), detection = ProjectedDetection(), voice = ProjectedVoice(), companion = ProjectedBudget()
    let feedback = ProjectedFeedback()
    var ambientDescriptions = true, textOnly = false, arabic = false, companionSettings = 30
    var currentReplyRevision = UUID(), sceneAnswerRevision = UUID()
    var currentReply = "" { didSet { currentReplyRevision = UUID() } }
    var sceneAnswer = "" { didSet { sceneAnswerRevision = UUID() } }
    var delivered: [(UUID, String)] = []
    var redactedDiagnostics: [String] = []
    var narrationHistory: [String] = [], modelContext: [String] = [], dialogue: [String] = []
    var notices: [String] = []
    var noticeSpeechIDs: [UUID] = []
    var noticeHadPriorSource = false
    var admission = true
    var onDispatch: ((UUID, String) -> Void)?
    var documentAttentionOwned: Bool { selectedDocumentImportOwner != nil || selectedDocument.ownsAttention }
    var ordinarySourceActive = false, capturedSourceActive = false, photoSourceActive = false
    var ordinaryRetirements = 0, capturedRetirements = 0, photoRetirements = 0
    var onRetireOtherWork: (() -> Void)?
    func interruptOrdinaryConversation(origin: CompanionCommandOrigin) {
        ordinaryRetirements += 1; ordinarySourceActive = false; onRetireOtherWork?()
    }
    func purgeCapturedTextPlayback() {
        capturedRetirements += 1; capturedSourceActive = false; onRetireOtherWork?()
    }
    func clearExploreSnapshot() {
        photoRetirements += 1; photoSourceActive = false; onRetireOtherWork?()
    }
    @discardableResult func speakRequested(_ text: String, replace: Bool) -> Bool {
        guard admission, companion.release <= ProcessInfo.processInfo.systemUptime else { return false }
        notices.append(text); return true
    }
    static func wordCount(_ text: String) -> Int { CompanionReferenceReading.wordCount(text) }
    func projectedNativeStart(id: UUID, text: String) {
        /* PRODUCTION_DOCUMENT_STARTED */
    }
    func dispatchText(_ text: String, kind: InformationCandidate.Kind, requested: Bool, replace: Bool, speechID: UUID) -> Bool {
        let speechID: UUID? = speechID
        /* PRODUCTION_PRIVATE_REFERENCE */
        redactedDiagnostics.append(privateReference ? "redacted" : text)
        guard admission, companion.release <= ProcessInfo.processInfo.systemUptime,
              Self.wordCount(text) <= companionSettings, let speechID,
              selectedDocumentSpeechPermission(id: speechID, text: text) else { return false }
        if privateReference { delivered.append((speechID, text)); onDispatch?(speechID, text) }
        else {
            noticeHadPriorSource = noticeHadPriorSource || ordinarySourceActive || capturedSourceActive || photoSourceActive
            notices.append(text); noticeSpeechIDs.append(speechID)
        }
        return true
    }
    func installFixture(words: Int = 70, issuedAgo: Double = 0) {
        let now = ProcessInfo.processInfo.systemUptime
        let identity = CompanionReferenceIdentity(sourceID: UUID(), revision: UUID(), sha256: String(repeating: "a", count: 64), media: .selectedDocument)
        _ = selectedDocument.select(identity: identity, pageCount: 2, generation: assistantSession.generation, now: now - issuedAgo)
        selectedPDF = .init(bytes: Data("PRIVATE_BYTES_SENTINEL".utf8), sha256: identity.sha256, pageCount: 2)
        let requestID = UUID()
        let request = selectedDocument.beginPage(pageNumber: 1, requestID: requestID, now: now - issuedAgo)!
        selectedDocumentRequestID = requestID
        let text = SelectedDocumentPDFAdapter.sentinel + " " + (1...words).map { "word\($0)" }.joined(separator: " ")
        // Installation is before original deadline; current delivery can be much later.
        precondition(selectedDocument.install(page: .init(identity: identity, pageNumber: 1,
            pageLabel: "PRIVATE_LABEL_SENTINEL", text: text), for: request, now: now - issuedAgo))
    }
    func installExpiredAcquisition() -> SelectedDocumentReference.Request {
        let old = ProcessInfo.processInfo.systemUptime - 61
        let identity = CompanionReferenceIdentity(sourceID: UUID(), revision: UUID(), sha256: String(repeating: "a", count: 64), media: .selectedDocument)
        _ = selectedDocument.select(identity: identity, pageCount: 1, generation: assistantSession.generation, now: old)
        selectedPDF = .init(bytes: Data("PRIVATE_BYTES_SENTINEL".utf8), sha256: identity.sha256, pageCount: 1)
        let requestID = UUID(); selectedDocumentRequestID = requestID
        return selectedDocument.beginPage(pageNumber: 1, requestID: requestID, now: old)!
    }
}
