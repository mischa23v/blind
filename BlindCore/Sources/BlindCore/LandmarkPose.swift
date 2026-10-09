import Foundation

/// One landmark (furniture or fixture) seen now and matched to its saved place in a known room map.
///
/// Frames:
/// - `mapPosition` is in the room map frame, which follows `Observation`, `IndoorMap` and `RoomLayout`:
///   ARKit-style world axes, y up, horizontal plane x/z. Only x and z are used.
/// - `relative` is where the landmark is now, measured from the person in a horizontal body frame:
///   `x` = metres to the person's right (negative = left), `z` = metres ahead (negative = behind),
///   `y` is ignored. This is exactly `Point3(side, 0, ahead)` from `Observation.coordinates`.
///   It is not the ARKit camera frame, which looks along -z.
///
/// Bearings come from on-device detection in the camera image and distances from LiDAR depth.
/// Both positions must name the same reference point on the object (for example the centre of its
/// footprint); a depth hit on the near face of a long bed is not the bed's saved centre.
public struct LandmarkSighting: Sendable {
    public var mapPosition: Point3
    public var relative: Point3
    /// Relative trust in this sighting; must be finite and above zero.
    public var weight: Double
    public init(mapPosition: Point3, relative: Point3, weight: Double = 1) {
        self.mapPosition = mapPosition; self.relative = relative; self.weight = weight
    }
}

/// Where the person stands and which way they face in the room map frame, from landmark sightings.
public struct LandmarkPoseEstimate: Equatable, Sendable {
    /// Map frame, y = 0 (the fit is horizontal only).
    public var position: Point3
    /// Unit horizontal heading in the map frame (y = 0), in whatever body frame `relative` used.
    public var forward: Point3
    /// Weighted root-mean-square distance between the fitted and saved landmark positions (metres).
    public var residualMetres: Double
    public var landmarkCount: Int
    public init(position: Point3, forward: Point3, residualMetres: Double, landmarkCount: Int) {
        self.position = position; self.forward = forward
        self.residualMetres = residualMetres; self.landmarkCount = landmarkCount
    }
}

/// Small closed-form fallback and cross-check for "the bed is ahead 2 m, the wardrobe is on my right
/// 1.5 m": a weighted 2D rigid alignment (rotation and translation, no scale; the planar
/// Kabsch/Umeyama solution) from body-frame landmark positions to their saved map positions.
///
/// ARKit relocalisation stays the primary pose source. This only applies after the room itself is
/// known and the landmarks are matched; it does not identify the room, does not prove a path is
/// clear, and returns nil rather than a guess whenever the evidence leaves the pose uncertain.
public enum LandmarkPose {
    /// Fewest matched landmarks accepted.
    public static let minimumLandmarks = 2
    /// The two farthest-apart landmarks must be at least this far apart, both as seen and in the map (metres).
    public static let minimumSeparationMetres = 0.5
    /// A fit whose weighted RMS residual exceeds this is declined, which catches most wrong matches (metres).
    public static let maxResidualMetres = 0.35
    /// With exactly two landmarks the fit has one spare constraint only, so their seen and saved
    /// separations must agree within this (metres).
    public static let pairDistanceToleranceMetres = 0.2
    /// Assumed per-landmark noise along the line of sight: depth plus reference-point offset (metres).
    public static let assumedDepthNoiseMetres = 0.05
    /// Assumed per-landmark bearing noise from the image detection (degrees).
    public static let assumedBearingNoiseDegrees = 2.0
    /// Geometry whose predicted heading error, under the assumed noise above, exceeds this is declined (degrees).
    public static let maxPredictedHeadingErrorDegrees = 10.0

