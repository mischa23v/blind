import Foundation

public struct TrailCue: Equatable, Sendable {
    public var sector: Int
    public var distance: Double
    public var remaining: Int
}

/// Retraces only an uninterrupted, current AR session. A bearing is not walking clearance.
/// Stops on tracking jumps or deviation; it never invents a shortcut through unknown space.
public struct ReturnTrail: Sendable {
    public enum State: String, Sendable { case idle, following, paused, arrived, invalidated }
    public private(set) var state: State = .idle
    public private(set) var reason = ""
    private var targets: [Point3] = []
    private var index = 0
    private var edgeStart = Point3(0, 0, 0)
    private var previous: (position: Point3, time: Double)?
    public init() {}
    public mutating func begin(journey: Journey, camera: Point3, at time: Double) -> Bool {
        self = ReturnTrail()
        guard camera.isFinite, time.isFinite, journey.points.count >= 2,
              journey.points.count < 50_000,
              let first = journey.points.first, let last = journey.points.last,
              first.segment == 0, journey.points.allSatisfy({ $0.segment == 0 && $0.position.isFinite }),
              zip(journey.points, journey.points.dropFirst()).allSatisfy({ $0.seconds < $1.seconds }),
              camera.distance(to: last.position) <= 0.75 else {
            invalidate("An uninterrupted current-session trail is required."); return false
        }
        targets = journey.points.reversed().map(\.position)
        edgeStart = camera; previous = (camera, time); state = .following
        return true
    }
    public mutating func invalidate(_ reason: String = "Tracking changed. Start a new trail.") {
        state = .invalidated; self.reason = reason; targets = []; previous = nil
    }
    public mutating func update(camera: Point3, forward: Point3, at time: Double,
                                tracking: Bool, hazard: Hazard) -> TrailCue? {
        guard state == .following || state == .paused else { return nil }
        guard tracking, camera.isFinite, forward.isFinite, time.isFinite,
              let previous, time > previous.time, time - previous.time <= 0.5,
              camera.distance(to: previous.position) <= 3 * (time - previous.time) else {
            invalidate(); return nil
        }
        self.previous = (camera, time)
        guard index < targets.count else { return nil }
        let target = targets[index]
        let deltaX = target.x - edgeStart.x, deltaZ = target.z - edgeStart.z
        let lengthSquared = deltaX * deltaX + deltaZ * deltaZ
        let along = lengthSquared > 0 ? max(0, min(1, ((camera.x - edgeStart.x) * deltaX + (camera.z - edgeStart.z) * deltaZ) / lengthSquared)) : 0
        let deviation = hypot(camera.x - edgeStart.x - along * deltaX, camera.z - edgeStart.z - along * deltaZ)
        guard deviation <= 1.2, abs(camera.y - target.y) <= 0.6 else {
            invalidate("Moved away from the recorded trail or changed level."); return nil
        }
        let forwardLength = hypot(forward.x, forward.z)
        guard hazard == .observing, forwardLength > 0.5 else { state = .paused; return nil }
        state = .following
        if hypot(camera.x - target.x, camera.z - target.z) <= 0.45 {
            edgeStart = target; index += 1
            if index == targets.count { state = .arrived; return nil }
        }
        let next = targets[index]
        let dx = next.x - camera.x, dz = next.z - camera.z
        let angle = atan2(-dx * forward.z + dz * forward.x, dx * forward.x + dz * forward.z)
        return TrailCue(sector: (Int((angle / (.pi / 4)).rounded()) + 8) % 8,
                        distance: hypot(dx, dz), remaining: targets.count - index)
    }
}
