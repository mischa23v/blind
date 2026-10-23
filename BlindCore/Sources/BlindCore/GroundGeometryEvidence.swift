import Foundation

/// Measurement settings, not a validated hazard threshold or a child safety profile.
/// Raw depth tolerance must ultimately be measured for the device/mount/surface.
public struct GroundGeometryProfile: Sendable {
    public let identifier: String
    public let residualTolerance: Double
    public let patchLength: Double
    public let halfWidth: Double
    public let patchCount: Int
    public let minimumSamples: Int
    public init(identifier: String, residualTolerance: Double, patchLength: Double = 0.2,
                halfWidth: Double = 0.38, patchCount: Int = 9, minimumSamples: Int = 12) {
        self.identifier = identifier; self.residualTolerance = residualTolerance
        self.patchLength = patchLength; self.halfWidth = halfWidth
        self.patchCount = patchCount; self.minimumSamples = minimumSamples
    }
    /// Shadow diagnostics only. This tolerance is NOT calibrated to an iPhone.
    public static let diagnostic = GroundGeometryProfile(identifier: "unvalidated-shadow-v1", residualTolerance: 0.015)
    var valid: Bool {
        !identifier.isEmpty && residualTolerance.isFinite && residualTolerance > 0 &&
        patchLength.isFinite && (0.05...0.5).contains(patchLength) &&
        halfWidth.isFinite && (0.1...0.8).contains(halfWidth) &&
        (2...16).contains(patchCount) && (6...1000).contains(minimumSamples)
    }
}

/// A fit describes only sampled geometry. It does not identify ground, a loose
/// object, slipperiness, traversability or safe foot/body clearance.
public struct GroundPlanePatch: Equatable, Codable, Sendable {
    public let index: Int
    public let near, far: Double
    public let forwardGradient, crossGradient: Double
    public let intercept: Double // y = forwardGradient * ahead + crossGradient * side + intercept
    public let maximumResidual: Double
    public let occupiedCells: Int
    public let sampleCount: Int
    /// Engineering tolerance propagated over patch length, NOT a calibrated confidence interval.
    public let gradientUncertainty: Double
    public var forwardDegrees: Double { atan(forwardGradient) * 180 / .pi }
    public var crossDegrees: Double { atan(crossGradient) * 180 / .pi }
    /// Unit normal in (ahead, up, side) coordinates, not a world-space orientation.
    public var localNormal: Point3 {
        let length = sqrt(1 + forwardGradient * forwardGradient + crossGradient * crossGradient)
        return Point3(-forwardGradient / length, 1 / length, -crossGradient / length)
    }
    public func height(ahead: Double, side: Double = 0) -> Double {
        forwardGradient * ahead + crossGradient * side + intercept
    }
}

public struct GroundTransition: Equatable, Codable, Sendable {
    public enum Kind: String, Codable, Sendable { case continuousCandidate, rise, drop, conflicting }
    public let fromPatch, toPatch: Int
    public let ahead, signedHeightChange, uncertainty: Double
    public let kind: Kind
}

public struct GroundGeometryEvidence: Equatable, Codable, Sendable {
    public enum Source: String, Codable, Sendable { case sceneDepth, recordedDepth, synthetic, replay }
    public enum Status: String, Codable, Sendable {
        case measured, incompleteSupport, invalidInput, stale, unanchored
    }
    public let source: Source
    public let frameID, profileID: String
    public let timestamp: Double
    public let status: Status
    public let camera: Point3?
    public let forward: Point3?
    public let patches: [GroundPlanePatch]
    public let transitions: [GroundTransition]
    public let referenceFloor: Double?
    /// Always false: diagnostic geometry cannot authorize speech, movement or pickup.
    public var authorizesPhysicalGuidance: Bool { false }
    public var frictionKnown: Bool { false }
    public var surfaceMovabilityKnown: Bool { false }
}

