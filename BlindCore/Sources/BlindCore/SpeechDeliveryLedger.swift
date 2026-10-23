import Foundation

/// One in-flight output, not a speech queue or an admission path. The platform
/// adapter starts only admitted text and resolves this token from real callbacks.
/// Timers may report uncertainty, never successful delivery.
public struct SpeechDeliveryLedger: Sendable {
    public enum Destination: Equatable, Sendable {
        case untracked
        case narration(UUID)
        case requested(UUID)
    }

    public enum Transport: Sendable {
        case synthesized, accessibility
    }

    public struct Attempt: Sendable {
        public let token: UUID
        public let text: String
        public let priority: SpeechPriority
        public let destination: Destination
        public let transport: Transport
        public let completionIsAmbiguous: Bool
    }

    public struct Completion: Sendable {
        public let attempt: Attempt
        public let outcome: NarrationDelivery
    }

    public private(set) var active: Attempt?
    private var seenAccessibilityText = Set<String>()
    private var echoTail: (words: [String], expiresAt: Double)?

    public init() {}

    /// Requested conversation needs cancellable utterance identity, including with
    /// VoiceOver enabled. The adapter uses prefersAssistiveTechnologySettings so
    /// VoiceOver still owns voice/rate/pitch. Ambient/control/safety announcements
    /// continue through UIKit when VoiceOver is running.
    public static func transport(for destination: Destination, priority: SpeechPriority,
                                 voiceOverRunning: Bool) -> Transport {
        guard voiceOverRunning else { return .synthesized }
        if case .requested = destination, priority.rawValue < SpeechPriority.mobility.rawValue {
            return .synthesized
        }
        return .accessibility
    }

    /// Refusal changes no active state, history or echo suppression. A higher
    /// priority producer must explicitly interrupt the old token before starting.
    @discardableResult
    public mutating func begin(text: String, priority: SpeechPriority,
                               destination: Destination = .untracked,
                               transport: Transport) -> Attempt? {
        guard active == nil, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        var ambiguous = false
        if transport == .accessibility {
            // UIKit gives text, not an utterance identifier. Reused text (and text
            // after the bounded history fills) can never prove which attempt ended.
            ambiguous = seenAccessibilityText.contains(text) || seenAccessibilityText.count >= 512
            if !ambiguous { seenAccessibilityText.insert(text) }
        }
        let attempt = Attempt(token: UUID(), text: text, priority: priority,
                              destination: destination, transport: transport,
                              completionIsAmbiguous: ambiguous)
        active = attempt
        return attempt
    }

    /// Exactly one terminal event per accepted attempt. Old finish/cancel/timeout
    /// signals cannot finish newer speech or make cancelled text count as spoken.
    @discardableResult
    public mutating func finish(token: UUID, outcome: NarrationDelivery, now: Double) -> Completion? {
        guard let attempt = active, attempt.token == token else { return nil }
        active = nil
        // A bounded residual acoustic tail helps reject delayed recognition of our
        // own output. It is not delivery evidence or speaker identification.
        echoTail = now.isFinite ? (Self.words(attempt.text), now + 1) : nil
        let resolved: NarrationDelivery = outcome == .completed && attempt.completionIsAmbiguous ? .unknown : outcome
        return Completion(attempt: attempt, outcome: resolved)
    }

    public func isLikelyOwnSpeech(_ text: String, now: Double) -> Bool {
        let words = Self.words(text)
        guard !words.isEmpty else { return false }
        if let active, Self.matches(words, output: Self.words(active.text)) { return true }
        if let echoTail, now.isFinite, now < echoTail.expiresAt, now >= echoTail.expiresAt - 1 {
            if Self.matches(words, output: echoTail.words) { return true }
            // A recognizer may keep the end of one chunk and the start of the next
            // in a single hypothesis. Retain at most this one-phrase residual tail.
            if let active, Self.matches(words, output: echoTail.words + Self.words(active.text)) { return true }
        }
        return false
    }

    private static func words(_ text: String) -> [String] {
        text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
    }

    private static func matches(_ words: [String], output: [String]) -> Bool {
        // Recognition arrives in short prefixes. Waiting for three words would
        // classify the start of our own greeting as a human interruption.
        if output.starts(with: words) { return true }
        guard words.count >= 3, words.count <= output.count else { return false }
        return (0...(output.count - words.count)).contains { index in
            output[index..<(index + words.count)].elementsEqual(words)
        }
    }
}
