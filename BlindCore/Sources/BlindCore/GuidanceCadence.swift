import Foundation

/// When to speak a route cue, so guidance stays short while walking (user, 2026-10-09: minimum words
/// to reach the goal). A cue is spoken when the target changes (full name, once), when its direction
/// changes, or when a distance milestone is passed; otherwise the guide stays quiet. Hazards and
/// arrival are separate and always spoken.
public struct GuidanceCadence: Sendable {
    public static let milestones: [Double] = [5, 3, 2, 1]
    /// Seconds between milestone cues; a change of direction may speak sooner.
    public static let minimumInterval = 1.5
    public static let directionInterval = 0.75

    private var target: String?
    private var sector: Sector?
    private var band = Double.infinity
    private var lastSpoken = -Double.infinity

    public init() {}

    /// The label to speak (the full name the first time for a target, the short name afterwards),
    /// or nil to stay quiet this time.
    public mutating func label(target name: String, short: String, relation: SpatialRelation, now: Double) -> String? {
        guard now.isFinite, relation.distance.isFinite else { return nil }
        let currentBand = Self.milestones.filter { relation.distance <= $0 }.min() ?? .infinity
        if name != target {
            target = name; sector = relation.sector; band = currentBand; lastSpoken = now
            return name
        }
        let turned = relation.sector != sector && now - lastSpoken >= Self.directionInterval
        let closer = currentBand < band && now - lastSpoken >= Self.minimumInterval
        guard turned || closer else { return nil }
        sector = relation.sector; band = min(band, currentBand); lastSpoken = now
        return short
    }

    public mutating func reset() { target = nil; sector = nil; band = .infinity; lastSpoken = -.infinity }
}