/// Bounded local least-squares plane measurement using the existing gravity-aligned
/// Observation. Unlike one global plane, separate patches never bridge a missing
/// row; resolved mixed steps fail the residual check rather than becoming a ramp. ALL sampled residuals must pass; outliers are
/// not discarded as harmless (they could be a small raised/loose object).
/// This is a new diagnostic adapter, not PCL code, a ground recognizer, or SLAM.
public enum GroundGeometryAnalyzer {
    public static func analyze(_ frame: Observation, now: Double, frameID: String,
                               source: GroundGeometryEvidence.Source,
                               referenceFloor: Double?, profile: GroundGeometryProfile = .diagnostic) -> GroundGeometryEvidence {
        func result(_ status: GroundGeometryEvidence.Status, _ patches: [GroundPlanePatch] = [],
                    _ transitions: [GroundTransition] = []) -> GroundGeometryEvidence {
            GroundGeometryEvidence(source: source, frameID: frameID, profileID: profile.identifier,
                timestamp: frame.timestamp.isFinite ? frame.timestamp : 0, status: status,
                camera: frame.camera.isFinite ? frame.camera : nil,
                forward: frame.forward.isFinite ? frame.forward : nil,
                patches: patches, transitions: transitions,
                referenceFloor: referenceFloor.flatMap { $0.isFinite ? $0 : nil })
        }
        guard profile.valid, !frameID.isEmpty, frame.timestamp.isFinite, now.isFinite,
              frame.camera.isFinite, frame.forward.isFinite, frame.trackingNormal,
              abs(frame.forward.y) < 0.001, abs(hypot(frame.forward.x, frame.forward.z) - 1) < 0.001,
              frame.samples.count <= 100_000,
              referenceFloor.map({ $0.isFinite }) ?? true else { return result(.invalidInput) }
        guard now >= frame.timestamp, now - frame.timestamp <= 0.5 else { return result(.stale) }
        // Full local support, not confidence alone, is required. A missing floor
        // reference leaves raw patches useful diagnostically but never anchored.
        var buckets = Array(repeating: [(x: Double, z: Double, y: Double)](), count: profile.patchCount)
        for sample in frame.samples where sample.confidence == 2 && sample.position.isFinite {
            let c = frame.coordinates(sample.position)
            guard c.ahead >= 0.3, c.ahead < 0.3 + Double(profile.patchCount) * profile.patchLength,
                  abs(c.side) < profile.halfWidth else { continue }
            let row = Int((c.ahead - 0.3) / profile.patchLength)
            buckets[row].append((c.ahead, c.side, sample.position.y))
        }
        var patches: [GroundPlanePatch] = []
        for index in buckets.indices {
            let points = buckets[index], near = 0.3 + Double(index) * profile.patchLength
            guard points.count >= profile.minimumSamples else { continue }
            // Every cell in the 3x3 footprint needs measured support. A dense
            // stripe, isolated cluster or two ends around a hole is insufficient.
            let cells = Set(points.map { p in
                min(2, max(0, Int((p.x - near) / profile.patchLength * 3))) * 3 +
                min(2, max(0, Int((p.z + profile.halfWidth) / (2 * profile.halfWidth) * 3)))
            })
            guard cells.count == 9 else { continue }
            guard let fit = fitPlane(points) else { continue }
            let (a, b, c, residual) = fit
            // A single least-squares plane can smooth a real step even when all
            // residuals fit the tolerance. Compare independently fitted halves
            // at internal boundaries; resolved jumps invalidate the whole patch.
            var internalJump = false
            var supportedAxes = 0
            for alongForward in [true, false] {
                var supportedSplit = false
                for fraction in [0.25, 0.5, 0.75] {
                    let boundary = alongForward ? near + profile.patchLength * fraction :
                        -profile.halfWidth + 2 * profile.halfWidth * fraction
                    // Rigid yaw transforms can put a mathematically identical
                    // sample row on both sides by round-off. Assign the whole
                    // numerical boundary to the right, never manufacture rank.
                    // 1e-9 m is numerical precision, NOT a physical noise cutoff.
                    let split = boundary - 1e-9
                    let left = points.filter { (alongForward ? $0.x : $0.z) < split }
                    let right = points.filter { (alongForward ? $0.x : $0.z) >= split }
                    guard left.count >= 6, right.count >= 6,
                          let l = fitPlane(left), let r = fitPlane(right),
                          l.3 <= profile.residualTolerance, r.3 <= profile.residualTolerance else { continue }
                    supportedSplit = true
                    let evaluations = alongForward ? [-profile.halfWidth, 0, profile.halfWidth] :
                        [near, near + profile.patchLength / 2, near + profile.patchLength]
                    let differences = evaluations.map { value in
                        let ahead = alongForward ? boundary : value
                        let side = alongForward ? value : boundary
                        return (r.0 - l.0) * ahead + (r.1 - l.1) * side + r.2 - l.2
                    }
                    if differences.contains(where: { abs($0) > 2 * profile.residualTolerance }) {
                        internalJump = true; break
                    }
                }
                if supportedSplit { supportedAxes += 1 }
                if internalJump { break }
            }
            // Without a nondegenerate split on each axis, sparse stair samples
            // can be indistinguishable from a plane. Preserve unknown instead.
            guard !internalJump, supportedAxes == 2 else { continue }
            // Steep/vertical/mixed surfaces remain unknown, not a walkable ramp.
            guard a.isFinite, b.isFinite, c.isFinite, abs(a) <= 1, abs(b) <= 1,
                  residual <= profile.residualTolerance else { continue }
            patches.append(GroundPlanePatch(index: index, near: near, far: near + profile.patchLength,
                forwardGradient: a, crossGradient: b, intercept: c, maximumResidual: residual,
                occupiedCells: cells.count, sampleCount: points.count,
                gradientUncertainty: 2 * profile.residualTolerance / profile.patchLength))
        }
        var transitions: [GroundTransition] = []
        for pair in zip(patches, patches.dropFirst()) where pair.1.index == pair.0.index + 1 {
            let a = pair.0, b = pair.1, boundary = b.near
            let deltas = [-profile.halfWidth, 0, profile.halfWidth].map {
                b.height(ahead: boundary, side: $0) - a.height(ahead: boundary, side: $0)
            }
            let tolerance = 2 * profile.residualTolerance
            let kind: GroundTransition.Kind
            if deltas.allSatisfy({ $0 > tolerance }) { kind = .rise }
            else if deltas.allSatisfy({ $0 < -tolerance }) { kind = .drop }
            else if deltas.allSatisfy({ abs($0) <= tolerance }) { kind = .continuousCandidate }
            else { kind = .conflicting }
            transitions.append(GroundTransition(fromPatch: a.index, toPatch: b.index,
                ahead: boundary, signedHeightChange: deltas[1], uncertainty: tolerance, kind: kind))
        }
        guard let referenceFloor, let first = patches.first, first.index == 0,
              abs(first.height(ahead: 0) - referenceFloor) <= profile.residualTolerance * 2 else {
            return result(.unanchored, patches, transitions)
        }
        return result(patches.count == profile.patchCount ? .measured : .incompleteSupport, patches, transitions)
    }
    private static func fitPlane(_ points: [(x: Double, z: Double, y: Double)]) -> (Double, Double, Double, Double)? {
        guard points.count >= 3 else { return nil }
        let n = Double(points.count)
        let mx = points.reduce(0) { $0 + $1.x } / n
        let mz = points.reduce(0) { $0 + $1.z } / n
        let my = points.reduce(0) { $0 + $1.y } / n
        var xx = 0.0, zz = 0.0, xz = 0.0, xy = 0.0, zy = 0.0
        for p in points {
            let x = p.x - mx, z = p.z - mz, y = p.y - my
            xx += x*x; zz += z*z; xz += x*z; xy += x*y; zy += z*y
        }
        let determinant = xx * zz - xz * xz
        guard determinant.isFinite, determinant > 1e-12 else { return nil }
        let a = (xy * zz - zy * xz) / determinant
        let b = (zy * xx - xy * xz) / determinant
        let c = my - a * mx - b * mz
        let residual = points.map { abs($0.y - (a * $0.x + b * $0.z + c)) }.max() ?? .infinity
        guard a.isFinite, b.isFinite, c.isFinite, residual.isFinite else { return nil }
        return (a, b, c, residual)
    }

}
