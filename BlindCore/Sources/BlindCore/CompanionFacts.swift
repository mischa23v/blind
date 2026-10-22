import Foundation

/// Conversation facts owned by code (2026-10-22 hallucination fix). The language model never
/// decides where an object is: the child's find requests and location reports are parsed here,
/// stored with their time, and every sentence about them is rendered by code. A child's report is
/// always spoken back as something they said at a time, never as where the object is now.
/// Mirrors server/src/companion-guards.mjs; both run Tests/BlindCoreTests/Fixtures/companion-evidence.json.
public enum CompanionUtterance: Equatable, Sendable {
    case find(object: String)
    /// `object` is nil for "it"/"them"; the caller resolves it from the current goal.
    case report(object: String?, place: String, tense: CompanionFact.Tense, hedged: Bool)

    private static func regex(_ pattern: String) -> NSRegularExpression {
        // Patterns are constants covered by the shared fixture tests.
        try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }
    private static let place = #"((?:on top of|in front of|next to|on|in|under|underneath|inside|behind|beside|near|by|at)\s+.+)"#
    private static let arPlace = #"((?:على|علي|في|تحت|عند|جنب|بجانب|قرب|فوق|داخل|ورا|وراء|خلف|[اأ]مام)\s+.+|بال\S.*)"#
    private static let findPatterns = [
        regex(#"^(?:(?:can|could|will|would) you\s+)?(?:please\s+)?(?:help me\s+)?(?:to\s+)?(?:find|look for|search for|locate)\s+(?:my|our)\s+(.+)$"#),
        regex(#"^i\s+(?:can't|cannot|can not|couldn't|could not)\s+find\s+(?:my|our)\s+(.+)$"#),
        regex(#"^i(?:'ve| have)?\s+lost\s+(?:my|our)\s+(.+)$"#),
        regex(#"^i(?:'m| am)\s+looking for\s+(?:my|our)\s+(.+)$"#),
        regex(#"^(?:ساعدني|ساعديني)\s+(?:[اأ]لاقي|[اأ]لقى|[اأ]جد|[اأ]دور على|[اأ]بحث عن|في البحث عن)\s+(.+)$"#),
        regex(#"^(?:ما|مو)\s+(?:لقيت|حصلت|[اأ]جد|[اأ]لقى)\s+(.+)$"#),
        regex(#"^(?:ضاع|ضاعت|فقدت|[اأ]ضعت)\s+(.+)$"#)
    ]
    private static let reportAction = regex(#"^i\s+(?:last\s+|just\s+)?(?:left|put|placed|dropped|set|had|kept|saw|forgot)\s+(?:(?:my|the|our)\s+(.+?)|(it|them))\s+"# + place + "$")
    private static let reportState = regex(#"^(?:(?:my|the|our)\s+(.+?)|(it|they))(?:\s+(is|are|was|were)|('s))\s+(?:still\s+)?"# + place + "$")
    private static let arReportAction = regex(#"^(?:تركت|حطيت|وضعت|نسيت|خليت)(ه|ها|هم)?\s+(?:(.+?)\s+)??"# + arPlace + "$")
    private static let hedgePrefix = regex(#"^(?:i think|i guess|maybe|probably)\s+(?:that\s+)?"#)
    private static let arHedgePrefix = regex(#"^(?:[اأ]ظن|[اأ]عتقد|يمكن|ربما)\s+(?:[اأ]ن(?:ي|ه|ها)?\s+)?"#)
    private static let trailing = regex(#"\s+(?:please|again|now|for me|right now|instead|too|as well)$"#)
    private static let questionEnd = regex(#"[?؟]\s*$"#)
    private static let trailingPunctuation = regex(#"[\s.!?؟,،;؛]+$"#)
    private static let leadingFiller = regex(#"^(?:okay|ok|um|so|and)[\s,]+"#)

    /// Groups of the first match; nil entries are groups that did not take part.
    static func groups(_ pattern: NSRegularExpression, _ text: String) -> [String?]? {
        guard let match = pattern.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return (0..<match.numberOfRanges).map { index in
            let range = match.range(at: index)
            guard range.location != NSNotFound, let bounds = Range(range, in: text) else { return nil }
            return String(text[bounds])
        }
    }
    private static func replacing(_ pattern: NSRegularExpression, in text: String) -> String {
        pattern.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
    }

    /// Sentences are tried from last to first, so "I changed my mind. Help me find my backpack"
    /// finds the backpack. Questions are never reports.
    public static func parse(_ raw: String) -> CompanionUtterance? {
        let text = raw.replacingOccurrences(of: "\u{2019}", with: "'").replacingOccurrences(of: "\u{2018}", with: "'")
        let parts = SpatialClaimGuard.sentences(text).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        for part in parts.reversed() { if let parsed = parseSentence(part) { return parsed } }
        return nil
    }

    private static func parseSentence(_ sentence: String) -> CompanionUtterance? {
        let question = groups(questionEnd, sentence) != nil
        var text = replacing(leadingFiller, in: replacing(trailingPunctuation, in: sentence)).trimmingCharacters(in: .whitespacesAndNewlines)
        for pattern in findPatterns {
            if let match = groups(pattern, text) {
                return match[1].flatMap(cleanObject).map { CompanionUtterance.find(object: $0) }
            }
        }
        if question { return nil }
        var hedged = false
        for prefix in [hedgePrefix, arHedgePrefix] {
            if let match = groups(prefix, text), let whole = match[0] {
                hedged = true; text = String(text.dropFirst(whole.count))
            }
        }
        if let match = groups(reportAction, text) {
            return report(match[1], match[3], .earlier, hedged)
        }
        if let match = groups(reportState, text) {
            let verb = (match[3] ?? "is").lowercased()
            return report(match[1], match[5], verb == "was" || verb == "were" ? .earlier : .current, hedged)
        }
        if let match = groups(arReportAction, text) {
            return report(match[1] != nil ? nil : match[2], match[3], .earlier, hedged)
        }
        return nil
    }

    private static func cleanObject(_ value: String) -> String? {
        let object = replacing(trailing, in: value).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !object.isEmpty, object.count <= 40, object.split(whereSeparator: { $0.isWhitespace }).count <= 4 else { return nil }
        return object
    }

    private static func report(_ objectText: String?, _ placeText: String?, _ tense: CompanionFact.Tense, _ hedged: Bool) -> CompanionUtterance? {
        let object = objectText.flatMap(cleanObject)
        let place = placeText.map { replacing(trailing, in: $0).trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
        guard objectText == nil || object != nil, !place.isEmpty, place.count <= 80 else { return nil }
        return .report(object: object, place: place, tense: tense, hedged: hedged)
    }
}

/// One location the child reported. Not a sensor observation and not proof of where the object is.
public struct CompanionFact: Codable, Equatable, Sendable {
    public enum Tense: String, Codable, Sendable {
        /// "I last left it on the table": where it was when they last had it.
        case earlier
        /// "My cup is on the table": what the child believed at the time they said it.
        case current
    }
    public let object: String
    public let key: String
    public let place: String
    public let tense: Tense
    public let hedged: Bool
    public let at: Date

    /// "were" for "shoes" or "cup and plate"; "was" for "glass" or "cup".
    private var verb: String {
        let lower = object.lowercased()
        return lower.contains(" and ") || (lower.hasSuffix("s") && !lower.hasSuffix("ss")) ? "were" : "was"
    }

    /// Spoken immediately after the report. Attributes the location to the child.
    public func acknowledgement(arabic: Bool) -> String {
        let name = ItemMemory.displayName(object, arabic: arabic)
        if arabic {
            let said = hedged ? "تظن أن" : "قلت إن"
            return "حسناً. \(said) \(name) كان \(place). سأتذكر ذلك."
        }
        switch (tense, hedged) {
        case (.earlier, false): return "Got it. You last had your \(name) \(place). I'll remember that."
        case (.earlier, true): return "Got it. You think you last had your \(name) \(place). I'll remember that."
        case (.current, false): return "Got it. You said your \(name) \(verb) \(place). I'll remember that."
        case (.current, true): return "Got it. You thought your \(name) \(verb) \(place). I'll remember that."
        }
    }

    /// Spoken when the child asks again later. Always past tense with the time it was said.
    public func recall(now: Date, arabic: Bool) -> String {
        let name = ItemMemory.displayName(object, arabic: arabic)
        let elapsed = ItemMemory.relativeTime(from: at, to: now, arabic: arabic)
        if arabic {
            return "قلت لي \(elapsed) إن \(name) كان \(place). لا أعرف مكانه الآن."
        }
        let thought = hedged ? "you thought " : ""
        let report = tense == .earlier ? "\(thought)you last had your \(name) \(place)" : "\(thought)your \(name) \(verb) \(place)"
        return "You told me \(elapsed) \(report). I don't know where it is now."
    }

    /// Spoken when nothing is known about the object.
    public static func unknown(object: String, arabic: Bool) -> String {
        let name = ItemMemory.displayName(object, arabic: arabic)
        return arabic ? "لا أعرف مكان \(name) بعد. أين كان آخر مرة؟"
            : "I don't know where your \(name) is yet. Where did you last have it?"
    }
}

/// Small on-phone list of the child's location reports, newest per object.
public struct CompanionFactBook: Codable, Equatable, Sendable {
    public static let limit = 24
    public private(set) var facts: [CompanionFact] = []
    public init() {}

    /// Saves a report; the same object replaces its earlier report. Nil when empty or too long.
    @discardableResult
    public mutating func record(object: String, place: String, tense: CompanionFact.Tense, hedged: Bool, at: Date = Date()) -> CompanionFact? {
        let object = object.trimmingCharacters(in: .whitespacesAndNewlines)
        let place = place.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = ItemMemory.key(for: object)
        guard !key.isEmpty, object.count <= ItemMemory.nameLimit, !place.isEmpty, place.count <= 80 else { return nil }
        let fact = CompanionFact(object: object, key: key, place: place, tense: tense, hedged: hedged, at: at)
        facts.removeAll { $0.key == key }
        facts.append(fact)
        facts = Array(facts.suffix(Self.limit))
        return fact
    }

    /// Exact normalized match first, then a whole-word match either way, newest first.
    public func latest(for object: String) -> CompanionFact? {
        let key = ItemMemory.key(for: object)
        guard !key.isEmpty else { return nil }
        if let exact = facts.last(where: { $0.key == key }) { return exact }
        let words = key.split(separator: " ").map(String.init)
        return facts.last(where: { fact in
            let factWords = fact.key.split(separator: " ").map(String.init)
            return ItemMemory.containsRun(factWords, words) || ItemMemory.containsRun(words, factWords)
        })
    }

    @discardableResult
    public mutating func forget(_ object: String) -> Bool {
        let key = ItemMemory.key(for: object)
        let before = facts.count
        facts.removeAll { $0.key == key }
        return facts.count != before
    }
}