    /// Returns nil when the sightings do not settle the pose.
    ///
    /// Heading-ambiguity test: the fitted heading comes from each landmark's offset from the landmark
    /// centroid. Only noise perpendicular to that offset turns the heading. For each landmark that
    /// perpendicular noise mixes depth noise (along the line of sight) and bearing noise (across it,
    /// growing with distance). The predicted heading standard deviation is
    /// `sqrt(Σ w² |d|² σ⊥²) / Σ w |d|²`, with `d` the centred body-frame offset. Landmarks lying
    /// nearly on one line of sight from the person (for example 3.0 m and 3.6 m straight ahead) get
    /// their heading only from bearing noise at range and are declined; the same separation side by
    /// side is accepted.
    public static func solve(_ sightings: [LandmarkSighting]) -> LandmarkPoseEstimate? {
        guard sightings.count >= minimumLandmarks,
              sightings.allSatisfy({ $0.mapPosition.isFinite && $0.relative.isFinite &&
                                     $0.weight.isFinite && $0.weight > 0 }) else { return nil }

        // Body vectors are (ahead, side) and map vectors are (x, z). With this ordering the map-from-body
        // transform is a proper rotation by the heading angle θ, where forward = (cos θ, 0, sin θ):
        // facing -z, "right" maps to +x, matching `Observation.coordinates`.
        let body = sightings.map { PlanarVector($0.relative.z, $0.relative.x) }
        let map = sightings.map { PlanarVector($0.mapPosition.x, $0.mapPosition.z) }
        let weights = sightings.map(\.weight)

        guard largestSeparation(body) >= minimumSeparationMetres,
              largestSeparation(map) >= minimumSeparationMetres else { return nil }
        if sightings.count == 2 {
            let seen = body[0].distance(to: body[1]), saved = map[0].distance(to: map[1])
            guard abs(seen - saved) <= pairDistanceToleranceMetres else { return nil }
        }

        let total = weights.reduce(0, +)
        guard total.isFinite, total > 0 else { return nil }
        var bodyCentre = PlanarVector(0, 0), mapCentre = PlanarVector(0, 0)
        for i in sightings.indices {
            let share = weights[i] / total
            bodyCentre = bodyCentre.plus(body[i].scaled(share))
            mapCentre = mapCentre.plus(map[i].scaled(share))
        }

        var sumCos = 0.0, sumSin = 0.0, lever = 0.0, spread = 0.0
        let depthVariance = assumedDepthNoiseMetres * assumedDepthNoiseMetres
        let bearingNoise = assumedBearingNoiseDegrees * Double.pi / 180
        for i in sightings.indices {
            let d = body[i].minus(bodyCentre), e = map[i].minus(mapCentre), w = weights[i]
            sumCos += w * d.dot(e)
            sumSin += w * d.cross(e)
            let lengthSquared = d.dot(d)
            lever += w * lengthSquared
            guard lengthSquared > 0 else { continue }
            // Unit direction across the centred offset, split into line-of-sight and sideways parts.
            let length = lengthSquared.squareRoot()
            let across = PlanarVector(-d.b / length, d.a / length)
            let range = body[i].length
            var alongSight = 1.0, sideways = 0.0
            if range > 1e-9 {
                let sight = PlanarVector(body[i].a / range, body[i].b / range)
                alongSight = across.dot(sight)
                sideways = sight.cross(across)
            }
            let bearingSpread = range * bearingNoise * sideways
            let variance = depthVariance * alongSight * alongSight + bearingSpread * bearingSpread
            spread += w * w * lengthSquared * variance
        }
        guard lever.isFinite, lever > 0, spread.isFinite else { return nil }
        let predictedHeadingError = spread.squareRoot() / lever
        guard predictedHeadingError <= maxPredictedHeadingErrorDegrees * Double.pi / 180 else { return nil }

        let norm = hypot(sumCos, sumSin)
        guard norm.isFinite, norm > 1e-12 else { return nil }
        let c = sumCos / norm, s = sumSin / norm
        func rotate(_ v: PlanarVector) -> PlanarVector { PlanarVector(c * v.a - s * v.b, s * v.a + c * v.b) }
        let translation = mapCentre.minus(rotate(bodyCentre))

        var squaredError = 0.0
        for i in sightings.indices {
            let gap = rotate(body[i]).plus(translation).minus(map[i])
            squaredError += weights[i] * gap.dot(gap)
        }
        let residual = (squaredError / total).squareRoot()
        guard residual.isFinite, residual <= maxResidualMetres,
              translation.a.isFinite, translation.b.isFinite else { return nil }
        return LandmarkPoseEstimate(position: Point3(translation.a, 0, translation.b),
                                    forward: Point3(c, 0, s),
                                    residualMetres: residual, landmarkCount: sightings.count)
    }

    /// True when the landmark estimate and the ARKit pose agree. Positions are compared horizontally
    /// (the estimate has y = 0, the camera does not). Headings are compared by their horizontal parts;
    /// a forward pointing nearly straight up or down gives false. Compare like with like: if
    /// `relative` was built from the camera's forward, pass the camera's forward here.
    public static func agrees(_ estimate: LandmarkPoseEstimate, with arkitPosition: Point3, arkitForward: Point3,
                              positionTolerance: Double = 0.5, headingToleranceDegrees: Double = 20) -> Bool {
        guard estimate.position.isFinite, estimate.forward.isFinite, arkitPosition.isFinite, arkitForward.isFinite,
              positionTolerance.isFinite, positionTolerance >= 0,
              headingToleranceDegrees.isFinite, headingToleranceDegrees >= 0 else { return false }
        let offset = hypot(estimate.position.x - arkitPosition.x, estimate.position.z - arkitPosition.z)
        guard offset <= positionTolerance,
              let estimatedYaw = BodyHeadingEstimator.yaw(of: estimate.forward),
              let arkitYaw = BodyHeadingEstimator.yaw(of: arkitForward) else { return false }
        let difference = abs(BodyHeadingEstimator.wrap(estimatedYaw - arkitYaw))
        return difference <= headingToleranceDegrees * Double.pi / 180
    }

    private static func largestSeparation(_ points: [PlanarVector]) -> Double {
        var largest = 0.0
        for i in points.indices {
            for j in points.indices where j > i { largest = max(largest, points[i].distance(to: points[j])) }
        }
        return largest
    }

    /// Plain 2D vector; `a` and `b` are the first and second planar components.
    private struct PlanarVector {
        var a: Double, b: Double
        init(_ a: Double, _ b: Double) { self.a = a; self.b = b }
        var length: Double { hypot(a, b) }
        func dot(_ o: PlanarVector) -> Double { a * o.a + b * o.b }
        func cross(_ o: PlanarVector) -> Double { a * o.b - b * o.a }
        func scaled(_ k: Double) -> PlanarVector { PlanarVector(a * k, b * k) }
        func distance(to o: PlanarVector) -> Double { hypot(a - o.a, b - o.b) }
        func plus(_ o: PlanarVector) -> PlanarVector { PlanarVector(a + o.a, b + o.b) }
        func minus(_ o: PlanarVector) -> PlanarVector { PlanarVector(a - o.a, b - o.b) }
    }
}
