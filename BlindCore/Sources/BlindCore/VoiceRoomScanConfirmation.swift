import Foundation

/// A narrow, transient two-turn gate for starting the existing room scanner.
/// This is application-specific confirmation policy, not a speech recognizer or
/// proof of who spoke or whom they addressed. Acoustic recognition cannot establish
/// the addressee. The caller must read the requested room back, ask explicitly before
/// starting, call `promptDidFinish` only for that prompt's matching completed speech,
/// and pass each completed user turn once. Never pass partial transcripts,
/// model output, OCR, or a tool's arguments as `.directUser`.
///
/// Use one monotonic clock. Clear this gate on session, profile, goal, microphone,
/// camera, or foreground lifecycle changes and when the prompt cannot be delivered.
/// A room name is only a label, not evidence of room identity, geometry or safety.
public struct VoiceRoomScanConfirmation: Sendable {
    public enum Source: Equatable, Sendable {
        case directUser
        case modelTool
        case observedContent
    }

    public enum Action: Equatable, Sendable {
        case requestConfirmation(name: String?)
        case start(name: String?)
        /// Finish an active scan through the scanner's normal save path.
        case stop
        /// Withdraw confirmation or discard an active scan; never save it.
        case cancel
        case none
    }

    private struct Pending: Sendable {
        let name: String?
        let requestedAt: Double
        var latestEventAt: Double
        var promptFinishedAt: Double?
    }

    public static let confirmationWindow: Double = 20
    /// Bounds undelivered prompts without using the listener's speech-speed setting.
    public static let maximumPromptDeliveryWindow: Double = 300
    private var pending: Pending?

    public init() {}

    /// Indicates a retained request, not proof it is still within the time window.
    /// Freshness is always checked again when the next completed turn arrives.
    public var hasPendingConfirmation: Bool { pending != nil }

    public mutating func cancel() { pending = nil }

    /// Arms the response window after delivery, never at request/queue time. The caller
    /// must match the current prompt speech ID, session and goal before invoking this.
    /// Duplicate callbacks never renew the window. Invalid/backward times cancel it.
    @discardableResult
    public mutating func promptDidFinish(now: Double) -> Bool {
        guard var request = pending else { return false }
        guard now.isFinite, now >= 0, now >= request.latestEventAt else {
            pending = nil
            return false
        }
        if let finishedAt = request.promptFinishedAt {
            if now - finishedAt > Self.confirmationWindow {
                pending = nil
            } else {
                request.latestEventAt = now
                pending = request
            }
            return false
        }
        guard now - request.requestedAt <= Self.maximumPromptDeliveryWindow else {
            pending = nil
            return false
        }
        request.promptFinishedAt = now
        request.latestEventAt = now
        pending = request
        return true
    }

    /// Only a separate, exact affirmative to a fresh pending request returns `.start`.
    /// Every direct-user turn consumes that request, including malformed, unrelated,
    /// quoted, negative and expired replies. A replacement scan request asks again.
    /// Non-user inputs cannot create, confirm, stop, cancel or replace the action.
    public mutating func consume(_ text: String, source: Source, now: Double) -> Action {
        guard source == .directUser else { return .none }
        let request = pending
        pending = nil
        guard let utterance = Self.utterance(text) else { return .none }

        // Cancellation/discard must never reach the scanner's finish-and-save path.
        // Neither stopping nor cancellation requires a valid clock.
        if Self.cancelPhrases.contains(utterance.normalized)
            || (request != nil && Self.cancelReplies.contains(utterance.normalized)) {
            return .cancel
        }
        if Self.stopPhrases.contains(utterance.normalized) {
            return .stop
        }
        guard now.isFinite, now >= 0 else { return .none }

        if let request, now < request.latestEventAt { return .none }
        if let request, let finishedAt = request.promptFinishedAt,
           now - finishedAt <= Self.confirmationWindow,
           Self.confirmReplies.contains(utterance.normalized) {
            return .start(name: request.name)
        }

        guard let command = Self.scanRequest(utterance) else { return .none }
        pending = Pending(name: command.name, requestedAt: now, latestEventAt: now, promptFinishedAt: nil)
        return .requestConfirmation(name: command.name)
    }

    private struct Utterance {
        let words: [String]
        let normalized: String
    }

    private static func utterance(_ text: String) -> Utterance? {
        guard text.unicodeScalars.count <= 256 else { return nil }
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Never strip quotation marks to turn quoted speech into a command. Question
        // punctuation, additional sentences and clause punctuation are not commands.
        let forbidden = CharacterSet(charactersIn: "\"'‘’“”«»‹›`?؟:：;؛,،()[]{}\\/")
            .union(.newlines).union(.controlCharacters)
        guard !value.isEmpty, value.rangeOfCharacter(from: forbidden) == nil else { return nil }
        if value.last == "." || value.last == "!" { value.removeLast() }
        guard value.rangeOfCharacter(from: CharacterSet(charactersIn: ".!")) == nil else { return nil }
        let words = value.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !words.isEmpty else { return nil }
        return Utterance(words: words, normalized: normalize(words.joined(separator: " ")))
    }

