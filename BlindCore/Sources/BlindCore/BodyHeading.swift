import Foundation

/// Which way the person's body faces, kept separate from where a chest-mounted camera points
/// (FR-13 / O03). Axes follow `Observation`: ARKit world, y up, horizontal plane x/z.
/// Yaw 0 looks along -z and positive yaw turns left (counter-clockwise seen from above).
///
/// Evidence comes from two places:
/// - walking: a reasonably straight path of at least `minWalkDistance` gives the heading directly;
/// - a declared fixed mount: the steady offset between camera yaw and walking heading, learned while
///   walking, turns camera yaw into body heading while the person stands.
/// Without either, the heading is `.unknown` and the app does not say which way the person faces.
/// A body heading is orientation evidence only; it never shows that a path is clear.
public struct BodyHeading: Equatable, Sendable {
    public enum Source: String, Sendable { case walking, declaredMount, unknown }
    /// Horizontal unit vector (y = 0); the zero vector when `source` is `.unknown`.
    public var forward: Point3
    public var source: Source
    /// 0...1.
    public var confidence: Double
    /// Seconds since the evidence behind this heading was observed.
    public var age: Double
    public init(forward: Point3, source: Source, confidence: Double, age: Double) {
        self.forward = forward; self.source = source
        self.confidence = confidence.isFinite ? min(1, max(0, confidence)) : 0
        self.age = age
    }
    /// No current evidence for the body heading.
    public static let unknown = BodyHeading(forward: Point3(0, 0, 0), source: .unknown, confidence: 0, age: .infinity)
    public var isKnown: Bool { source != .unknown }
}

/// Feed one tracked camera pose per frame with `observe`, then ask `heading(at:declaredFixedMount:)`.
/// When `mountSlipSuspected` becomes true the app asks the person to re-check the mount and calls
/// `reset()` afterwards; until then the mount offset is not used.
public struct BodyHeadingEstimator: Sendable {
    // Walking evidence.
    /// Straight-line distance the person covers before their path gives a heading (metres).
    public static let minWalkDistance = 1.5
    /// Only this many recent seconds of path are used, so an older leg does not set the heading.
    public static let trailWindow = 5.0
    /// Path points are kept at this spacing (metres) so standing sway is not counted as walking.
    public static let trailSpacing = 0.1
    /// Upper bound on stored path points.
    public static let maxTrailPoints = 80
    /// Largest sideways distance (metres) from the straight line before the path counts as not straight.
    public static let maxLateralDeviation = 0.25
    /// Straight-line distance divided by walked length; below this the path is wandering.
    public static let minStraightness = 0.9
    /// Walking evidence is never treated as certain.
    public static let maxWalkingConfidence = 0.95
    /// A walking heading this recent (seconds) is the current heading.
    public static let walkingFreshSeconds = 1.0
    /// After stopping, a walking heading fades to unknown over this many seconds.
    public static let walkingHoldSeconds = 20.0
    /// A held walking heading is dropped once the camera has turned this far, since the person may have turned.
    public static let heldTurnTolerance = 45.0 * Double.pi / 180

    // Sample validity.
    /// Longer gaps between samples (seconds) start a new path.
    public static let maxSampleGap = 0.5
    /// Faster apparent movement (metres per second) is a tracking jump, not walking.
    public static let maxPlausibleSpeed = 4.0
    /// Camera forward must be at least this horizontal (fraction of its length) to give a yaw.
    public static let minHorizontalFraction = 0.3

    // Declared fixed mount.
    /// Seconds of walking used to learn the camera-to-body offset.
    public static let offsetLearnSeconds = 2.0
    /// Mean resultant length of offset samples required to accept the learned offset (about ±18° spread).
    public static let offsetConsistency = 0.95
    /// Share of each agreeing sample that refines the learned offset.
    public static let offsetSmoothing = 0.05
    /// An offset change larger than this suggests the mount moved.
    public static let slipThreshold = 25.0 * Double.pi / 180
    /// Seconds of walking with a shifted offset before a mount re-check is requested.
    public static let slipConfirmSeconds = 3.0
    /// Confidence of a heading from a declared mount while standing.
    public static let mountConfidence = 0.8
    /// Walking samples further apart than this (seconds) do not count as continuous walking time.
    public static let walkingSampleGap = 1.0

