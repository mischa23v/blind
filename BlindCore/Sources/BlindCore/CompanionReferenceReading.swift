import Foundation
#if canImport(NaturalLanguage)
import NaturalLanguage
#endif

/// Identity supplied by the local, non-model source adapter. A model label alone
/// never identifies a manual. Digest is the adapter's SHA-256 of the selected
/// source bytes, not a digest guessed or calculated from an answer by the model.
public struct CompanionReferenceIdentity: Equatable, Sendable {
    public enum Media: String, Sendable { case manual, capturedText, selectedPhoto }
    public let sourceID: UUID
    public let revision: UUID
    public let sha256: String
    public let media: Media
    public let exactModel: String?
    public init(sourceID: UUID, revision: UUID, sha256: String, media: Media, exactModel: String? = nil) {
        self.sourceID = sourceID; self.revision = revision; self.sha256 = sha256
        self.media = media; self.exactModel = exactModel
    }
    public var evidenceSource: String { "local-reference:\(sourceID.uuidString):\(revision.uuidString)" }
    fileprivate var isValid: Bool {
        guard sha256.count == 64,
              sha256.unicodeScalars.allSatisfy({ "0123456789abcdef".unicodeScalars.contains($0) }) else { return false }
        if let model = exactModel {
            guard !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, model.utf8.count <= 480,
                  !model.unicodeScalars.contains(where: {
                      CharacterSet.controlCharacters.contains($0) || $0.properties.generalCategory == .format
                  }) else { return false }
        }
        return media != .manual || exactModel != nil
    }
}

/// One COMPLETE extracted block, including its heading and qualifiers. The body
/// range is source-adapter metadata, not a model-selected answer. Only this range
/// participates in lexical relevance; delivery preserves the entire text.
public struct CompanionReferenceBlock: Sendable {
    public let evidence: CompanionEvidence
    public let bodyUTF16Range: NSRange
    public let locator: String
    public init(evidence: CompanionEvidence, bodyUTF16Range: NSRange, locator: String) {
        self.evidence = evidence; self.bodyUTF16Range = bodyUTF16Range; self.locator = locator
    }
}

/// Keeps original source records outside CompanionToolRuntime's model-context
/// budget. This is a reading receipt, NEVER current observation/physical authority.
/// Native PDF/manual extraction is NOT implemented by this Core container.
public struct CompanionReferenceSource: Sendable {
    public let identity: CompanionReferenceIdentity
    public let toolResult: CompanionToolResult
    public let blocks: [CompanionReferenceBlock]
    public init(identity: CompanionReferenceIdentity, toolResult: CompanionToolResult,
                blocks: [CompanionReferenceBlock]) {
        self.identity = identity; self.toolResult = toolResult; self.blocks = blocks
    }
}

/// Bounded code-owned quotation delivery, not a summarizer, recognizer, route or
/// instruction executor. No method accepts a model-authored replacement answer.
/// All chunks retain their exact source slice; source text is never sent to an
/// LLM to make it fit. The original 60-second request deadline cannot be renewed.
public struct CompanionReferenceReading: Sendable {
    public static let maximumWords = 35
    public static let lifetime: Double = 60
    // Resource limits reject the WHOLE selection explicitly, never trim records.
    public static let maximumSourceUTF8Bytes = 256 * 1024
    public static let maximumBlocks = 256

    public struct Binding: Equatable, Sendable {
        public let requestID: UUID
        public let generation: UInt64
        public init(requestID: UUID, generation: UInt64) {
            self.requestID = requestID; self.generation = generation
        }
    }
    public struct Context: Sendable {
        public let binding: Binding
        public let selectedSource: CompanionReferenceIdentity
        public let monotonicNow: Double
        public let foreground: Bool
        public let quiet: Bool
        public let hazard: Bool
        public init(binding: Binding, selectedSource: CompanionReferenceIdentity, monotonicNow: Double,
                    foreground: Bool = true, quiet: Bool = false, hazard: Bool = false) {
            self.binding = binding; self.selectedSource = selectedSource; self.monotonicNow = monotonicNow
            self.foreground = foreground; self.quiet = quiet; self.hazard = hazard
        }
    }
    public enum Rejection: Error, Equatable, Sendable {
        case invalidClock, expired, wrongSource, invalidIdentity, unsupportedTool
        case unreadable, malformedBlock, resourceLimit, noRelevantBody
    }
    public enum Withdrawal: String, Sendable {
        case interruption, quiet, hazard, sourceReplacement, newQuestion, background, expired, invalidClock
    }
    public enum State: Equatable, Sendable {
        case ready, awaitingCompletion, completed, withdrawn(Withdrawal)
    }
    public struct Chunk: Equatable, Sendable {
        public let id: UUID
        public let index: Int
        public let blockID: String
        public let locator: String
        public let source: CompanionReferenceIdentity
        /// Concatenate in block order to recover the original bytes, including whitespace.
        public let originalSlice: String
        public let spokenText: String
    }
    public struct Dispatch: Sendable {
        public let chunk: Chunk
        public let attempt: SpeechDeliveryLedger.Attempt
    }

