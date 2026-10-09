import Foundation

public enum Hazard: String, Codable, Sendable {
    case stopped, calibrating, needsCalibration, observing, uncertain, drop, obstacle, overhead
    public var isUrgent: Bool { self == .drop || self == .obstacle || self == .overhead }
    /// Loss of monitoring must also interrupt optional speech, without inventing a hazard.
    public var requiresImmediateAttention: Bool { isUrgent || self == .uncertain || self == .needsCalibration }
}

public struct Detection: Equatable, Sendable {
    public var hazard: Hazard
    public var distance: Double?
    public var sector: Int
    public var coverage: Double
    public var reason: MonitoringReason?
    public init(_ hazard: Hazard, distance: Double? = nil, sector: Int = 0, coverage: Double = 0, reason: MonitoringReason? = nil) {
        self.hazard = hazard; self.distance = distance; self.sector = sector; self.coverage = coverage
        self.reason = reason
    }
}

/// Research prototype for a LEVEL calibrated floor. Absence of returns is UNKNOWN.
/// A credible lower surface is evidence of a drop; it is never a clearance test.
public struct HazardDetector: Sendable {
    public private(set) var floorHeight: Double?
    public private(set) var calibrationProgress: Double = 0
    private var calibrating = false
    private var calibrationHeights: [Double] = []
    private var calibrationOrigin: Point3?
    private var lastTimestamp: Double?
    private var held: Detection?
    private var heldUntil: Double = 0
    private var groundMemory = GroundEvidenceMemory()

    public init() {}
    public mutating func reset() { self = HazardDetector() }
    public mutating func invalidateRecentEvidence() {
        held = nil; groundMemory = GroundEvidenceMemory()
        calibrationHeights = []; calibrationProgress = 0
    }
    public mutating func beginCalibration() { reset(); calibrating = true }

    public mutating func process(_ frame: Observation) -> Detection {
        guard frame.trackingNormal else { return unavailable(.trackingUnavailable) }
        guard frame.timestamp.isFinite, frame.camera.isFinite, frame.forward.isFinite,
              frame.trackingNormal,
              abs(hypot(frame.forward.x, frame.forward.z) - 1) < 0.05 else {
            return unavailable(.invalidGeometry)
        }
        if let previous = lastTimestamp {
            guard frame.timestamp > previous else { return unavailable(.frameUnavailable) }
            if frame.timestamp - previous > 0.5 {
                held = nil; calibrationHeights = []; groundMemory = GroundEvidenceMemory()
            }
        }
        lastTimestamp = frame.timestamp
        let valid = frame.samples.filter { $0.confidence >= 2 && $0.position.isFinite }
        if calibrating { return calibrate(frame, samples: valid) }
        guard let floor = floorHeight else { return Detection(.needsCalibration) }
        let height = frame.camera.y - floor
        guard (0.65...1.9).contains(height) else { return unavailable(.cameraHeight) }

        let corridor = valid.filter {
            let c = frame.coordinates($0.position)
            return (0.3...2.2).contains(c.ahead) && abs(c.side) <= 0.38
        }
        // Count occupied cells rather than trusting many pixels on one surface.
        var floorCells = Set<Int>()
        var floorCounts: [Int: Int] = [:]
        var belowCells = Set<Int>()
        var aboveCells = Set<Int>()
        var headCells = Set<Int>()
        var dropDistance = Double.infinity, obstacleDistance = Double.infinity
        var headDistance = Double.infinity, obstacleSide = 0.0
        for sample in corridor {
            let c = frame.coordinates(sample.position)
            let cell = Int((c.ahead - 0.3) / 0.2) * 4 + min(3, max(0, Int((c.side + 0.38) / 0.19)))
            let elevation = sample.position.y - floor
            // Conservative prototype bands: small departures from calibrated floor
            // remove support evidence even before they can be labelled as a step.
            if abs(elevation) < 0.04 { floorCells.insert(cell); floorCounts[cell, default: 0] += 1 }
            if elevation < -0.09 {
                belowCells.insert(cell); dropDistance = min(dropDistance, c.ahead)
            }
            if elevation > 0.09 && elevation < height + 0.18 && c.ahead < 1.6 {
                aboveCells.insert(cell)
                if c.ahead < obstacleDistance { obstacleDistance = c.ahead; obstacleSide = c.side }
            }
            if elevation >= height + 0.18 && elevation <= height + 0.8 && c.ahead < 1.4 {
                headCells.insert(cell); headDistance = min(headDistance, c.ahead)
            }
        }
        let coverage = min(1, Double(floorCells.count) / 24)
        let recentlyMeasured = groundMemory.missingGroundWasRecentlyMeasured(frame, floor: floor, current: floorCounts)
        let raw: Detection
        if belowCells.count >= 3 { raw = Detection(.drop, distance: dropDistance, coverage: coverage) }
        else if headCells.count >= 3 { raw = Detection(.overhead, distance: headDistance, coverage: coverage) }
        else if aboveCells.count >= 3 {
            raw = Detection(.obstacle, distance: obstacleDistance,
                            sector: obstacleSide < -0.15 ? 7 : obstacleSide > 0.15 ? 1 : 0,
                            coverage: coverage)
        } else {
            // Near and far patches must not conceal a hole between them. Require
            // repeated support samples in both central columns of every 20 cm row,
            // from 0.3 to 2.1 m. Missing support remains unknown, never inferred floor.
            let continuousSupport = (0..<9).allSatisfy { row in
                floorCounts[row * 4 + 1, default: 0] >= 3 && floorCounts[row * 4 + 2, default: 0] >= 3
            }
            raw = Detection(continuousSupport ? .observing : .uncertain,
                            coverage: coverage, reason: continuousSupport ? nil : recentlyMeasured ? .groundNeedsRecheck : .groundCoverage)
        }
        if raw.hazard.isUrgent {
            // Validate spatial evidence above, then warn on this very frame.
            // Hold the warning on release; never debounce its onset.
            held = raw; heldUntil = frame.timestamp + 0.7
            return raw
        }
        if let held, frame.timestamp < heldUntil { return held }
        held = nil
        return raw
    }

