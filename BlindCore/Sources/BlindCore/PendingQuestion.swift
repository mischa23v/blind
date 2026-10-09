import Foundation

/// A question may wait for speech, but its old answer/geometry may not.
/// Uses the same delivery validity checks as immediate scene requests.
public struct PendingQuestion: Sendable {
    public let question: String
    public let cloud: Bool
    public let focus: String
    public let goalRevision: String
    public let mapRevision: String
    public let alignmentRevision: String
    private let created: Double
    private let camera: Point3
    private let forward: Point3
    public init(question: String, cloud: Bool, focus: String, goalRevision: String, mapRevision: String,
                alignmentRevision: String, created: Double, camera: Point3, forward: Point3) {
        self.question = question; self.cloud = cloud; self.focus = focus; self.goalRevision = goalRevision
        self.mapRevision = mapRevision; self.alignmentRevision = alignmentRevision
        self.created = created; self.camera = camera; self.forward = forward
    }
    public func isCurrent(goalRevision: String, mapRevision: String, alignmentRevision: String,
                          now: Double, camera: Point3?, forward: Point3?, frameAt: Double, tracking: Bool, hazard: Hazard) -> Bool {
        self.goalRevision == goalRevision && self.mapRevision == mapRevision && self.alignmentRevision == alignmentRevision &&
            SceneDelivery.allowed(capturedAt: created, now: now, origin: self.camera, current: camera,
                currentFrameAt: frameAt, hazard: hazard, tracking: tracking, originForward: self.forward, currentForward: forward)
    }
}
