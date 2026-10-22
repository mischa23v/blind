import Foundation

public enum DetailLevel: String, CaseIterable, Codable { case minimal, balanced, detailed }
public struct AlertPolicy: Sendable {
    private var lastHazard: Hazard?
    private var lastTime = -Double.infinity
    private var lastReason: MonitoringReason?
    public init() {}
    public mutating func shouldAnnounce(_ detection: Detection, at time: Double) -> Bool {
        // A non-finite time would freeze repetition of the same urgent hazard; announce, store nothing.
        guard time.isFinite else { return detection.hazard.isUrgent }
        let changedUrgentEvidence = detection.hazard.isUrgent && lastHazard == detection.hazard && lastReason != detection.reason
        lastReason = detection.reason
        let scheduled = shouldAnnounce(detection.hazard, at: time)
        if changedUrgentEvidence { lastTime = time; return true }
        return scheduled
    }
    public mutating func shouldAnnounce(_ hazard: Hazard, at time: Double) -> Bool {
        let interval = hazard.isUrgent ? 1.5 : hazard == .uncertain ? 15.0 : 8.0
        if hazard != lastHazard || time - lastTime >= interval {
            lastHazard = hazard; lastTime = time
            return hazard != .observing && hazard != .stopped && hazard != .calibrating
        }
        return false
    }
    public static func highest(_ detections: [Detection]) -> Detection {
        let priorities: [Hazard: Int] = [.drop: 7, .overhead: 6, .obstacle: 5, .uncertain: 4,
                                       .needsCalibration: 3, .calibrating: 2, .observing: 1, .stopped: 0]
        return detections.max {
            let a = priorities[$0.hazard, default: 0], b = priorities[$1.hazard, default: 0]
            if a != b { return a < b }
            return $0.reason == .visualStairs && $1.reason != .visualStairs
        }
            ?? Detection(.stopped)
    }
}
