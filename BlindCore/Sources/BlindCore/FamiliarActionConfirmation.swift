import Foundation

/// One-shot, short-lived confirmation for a separately retained exact gallery action.
/// The caller owns the action and label, reads them back before requesting confirmation,
/// and cancels this gate whenever that action, profile, gallery revision, or session changes.
/// Times must come from one monotonic clock; this transient gate must not be persisted.
/// This checks freshness and token identity, not the speaker's identity or consent.
public struct FamiliarActionConfirmation: Sendable {
    private struct Pending: Sendable {
        let token: UUID
        let requestedAt: Double
        let deadline: Double
    }
    private var pending: Pending?

    public init() {}

    /// Replaces any earlier request. An invalid time also invalidates the previous request.
    public mutating func request(now: Double) -> UUID? {
        pending = nil
        guard now.isFinite, now >= 0 else { return nil }
        let token = UUID()
        pending = Pending(token: token, requestedAt: now, deadline: now + 30)
        return token
    }

    /// Every attempt consumes the pending request, even a wrong token or invalid time.
    public mutating func consume(_ token: UUID, now: Double) -> Bool {
        let request = pending
        pending = nil
        guard let request, now.isFinite, now >= 0,
              token == request.token, now >= request.requestedAt, now <= request.deadline else { return false }
        return true
    }

    public mutating func cancel() { pending = nil }
}
