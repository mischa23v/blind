import Foundation

/// Bounded continuation of one explicit banknote request. This policy neither
/// captures images nor schedules retries nor authorizes any monetary answer.
/// The caller clears it on success, cancellation, a new task, backgrounding,
/// hazard/attention invalidation, or unavailable recognition.
public struct CurrencyRetakeSession: Sendable {
    public enum Reason: Equatable, Sendable {
        case unknown, tooSmall, clipped, multiple, processingFailure, unavailable
    }
    public static let lifetime: Double = 30
    public static let maximumAdditionalAttempts = 2

    private enum Phase: Sendable { case idle, armed, awaitingResult, closed }
    private var phase: Phase = .idle
    private var lastFrameAt: Double?
    private var lastObservedAt: Double?
    public private(set) var retriesUsed = 0
    public private(set) var expiresAt: Double?
    public private(set) var reason: Reason?

    /// An armed session may have expired since the last call. takeRetry always
    /// checks the clock and expiry again before admitting an explicit retry.
    public var isPending: Bool { phase == .armed }
    public init() {}

    /// Called only after a retryable result. The first rejected capture starts
    /// the window; rearming never extends its deadline or restores attempts.
    /// A retry result must belong to the exact frame reserved by takeRetry.
    @discardableResult public mutating func arm(reason: Reason, rejectedFrameAt: Double, now: Double) -> Bool {
        if reason == .unavailable { clear(); return false }
        guard observe(now), phase != .closed else { return false }
        guard rejectedFrameAt.isFinite, rejectedFrameAt >= 0, rejectedFrameAt <= now else {
            close(); return false
        }
        if phase == .idle {
            let deadline = now + Self.lifetime
            guard deadline.isFinite, deadline > now else { close(); return false }
            expiresAt = deadline
            lastFrameAt = rejectedFrameAt
        } else {
            guard let expiresAt, now < expiresAt, retriesUsed < Self.maximumAdditionalAttempts,
                  rejectedFrameAt == lastFrameAt else { close(); return false }
        }
        self.reason = reason
        phase = .armed
        return true
    }

    /// Call only in response to a new explicit retry command, never on a timer,
    /// capture callback or inference completion. The frame must be strictly newer
    /// than the rejected one. A stale frame consumes no attempt; ask again once a
    /// fresh frame exists. Concurrent/double requests cannot reserve another frame.
    @discardableResult public mutating func takeRetry(frameAt: Double, now: Double) -> Bool {
        guard observe(now), phase == .armed else { return false }
        guard let expiresAt, now < expiresAt, retriesUsed < Self.maximumAdditionalAttempts,
              frameAt.isFinite, frameAt >= 0, frameAt <= now else { close(); return false }
        guard let lastFrameAt, frameAt > lastFrameAt else { return false }
        retriesUsed += 1
        self.lastFrameAt = frameAt
        reason = nil
        phase = .awaitingResult
        return true
    }

    /// An explicit new full request may start a new session after clearing the
    /// previous one. Expired/exhausted sessions otherwise stay closed, preventing
    /// repeated callbacks from silently restarting the retry budget.
    public mutating func clear() { self = Self() }

    /// Exact short commands only. No substring matching or general conversation
    /// diversion. The caller additionally requires a pending currency session.
    public static func isRetryCommand(_ text: String) -> Bool {
        guard text.unicodeScalars.count <= 128 else { return false }
        let folded = text.lowercased().folding(options: [.diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .decomposedStringWithCanonicalMapping
        let unmarked = String(String.UnicodeScalarView(folded.unicodeScalars.filter {
            !CharacterSet.nonBaseCharacters.contains($0) && $0.value != 0x0640
        }))
        let normalized = unmarked.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            .components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
        return ["try again", "again", "retry", "حاول مجددا", "مرة ثانية"].contains(normalized)
    }

    private mutating func observe(_ now: Double) -> Bool {
        guard now.isFinite, now >= 0, lastObservedAt.map({ now >= $0 }) ?? true else { close(); return false }
        lastObservedAt = now
        return true
    }
    private mutating func close() {
        phase = .closed
        reason = nil
    }
}
