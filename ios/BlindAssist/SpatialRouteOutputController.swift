import Foundation
import BlindCore

/// Main-thread route delivery owner used by NavigationModel. It does not authorize
/// localization: the installed route owner and independent sensor gate must still
/// permit the exact ticket at enqueue, beacon dispatch, playback start and watchdog.
/// Callbacks target one attempt ID only, never a shared hazard/status stop channel.
final class SpatialRouteOutputController {
    struct Attempt {
        let id: UUID
        let ticket: SpatialRouteTicket
        let goalRevision: String
    }
    private(set) var active: Attempt?
    var permits: ((SpatialRouteTicket, String) -> Bool)?
    var stopSpeech: ((UUID) -> Void)?
    var stopBeacon: ((UUID) -> Void)?

    @discardableResult
    func deliver(ticket: SpatialRouteTicket, goalRevision: String,
                 speech: (UUID) -> Bool, beacon: (UUID) -> Bool) -> Bool {
        retire()
        let attempt = Attempt(id: UUID(), ticket: ticket, goalRevision: goalRevision)
        active = attempt
        guard validateForStart(attempt.id) else { return false }
        guard speech(attempt.id) else { retire(id: attempt.id); return false }
        // A synchronous callback or priority change can invalidate the ticket
        // between sinks. Do not promote speech admission into beacon permission.
        guard validateForStart(attempt.id) else { return false }
        _ = beacon(attempt.id)
        guard validateForStart(attempt.id) else { return false }
        return true
    }
    @discardableResult
    func validateForStart(_ id: UUID) -> Bool {
        guard let active, active.id == id else { return false }
        guard permits?(active.ticket, active.goalRevision) == true else {
            retire(id: id); return false
        }
        return true
    }
    func revalidate() {
        if let active { _ = validateForStart(active.id) }
    }
    func retire(id: UUID? = nil) {
        guard let attempt = active, id == nil || id == attempt.id else { return }
        // Invalidate before callbacks: completion of the old speech must never
        // retire a replacement attempt or a newer independent alert beacon.
        active = nil
        stopSpeech?(attempt.id); stopBeacon?(attempt.id)
    }
}

/// The audio player is shared with independent alerts. An alert or unowned beep
/// replaces this token before playback; a delayed route retirement cannot stop it.
struct SpatialRouteBeaconOwnership {
    private(set) var routeID: UUID?
    mutating func replace(routeID: UUID?) { self.routeID = routeID }
    mutating func retire(_ id: UUID) -> Bool {
        guard routeID == id else { return false }
        routeID = nil; return true
    }
}
