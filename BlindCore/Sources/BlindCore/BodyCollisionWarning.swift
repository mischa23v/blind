import Foundation

/// Supplemental positive-observation warnings, not a floor detector or navigation
/// permission. Reported maximum dimensions affect this warning even when their
/// accuracy is unknown. No result from this type means that space is clear.
public struct BodyCollisionWarning: Sendable {
    /// sensorFloor is the retained level-floor calibration, NOT fresh support.
    public enum VerticalReference: String, Sendable { case sensorFloor, reportedMount }
    public enum Status: String, Sendable {
        case unavailableProfile, unavailableMount, unavailablePose, unavailableDepth
        case noObservedIntersection, observedIntersection
    }
    public struct Assessment: Sendable {
        public let status: Status
        public let detection: Detection?
        public let profileRevision: UUID?
        public let verticalReference: VerticalReference?
        /// Missing error/equipment coverage is retained, never represented as zero.
        public let unquantifiedDimensionError: Bool
        public let equipmentBoundsIncomplete: Bool
    }
    /// Warning lookahead only, not a stopping distance or measured error estimate.
    /// Nearby is deliberately isotropic: camera heading does not establish body
    /// facing or travel direction. The cylinder covers every body yaw.
    public static let nearbyWarningDistance = 0.7
    public static let warningPadding = 0.15
    private init() {}

    public static func assess(_ frame: Observation, cameraToWorld: NativeCameraTransform?,
                              profile: LocalBodyProfile?, fixedMount: Bool, now: Double,
                              floorHeight: Double? = nil) -> Assessment {
        func result(_ status: Status, detection: Detection? = nil, reference: VerticalReference? = nil,
                    unknownError: Bool = true, incompleteEquipment: Bool = true) -> Assessment {
            .init(status: status, detection: detection, profileRevision: profile?.geometryRevision,
                  verticalReference: reference, unquantifiedDimensionError: unknownError,
                  equipmentBoundsIncomplete: incompleteEquipment)
        }
        guard let profile, profile.valid else { return result(.unavailableProfile) }
        guard fixedMount, profile.mount.complete, let up = profile.mount.up,
              let right = profile.mount.right, let forward = profile.mount.forward else {
            return result(.unavailableMount)
        }
        // Do not derive anatomy from demographics or use generic preview defaults.
        let dimensions = profile.dimensions.filter { $0.source != .estimated }
        guard !dimensions.isEmpty else { return result(.unavailableProfile) }
        guard frame.trackingNormal, frame.timestamp.isFinite, frame.timestamp >= 0,
              now.isFinite, now >= frame.timestamp, now - frame.timestamp <= SavedWorldFrameRecovery.maximumFrameAge,
              frame.camera.isFinite, let cameraToWorld, cameraToWorld.valid,
              let cameraOrigin = try? cameraToWorld.applying(to: .init(0, 0, 0)),
              cameraOrigin.distance(to: frame.camera) < 0.00001 else { return result(.unavailablePose) }
        // The full camera matrix has already projected observed depth into world
        // coordinates, including pitch/roll. It is NEVER substituted for body yaw.
        // For unknown yaw, the triangle inequality bounds every horizontal mount
        // location by |offset| around the camera. No signed-offset guess is made.
        let radius = dimensions.map { hypot($0.width, $0.depth) / 2 + ($0.uncertainty ?? 0) }.max()!
        let height = dimensions.map { $0.height + ($0.uncertainty ?? 0) }.max()!
        let radial = profile.equipment.radialExtension ?? 0
        let overhead = profile.equipment.overheadExtension ?? 0
        let unknownError = dimensions.contains { $0.uncertainty == nil }
        let incompleteEquipment = profile.equipment.radialExtension == nil || profile.equipment.overheadExtension == nil
        let extent = radius + radial + hypot(right, forward) + warningPadding + nearbyWarningDistance
        let reference: VerticalReference
        let base: Double
        if let floorHeight, floorHeight.isFinite {
            base = floorHeight; reference = .sensorFloor
        } else {
            // A reported mount reference is NOT observed floor or support. It only
            // positions the reported warning volume; independent floor warnings
            // remain unchanged. Its missing accuracy is not a zero-error bound.
            base = frame.camera.y - up; reference = .reportedMount
        }
        let top = base + height + overhead + warningPadding
        // Reuse the independent detector's obstacle departure band; this path
        // deliberately does not classify feet, small steps, drops or terrain.
        let bottom = base + 0.09
        guard extent.isFinite, top.isFinite, bottom.isFinite else { return result(.unavailableProfile) }
        var observed = false
        var cells = Set<String>()
        for sample in frame.samples where sample.confidence >= 2 && sample.position.isFinite {
            observed = true
            let p = sample.position
            guard p.y > bottom, p.y <= top,
                  hypot(p.x - frame.camera.x, p.z - frame.camera.z) <= extent else { continue }
            // Spatially distinct returns, not three duplicates of one point. The
            // grid is an anti-duplication policy, not an accuracy/coverage claim.
            let x = Int(floor((p.x - frame.camera.x) / 0.1))
            let y = Int(floor((p.y - frame.camera.y) / 0.1))
            let z = Int(floor((p.z - frame.camera.z) / 0.1))
            cells.insert("\(x):\(y):\(z)")
            if cells.count >= 3 {
                // No bearing or range: the entered body/mount may be approximate.
                return result(.observedIntersection, detection: Detection(.obstacle, reason: .bodyEnvelope),
                              reference: reference, unknownError: unknownError, incompleteEquipment: incompleteEquipment)
            }
        }
        return result(observed ? .noObservedIntersection : .unavailableDepth, reference: reference,
                      unknownError: unknownError, incompleteEquipment: incompleteEquipment)
    }

    /// Legacy drop/overhead/obstacle alerts always win. Supplementation may add an
    /// urgent warning, but never replace uncertainty with observing/clearance.
    public static func combining(_ legacy: Detection, with assessment: Assessment) -> Detection {
        guard !legacy.hazard.isUrgent, let supplemental = assessment.detection else { return legacy }
        return supplemental
    }
}
