import Foundation
import BlindCore

/// Same exclusive owner's recovery state. Scalar native observations only; no
/// inferred transform, persisted localization, body pose or physical authority.
/// Lock permits producer callbacks and main admission to share the existing gate.
public final class MeshBenchSavedWorldRecovery {
    private let lock = NSLock()
    private var recovery = SavedWorldFrameRecovery()
    private var latest: (session: UUID, capturedAt: Double)?
    public init() {}
    public func begin(frame: SavedWorldFrame, session: UUID, now: Double) {
        lock.lock(); defer { lock.unlock() }
        latest=nil;recovery.begin(frame:frame,sessionID:session,now:now)
    }
    public func retire() {
        lock.lock();defer{lock.unlock()};latest=nil;recovery.reset()
    }
    public func observe(session: UUID, tracking: SavedWorldFrameRecovery.Tracking,
        mappingAvailable: Bool, originMatches: Bool, capturedAt: Double, now: Double) {
        lock.lock();defer{lock.unlock()}
        let frame=recovery.observe(sessionID:session,tracking:tracking,mappingAvailable:mappingAvailable,
            originAnchorMatches:originMatches,frameTime:capturedAt,now:now)
        if frame != nil {latest=(session,capturedAt)}
        else if recovery.current(sessionID:session,now:now) == nil {latest=nil}
    }
    public func association(session: UUID, capturedAt: Double, now: Double) -> SavedWorldFrameCameraAssociation? {
        lock.lock();defer{lock.unlock()}
        return recovery.cameraAssociation(sessionID:session,capturedAt:capturedAt,now:now)
    }
    /// A later normal frame can maintain the epoch, never replace the original
    /// capture. Caller separately checks its exact frozen-capture/request lease.
    public func isCurrent(_ association: SavedWorldFrameCameraAssociation, now: Double) -> Bool {
        lock.lock();defer{lock.unlock()}
        guard let latest,let current=recovery.cameraAssociation(sessionID:latest.session,capturedAt:latest.capturedAt,now:now) else {return false}
        return current.sessionID == association.sessionID && current.frame == association.frame
            && current.recoveryID == association.recoveryID && association.capturedAt <= current.capturedAt
    }
}
