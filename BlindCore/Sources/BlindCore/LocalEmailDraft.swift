import Foundation

/// Literal user-owned draft edits. No model intent parsing, recipient lookup,
/// message generation or send command is exposed by this syntax.
public enum LocalEmailDraftCommand: Equatable, Sendable {
    case recipient(String), subject(String), body(String), append(String)
    case readRecipient, readSubject, readBody, nextPart, previousPart
    case checkpoint, undo, discard, handoff

    /// Consume this private namespace BEFORE ordinary input diagnostics/history
    /// or an unverified-microphone model fallback, including malformed commands.
    public static func isPrivateInput(_ raw: String) -> Bool {
        let text = raw.lowercased()
        return text.contains("email draft") || text.contains("مسودة البريد")
    }
    /// Also used by the earlier ASR-final diagnostic boundary, before the
    /// controller receives the turn. Ordinary diagnostic content is unchanged.
    public static func diagnosticText(_ raw: String) -> String? {
        isPrivateInput(raw) ? nil : raw
    }
    public static func parse(_ raw: String) -> Self? {
        guard raw.unicodeScalars.count <= AssistantDialogue.maximumTurnScalars else { return nil }
        let text = String(raw.drop(while: { $0.isWhitespace }))
        let lower = text.lowercased()
        let edits: [(String, (String) -> Self)] = [
            ("email draft recipient: ", Self.recipient), ("email draft subject: ", Self.subject),
            ("replace email draft body: ", Self.body), ("append email draft body: ", Self.append),
            ("مستلم مسودة البريد: ", Self.recipient), ("موضوع مسودة البريد: ", Self.subject),
            ("استبدل نص مسودة البريد: ", Self.body), ("أضف إلى نص مسودة البريد: ", Self.append)
        ]
        for (prefix, make) in edits where lower.hasPrefix(prefix) {
            let literal = String(text.dropFirst(prefix.count))
            guard !literal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return make(literal) // preserve case, punctuation and literal content
        }
        var value = lower.trimmingCharacters(in: .whitespacesAndNewlines)
        if let last = value.last, ".!?؟".contains(last) { value.removeLast() }
        let commands: [(Self, [String])] = [
            (.readRecipient, ["read email draft recipient", "اقرأ مستلم مسودة البريد"]),
            (.readSubject, ["read email draft subject", "اقرأ موضوع مسودة البريد"]),
            (.readBody, ["read email draft body", "اقرأ نص مسودة البريد"]),
            (.nextPart, ["next email draft part", "الجزء التالي من مسودة البريد"]),
            (.previousPart, ["previous email draft part", "الجزء السابق من مسودة البريد"]),
            (.checkpoint, ["checkpoint email draft", "احفظ نقطة تراجع لمسودة البريد"]),
            (.undo, ["undo email draft", "تراجع عن تعديل مسودة البريد"]),
            (.discard, ["discard email draft", "احذف مسودة البريد"]),
            (.handoff, ["review email draft in mail", "راجع مسودة البريد في تطبيق البريد"])
        ]
        return commands.first { $0.1.contains(value) }?.0
    }
}

