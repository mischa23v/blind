import Foundation

/// Pure ownership/delivery controller for the explicit camera text receipt. The native
/// adapter owns actual Vision work and Feedback owns actual speech callbacks.
/// No image, OCR or source identifier is persisted by this controller.
public struct CapturedTextReference: Sendable {
    /// One terminal playback receipt, not source text, a current observation or
    /// proof of understanding/real-world task completion. One receipt per playback attempt; retaining source text does not renew it.
    public struct PlaybackReceipt: Equatable, Sendable {
        public enum Outcome: String, Sendable { case completed, cancelled }
        public let sourceID: UUID
        public let revision: UUID
        public let requestID: UUID
        public let sessionGeneration: UInt64
        public let completedPhraseCount: Int
        public let totalPhraseCount: Int
        public let outcome: Outcome
    }
    public struct Selection: Equatable, Sendable {
        public let id: UUID
        public let cameraEpoch: UUID
        public let generation: UInt64
        public let requestID: UUID
        public let issuedAt: Double
        public let capturedAt: Double
        public let orientation: UInt32
    }
    public struct Context: Sendable {
        public let selection: Selection
        public let source: CompanionReferenceIdentity?
        public let cameraEpoch: UUID?
        public let generation: UInt64
        public let requestID: UUID
        public let now: Double
        public var foreground: Bool = true
        public var quiet: Bool = false
        public var hazard: Bool = false
        public var privateAudioHeld: Bool = false
        public init(selection: Selection, source: CompanionReferenceIdentity?, cameraEpoch: UUID?, generation: UInt64,
                    requestID: UUID, now: Double, foreground: Bool = true, quiet: Bool = false,
                    hazard: Bool = false, privateAudioHeld: Bool = false) {
            self.selection = selection; self.source = source; self.cameraEpoch = cameraEpoch
            self.generation = generation; self.requestID = requestID; self.now = now
            self.foreground = foreground; self.quiet = quiet; self.hazard = hazard
            self.privateAudioHeld = privateAudioHeld
        }
    }
    public struct Phrase: Equatable, Sendable {
        public let id: UUID
        public let text: String
        public let originalSlice: String
    }
    public private(set) var selection: Selection?
    public private(set) var source: CompanionReferenceSource?
    public private(set) var phrases: [Phrase] = []
    public private(set) var pending: Phrase?
    public private(set) var completed = 0
    public private(set) var withdrawn = false
    /// Finite installed reference progress, not freshness or real-world goal completion.
    public var playbackCompleted: Bool { source != nil && !phrases.isEmpty && completed == phrases.count && !withdrawn }
    public var awaitingAcquisition: Bool { selection != nil && source == nil && !withdrawn }
    // Source inventory is bounded by CompanionReferenceReading.prepare; no persistence.
    private var sourcePhrases: [Phrase] = []
    private var partOffset = 0
    public private(set) var lastSpokenPart: Int?
    public private(set) var paused = false
    private var lastNow = 0.0
    public var playbackReceipt: PlaybackReceipt? {
        guard let selection, let source else { return nil }
        return PlaybackReceipt(sourceID: source.identity.sourceID, revision: source.identity.revision,
            requestID: selection.requestID, sessionGeneration: selection.generation,
            completedPhraseCount: completed, totalPhraseCount: phrases.count,
            outcome: playbackCompleted ? .completed : .cancelled)
    }

    /// Actual start evidence only; an admitted/queued phrase is not heard speech.
    @discardableResult public mutating func started(id: UUID, text: String, context: Context) -> Bool {
        guard let pending, pending.id == id, pending.text.utf8.elementsEqual(text.utf8),
              revalidate(context) else { return false }
        lastSpokenPart = partOffset + completed
        return true
    }

    /// New playback, same frozen historical source. Never revives a withdrawn owner.
    /// A backend without onset evidence falls back to the last completed part.
    @discardableResult public mutating func review(_ command: CapturedTextReviewCommand,
        requestID: UUID, context: Context) -> Bool {
        guard revalidate(context), let selection, source != nil else { return false }
        let index: Int
        switch command {
        case .repeatPart: guard let lastSpokenPart else { return false }; index = lastSpokenPart
        case .previousPart: guard let lastSpokenPart else { return false }; index = lastSpokenPart - 1
        case .nextPart: index = lastSpokenPart.map { $0 + 1 } ?? 0
        case .readAgain: index = 0
        case .forget: return false // native owner clears all work synchronously
        }
        guard sourcePhrases.indices.contains(index) else { return false }
        let slices = command == .readAgain ? Array(sourcePhrases[index...]) : [sourcePhrases[index]]
        phrases = slices.map { Phrase(id: UUID(), text: $0.text, originalSlice: $0.originalSlice) }
        // Selection identity fences old timers; source identity remains unchanged.
        self.selection = Selection(id: UUID(), cameraEpoch: selection.cameraEpoch, generation: selection.generation,
            requestID: requestID, issuedAt: selection.issuedAt, capturedAt: selection.capturedAt, orientation: selection.orientation)
        partOffset = index; completed = 0; pending = nil; paused = false
        return true
    }
    public init() {}

