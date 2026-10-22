/// Bounds actual recognition attempts in one named-person search. Call consumeAttempt only
/// immediately before starting work, not on every camera frame. Generation/cancellation,
/// enrollment permission, fresh frames, and exact-label resolution belong to the caller.
/// Use one monotonic clock; this transient value must not survive a session restart.
public struct FamiliarSearchBudget: Sendable {
    private let startedAt: Double
    private var lastObservedAt: Double
    private var lastAttemptAt: Double?
    private var attempts = 0
    private var invalidated = false

    public init(startedAt: Double) {
        self.startedAt = startedAt
        self.lastObservedAt = startedAt
    }

    /// At most six attempts, separated by at least two seconds, through elapsed second 20.
    /// A spacing rejection does not spend an attempt. Invalid/expired consumption is terminal.
    public mutating func consumeAttempt(now: Double) -> Bool {
        guard !isExpired(now: now) else {
            invalidated = true
            return false
        }
        lastObservedAt = now
        if let lastAttemptAt, now - lastAttemptAt < 2 { return false }
        lastAttemptAt = now
        attempts += 1
        return true
    }

    /// Exhaustion, invalid clocks, reversal, and times outside the session window expire it.
    public func isExpired(now: Double) -> Bool {
        invalidated || attempts >= 6 || !startedAt.isFinite || startedAt < 0 || !now.isFinite
            || now < startedAt || now < lastObservedAt || now - startedAt > 20
    }
}