    private struct TrailPoint: Sendable { var time, x, z: Double }
    private struct WalkingEstimate: Sendable {
        var yaw: Double
        var confidence: Double
        var time: Double
        var cameraYaw: Double?
    }

    private var trail: [TrailPoint] = []
    private var lastSampleTime: Double?
    private var lastPosition: Point3?
    private var cameraYaw: Double?
    private var walking: WalkingEstimate?
    private var mountOffset: Double?
    private var baselineOffset: Double?
    private var learnCos = 0.0
    private var learnSin = 0.0
    private var learnCount = 0
    private var learnSeconds = 0.0
    private var divergentSeconds = 0.0
    /// True once the learned mount offset has shifted and stayed shifted while walking.
    /// The mount offset is not used again until `reset()`.
    public private(set) var mountSlipSuspected = false

    public init() {}

    /// Clears all evidence, including the learned mount offset and the slip flag.
    public mutating func reset() { self = BodyHeadingEstimator() }

    /// `camera` is the tracked camera position; `cameraForward` is its viewing direction in the same
    /// world axes (it may include pitch). Tracking loss, non-finite input, time running backwards or
    /// a tracking jump clear the estimate.
    public mutating func observe(camera: Point3, cameraForward: Point3, at time: Double, tracking: Bool) {
        guard tracking, camera.isFinite, cameraForward.isFinite, time.isFinite else { reset(); return }
        if let previous = lastSampleTime, let last = lastPosition {
            let dt = time - previous
            if dt == 0 { return }
            if dt < 0 { reset() }
            else if Self.horizontalDistance(last, camera) / dt > Self.maxPlausibleSpeed { reset() }
            else if dt > Self.maxSampleGap { trail.removeAll() }
        }
        lastSampleTime = time
        lastPosition = camera
        cameraYaw = Self.yaw(of: cameraForward)

        let point = TrailPoint(time: time, x: camera.x, z: camera.z)
        var advanced = false
        if let anchor = trail.last {
            if hypot(point.x - anchor.x, point.z - anchor.z) >= Self.trailSpacing { trail.append(point); advanced = true }
        } else {
            trail.append(point)
        }
        while trail.count > 1, trail[0].time < time - Self.trailWindow || trail.count > Self.maxTrailPoints {
            trail.removeFirst()
        }

        // Only a new step along the path refreshes walking evidence; standing lets it age.
        guard advanced, let leg = straightLeg() else { return }
        let previousWalkTime = walking?.time
        walking = WalkingEstimate(yaw: leg.yaw, confidence: leg.confidence, time: time, cameraYaw: cameraYaw)
        var seconds = 0.0
        if let previousWalkTime, time - previousWalkTime <= Self.walkingSampleGap { seconds = time - previousWalkTime }
        learnOffset(walkingYaw: leg.yaw, seconds: seconds)
    }

    /// `declaredFixedMount` is the person's own statement that the phone is fixed to the chest.
    public func heading(at time: Double, declaredFixedMount: Bool) -> BodyHeading {
        guard time.isFinite, let lastSampleTime else { return .unknown }
        if let walking {
            let age = max(0, time - walking.time)
            if age <= Self.walkingFreshSeconds {
                return BodyHeading(forward: Self.direction(yaw: walking.yaw), source: .walking,
                                   confidence: walking.confidence, age: age)
            }
        }
        let sampleAge = max(0, time - lastSampleTime)
        if declaredFixedMount, !mountSlipSuspected, let offset = mountOffset, let cameraYaw,
           sampleAge <= Self.maxSampleGap {
            return BodyHeading(forward: Self.direction(yaw: cameraYaw + offset), source: .declaredMount,
                               confidence: Self.mountConfidence, age: sampleAge)
        }
        if let walking {
            let age = max(0, time - walking.time)
            var turned = false
            if let then = walking.cameraYaw, let now = cameraYaw {
                turned = abs(Self.wrap(now - then)) > Self.heldTurnTolerance
            }
            if age < Self.walkingHoldSeconds, !turned {
                return BodyHeading(forward: Self.direction(yaw: walking.yaw), source: .walking,
                                   confidence: walking.confidence * (1 - age / Self.walkingHoldSeconds), age: age)
            }
        }
        return .unknown
    }

