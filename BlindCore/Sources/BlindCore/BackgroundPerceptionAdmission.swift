import Foundation

/// Fair, bounded ownership of the foreground nonurgent perception slot.
/// This is domain admission glue, not an inference runtime or evidence validator.
/// The caller supplies BOTH currently eligible producers once per frame, then
/// dispatches only the returned producer. Hazard work never uses this slot.
public struct BackgroundPerceptionAdmission: Sendable {
    public enum Producer: String, CaseIterable, Hashable, Sendable {
        case passiveMemory, contextual
    }

    public struct Lease: Equatable, Sendable {
        public let id: UUID
        public let producer: Producer
        public let generation: UUID
        public let startedAt: Double
        fileprivate init(producer: Producer, generation: UUID, startedAt: Double) {
            id = UUID(); self.producer = producer
            self.generation = generation; self.startedAt = startedAt
        }
    }

    public static let defaultTimeout = 6.0
    public let timeout: Double
    public private(set) var activeLease: Lease?
    public private(set) var disabledProducers: Set<Producer> = []
    private var nextProducer: Producer = .contextual
    private var outputRetired = false
    private var lastNow: Double?

    public init(timeout: Double = Self.defaultTimeout) {
        self.timeout = timeout.isFinite && timeout > 0 ? timeout : Self.defaultTimeout
    }

    /// Readiness/interval/capture/attention gates remain with the existing adapters.
    /// An unavailable producer cannot hold the turn of another eligible producer.
    public mutating func reserve(eligible: Set<Producer>, generation: UUID, now: Double) -> Lease? {
        guard observe(now) else { return nil }
        _ = expire(now: now)
        if let activeLease {
            if activeLease.generation != generation { outputRetired = true }
            return nil
        }
        let order: [Producer] = nextProducer == .contextual
            ? [.contextual, .passiveMemory] : [.passiveMemory, .contextual]
        guard let producer = order.first(where: { eligible.contains($0) && !disabledProducers.contains($0) }) else { return nil }
        let lease = Lease(producer: producer, generation: generation, startedAt: now)
        activeLease = lease; outputRetired = false
        nextProducer = producer == .contextual ? .passiveMemory : .contextual
        return lease
    }

    /// Cancellation retires output, NOT native work. A synchronous Vision call may
    /// still own resources after cancellation; do not enqueue its replacement.
    public mutating func invalidate() { outputRetired = true }

    /// This only checks resource/callback ownership. Positive evidence, target
    /// association, freshness, privacy and speech admission still belong to callers.
    public func accepts(_ lease: Lease, generation: UUID, now: Double) -> Bool {
        activeLease == lease && !outputRetired && lease.generation == generation &&
            now.isFinite && now >= lease.startedAt && now - lease.startedAt < timeout &&
            (lastNow.map { now >= $0 } ?? true) && !disabledProducers.contains(lease.producer)
    }

    /// Completion of cancelled work may free its own slot, but never authorizes its
    /// output. Call accepts BEFORE finish if the result is otherwise deliverable.
    /// A stale/duplicate callback cannot retire a successor or reenable a producer.
    @discardableResult public mutating func finish(_ lease: Lease, now: Double) -> Bool {
        guard activeLease == lease, observe(now) else { return false }
        _ = expire(now: now)
        guard activeLease == lease else { return false }
        activeLease = nil; outputRetired = false
        return true
    }

    /// Call from the existing foreground watchdog even without new camera frames.
    /// Timed-out native work cannot be forcibly stopped. Disable its producer for
    /// this policy's lifetime before releasing the slot to the OTHER producer.
    /// Do not recreate this policy for ordinary cancellation/lifecycle changes.
    @discardableResult public mutating func expire(now: Double) -> Lease? {
        guard observe(now), let lease = activeLease, now - lease.startedAt >= timeout else { return nil }
        disabledProducers.insert(lease.producer)
        activeLease = nil; outputRetired = false
        return lease
    }

    private mutating func observe(_ now: Double) -> Bool {
        guard now.isFinite, now >= 0, lastNow.map({ now >= $0 }) ?? true else {
            outputRetired = true
            return false
        }
        lastNow = now
        return true
    }
}