    private mutating func unavailable(_ reason: MonitoringReason) -> Detection {
        held = nil; calibrationHeights = []; calibrationProgress = 0
        groundMemory = GroundEvidenceMemory()
        return Detection(.uncertain, reason: reason)
    }

    private mutating func calibrate(_ frame: Observation, samples: [DepthSample]) -> Detection {
        if let origin = calibrationOrigin, origin.distance(to: frame.camera) > 0.12 {
            calibrationHeights = []; calibrationOrigin = frame.camera
        }
        if calibrationOrigin == nil { calibrationOrigin = frame.camera }
        let near = samples.filter {
            let c = frame.coordinates($0.position)
            return (0.3...1.25).contains(c.ahead) && abs(c.side) <= 0.35 &&
                   (0.65...1.9).contains(frame.camera.y - $0.position.y)
        }
        let heights = near.map(\.position.y).sorted()
        guard heights.count >= 30 else {
            calibrationHeights = []; calibrationProgress = 0; return Detection(.calibrating)
        }
        let median = heights[heights.count / 2]
        let inliers = near.filter { abs($0.position.y - median) < 0.035 }
        let bins = Set(inliers.map { Int((frame.coordinates($0.position).ahead - 0.3) / 0.3) })
        guard Double(inliers.count) / Double(near.count) >= 0.8, bins.count >= 3 else {
            calibrationHeights = []; calibrationProgress = 0; return Detection(.calibrating)
        }
        if let first = calibrationHeights.first, abs(first - median) > 0.035 { calibrationHeights = [] }
        calibrationHeights.append(median)
        calibrationProgress = min(1, Double(calibrationHeights.count) / 15)
        if calibrationHeights.count >= 15 {
            let sorted = calibrationHeights.sorted()
            floorHeight = sorted[sorted.count / 2]; calibrating = false
            return Detection(.observing)
        }
        return Detection(.calibrating)
    }
}