    public let binding: Binding
    public let source: CompanionReferenceSource
    public let issuedAt: Double
    public let deadline: Double
    public let chunks: [Chunk]
    public private(set) var state: State = .ready
    public private(set) var completedChunkCount = 0
    /// Adapter must stop this exact requested speech ID on a failed revalidation.
    /// Do not stop the independent sensor-hazard channel.
    public private(set) var withdrawnSpeechID: UUID?
    private var lastMonotonic: Double
    private var pending: Dispatch?

    private init(binding: Binding, source: CompanionReferenceSource, issuedAt: Double,
                 now: Double, chunks: [Chunk]) {
        self.binding = binding; self.source = source; self.issuedAt = issuedAt
        self.deadline = issuedAt + Self.lifetime; self.lastMonotonic = now; self.chunks = chunks
    }

    /// request.query is an exact requested search phrase, not an LLM answer.
    /// Bounded lexical relevance is intentionally conservative: it does not claim
    /// semantic understanding of arbitrary questions. At least one BODY must
    /// contain that phrase; heading matches alone do not authorize an answer.
    /// Once relevant, EVERY supplied source block is retained, in original order.
    /// issuedAt is the ORIGINAL request time, not extraction/queue/retry time.
    public static func prepare(request: CompanionToolRequest, binding: Binding,
                               selectedSource: CompanionReferenceIdentity, source: CompanionReferenceSource,
                               issuedAt: Double, monotonicNow: Double, arabic: Bool = false) throws -> Self {
        guard issuedAt.isFinite, issuedAt >= 0, monotonicNow.isFinite, monotonicNow >= issuedAt else {
            throw Rejection.invalidClock
        }
        guard monotonicNow - issuedAt < lifetime else { throw Rejection.expired }
        guard selectedSource == source.identity else { throw Rejection.wrongSource }
        guard selectedSource.isValid else { throw Rejection.invalidIdentity }
        guard request.kind == .readText, !request.query.isEmpty, request.query.count <= 300 else {
            throw Rejection.unsupportedTool
        }
        let sought = words(request.query)
        guard !sought.isEmpty else { throw Rejection.noRelevantBody }
        guard source.toolResult.status == .success, !source.blocks.isEmpty else { throw Rejection.unreadable }
        guard source.blocks.count <= maximumBlocks,
              source.toolResult.evidence == source.blocks.map(\.evidence) else { throw Rejection.malformedBlock }
        guard source.toolResult.source == selectedSource.evidenceSource else { throw Rejection.wrongSource }
        guard source.toolResult.summary.utf8.count <= 4_096 else { throw Rejection.resourceLimit }
        var bytes = source.toolResult.source.utf8.count + source.toolResult.summary.utf8.count
            + selectedSource.sha256.utf8.count + (selectedSource.exactModel?.utf8.count ?? 0) + 72
        var seenIDs = Set<String>(), foundBody = false
        for block in source.blocks {
            let item = block.evidence
            guard item.id.utf8.count <= 120, block.locator.utf8.count <= 512,
                  item.source.utf8.count <= 120 else { throw Rejection.resourceLimit }
            // Both result records and block metadata are retained. Count both,
            // even when Swift's strings share backing storage, plus date fields.
            bytes += 2 * (item.text.utf8.count + item.id.utf8.count + item.source.utf8.count + 32)
                + block.locator.utf8.count + 16
            guard bytes <= maximumSourceUTF8Bytes else { throw Rejection.resourceLimit }
            guard !item.id.isEmpty, seenIDs.insert(item.id).inserted,
                  item.kind == .historicalMemory, item.source == selectedSource.evidenceSource,
                  item.expiresAt == nil, !item.text.isEmpty, !block.locator.isEmpty,
                  let range = Range(block.bodyUTF16Range, in: item.text), !range.isEmpty else {
                throw Rejection.malformedBlock
            }
            let bodyWords = words(String(item.text[range]))
            if contains(sought, in: bodyWords) { foundBody = true }
        }
        guard foundBody else { throw Rejection.noRelevantBody }
        let prefix = arabic ? "يقول المصدر المحدد: «" : "The selected source says: «"
        let bodyLimit = maximumWords - wordCount(prefix)
        var chunks: [Chunk] = []
        for block in source.blocks {
            for slice in slices(block.evidence.text, wordLimit: bodyLimit) {
                // Language-sensitive platform tokenization may differ after
                // adding attribution. Never dispatch an over-budget phrase.
                guard wordCount(prefix + slice + "»") <= maximumWords else { throw Rejection.resourceLimit }
                chunks.append(Chunk(id: UUID(), index: chunks.count, blockID: block.evidence.id,
                    locator: block.locator, source: source.identity,
                    originalSlice: slice, spokenText: prefix + slice + "»"))
            }
        }
        guard !chunks.isEmpty else { throw Rejection.unreadable }
        return Self(binding: binding, source: source, issuedAt: issuedAt, now: monotonicNow, chunks: chunks)
    }

