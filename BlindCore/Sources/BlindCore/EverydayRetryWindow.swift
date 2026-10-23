import Foundation

/// One deferred fresh-frame retry. This does not grant capture permission or
/// replenish the owning coordinator's attempt budget. Only its adapter may arm it.
public struct EverydayRetryWindow: Sendable {
    public static let minimumDelay = 1.0
    public static let lifetime = 10.0
    public static let maximumFrameAge = 0.5
    private struct Pending: Sendable {
        let ticketID: UUID
        let scheduledAt: Double
        let frameAt: Double
    }
    private var pending: Pending?
    private var lastNow: Double?
    public var isPending: Bool { pending != nil }
    public init() {}

    /// Repeated scheduling cannot extend an existing deadline. The caller must
    /// explicitly cancel a replaced task before arming its successor.
    public mutating func schedule(ticketID: UUID, now: Double, frameAt: Double) {
        guard validTime(now), frameAt.isFinite, frameAt >= 0, frameAt <= now else { cancel(); return }
        guard pending == nil else { return }
        pending = Pending(ticketID: ticketID, scheduledAt: now, frameAt: frameAt)
    }
    public mutating func cancel() { pending = nil; lastNow = nil }

    /// Busy and unchanged frames defer, not reset. A consumed/expired/cancelled
    /// retry cannot execute again; unavailable or superseded work is invalidated.
    public mutating func takeIfReady(ticketID: UUID?, now: Double, frameAt: Double,
                                     quiescent: Bool, available: Bool) -> Bool {
        guard validTime(now), let value = pending else { cancel(); return false }
        guard ticketID == value.ticketID, available, now - value.scheduledAt <= Self.lifetime,
              frameAt.isFinite, frameAt >= 0, frameAt <= now else { cancel(); return false }
        guard quiescent, now - value.scheduledAt >= Self.minimumDelay,
              frameAt > value.frameAt, now - frameAt <= Self.maximumFrameAge else { return false }
        pending = nil
        return true
    }
    private mutating func validTime(_ now: Double) -> Bool {
        guard now.isFinite, now >= 0, lastNow.map({ now >= $0 }) ?? true else { return false }
        lastNow = now
        return true
    }
}
