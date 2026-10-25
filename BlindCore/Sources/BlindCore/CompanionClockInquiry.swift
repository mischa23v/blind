import Foundation

/// Bounded, whole-utterance routing for a read-only device-clock question. This
/// is not speaker verification, a general intent classifier, or an action tool.
/// A recognized inquiry must be handled before any goal/search/task mutation.
public enum CompanionClockInquiry {
    public static func recognizes(_ question: String) -> Bool {
        guard !question.isEmpty, question.unicodeScalars.count <= 300,
              !question.unicodeScalars.contains(where: {
                  CharacterSet.controlCharacters.contains($0) || $0.properties.generalCategory == .format
              }) else { return false }
        var text = SpatialClaimGuard.normalizeArabic(question.lowercased())
            .replacingOccurrences(of: "’", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".!?؟،,؛;:"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        text = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        for prefix in ["please ", "من فضلك ", "لو سمحت "] where text.hasPrefix(prefix) {
            text.removeFirst(prefix.count)
        }
        for suffix in [" please", " من فضلك", " لو سمحت"] where text.hasSuffix(suffix) {
            text.removeLast(suffix.count)
        }
        return [
            "what time is it", "what time is it now", "what time is it right now",
            "what's the time", "what is the time", "what's the time now", "what is the time now",
            "what's the current time", "what is the current time", "tell me the time",
            "tell me what time it is", "can you tell me the time", "could you tell me the time",
            "can you tell me what time it is", "could you tell me what time it is",
            "do you know what time it is", "what does the device clock say",
            "كم الساعه", "كم الساعه الان", "كم الساعه الحين", "الساعه كم",
            "الساعه كم الان", "الساعه كم الحين", "ما الوقت الان", "ما هو الوقت الان",
            "وش الوقت", "وش الوقت الحين", "ايش الوقت", "كم الوقت"
        ].contains(text)
    }

    /// Authority is still checked for this camera-independent lane. Microphone
    /// conversation is allowed by the existing policy, but cannot acquire the
    /// authority to change a goal, confirm a task, or persist a user report.
    public static func accepts(_ question: String, origin: CompanionCommandOrigin) -> Bool {
        CommandAuthority.permits(.conversation, from: origin) && recognizes(question)
    }
}

/// Ephemeral delivery authority for one code-owned clock read. Never persist or
/// decode this lease, mint it from a model result, or recreate it when queueing.
/// Repeating/queueing the same answer retains the ORIGINAL five-second cap.
/// Foundation Date/TimeZone and the existing CompanionClock supply the value;
/// monotonic time is only the expiry authority, never a source of local time.
public struct CompanionClockReplyLease: Equatable, Sendable {
    public struct Binding: Equatable, Sendable {
        public let requestID: UUID
        public let generation: UInt64
        public let replyID: UUID
        public init(requestID: UUID, generation: UInt64, replyID: UUID) {
            self.requestID = requestID; self.generation = generation; self.replyID = replyID
        }
    }

    public let binding: Binding
    public let result: CompanionToolResult
    public let issuedAt: Double
    public let observedAt: Date
    public let timeZoneIdentifier: String
    public private(set) var invalidated = false
    private let utcOffset: Int
    private var lastMonotonic: Double
    private var lastWall: Date

    /// Scheduling/sample skew only. This tolerance NEVER expands either the
    /// monotonic or wall five-second maximum, nor allows a backwards sample.
    public static let maximumWallSkew: TimeInterval = 0.25
    public var reply: String { result.evidence[0].text }
    public var evidence: CompanionEvidence { result.evidence[0] }

    private init(binding: Binding, result: CompanionToolResult, now: Date,
                 monotonicNow: Double, timeZone: TimeZone) {
        self.binding = binding; self.result = result; self.issuedAt = monotonicNow
        self.observedAt = now; self.timeZoneIdentifier = timeZone.identifier
        self.utcOffset = timeZone.secondsFromGMT(for: now)
        self.lastMonotonic = monotonicNow; self.lastWall = now
    }

    /// Production callers take a NEW Date(), .current time zone, and
    /// ProcessInfo.processInfo.systemUptime together. Injection is for tests;
    /// nothing in this API accepts an old evidence record as a fresh read.
    public static func read(binding: Binding, now: Date, monotonicNow: Double,
                            timeZone: TimeZone, arabic: Bool) -> Self? {
        guard monotonicNow.isFinite, monotonicNow >= 0 else { return nil }
        let result = CompanionClock.read(now: now, timeZone: timeZone, arabic: arabic)
        guard result.status == .success, result.evidence.count == 1,
              CompanionClock.isClockEvidence(result.evidence[0]),
              result.evidence[0].isCurrent(at: now) else { return nil }
        return Self(binding: binding, result: result, now: now,
                    monotonicNow: monotonicNow, timeZone: timeZone)
    }

    /// Recheck before display/queue, at speech dispatch, during playback and on
    /// repeat. One failure irreversibly retires this lease. Neither a wall-clock
    /// rollback nor repeating an identical minute string can renew the answer.
    @discardableResult
    public mutating func validates(reply: String, binding: Binding, now: Date,
                                   monotonicNow: Double, timeZone: TimeZone) -> Bool {
        let age = monotonicNow - issuedAt
        let wallAge = now.timeIntervalSince(observedAt)
        let valid = !invalidated && self.binding == binding
            && self.reply.utf8.elementsEqual(reply.utf8)
            && monotonicNow.isFinite && monotonicNow >= lastMonotonic
            && age.isFinite && age >= 0 && age < CompanionClock.lifetime
            && now.timeIntervalSinceReferenceDate.isFinite && now >= lastWall
            && wallAge.isFinite && wallAge >= 0 && wallAge < CompanionClock.lifetime
            && abs(wallAge - age) <= Self.maximumWallSkew
            && timeZone.identifier == timeZoneIdentifier
            && timeZone.secondsFromGMT(for: observedAt) == utcOffset
            && timeZone.secondsFromGMT(for: now) == utcOffset
            && CompanionClock.isClockEvidence(evidence) && evidence.isCurrent(at: now)
        guard valid else { invalidated = true; return false }
        lastMonotonic = monotonicNow; lastWall = now
        return true
    }

    public mutating func invalidate() { invalidated = true }
}
