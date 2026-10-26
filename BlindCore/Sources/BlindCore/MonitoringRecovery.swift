import Foundation

public enum MonitoringReason: String, Codable, Sendable {
    case trackingUnavailable, depthUnavailable, cameraOrientation, cameraHeight
    case frameUnavailable, invalidGeometry, groundCoverage, groundNeedsRecheck, localizing
    case visualStairs, bodyEnvelope
}

/// Holds UNAVAILABILITY during recovery, never postpones a new hazard.
/// This changes presentation and guidance eligibility, not the raw detector result.
public struct MonitoringContinuity: Sendable {
    private var unavailable: Detection?
    private var recoveryStarted: Double?
    private var previousTime: Double?
    public init() {}

    public mutating func process(_ detection: Detection, at time: Double) -> Detection {
        guard time.isFinite else {
            self = MonitoringContinuity()
            return detection.hazard.isUrgent ? detection : Detection(.uncertain, reason: .frameUnavailable)
        }
        if let previousTime, time < previousTime || time - previousTime > 0.5 {
            recoveryStarted = nil
            unavailable = Detection(.uncertain, reason: .frameUnavailable)
        }
        previousTime = time
        if detection.hazard == .uncertain {
            unavailable = detection; recoveryStarted = nil
            return detection
        }
        guard detection.hazard == .observing else {
            unavailable = nil; recoveryStarted = nil
            return detection // New danger, calibration and stop always take effect now.
        }
        guard let unavailable else { return detection }
        if recoveryStarted == nil { recoveryStarted = time }
        guard time - recoveryStarted! >= 1 else { return unavailable }
        self.unavailable = nil; recoveryStarted = nil
        return detection
    }
}

/// Diagnostic history of MEASURED floor only. Never used to authorize clearance.
/// No interpolation, map completion, or learned predictions are inserted here.
struct GroundEvidenceMemory: Sendable {
    private struct Entry: Sendable {
        var time: Double
        var camera: Point3
        var forward: Point3
        var points: [DepthSample]
    }
    private var entries: [Entry] = []

    static func counts(_ samples: [DepthSample], frame: Observation, floor: Double) -> [Int: Int] {
        var result: [Int: Int] = [:]
        for sample in samples where sample.confidence >= 2 && sample.position.isFinite && abs(sample.position.y - floor) < 0.04 {
            let c = frame.coordinates(sample.position)
            guard (0.3..<2.1).contains(c.ahead), abs(c.side) <= 0.38 else { continue }
            let column = min(3, max(0, Int((c.side + 0.38) / 0.19)))
            result[Int((c.ahead - 0.3) / 0.2) * 4 + column, default: 0] += 1
        }
        return result
    }

    mutating func missingGroundWasRecentlyMeasured(_ frame: Observation, floor: Double, current: [Int: Int]) -> Bool {
        entries.removeAll {
            frame.timestamp <= $0.time || frame.timestamp - $0.time > 0.25 ||
            frame.camera.distance(to: $0.camera) > 0.1 ||
            frame.forward.x * $0.forward.x + frame.forward.z * $0.forward.z < 0.966
        }
        let missing = (0..<9).flatMap { [$0 * 4 + 1, $0 * 4 + 2] }.filter { current[$0, default: 0] < 3 }
        // Require a complete measured patch in one prior frame; don't multiply
        // one pixel's credibility by counting it again in several frames.
        let found = !missing.isEmpty && entries.contains { entry in
            let previous = Self.counts(entry.points, frame: frame, floor: floor)
            return missing.contains { previous[$0, default: 0] >= 3 }
        }
        let points = frame.samples.filter { $0.confidence >= 2 && $0.position.isFinite && abs($0.position.y - floor) < 0.04 }
        entries.append(Entry(time: frame.timestamp, camera: frame.camera, forward: frame.forward,
                             points: Array(points.prefix(16_000))))
        if entries.count > 4 { entries.removeFirst(entries.count - 4) }
        return found
    }
}