/// Extracted from the existing local email helper's fields/checkpoints and
/// immutable Mail-review snapshot. Volatile only; intentionally not Codable.
public struct LocalEmailDraft: Sendable {
    public static let maximumBodyBytes = 32 * 1024
    public static let maximumCheckpoints = 5
    public static let responseLifetime: Double = 60
    public enum Field: Equatable, Sendable { case recipient, subject, body }
    public enum MailOutcome: Equatable, Sendable { case cancelled, saved, queued, failed, unknown }
    public struct Content: Equatable, Sendable {
        public var recipient = ""
        public var subject = ""
        public var body = ""
        public init() {}
        public var permitsMailReview: Bool {
            !recipient.isEmpty && recipient.utf8.count <= 254 &&
            !recipient.unicodeScalars.contains(where: { CharacterSet.whitespacesAndNewlines.contains($0) || CharacterSet.controlCharacters.contains($0) }) &&
            recipient.filter({ $0 == "@" }).count == 1 &&
            subject.utf8.count <= 500 && !subject.contains("\n") && !subject.contains("\r") &&
            body.utf8.count <= LocalEmailDraft.maximumBodyBytes &&
            !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    public struct Snapshot: Equatable, Sendable {
        public let id: UUID
        public let revision: UUID
        public let generation: UInt64
        public let content: Content
    }
    public struct Handoff: Identifiable, Equatable, Sendable {
        public let id: UUID
        public let snapshot: Snapshot
    }
    public struct Response: Equatable, Sendable {
        public let id: UUID
        public let snapshot: Snapshot
        public let text: String
        public let issuedAt: Double
    }
    public private(set) var snapshot: Snapshot?
    public private(set) var commandsEnabled = false
    public private(set) var checkpointCount = 0
    public private(set) var handoff: Handoff?
    public private(set) var response: Response?
    private var history: [Content] = []
    private var review: (revision: UUID, field: Field, index: Int)?
    public init() {}

    @discardableResult public mutating func open(generation: UInt64, origin: CompanionCommandOrigin) -> Snapshot? {
        guard origin == .trustedInterface else { return nil }
        if let snapshot, snapshot.generation == generation { return snapshot }
        clear()
        let value = Snapshot(id: UUID(), revision: UUID(), generation: generation, content: Content())
        snapshot = value; return value
    }
    public func owns(_ expected: Snapshot, generation: UInt64) -> Bool {
        snapshot == expected && expected.generation == generation
    }
    @discardableResult public mutating func enable(_ expected: Snapshot, generation: UInt64,
        origin: CompanionCommandOrigin) -> Bool {
        guard origin == .trustedInterface, owns(expected, generation: generation), handoff == nil else { return false }
        commandsEnabled = true; return true
    }
    @discardableResult public mutating func edit(_ field: Field, value: String, expected: Snapshot,
        generation: UInt64, origin: CompanionCommandOrigin, checkpoint: Bool = false) -> Bool {
        guard origin == .trustedInterface, owns(expected, generation: generation), handoff == nil else { return false }
        let limit = field == .body ? Self.maximumBodyBytes : field == .recipient ? 254 : 500
        guard value.utf8.count <= limit,
              !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) && (field != .body || ($0 != "\n" && $0 != "\t")) }) else { return false }
        var updated = expected.content
        switch field { case .recipient: updated.recipient = value; case .subject: updated.subject = value; case .body: updated.body = value }
        guard updated != expected.content else { return true }
        if checkpoint { saveCheckpointContent(expected.content) }
        replace(updated, expected: expected)
        return true
    }
    @discardableResult public mutating func saveCheckpoint(expected: Snapshot, generation: UInt64,
        origin: CompanionCommandOrigin) -> Bool {
        guard origin == .trustedInterface, owns(expected, generation: generation), handoff == nil else { return false }
        saveCheckpointContent(expected.content); return true
    }
    @discardableResult public mutating func undo(expected: Snapshot, generation: UInt64,
        origin: CompanionCommandOrigin) -> Bool {
        guard origin == .trustedInterface, owns(expected, generation: generation), handoff == nil,
              let prior = history.popLast() else { return false }
        checkpointCount = history.count; replace(prior, expected: expected); return true
    }
    private mutating func saveCheckpointContent(_ content: Content) {
        if history.last != content { history.append(content) }
        if history.count > Self.maximumCheckpoints { history.removeFirst(history.count - Self.maximumCheckpoints) }
        checkpointCount = history.count
    }
    private mutating func replace(_ content: Content, expected: Snapshot) {
        snapshot = Snapshot(id: expected.id, revision: UUID(), generation: expected.generation, content: content)
        response = nil; review = nil
    }
    public mutating func retireResponse() { response = nil }
    public mutating func clear() { self = Self() }

    /// The existing system composer is a review handoff, never a send API.
    @discardableResult public mutating func beginHandoff(expected: Snapshot, generation: UInt64,
        origin: CompanionCommandOrigin) -> Handoff? {
        guard origin == .trustedInterface, owns(expected, generation: generation),
              handoff == nil, expected.content.permitsMailReview else { return nil }
        response = nil
        let value = Handoff(id: UUID(), snapshot: expected); handoff = value; return value
    }
    public func ownsHandoff(_ expected: Handoff, generation: UInt64) -> Bool {
        handoff == expected && owns(expected.snapshot, generation: generation)
    }
    @discardableResult public mutating func finishHandoff(_ expected: Handoff, generation: UInt64) -> Bool {
        guard ownsHandoff(expected, generation: generation) else { return false }
        handoff = nil; return true
    }

    /// One explicit review part per request. Long drafts can be reviewed without
    /// an unbounded auto-reading loop; mutation resets the review cursor.
    public mutating func read(_ command: LocalEmailDraftCommand, expected: Snapshot,
        generation: UInt64, origin: CompanionCommandOrigin, uptime: Double, arabic: Bool) -> Response? {
        guard origin == .trustedInterface, commandsEnabled, owns(expected, generation: generation),
              handoff == nil, uptime.isFinite, uptime >= 0 else { return nil }
        response = nil
        let field: Field
        let index: Int
        switch command {
        case .readRecipient: field = .recipient; index = 0
        case .readSubject: field = .subject; index = 0
        case .readBody: field = .body; index = 0
        case .nextPart, .previousPart:
            guard let review, review.revision == expected.revision else { return nil }
            field = review.field; index = review.index + (command == .nextPart ? 1 : -1)
        default: return nil
        }
        let source: String, fieldName: String
        switch field {
        case .recipient: source = expected.content.recipient; fieldName = arabic ? "المستلم" : "recipient"
        case .subject: source = expected.content.subject; fieldName = arabic ? "الموضوع" : "subject"
        case .body: source = expected.content.body; fieldName = arabic ? "النص" : "body"
        }
        let prefix = arabic ? "مسودتك، \(fieldName)، جزء 000 من 000: «" : "Your draft \(fieldName), part 000 of 000: «"
        guard let parts = BoundedReferenceChunkPlan.make(text: source, prefix: prefix,
            maximumUTF8Bytes: Self.maximumBodyBytes, phraseWordLimit: 30),
            parts.allSatisfy({ $0.attributed.utf8.count <= 4000 }), parts.indices.contains(index) else { return nil }
        review = (expected.revision, field, index)
        let label = arabic ? "مسودتك، \(fieldName)، جزء \(index + 1) من \(parts.count): «"
            : "Your draft \(fieldName), part \(index + 1) of \(parts.count): «"
        let text = label + parts[index].original + "»"
        let value = Response(id: UUID(), snapshot: expected, text: text, issuedAt: uptime)
        response = value; return value
    }
    public func validates(_ value: Response, generation: UInt64, uptime: Double) -> Bool {
        value == response && owns(value.snapshot, generation: generation) && handoff == nil &&
        uptime.isFinite && uptime >= value.issuedAt && uptime - value.issuedAt < Self.responseLifetime
    }
}
