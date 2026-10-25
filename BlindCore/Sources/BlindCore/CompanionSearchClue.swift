import Foundation

/// Transient ownership for an answer to one code-owned search-area question.
/// A clue is exactly what the user supplied, NOT a physical area classification,
/// object location, map binding, sensor observation or permission to move.
/// Intentionally not Codable: restart cannot restore question/answer authority.
public struct CompanionSearchClue: Sendable {
    public static let lifetime = 30.0
    public struct Binding: Equatable, Sendable {
        public let target: String
        public let key: String
        public let goalRevision: String
        public let generation: UInt64
        public let scope: CompanionMemoryScope?
        public init(target: String, goalRevision: String, generation: UInt64, scope: CompanionMemoryScope?) {
            self.target = target.trimmingCharacters(in: .whitespacesAndNewlines)
            self.key = ItemMemory.key(for: target)
            self.goalRevision = goalRevision; self.generation = generation; self.scope = scope
        }
        public var valid: Bool {
            !key.isEmpty && target.unicodeScalars.count <= ItemMemory.nameLimit &&
            !goalRevision.isEmpty && goalRevision.utf8.count <= 128 && scope?.valid != false &&
            !goalRevision.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) &&
            !target.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
        }
        public static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.key == rhs.key && lhs.goalRevision == rhs.goalRevision && lhs.generation == rhs.generation && lhs.scope == rhs.scope
        }
    }
    public enum Delivery: Equatable, Sendable { case speech, trustedText }
    public struct Question: Equatable, Sendable {
        public let id: UUID
        public let text: String
        public let binding: Binding
        public let issuedAt: Double
        public var expiresAt: Double { issuedAt + CompanionSearchClue.lifetime }
    }
    public struct Clue: Equatable, Sendable {
        public let id: UUID
        public let amendmentID: UUID
        public let questionID: UUID
        public let binding: Binding
        /// Complete input retained, including an explicit correction prefix.
        public let originalInput: String
        /// Only the explicit correction prefix is removed; no place is inferred.
        public let text: String
        public let sourceID: String
        public let at: Date
        public let supersededSourceID: String?
        /// Original question/amendment deadline, retained as provenance; this
        /// is NOT a TTL for the accepted attributed clue in its active goal.
        public let answerWindowExpiresAt: Double
        public func reply(arabic: Bool) -> String {
            arabic ? "سأستخدم «\(text)» كتلميح للبحث."
                : "I'll use «\(text)» as a search clue."
        }
    }
    public private(set) var question: Question?
    public private(set) var clue: Clue?
    public private(set) var deliveredVia: Delivery?
    private var lastNow = 0.0
    private var sourceIDs: Set<String> = []
    /// Separate one-use amendment ownership, not a reissued delivery receipt.
    private struct Amendment: Sendable {
        let id: UUID
        let clueID: UUID
        let sourceID: String
        let binding: Binding
        let answerWindowExpiresAt: Double
    }
    private var amendment: Amendment?
    public init() {}
    public mutating func clear() { self = Self() }
    /// Stop accepting answers/corrections without discarding what the user
    /// already supplied for this still-active goal. This does not renew a lease.
    public mutating func retireAnswerWindow() {
        question = nil; deliveredVia = nil; amendment = nil
    }

    /// The caller supplies only the actual code-owned reply selected AFTER
    /// memory and sensor alternatives, never a proposed or model-authored reply.
    @discardableResult public mutating func prepare(binding: Binding, text: String, now: Double) -> Question? {
        clear()
        guard binding.valid, now.isFinite, now >= 0, (now + Self.lifetime).isFinite,
              !text.isEmpty, text.unicodeScalars.count <= 400 else { return nil }
        let value = Question(id: UUID(), text: text, binding: binding, issuedAt: now)
        question = value; lastNow = now
        return value
    }
    /// Exact completed playback only. A stale callback must not retire a newer
    /// question, and duplicate completion never reopens an already consumed turn.
    @discardableResult public mutating func deliverSpeech(questionID: UUID, text: String, completed: Bool,
                                                          binding: Binding, now: Double) -> Bool {
        guard question?.id == questionID else { return false }
        guard clue == nil, deliveredVia == nil else { return false }
        guard revalidate(binding: binding, now: now), completed,
              question?.text.utf8.elementsEqual(text.utf8) == true else { clear(); return false }
        deliveredVia = .speech
        return true
    }
    /// Separate explicit trusted text interaction, NOT a spoken-delivery receipt.
    @discardableResult public mutating func presentTrustedText(questionID: UUID, text: String,
                                                               binding: Binding, origin: CompanionCommandOrigin, now: Double) -> Bool {
        guard origin == .trustedInterface, CommandAuthority.permits(.commitUserReport, from: origin) else { retireAnswerWindow(); return false }
        guard question?.id == questionID else { return false }
        guard clue == nil, deliveredVia == nil else { return false }
        guard revalidate(binding: binding, now: now),
              question?.text.utf8.elementsEqual(text.utf8) == true else { clear(); return false }
        deliveredVia = .trustedText
        return true
    }
    /// Used by the native adapter at dispatch/lifecycle boundaries as well as at
    /// answer time. No call can extend the original question's 30-second expiry.
    @discardableResult public mutating func revalidate(binding: Binding, now: Double) -> Bool {
        guard validateContext(binding: binding, now: now) else { return false }
        guard let question, now < question.expiresAt else {
            retireAnswerWindow(); return false
        }
        return true
    }
    private mutating func validateContext(binding: Binding, now: Double) -> Bool {
        guard let owned = clue?.binding ?? question?.binding, binding.valid, owned == binding,
              now.isFinite, now >= 0, now >= lastNow else { clear(); return false }
        lastNow = now
        return true
    }
    public mutating func currentClue(binding: Binding, now: Double) -> Clue? {
        guard validateContext(binding: binding, now: now) else { return nil }
        if let question, now >= question.expiresAt { retireAnswerWindow() }
        return clue
    }
    /// Existing native command/control/report routes must run first. This bounded
    /// parser only owns remaining short conversational answers; it is deliberately
    /// not a classifier of whether a word denotes a physical room or area.
    public mutating func accept(text: String, sourceID: String, at: Date, binding: Binding,
                                origin: CompanionCommandOrigin, now: Double, arabic: Bool = false) -> String? {
        guard revalidate(binding: binding, now: now) else { return nil }
        guard origin == .trustedInterface, CommandAuthority.permits(.commitUserReport, from: origin), let question,
              !sourceID.isEmpty, sourceID.utf8.count <= 64,
              !sourceID.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
              !sourceIDs.contains(sourceID), sourceIDs.count < 12,
              at.timeIntervalSinceReferenceDate.isFinite, at >= .distantPast, at <= .distantFuture,
              clue.map({ at >= $0.at }) ?? true,
              let candidate = Self.candidate(text),
              (clue == nil ? (deliveredVia != nil && !candidate.correction) : (candidate.correction && amendmentMatchesCurrentClue)) else {
            retireAnswerWindow(); return nil
        }
        // The delivery receipt is consumed once. Later explicit corrections use
        // the latest clue's source-bound amendment handle, never that receipt.
        deliveredVia = nil
        let next = Clue(id: UUID(), amendmentID: UUID(), questionID: question.id, binding: question.binding,
                        originalInput: text, text: candidate.text, sourceID: sourceID, at: at,
                        supersededSourceID: clue?.sourceID, answerWindowExpiresAt: question.expiresAt)
        sourceIDs.insert(sourceID); clue = next
        amendment = Amendment(id: next.amendmentID, clueID: next.id, sourceID: next.sourceID,
                              binding: next.binding, answerWindowExpiresAt: next.answerWindowExpiresAt)
        return next.reply(arabic: arabic)
    }

    private var amendmentMatchesCurrentClue: Bool {
        guard let clue, let amendment else { return false }
        return amendment.id == clue.amendmentID && amendment.clueID == clue.id &&
            amendment.sourceID == clue.sourceID && amendment.binding == clue.binding &&
            amendment.answerWindowExpiresAt == clue.answerWindowExpiresAt
    }

    private static let nonClueAnswers: Set<String> = ["yes", "yeah", "sure", "ok", "okay", "no", "nope", "nothing", "nowhere", "unknown", "thanks", "thank you", "hello", "hi", "hey", "good morning", "good evening", "good night", "مرحبا", "شكرا", "اهلا", "اهلا وسهلا", "صباح الخير", "مساء الخير", "dunno", "idk", "no idea", "no clue", "not really", "maybe", "perhaps", "possibly", "i don't know", "i dont know", "don't know", "dont know", "not sure", "i'm not sure", "i am not sure", "نعم", "ايوه", "اي", "اجل", "لا", "ما ادري", "لا اعرف", "لست متاكدا", "مش عارف", "مو عارف", "ما اعرف", "لا ادري", "لا اعلم", "مدري", "مادري", "يمكن", "ربما", "غير معروف"]

    private static func candidate(_ input: String) -> (text: String, correction: Bool)? {
        let original = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !original.isEmpty, original.unicodeScalars.count <= 96, original.utf8.count <= 192,
              !original.contains(where: { "?؟\n\r\"“”«»;؛:!".contains($0) }),
              !original.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
              CompanionUtterance.parse(original) == nil, AssistantControl.parse(original) == nil,
              !CompanionEvidenceGuard.explicitCompletionReport(original, latest: original),
              AssistantControl.explicitGoal(original) == nil, EverydayTaskRequest.route(original) == nil,
              ConversationIntent.explicitTaskGoal(original) == nil,
              ConversationIntent.classify(original) == .conversation else { return nil }
        var value = original.trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        // Reject whole declines BEFORE recognizing an explicit correction.
        // Otherwise "no idea" / "لا أعرف" would become invented clues "idea"
        // / "أعرف" after their negative prefix was removed.
        let whole = SpatialClaimGuard.normalizeArabic(value.lowercased())
            .replacingOccurrences(of: #"[,،]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        let unknownPrefixes = ["no idea", "no clue", "لا اعرف", "لا ادري", "لا اعلم"]
        guard !nonClueAnswers.contains(whole), AssistantControl.offerAnswer(value) == nil,
              !unknownPrefixes.contains(where: { whole == $0 || whole.hasPrefix($0 + " ") }) else { return nil }
        var correction = false
        // An explicit correction is distinct from a bare negative answer. It
        // still supplies only raw words, not an object-location report.
        let prefix = #"^(?:no|actually|instead|لا|بل|بدلا من ذلك)(?:[,،]\s*|\s+)"#
        if let range = value.range(of: prefix, options: [.regularExpression, .caseInsensitive]) {
            correction = true; value = String(value[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        }
        let normalized = SpatialClaimGuard.normalizeArabic(value.lowercased())
        let words = normalized.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !words.isEmpty, words.count <= 5,
              !value.contains(where: { ",،".contains($0) }),
              value.unicodeScalars.allSatisfy({ CharacterSet.letters.contains($0) || CharacterSet.decimalDigits.contains($0) || CharacterSet.nonBaseCharacters.contains($0) || " '-’".unicodeScalars.contains($0) }) else { return nil }
        let emptyArea: Set<String> = ["in", "at", "the", "near", "by", "on", "inside", "في", "عند", "قرب", "بجانب"]
        let bareAffirmation: Set<String> = ["yes", "yeah", "sure", "ok", "okay", "please", "نعم", "ايوه", "اي", "اجل"]
        guard !words.allSatisfy({ bareAffirmation.contains($0) }),
              !words.allSatisfy({ emptyArea.contains($0) }),
              !CompanionEvidenceGuard.explicitCompletionReport(value, latest: value),
              !nonClueAnswers.contains(normalized), AssistantControl.offerAnswer(value) == nil,
              CompanionUtterance.parse(value) == nil, AssistantControl.parse(value) == nil,
              AssistantControl.explicitGoal(value) == nil, EverydayTaskRequest.route(value) == nil,
              ConversationIntent.explicitTaskGoal(value) == nil,
              ConversationIntent.classify(value) == .conversation else { return nil }
        // Do not swallow short new questions/requests just because they fit a
        // word budget. These are conservative conversational exclusions, not a
        // complete intent classifier or evidence that accepted words name a place.
        let newTurnHeads: Set<String> = ["what", "where", "when", "why", "who", "how", "which", "can", "could", "would", "will", "do", "does", "did", "is", "are", "am", "was", "were", "tell", "explain", "help", "find", "locate", "search", "show", "read", "describe", "open", "close", "stop", "cancel", "pause", "resume", "go", "take", "turn", "set", "play", "talk", "change", "thank", "sing", "write", "draw", "calculate", "translate", "call", "send", "please", "not", "never", "don't", "dont", "i", "we", "you", "ماذا", "ما", "من", "كيف", "اين", "وين", "متي", "متى", "لماذا", "هل", "اشرح", "ساعدني", "ابحث", "افتح", "اغلق", "توقف", "الغ", "انتظر", "اقرا", "قل", "اخبرني", "حدثني", "تحدث", "غير", "صف", "اذهب", "انا", "نحن", "انت", "ليس", "ليست", "مو", "مش"]
        guard !newTurnHeads.contains(words[0]) else { return nil }
        return (value, correction)
    }
}
