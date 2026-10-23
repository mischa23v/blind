import Foundation

/// Request identity, not tool equality, owns asynchronous reading work. This also fences
/// Stop -> restart of the same tool. Durations are policy bounds, not measured device latency.
public struct ReadingWorkSession: Sendable {
    public private(set) var token = UUID()
    public private(set) var active = false
    public init() {}
    @discardableResult public mutating func begin() -> UUID {
        token = UUID(); active = true; return token
    }
    public mutating func cancel() { token = UUID(); active = false }
    public func owns(_ candidate: UUID) -> Bool { active && token == candidate }
    public func accepts(_ candidate: UUID, capturedAt: Double, now: Double) -> Bool {
        owns(candidate) && capturedAt.isFinite && now.isFinite && now >= capturedAt && now - capturedAt < 0.5
    }
}

/// Three consistent page polygons are a framing prerequisite, not an identity or stillness
/// proof. The app independently rechecks capture pose, foreground state and frame freshness.
public struct DocumentStability: Sendable {
    private var previous: [(x: Double, y: Double)]?
    private var count = 0
    public init() {}
    public mutating func reset() { previous = nil; count = 0 }
    public mutating func observe(_ corners: [(x: Double, y: Double)]?) -> Bool {
        guard let corners, DocumentGuidance.evaluate(corners) == .holdStill,
              corners.allSatisfy({ (0...1).contains($0.x) && (0...1).contains($0.y) }) else {
            reset(); return false
        }
        let consistent = previous.map { old in
            zip(old, corners).allSatisfy { hypot($0.0.x - $0.1.x, $0.0.y - $0.1.y) <= 0.025 }
        } ?? false
        count = consistent ? count + 1 : 1
        previous = corners
        return count >= 3
    }
}
