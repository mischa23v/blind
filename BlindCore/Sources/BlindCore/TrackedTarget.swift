import Foundation

/// A located object kept as one tracked 3D target through approach and reach (2026-10-22, idea from
/// Touvigation, arXiv 2609.21828; no code copied). Once the sensors find the object, its LiDAR world
/// point is kept and guidance is re-measured from the person's current pose on every frame, instead
/// of asking a model again: instant, and only from sensors. Re-detections refresh the point; if the
/// object is not seen again for `lostAfter` seconds, tracking ends with a "lost sight" result.
/// Times are phone monotonic seconds.
public struct TrackedTarget: Equatable, Sendable {
    public enum Update: Equatable, Sendable {
        case none
        case guidance(String)
        case reached(String)
        case lost(String)
    }
    public static let lostAfter = 8.0
    public static let reachDistance = 0.6
    /// Distances (metres) at which progress is spoken once each, nearest last.
    static let bands: [Double] = [3, 2, 1]
    /// A turn of at least this much repeats the direction.
    static let turnDegrees = 45.0

    public let label: String
    /// The words the detector matches when looking again ("cup", "exit sign").
    public let query: String
    public private(set) var point: Point3
    public private(set) var lastSeen: Double
    private var spokenBand: Int?
    private var spokenAngle: Double?

    public init(label: String, query: String, point: Point3, now: Double) {
        self.label = label; self.query = query; self.point = point; lastSeen = now
    }

    /// A fresh detection of the same object.
    public mutating func seen(at point: Point3, now: Double) {
        guard point.isFinite, now.isFinite else { return }
        self.point = point; lastSeen = now
    }

    /// Guidance from where the person is now. `fromCamera` when body heading is not established.
    public mutating func update(from position: Point3, facing: Point3, now: Double, arabic: Bool, fromCamera: Bool) -> Update {
        guard now.isFinite, let relation = SpatialFacts.relation(from: position, facing: facing, to: point) else { return .none }
        let phrase = SpatialFacts.phrase(label: label, relation: relation, arabic: arabic, inView: nil)
        let spoken = fromCamera ? (arabic ? "من الكاميرا: " : "From the camera: ") + phrase : phrase
        if relation.distance <= Self.reachDistance {
            return .reached((arabic ? "في متناول يدك. " : "Within reach. ") + spoken)
        }
        if now - lastSeen > Self.lostAfter {
            return .lost((arabic ? "لم أعد أرى \(label). آخر مرة كان: " : "I can't see the \(label) any more. It was last: ") + phrase)
        }
        if let band = Self.bands.lastIndex(where: { relation.distance <= $0 }), spokenBand.map({ band > $0 }) ?? true {
            spokenBand = band; spokenAngle = relation.angleDegrees
            return .guidance(spoken)
        }
        if spokenAngle == nil { spokenAngle = relation.angleDegrees; return .guidance(spoken) }
        if let previous = spokenAngle {
            var turn = abs(relation.angleDegrees - previous).truncatingRemainder(dividingBy: 360)
            if turn > 180 { turn = 360 - turn }
            if turn >= Self.turnDegrees { spokenAngle = relation.angleDegrees; return .guidance(spoken) }
        }
        return .none
    }
}
