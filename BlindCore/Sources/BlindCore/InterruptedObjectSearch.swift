import Foundation

/// One transient search interrupted by conversation, never a durable task or a
/// license to resume sensors. The controller waits for an active foreground
/// session, fresh sensing and an idle speech channel before calling `restore`.
/// An explicit pause/cancel, new operation or session end calls `cancel`.
public struct InterruptedObjectSearch: Sendable {
    private struct Pending: Sendable {
        let search: ObjectSearch
        let goalRevision: String
        let generation: UInt64
        let capturedAt: Double
    }
    private var pending: Pending?
    public init() {}
    /// A receipt can expire while waiting; `restore` checks its original lifetime.
    public var hasPending: Bool { pending != nil }

    /// Call at speech onset before cancelling work, and again for typed input.
    /// A nil search preserves an already captured receipt (for subsequent ordinary
    /// questions). Neither repeated capture nor a new question extends its life.
    public mutating func capture(search: ObjectSearch?, goalRevision: String, generation: UInt64, now: Double) {
        if let current = pending, !Self.valid(current, goalRevision: goalRevision, generation: generation, now: now) {
            pending = nil
        }
        guard pending == nil, let search, search.active,
              !search.target.isEmpty, !goalRevision.isEmpty,
              now.isFinite, search.startedAt.isFinite,
              now >= search.startedAt, now - search.startedAt < ObjectSearch.duration else { return }
        pending = Pending(search: search, goalRevision: goalRevision, generation: generation, capturedAt: now)
    }

    /// One shot. Return the original search, including its attempts, hint state and
    /// start time. Never reset a 20-second search merely because it was interrupted.
    public mutating func restore(goalRevision: String, generation: UInt64, now: Double) -> ObjectSearch? {
        guard let current = pending else { return nil }
        pending = nil
        guard Self.valid(current, goalRevision: goalRevision, generation: generation, now: now) else { return nil }
        return current.search
    }

    public mutating func cancel() { pending = nil }

    private static func valid(_ pending: Pending, goalRevision: String, generation: UInt64, now: Double) -> Bool {
        pending.goalRevision == goalRevision && pending.generation == generation && pending.search.active &&
            now.isFinite && now >= pending.capturedAt && now >= pending.search.startedAt &&
            now - pending.search.startedAt < ObjectSearch.duration
    }
}
