import Foundation
import BlindCore
import BlindRoomMesh

/// Main-actor display owner connects actual runtime output, while rechecking its
/// revision every time a consumer reads it. No speech/haptic/physical route sink.
@MainActor public final class RoomMeshPreviewOwner {
    private var retained: RoomMeshPreview?
    private var runtime: RoomMeshCandidateRuntime?
    private var candidate: MeshCandidateRoute?
    public init() {}
    public var current: RoomMeshPreview? {
        if let candidate = candidate {
            guard let runtime = runtime, runtime.isCurrent(candidate) else { clear(); return nil }
        }
        return retained
    }
    public func clear() { retained = nil; candidate = nil; runtime = nil }
    public func installSaved(_ preview: RoomMeshPreview) {
        clear(); retained = preview
    }
    public func accept(_ candidate: MeshCandidateRoute, from runtime: RoomMeshCandidateRuntime,
                       context: RoomPreviewContext) throws {
        // Rejecting a new result also retires the prior preview; it cannot stay on screen.
        clear()
        guard runtime.isCurrent(candidate) else { throw RoomPreviewError.staleCandidate }
        let preview = try RoomMeshPreview(context: context,
            sourceID: candidate.sessionID + ":" + String(candidate.generation) + ":" + String(candidate.revision),
            points: candidate.points, projectedStart: candidate.projectedStart,
            projectedGoal: candidate.projectedGoal, complete: candidate.complete,
            nativeStatus: candidate.nativeStatus, unknownCoverage: candidate.unknownCoverage,
            sourceDeliveryComplete: candidate.sourceDeliveryComplete)
        guard runtime.isCurrent(candidate) else { throw RoomPreviewError.staleCandidate }
        self.runtime = runtime; self.candidate = candidate; retained = preview
    }
}
