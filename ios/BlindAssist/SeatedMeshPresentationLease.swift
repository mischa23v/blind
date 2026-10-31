#if DEBUG && BLIND_MESH_CANDIDATE_DIAGNOSTICS
import Foundation

/// Main-owner UI authorization only; never a tracking, geometry or safety lease.
/// A queued dialog action cannot outlive Stop, End, background or its exact view.
struct SeatedMeshPresentationLease {
    private var view: UUID?
    private var confirmation: UUID?
    mutating func open() -> UUID { let id = UUID(); view = id; confirmation = nil; return id }
    func owns(view id: UUID) -> Bool { view == id }
    mutating func confirm(view id: UUID) -> UUID? {
        guard view == id else { return nil }
        let ticket = UUID(); confirmation = ticket; return ticket
    }
    mutating func consume(view id: UUID, confirmation ticket: UUID) -> Bool {
        guard view == id, confirmation == ticket else { return false }
        confirmation = nil; return true
    }
    mutating func cancelConfirmation() { confirmation = nil }
    @discardableResult mutating func close(view id: UUID) -> Bool {
        guard view == id else { return false }
        view = nil; confirmation = nil; return true
    }
}
#endif
