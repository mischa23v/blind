import Foundation

/// Authored/observed terrain annotation, not proof of traversability. A level
/// label never overrides the actual sampled support heights or missing coverage.
public enum SurfaceTerrainAnnotation: String, Codable, Sendable {
    case level, rise, drop, slope, step, stairs, unknown
}

/// A stored graph can use numerically level geometry, but neither a graph nor
/// this assessment certifies current footing, child gait or physical clearance.
public struct StoredTerrainAssessment: Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case numericallyLevel, rise, drop, slope, step, stairs, unknown }
    public let kind: Kind
    /// nil = no measurement uncertainty supplied. This is usable only as stored
    /// geometry, not as a claim of a precise physical floor measurement.
    public let measurementUncertaintyMetres: Double?
    public var permitsStoredLevelRoute: Bool { kind == .numericallyLevel }
    public var grantsPhysicalClearance: Bool { false }
}

public enum StoredTerrainPolicy {
    /// Floating-point identity tolerance ONLY, not permitted rise/drop or sensor
    /// error. A few ULPs permit arithmetic roundoff; the nanometre ceiling prevents
    /// large coordinates from creating a meaningful physical-height allowance.
    /// This is not configurable from age, weight, height, accessibility or gait.
    public static func numericallyEqual(_ a: Double, _ b: Double) -> Bool {
        guard a.isFinite, b.isFinite else { return false }
        let scale = max(1, max(abs(a), abs(b)))
        let tolerance = min(1e-9, scale.ulp * 8)
        return abs(a - b) <= tolerance
    }
    public static func assess(sourceHeight: Double, destinationHeight: Double, floorHeight: Double?,
                              floorUncertainty: Double? = nil, annotation: SurfaceTerrainAnnotation? = nil) -> StoredTerrainAssessment {
        func result(_ kind: StoredTerrainAssessment.Kind) -> StoredTerrainAssessment {
            .init(kind: kind, measurementUncertaintyMetres: floorUncertainty)
        }
        guard sourceHeight.isFinite, destinationHeight.isFinite, let floorHeight, floorHeight.isFinite else { return result(.unknown) }
        // An uncertainty interval is not a licence to flatten a possible edge.
        // The geometry-only path accepts no positive measurement error allowance.
        if let floorUncertainty, !floorUncertainty.isFinite || floorUncertainty < 0 || floorUncertainty > 0 { return result(.unknown) }
        switch annotation {
        case .unknown: return result(.unknown)
        case .rise: return result(.rise)
        case .drop: return result(.drop)
        case .slope: return result(.slope)
        case .step: return result(.step)
        case .stairs: return result(.stairs)
        case .level, nil: break
        }
        if !numericallyEqual(sourceHeight, destinationHeight) {
            return result(destinationHeight > sourceHeight ? .rise : .drop)
        }
        if !numericallyEqual(sourceHeight, floorHeight) {
            return result(floorHeight > sourceHeight ? .rise : .drop)
        }
        return result(.numericallyLevel)
    }
}