    /// The longest recent stretch of path, ending at the newest point, that is long and straight enough.
    private func straightLeg() -> (yaw: Double, confidence: Double)? {
        guard let end = trail.last, trail.count >= 2 else { return nil }
        for i in 0..<(trail.count - 1) {
            let start = trail[i]
            let dx = end.x - start.x, dz = end.z - start.z
            let distance = hypot(dx, dz)
            guard distance >= Self.minWalkDistance else { continue }
            let ux = dx / distance, uz = dz / distance
            var lateral = 0.0, pathLength = 0.0, endIsFarthest = true
            for j in i..<trail.count {
                let p = trail[j]
                let along = (p.x - start.x) * ux + (p.z - start.z) * uz
                lateral = max(lateral, abs((p.x - start.x) * uz - (p.z - start.z) * ux))
                if along > distance + 1e-6 { endIsFarthest = false }
                if j > i { pathLength += hypot(p.x - trail[j - 1].x, p.z - trail[j - 1].z) }
            }
            guard endIsFarthest, pathLength > 0, lateral <= Self.maxLateralDeviation,
                  distance / pathLength >= Self.minStraightness else { continue }
            guard let yaw = Self.yaw(of: Point3(ux, 0, uz)) else { return nil }
            let distanceScore = min(1, (distance - Self.minWalkDistance) / Self.minWalkDistance)
            let straightScore = 1 - lateral / Self.maxLateralDeviation
            let confidence = min(Self.maxWalkingConfidence, 0.5 + 0.25 * distanceScore + 0.25 * straightScore)
            return (yaw, confidence)
        }
        return nil
    }

    /// Learns the camera-to-body offset from walking, then watches it for a lasting shift.
    private mutating func learnOffset(walkingYaw: Double, seconds: Double) {
        guard !mountSlipSuspected, let cameraYaw else { return }
        let sample = Self.wrap(walkingYaw - cameraYaw)
        guard let offset = mountOffset, let baseline = baselineOffset else {
            learnCos += cos(sample); learnSin += sin(sample); learnCount += 1; learnSeconds += seconds
            guard learnSeconds >= Self.offsetLearnSeconds else { return }
            if hypot(learnCos, learnSin) / Double(learnCount) >= Self.offsetConsistency {
                let learned = atan2(learnSin, learnCos)
                mountOffset = learned; baselineOffset = learned
            }
            // An inconsistent window starts learning again rather than accepting a spread offset.
            learnCos = 0; learnSin = 0; learnCount = 0; learnSeconds = 0
            return
        }
        let difference = Self.wrap(sample - offset)
        var refined = offset
        if abs(difference) <= Self.slipThreshold {
            refined = Self.wrap(offset + Self.offsetSmoothing * difference)
            mountOffset = refined
            divergentSeconds = max(0, divergentSeconds - seconds)
        } else {
            divergentSeconds += seconds
        }
        // A sudden lasting shift, or slow creep away from the first learned offset, both ask for a re-check.
        if divergentSeconds >= Self.slipConfirmSeconds || abs(Self.wrap(refined - baseline)) > Self.slipThreshold {
            mountSlipSuspected = true
        }
    }

    /// Yaw of a direction's horizontal part, or nil when it points nearly straight up or down.
    static func yaw(of v: Point3) -> Double? {
        let length = (v.x * v.x + v.y * v.y + v.z * v.z).squareRoot()
        guard length.isFinite, length > 0, hypot(v.x, v.z) / length >= Self.minHorizontalFraction else { return nil }
        return atan2(-v.x, -v.z)
    }
    static func direction(yaw: Double) -> Point3 { Point3(-sin(yaw), 0, -cos(yaw)) }
    static func wrap(_ angle: Double) -> Double { atan2(sin(angle), cos(angle)) }
    static func horizontalDistance(_ a: Point3, _ b: Point3) -> Double { hypot(a.x - b.x, a.z - b.z) }
}
