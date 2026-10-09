import Foundation

/// Supplemental RGB evidence. Absence of a match never grants clearance.
public enum VisualHazard {
    public static func isStairIdentifier(_ identifier: String) -> Bool {
        ["stairs", "stair", "staircase", "stairway"].contains(identifier.lowercased())
    }
    public static func warning(identifier: String, confidence: Double, capturedAt: Double, now: Double,
                               origin: Point3, current: Point3, originForward: Point3,
                               currentForward: Point3, tracking: Bool, currentFrameAt: Double,
                               originPitch: Double = 0, currentPitch: Double = 0) -> Detection? {
        guard isStairIdentifier(identifier), confidence.isFinite, (0.75...1).contains(confidence),
              capturedAt.isFinite, now.isFinite, currentFrameAt.isFinite,
              now >= capturedAt, now - capturedAt <= 1.5,
              now >= currentFrameAt, now - currentFrameAt <= 0.5, tracking,
              originPitch.isFinite, currentPitch.isFinite, abs(currentPitch - originPitch) <= .pi / 12,
              origin.isFinite, current.isFinite, origin.distance(to: current) <= 0.3,
              originForward.isFinite, currentForward.isFinite,
              abs(hypot(originForward.x, originForward.z) - 1) < 0.05,
              abs(hypot(currentForward.x, currentForward.z) - 1) < 0.05,
              (originForward.x * currentForward.x + originForward.z * currentForward.z) /
                (hypot(originForward.x, originForward.z) * hypot(currentForward.x, currentForward.z)) >= cos(.pi / 12) else { return nil }
        // Image classification provides no edge distance, up/down or body bearing.
        return Detection(.obstacle, reason: .visualStairs)
    }
}
