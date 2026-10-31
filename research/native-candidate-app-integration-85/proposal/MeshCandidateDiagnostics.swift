#if DEBUG && BLIND_MESH_CANDIDATE_DIAGNOSTICS
import Foundation
import MeshCandidateIngress83

/// Counters/lifecycle only. No native anchor, geometry, route or output API.
/// Existing NavigationModel/main callback ownership is deliberately unchanged.
final class MeshCandidateDiagnostics {
    // NavigationModel is not globally @MainActor; match its existing .main delegate.
    private func requireMain() { dispatchPrecondition(condition: .onQueue(.main)) }
    enum Event: Hashable { case added, updated, removed }
    private(set) var enabled = false // process-local explicit opt-in, never persisted
    private(set) var counts: [Event: UInt64] = [:]
    private(set) var refusedCopies: UInt64 = 0
    private(set) var epoch = UUID()
    private var owner: MeshCandidateIngress83?
    private var terminal = false

    func setEnabled(_ value: Bool) {
        requireMain()
        guard !terminal else { return }
        enabled = value
        if value { beginEpoch() } else { stop() }
    }
    func beginEpoch() {
        requireMain()
        guard enabled, !terminal else { return }
        epoch = UUID(); counts.removeAll(); refusedCopies = 0
        do {
            if let owner { try owner.reset() }
            else { owner = try MeshCandidateIngress83(maxAnchors: 128, maxCopies: 1) }
        } catch { enabled = false; owner?.stop() }
    }
    func observe(_ event: Event, anchorID: UUID, receiptUptime: Double) {
        requireMain()
        guard enabled, !terminal else { return }
        let count = counts[event, default: 0]
        counts[event] = count == .max ? count : count + 1
        switch event {
        case .added, .updated:
            // Main/hazard callback copying is NOT approved. Do not invoke ingest.
            refusedCopies = refusedCopies == .max ? refusedCopies : refusedCopies + 1
            owner?.stop() // refuse stale candidate state; no synthetic empty geometry
        case .removed:
            _ = owner?.remove(anchorID: anchorID, receiptUptime: receiptUptime)
        }
    }
    func stop() { requireMain(); owner?.stop() } // reusable same owner; not a purge
    func scanStarted() { beginEpoch(); stop() }
    func discard(completion: @escaping () -> Void) {
        requireMain()
        terminal = true; enabled = false
        // No replacement owner, including while the asynchronous acknowledgement waits.
        if let owner { owner.stopAndDiscard(completion: completion) }
        else { DispatchQueue.global(qos: .utility).async { completion() } }
    }
}
#endif
