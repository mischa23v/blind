import Foundation

/// Lifecycle gate around ARKit relocalisation, not a place recogniser.
/// A timeout means unresolved, never "new place". No pose survives a restart.
public struct PlaceRecovery: Sendable {
    public enum State: Equatable, Sendable { case unknown, matching(String), matched(String), needsHelp }
    public private(set) var state: State = .unknown
    private var startedAt: Double?
    private var frames = 0
    public init() {}
    public mutating func begin(candidate: String, now: Double) {
        reset()
        guard !candidate.isEmpty, now.isFinite else { return }
        state = .matching(candidate); startedAt = now
    }
    public mutating func reset() { state = .unknown; startedAt = nil; frames = 0 }
    @discardableResult public mutating func expire(now: Double) -> Bool {
        guard case .matching = state, let startedAt else { return false }
        guard now.isFinite, now >= startedAt, now - startedAt < 30 else {
            state = .needsHelp; self.startedAt = nil; frames = 0; return true
        }
        return false
    }
    public mutating func observe(normal: Bool, mapped: Bool, now: Double) -> String? {
        guard !expire(now: now), case let .matching(candidate) = state else { return nil }
        guard normal && mapped else { frames = 0; return nil }
        frames += 1
        guard frames >= 30 else { return nil }
        state = .matched(candidate); startedAt = nil; return candidate
    }
}
