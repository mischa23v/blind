import Foundation

/// Eight horizontal sectors around the person, matching the evaluation thresholds in
/// tools/evaluate-real-scene.mjs (`relation`): under 30 degrees ahead, under 75 ahead-side,
/// under 120 side, under 160 behind-side, otherwise behind.
public enum Sector: String, Codable, Sendable {
    case ahead, aheadLeft, aheadRight, left, right, behindLeft, behindRight, behind
}

/// A sensor-derived horizontal relation. Positive angle means to the person's right.
public struct SpatialRelation: Equatable, Sendable {
    /// Degrees in (-180, 180]; positive is right, negative is left, 0 is straight ahead.
    public var angleDegrees: Double
    /// Horizontal distance in metres.
    public var distance: Double
    public var sector: Sector
    public init(angleDegrees: Double, distance: Double, sector: Sector) {
        self.angleDegrees = angleDegrees; self.distance = distance; self.sector = sector
    }
}

/// Code-rendered spatial facts (tasks E13 and E14). Positions, directions and distances here come
/// from sensors and are computed by code, so they are spoken plainly and confidently. Model
/// estimates are a separate path and are worded as estimates (see SpatialClaimGuard).
/// Step counts come only from the person's calibrated stride, never from an average stride.
public enum SpatialFacts {
    // Sector boundaries in absolute degrees, shared with tools/evaluate-real-scene.mjs.
    public static let aheadLimitDegrees = 30.0
    public static let aheadSideLimitDegrees = 75.0
    public static let sideLimitDegrees = 120.0
    public static let behindSideLimitDegrees = 160.0
    // Camera depth range accepted as a usable LiDAR reading.
    public static let cameraDepthRange: ClosedRange<Double> = 0.1...10
    // Below this distance, distances are spoken with one decimal; at or above, whole metres.
    public static let decimalDistanceLimit = 3.0
    // A personal stride outside this range is treated as not calibrated.
    public static let calibratedStrideRange: ClosedRange<Double> = 0.2...1.5
    // Facing vectors shorter than this have no usable horizontal heading.
    static let minimumFacingLength = 1e-9

    public static func sector(angleDegrees: Double) -> Sector {
        let magnitude = abs(angleDegrees), right = angleDegrees >= 0
        if magnitude < aheadLimitDegrees { return .ahead }
        if magnitude < aheadSideLimitDegrees { return right ? .aheadRight : .aheadLeft }
        if magnitude < sideLimitDegrees { return right ? .right : .left }
        if magnitude < behindSideLimitDegrees { return right ? .behindRight : .behindLeft }
        return .behind
    }

    /// Horizontal relation in ARKit world coordinates (y up, horizontal plane x/z).
    /// Uses the same axes as Observation.coordinates: ahead = d . f, side = -dx * fz + dz * fx,
    /// where positive side is the person's right. Height differences are ignored.
    public static func relation(from position: Point3, facing forward: Point3, to target: Point3) -> SpatialRelation? {
        guard position.isFinite, forward.isFinite, target.isFinite else { return nil }
        let length = hypot(forward.x, forward.z)
        guard length.isFinite, length > minimumFacingLength else { return nil }
        let fx = forward.x / length, fz = forward.z / length
        let dx = target.x - position.x, dz = target.z - position.z
        let ahead = dx * fx + dz * fz
        let side = -dx * fz + dz * fx
        let distance = hypot(dx, dz)
        guard distance.isFinite else { return nil }
        let angle = atan2(side, ahead) * 180 / .pi
        return SpatialRelation(angleDegrees: angle, distance: distance, sector: sector(angleDegrees: angle))
    }

    /// Relation for an object seen in the camera image. `boxCenterX` is 0 at the left edge and 1 at
    /// the right edge of the upright image (the caller rotates boxes for device orientation first).
    /// The angle uses the linear mapping (x - 0.5) * field of view. `depth` is the LiDAR depth at the
    /// box centre and is used as the horizontal distance for a phone held roughly upright.
    public static func cameraRelation(boxCenterX: Double, depth: Double,
                                      horizontalFieldOfViewDegrees: Double) -> SpatialRelation? {
        guard boxCenterX.isFinite, (0...1).contains(boxCenterX),
              depth.isFinite, cameraDepthRange.contains(depth),
              horizontalFieldOfViewDegrees.isFinite,
              horizontalFieldOfViewDegrees > 0, horizontalFieldOfViewDegrees < 180 else { return nil }
        let angle = (boxCenterX - 0.5) * horizontalFieldOfViewDegrees
        return SpatialRelation(angleDegrees: angle, distance: depth, sector: sector(angleDegrees: angle))
    }

    static func direction(_ sector: Sector, arabic: Bool) -> String {
        switch sector {
        case .ahead: return arabic ? "أمامك" : "ahead"
        case .aheadLeft: return arabic ? "أمامك قليلاً إلى اليسار" : "ahead, slightly left"
        case .aheadRight: return arabic ? "أمامك قليلاً إلى اليمين" : "ahead, slightly right"
        case .left: return arabic ? "على يسارك" : "on your left"
        case .right: return arabic ? "على يمينك" : "on your right"
        case .behindLeft: return arabic ? "خلفك إلى اليسار" : "behind you on the left"
        case .behindRight: return arabic ? "خلفك إلى اليمين" : "behind you on the right"
        case .behind: return arabic ? "خلفك" : "behind you"
        }
    }

    /// Distance text with Western digits and a "." decimal point, independent of device locale.
    /// Returns nil for a distance that cannot be spoken.
    static func distanceText(_ distance: Double) -> String? {
        guard distance.isFinite, distance >= 0 else { return nil }
        if distance < decimalDistanceLimit {
            let tenths = (distance * 10).rounded() / 10
            return String(format: "%.1f", tenths)
        }
        return String(Int(distance.rounded()))
    }

    /// Short, confident wording for a sensor fact, for example
    /// "Door: behind you on the right, 2.1 metres." or "الباب: خلفك إلى اليمين، 2.1 متر."
    /// `inView == false` adds that the object is not in the camera view; nil or true adds nothing.
    public static func phrase(label: String, relation: SpatialRelation, arabic: Bool, inView: Bool?) -> String {
        let separator = arabic ? "، " : ", "
        var parts = [direction(relation.sector, arabic: arabic)]
        if let distance = distanceText(relation.distance) {
            parts.append(arabic ? "\(distance) متر" : "\(distance) metres")
        }
        if inView == false {
            parts.append(arabic ? "ليس ضمن مجال الكاميرا" : "not in camera view")
        }
        return "\(label): " + parts.joined(separator: separator) + "."
    }

    /// Whole steps for a distance, only from the person's calibrated stride. Returns nil when no
    /// calibrated stride is available or it lies outside the calibrated range; there is no average fallback.
    public static func calibratedSteps(distance: Double, strideMetres: Double?) -> Int? {
        guard let stride = strideMetres, stride.isFinite, calibratedStrideRange.contains(stride),
              distance.isFinite, distance >= 0 else { return nil }
        return Int((distance / stride).rounded())
    }
}
