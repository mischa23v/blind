import Foundation

/// Intent and retry fencing only. This does not recognize speech, manage an
/// AVAudioSession, or promise that iOS will keep a background process running.
public struct VoiceCaptureRecoveryPolicy: Sendable {
    public struct Retry: Equatable, Sendable {
        public let session: UUID
        public let token: UUID
        public let delay: TimeInterval
    }

    public private(set) var session = UUID()
    public private(set) var requested = false
    public private(set) var continuous = false
    public private(set) var interrupted = false
    public private(set) var mediaServicesAvailable = true
    public private(set) var attempts = 0
    private var pendingRetry: UUID?
    private var healthySince: TimeInterval?

    public init() {}

    @discardableResult public mutating func begin(continuous: Bool) -> UUID {
        cancel()
        requested = true
        self.continuous = continuous
        return session
    }

    public mutating func cancel() {
        session = UUID()
        requested = false; continuous = false; interrupted = false
        mediaServicesAvailable = true; attempts = 0
        pendingRetry = nil; healthySince = nil
    }

    /// A disconnected private audio route is an explicit privacy stop, not a
    /// recoverable interruption. Only a new user-started session may listen again.
    public mutating func privateRouteLost() { cancel() }

    public func allowsCapture(session: UUID, inBackground: Bool, backgroundAllowed: Bool) -> Bool {
        requested && self.session == session && !interrupted && mediaServicesAvailable &&
            (!inBackground || backgroundAllowed)
    }

    public mutating func captureStarted(at now: TimeInterval) {
        pendingRetry = nil
        healthySince = now
    }

    /// A short successful start or partial transcript does not reset backoff.
    /// Only a sustained healthy capture interval replenishes the retry budget.
    public mutating func nextRetry(inBackground: Bool, backgroundAllowed: Bool, now: TimeInterval) -> Retry? {
        guard continuous, allowsCapture(session: session, inBackground: inBackground,
                                        backgroundAllowed: backgroundAllowed) else { return nil }
        if let healthySince, now.isFinite, now - healthySince >= 30 { attempts = 0 }
        healthySince = nil
        pendingRetry = nil
        guard attempts < 3 else { cancel(); return nil }
        attempts += 1
        let token = UUID(); pendingRetry = token
        return Retry(session: session, token: token, delay: pow(2, Double(attempts - 1)))
    }

    public mutating func claim(_ retry: Retry, inBackground: Bool, backgroundAllowed: Bool) -> Bool {
        guard retry.token == pendingRetry,
              allowsCapture(session: retry.session, inBackground: inBackground,
                            backgroundAllowed: backgroundAllowed) else { return false }
        pendingRetry = nil
        return true
    }

    public mutating func interruptionBegan() {
        guard requested else { return }
        interrupted = true; pendingRetry = nil; healthySince = nil
    }

    @discardableResult public mutating func interruptionEnded(shouldResume: Bool) -> Bool {
        guard requested, interrupted else { return false }
        guard continuous, shouldResume else { cancel(); return false }
        interrupted = false
        return true
    }

    public mutating func mediaServicesLost() {
        guard requested else { return }
        mediaServicesAvailable = false; pendingRetry = nil; healthySince = nil
    }

    public mutating func mediaServicesReset() { mediaServicesAvailable = true }
}

/// Evidence from an on-device recognizer, not an acoustic voice activity detector.
/// Echo decisions come from the speech-output owner and cannot identify a speaker.
public struct VoiceUtteranceTracker: Sendable {
    public private(set) var text = ""
    public private(set) var hasUserSpeech = false
    public private(set) var ignored = false

    public init() {}

    /// Returns true once for the first nonempty, non-echo hypothesis in this turn.
    /// An unchanged rejected hypothesis stays rejected after playback ends.
    @discardableResult public mutating func observe(_ hypothesis: String, isEcho: Bool) -> Bool {
        let next = hypothesis.trimmingCharacters(in: .whitespacesAndNewlines)
        let wasRejected = ignored && next == text
        text = next
        ignored = isEcho || wasRejected
        guard !next.isEmpty, !ignored, !hasUserSpeech else { return false }
        hasUserSpeech = true
        return true
    }

    public func deliverable(isEcho: Bool) -> String? {
        guard !text.isEmpty, !ignored, !isEcho else { return nil }
        return text
    }
}