    private static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: "أ", with: "ا")
            .replacingOccurrences(of: "إ", with: "ا")
            .replacingOccurrences(of: "آ", with: "ا")
            .replacingOccurrences(of: "ـ", with: "")
    }

    private struct ScanRequest {
        let name: String?
    }

    private static func scanRequest(_ utterance: Utterance) -> ScanRequest? {
        for prefix in startPhrases {
            if utterance.normalized == prefix { return ScanRequest(name: nil) }
            guard utterance.normalized.hasPrefix(prefix + " ") else { continue }
            var nameWords = Array(utterance.words.dropFirst(prefix.split(separator: " ").count))
            if let first = nameWords.first, nameIntroducers.contains(normalize(first)) {
                nameWords.removeFirst()
            }
            guard !nameWords.isEmpty, nameWords.count <= 6 else { return nil }
            let name = nameWords.joined(separator: " ")
            let allowed = CharacterSet.letters.union(.decimalDigits).union(.nonBaseCharacters)
                .union(CharacterSet(charactersIn: " -"))
            guard name.unicodeScalars.count <= 64,
                  name.rangeOfCharacter(from: allowed.inverted) == nil,
                  name.unicodeScalars.contains(where: { CharacterSet.letters.contains($0) }),
                  !nameWords.contains(where: { disallowedNameWords.contains(normalize($0)) }) else { return nil }
            return ScanRequest(name: name)
        }
        return nil
    }

    // Entire utterances only. Prefix matching is solely for a short optional label,
    // never for an arbitrary instruction body. Longer prefixes precede shorter ones.
    private static let startPhrases = [
        "start scanning the room", "start scanning room", "start a room scan",
        "start the room scan", "start room scan", "start scan room",
        "scan the room", "scan room", "scan this room", "scan my room",
        "ابدا مسح الغرفة", "ابدا مسح غرفة", "ابدا فحص الغرفة", "ابدا فحص غرفة",
        "امسح الغرفة", "امسح غرفة", "امسح هذه الغرفة"
    ]
    private static let nameIntroducers: Set<String> = ["named", "called", "باسم", "اسمها"]
    private static let confirmReplies: Set<String> = [
        "yes", "yes please", "yes start", "yes start scanning", "yes start the scan",
        "start", "start scanning", "start scan", "start the scan",
        "نعم", "نعم ابدا", "نعم ابدا المسح", "ابدا", "ابدا المسح"
    ]
    private static let cancelReplies: Set<String> = [
        "no", "no thanks", "no thank you", "not now", "cancel", "stop",
        "لا", "لا شكرا", "ليس الان", "الغ", "الغاء", "توقف"
    ]
    private static let stopPhrases: Set<String> = [
        "stop scanning", "stop scan", "stop the scan", "stop room scan", "stop the room scan",
        "اوقف المسح", "اوقف مسح الغرفة", "اوقف مسح غرفة", "توقف عن المسح"
    ]
    private static let cancelPhrases: Set<String> = [
        "cancel scanning", "cancel scan", "cancel the scan", "cancel room scan",
        "الغ المسح", "الغ مسح الغرفة", "الغ فحص الغرفة"
    ]

    // Reject common conversational, conditional, negated, quoted-as-discussion and
    // third-person tails rather than treating them as room labels. This deliberately
    // rejects some valid labels. It is not exhaustive semantic/addressee detection.
    private static let disallowedNameWords: Set<String> = [
        "if", "unless", "when", "while", "after", "before", "later", "tomorrow",
        "maybe", "perhaps", "would", "could", "should", "can", "might", "will",
        "not", "no", "never", "dont", "do", "does", "did", "was", "were", "is", "are",
        "i", "we", "you", "he", "she", "they", "it", "said", "says", "say", "told",
        "tell", "talk", "talking", "discuss", "discussing", "mean", "means", "example",
        "and", "or", "but", "then", "because", "with", "without", "for", "to", "please",
        "اذا", "لو", "لما", "عندما", "حين", "بينما", "بعد", "قبل", "لاحقا", "غدا", "بكرة",
        "ربما", "يمكن", "ممكن", "لا", "ليس", "لن", "لم", "مو", "مش", "ما", "ابدا",
        "انا", "نحن", "انت", "انتي", "هو", "هي", "هم", "قال", "قالت", "قلت", "يقول",
        "قل", "اخبر", "اتكلم", "نتكلم", "نتحدث", "اقصد", "مثلا", "ثم", "لكن", "لان", "مع", "بدون"
    ]
}