    /// Call at dispatch, while active, and from the actual speech completion
    /// callback. Invalid contexts retire, rather than pause, this sequence.
    @discardableResult public mutating func revalidate(_ context: Context) -> Bool {
        switch state { case .completed, .withdrawn: return false; default: break }
        let reason: Withdrawal?
        if context.binding != binding { reason = .newQuestion }
        else if context.selectedSource != source.identity { reason = .sourceReplacement }
        else if !context.monotonicNow.isFinite || context.monotonicNow < lastMonotonic { reason = .invalidClock }
        else if context.monotonicNow - issuedAt >= Self.lifetime { reason = .expired }
        else if !context.foreground { reason = .background }
        else if context.quiet { reason = .quiet }
        else if context.hazard { reason = .hazard }
        else { reason = nil }
        if let reason { withdraw(reason); return false }
        lastMonotonic = context.monotonicNow
        return true
    }

    /// Admission/word budgets remain the native adapter's responsibility. It may
    /// call this ONLY after admitting the whole chunk, then start the returned
    /// exact text with the existing speech backend. No timer can complete it.
    /// A busy ledger is not an instruction to interrupt its existing output.
    public mutating func beginNext(ledger: inout SpeechDeliveryLedger, context: Context) -> Dispatch? {
        guard revalidate(context), state == .ready, pending == nil,
              completedChunkCount < chunks.count else { return nil }
        let chunk = chunks[completedChunkCount]
        guard let attempt = ledger.begin(text: chunk.spokenText, priority: .information,
            destination: .requested(chunk.id), transport: .synthesized) else { return nil }
        let dispatch = Dispatch(chunk: chunk, attempt: attempt)
        pending = dispatch; state = .awaitingCompletion
        return dispatch
    }

    /// Feed only a completion returned by the existing speech ledger from an
    /// AVSpeechSynthesizer/VoiceOver callback. It is not a user-comprehension proof.
    /// IDs, text, destination and transport all bind the callback to this chunk.
    @discardableResult public mutating func complete(_ completion: SpeechDeliveryLedger.Completion,
                                                     context: Context) -> Bool {
        guard revalidate(context), let pending,
              completion.attempt.token == pending.attempt.token,
              completion.attempt.destination == .requested(pending.chunk.id),
              completion.attempt.text.utf8.elementsEqual(pending.chunk.spokenText.utf8),
              completion.attempt.priority == .information,
              completion.attempt.transport == .synthesized,
              !completion.attempt.independentAlert else { return false }
        guard completion.outcome == .completed else { withdraw(.interruption); return false }
        self.pending = nil; completedChunkCount += 1
        state = completedChunkCount == chunks.count ? .completed : .ready
        return true
    }

    /// Explicit interruption, quiet, hazard, source replacement or a new question
    /// is terminal. There is deliberately no resume or renew method.
    @discardableResult public mutating func withdraw(_ reason: Withdrawal) -> UUID? {
        switch state { case .completed, .withdrawn: return withdrawnSpeechID; default: break }
        withdrawnSpeechID = pending?.chunk.id
        pending = nil; state = .withdrawn(reason)
        return withdrawnSpeechID
    }

    /// Native builds reuse the same Apple NLTokenizer API as document admission.
    /// Portable tests use SpeechDeliveryLedger's existing letter/number convention;
    /// they do not prove Apple tokenization or speech behavior on a device.
    public static func wordCount(_ text: String) -> Int { wordStarts(text).count }
    private static func wordStarts(_ text: String) -> [String.Index] {
        #if canImport(NaturalLanguage)
        let tokenizer = NLTokenizer(unit: .word); tokenizer.string = text
        return tokenizer.tokens(for: text.startIndex..<text.endIndex).map(\.lowerBound)
        #else
        return text.split { !$0.isLetter && !$0.isNumber }.map(\.startIndex)
        #endif
    }
    private static func words(_ text: String) -> [String] {
        text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
    }
    private static func contains(_ needle: [String], in haystack: [String]) -> Bool {
        guard !needle.isEmpty, needle.count <= haystack.count else { return false }
        return (0...(haystack.count - needle.count)).contains { start in
            haystack[start..<(start + needle.count)].elementsEqual(needle)
        }
    }
    private static func slices(_ text: String, wordLimit: Int) -> [String] {
        let tokens = wordStarts(text)
        guard !tokens.isEmpty else { return [text] }
        var result: [String] = [], start = text.startIndex
        for index in stride(from: wordLimit, to: tokens.count, by: wordLimit) {
            let end = tokens[index]
            result.append(String(text[start..<end])); start = end
        }
        result.append(String(text[start..<text.endIndex]))
        return result
    }
}