    /// Call synchronously BEFORE awaiting any native OCR. Replacing even a
    /// still-loading selection revokes all older ownership immediately.
    @discardableResult public mutating func select(cameraEpoch: UUID, generation: UInt64,
                                                   requestID: UUID, issuedAt: Double, capturedAt: Double, orientation: UInt32, now: Double) -> Selection? {
        clear()
        guard now.isFinite, now >= 0, issuedAt.isFinite, issuedAt >= 0, now >= issuedAt, now - issuedAt < CompanionReferenceReading.lifetime,
              capturedAt.isFinite, capturedAt >= issuedAt, now >= capturedAt, now - capturedAt < 0.5, orientation == 6 else { return nil }
        let value = Selection(id: UUID(), cameraEpoch: cameraEpoch, generation: generation, requestID: requestID, issuedAt: issuedAt, capturedAt: capturedAt, orientation: orientation)
        selection = value; lastNow = now
        return value
    }
    public func owns(_ value: Selection, cameraEpoch: UUID?, generation: UInt64, now: Double) -> Bool {
        selection == value && !withdrawn && cameraEpoch == value.cameraEpoch && generation == value.generation &&
            now.isFinite && now >= lastNow && now >= value.issuedAt &&
            // The acquisition lease cannot renew. Once validated and frozen, the
            // finite source/cursor owns playback through budget waits and slow speech.
            (source != nil || now - value.issuedAt < CompanionReferenceReading.lifetime)
    }
    public mutating func install(_ source: CompanionReferenceSource, for value: Selection, now: Double, arabic: Bool = false) -> Bool {
        guard owns(value, cameraEpoch: value.cameraEpoch, generation: value.generation, now: now),
              self.source == nil, now >= value.capturedAt, now - value.capturedAt < 0.5,
              source.identity.media == .capturedText, source.identity.sourceID == value.id,
              // The explicit camera reading request reads the WHOLE selected source. The
              // phrase below selects all blocks, not a model-selected answer.
              let first = source.blocks.first?.evidence.text.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).first,
              let reader = try? CompanionReferenceReading.prepare(request: .init(kind: .readText, query: String(first)),
                  binding: .init(requestID: value.id, generation: value.generation), selectedSource: source.identity,
                  source: source, issuedAt: value.issuedAt, monotonicNow: now, arabic: arabic, phraseWordLimit: 25) else { return false }
        // Reserve additional Arabic captured-view attribution overhead within
        // the native minimum 30-word admission budget, without trimming text.
        let prefix = arabic ? "نص الصورة الملتقطة (غير مؤكد): «" : "Captured text (uncertain): «"
        let phrases = reader.chunks.map { Phrase(id: $0.id, text: prefix + $0.originalSlice + "»", originalSlice: $0.originalSlice) }
        guard phrases.allSatisfy({ CompanionReferenceReading.wordCount($0.text) <= 30 }) else { return false }
        self.source = source; self.phrases = phrases; self.sourcePhrases = phrases; lastNow = now
        return true
    }
    @discardableResult public mutating func revalidate(_ context: Context) -> Bool {
        guard owns(context.selection, cameraEpoch: context.cameraEpoch, generation: context.generation, now: context.now),
              context.requestID == context.selection.requestID, context.source == source?.identity,
              context.foreground, !context.quiet, !context.hazard, !context.privateAudioHeld else {
            withdrawn = true; return false
        }
        lastNow = context.now
        return true
    }
    public mutating func next(_ context: Context) -> Phrase? {
        guard revalidate(context), source != nil, !paused, pending == nil, completed < phrases.count else { return nil }
        return phrases[completed]
    }
    /// Reserve before native dispatch (callbacks may be synchronous in tests).
    public mutating func begin(_ phrase: Phrase, context: Context) -> Bool {
        guard next(context) == phrase else { return false }
        pending = phrase; return true
    }
    public mutating func admissionRejected(_ id: UUID) { if pending?.id == id { pending = nil } }
    @discardableResult public mutating func finish(id: UUID, text: String, outcome: NarrationDelivery, context: Context) -> Bool {
        guard let pending, pending.id == id, pending.text.utf8.elementsEqual(text.utf8),
              revalidate(context) else { return false }
        guard outcome == .completed else { paused = true; self.pending = nil; return false }
        lastSpokenPart = partOffset + completed
        self.pending = nil; completed += 1; return true
    }
    @discardableResult public mutating func clear() -> PlaybackReceipt? {
        let receipt = playbackReceipt
        self = Self()
        return receipt
    }

}
