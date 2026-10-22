import Foundation

/// Shared strict captured-view gate for requested visual facts, not navigation heading.
public enum RequestedVisualCapturePose {
    /// Full optical direction (including pitch), not the horizontal navigation heading.
    public static func poseStable(origin: Point3, current: Point3, originForward: Point3, currentForward: Point3) -> Bool {
        guard origin.isFinite, current.isFinite, originForward.isFinite, currentForward.isFinite,
              origin.distance(to: current) < 0.10 else { return false }
        let first = hypot(hypot(originForward.x,originForward.y),originForward.z)
        let last = hypot(hypot(currentForward.x,currentForward.y),currentForward.z)
        guard (0.9...1.1).contains(first), (0.9...1.1).contains(last) else { return false }
        let cosine = (originForward.x*currentForward.x + originForward.y*currentForward.y + originForward.z*currentForward.z)/(first*last)
        return cosine.isFinite && cosine > cos(.pi/36)
    }
}
