import Foundation
import MeshCandidateIngress83
import MeshSnapshot82
import BlindRoomMesh

/// Bounded per-callback scheduling, not a queue or retained anchor collection.
/// Nonescaping delivery keeps native references in their original callback scope.
struct MeshBenchCallbackBudget {
    private var next = 0
    @discardableResult mutating func deliver(count: Int, _ offer: (Int, Bool) -> Void) -> Bool {
        guard (0...128).contains(count) else { return false }
        guard count > 0 else { return true }
        let selected = next % count; next = (selected + 1) % count
        offer(selected, true)
        for index in 0..<count where index != selected { offer(index, false) }
        return true
    }
}

/// One terminal diagnostic generation. Existing 83 owns geometry, copy slots,
/// revision/tombstone fencing, decoding and native Recast requests. No new mapper.
/// Creating this value does not create/run a camera or enable app diagnostics.
public final class LiveMeshBenchIngress {
    public let generation = UUID()
    private let ingress: MeshCandidateIngress83
    private let lock = NSLock()
    private var stopped = false
    public let phoneMonitoringAvailable = false
    public let authorizesPhysicalGuidance = false

    public init(decodeQueue: DispatchQueue = DispatchQueue(label: "blind.mesh-bench.decode", qos: .utility)) throws {
        // Source floor semantics only. Nonfloor/unknown faces remain geometry;
        // this does not certify support or convert an omitted revision to free space.
        ingress = try MeshCandidateIngress83(maxAnchors: 128, maxCopies: 1,
            supportPolicy: .classifiedFloorOnly, decodeQueue: decodeQueue)
    }
    private func active(_ generation: UUID) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return !stopped && self.generation == generation
    }
    /// The native producer calls this synchronously on its owning callback queue.
    /// It is also the real dependency seam used by synthetic owned-buffer tests.
    /// It never retains capture; borrowed ARKit/Metal values cannot cross its worker.
    @discardableResult public func observe(anchorID: UUID, generation: UUID, receiptUptime: Double,
        capture: (MeshSnapshot82.Context) -> MeshSnapshot82.Capture) -> Bool {
        guard active(generation) else { return false }
        // A concurrent stop is also fenced by 83 before capture admission.
        return ingress.ingest(anchorID: anchorID, receiptUptime: receiptUptime, capture: capture)
    }
    @discardableResult public func remove(anchorID: UUID, generation: UUID, receiptUptime: Double) -> Bool {
        guard active(generation) else { return false }
        return ingress.remove(anchorID: anchorID, receiptUptime: receiptUptime)
    }
    /// Explicit supplied test points, never current body pose or a movement request.
    /// Delivery/coverage authority remains false in the existing candidate type.
    public func request(generation: UUID, start: [Float], goal: [Float], body: MeshCandidateBody,
        completion: @escaping (Result<MeshCandidateIngress83.Candidate, MeshCandidateIngress83.Failure>) -> Void) {
        guard active(generation) else { completion(.failure(.unavailable)); return }
        ingress.request(start: start, goal: goal, body: body) { [weak self] result in
            guard let self, self.active(generation) else { completion(.failure(.stale)); return }
            if case .success(let candidate) = result {
                //83/75 may retain earlier tiles after a rejected/omitted revision.
                // Never expose that incomplete diagnostic geometry as this preview.
                guard Self.hasCompleteSource(candidate) else { completion(.failure(.unavailable)); return }
                guard self.ingress.isCurrent(candidate) else { completion(.failure(.stale)); return }
            }
            completion(result)
        }
    }
    /// Recheck at display/use, not only at completion. No physical-output sink exists.
    public func isCurrent(_ candidate: MeshCandidateIngress83.Candidate, generation: UUID) -> Bool {
        Self.hasCompleteSource(candidate) && active(generation) && ingress.isCurrent(candidate)
    }
    // Completeness is delivery bookkeeping, NOT actual-world coverage or freshness.
    private static func hasCompleteSource(_ candidate: MeshCandidateIngress83.Candidate) -> Bool {
        candidate.route.sourceDeliveryComplete && candidate.route.unknownCoverage.isEmpty
    }
    public func stop() {
        lock.lock(); stopped = true; lock.unlock()
        ingress.stop()
    }
    /// No reset/restart API: a new generation requires a distinct owner after drain.
    /// Acknowledgement covers this owner, not ARKit/OS/caller-held memory erasure.
    public func stopAndDiscard(completion: @escaping () -> Void) {
        stop(); ingress.stopAndDiscard(completion: completion)
    }
}
