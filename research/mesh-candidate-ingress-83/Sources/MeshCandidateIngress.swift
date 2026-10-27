import Foundation
import MeshSnapshot82
import BlindRoomMesh

/// Candidate-only owner. The lock is the serialized ingress/lifecycle boundary;
/// it is deliberately entered BEFORE synchronous native-buffer copying.
public final class MeshCandidateIngress83 {
    public enum Failure: Error { case unavailable, stale, runtime(MeshCandidateError) }
    public struct Candidate {
        public let route: MeshCandidateRoute
        fileprivate let epoch: UUID, token: UInt64
        public var physicalAuthority: Bool { false }
        public var coverageKnown: Bool { false }
    }
    private let lock = NSLock()
    private let worker: DispatchQueue
    private let runtime: RoomMeshCandidateRuntime
    private let maxAnchors: Int, maxCopies: Int
    private var epoch: UUID
    private var token: UInt64 = 0
    private var stopped = false, copies = 0
    private var discarding = false, runtimeDiscarded = false, discarded = false
    private var discardWaiters: [() -> Void] = []
    // Only the decode job reads/releases contents. Clearing this box also releases
    // the ingress stack's reference even if a fast worker finishes before return.
    private final class OwnedCopy {
        var value: MeshSnapshot82.Capture?
        init(_ value: MeshSnapshot82.Capture) { self.value = value }
    }
    private var receipt: Double = -1
    // Tombstones remain until reset; no eviction that could permit anchor ABA.
    private var revisions: [UUID: UInt64] = [:]
    public init(maxAnchors: Int = 128, maxCopies: Int = 1,
                decodeQueue: DispatchQueue = DispatchQueue(label: "blind.mesh83.decode", qos: .utility)) throws {
        guard (1...1024).contains(maxAnchors), (1...2).contains(maxCopies) else { throw Failure.unavailable }
        self.maxAnchors = maxAnchors; self.maxCopies = maxCopies; worker = decodeQueue
        let initialEpoch = UUID(); epoch = initialEpoch
        runtime = try RoomMeshCandidateRuntime(sessionID: initialEpoch.uuidString, generation: 1)
    }
    private func locked<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock(); defer { lock.unlock() }; return try body()
    }
    private func advance() -> Bool {
        guard token < UInt64.max else { stopped = true; runtime.stop(); return false }
        token += 1; return true
    }
    private func gap() { runtime.invalidate() } // ONLY loss/failure, never ordinary updates.
    private func admit(_ anchor: UUID, _ time: Double) -> MeshSnapshot82.Context? {
        // Even malformed/newer/overflow callbacks retire the outer result immediately.
        guard advance(), !stopped else { return nil }
        guard time.isFinite, time >= 0, time > receipt else { gap(); return nil }
        receipt = time
        guard revisions[anchor] != nil || revisions.count < maxAnchors else { gap(); return nil }
        let revision = revisions[anchor, default: 0]
        guard revision < UInt64(Int.max) else { stopped = true; runtime.stop(); return nil }
        revisions[anchor] = revision + 1
        return .init(sessionID: epoch, generation: 1, revision: revision + 1, receiptUptime: time)
    }
    /// Call on the owning AR callback queue AFTER independent hazards. `capture` is
    /// nonescaping: do not send anchors/Metal/raw pointers to the decode worker.
    /// Explicit receipt uptime must increase; it is NEVER sensor capture freshness.
    @discardableResult public func ingest(anchorID: UUID, receiptUptime: Double,
        capture: (MeshSnapshot82.Context) -> MeshSnapshot82.Capture) -> Bool {
        let context: MeshSnapshot82.Context? = locked {
            guard let c = admit(anchorID, receiptUptime) else { return nil }
            guard copies < maxCopies else { gap(); return nil }
            copies += 1; return c
        }
        guard let context else { return false }
        let owned = OwnedCopy(capture(context)) // token retired and aggregate slot reserved BEFORE copy
        worker.async { [self] in
            install(owned, context: context, anchorID: anchorID)
            owned.value = nil
            locked { copies -= 1; acknowledgeDiscardIfDrained() }
        }
        return true
    }
    // Separate scope releases decoded geometry/event temporaries before the slot.
    private func install(_ owned: OwnedCopy, context: MeshSnapshot82.Context, anchorID: UUID) {
            // A lifecycle fence before expensive decode, then again at install.
            let eligible = locked { !stopped && epoch == context.sessionID && revisions[anchorID] == context.revision }
            let decoded = eligible ? MeshSnapshot82.decode(owned.value!) : nil
            locked {
                guard !stopped, epoch == context.sessionID else { return }
                // A newer accepted update/removal subsumes this copy. Any refusal
                // already marked its own gap at ingress; stale completion adds none.
                guard revisions[anchorID] == context.revision else { return }
                guard let decoded else { gap(); return }
                switch decoded {
                case .unknownGap: gap()
                case .revision(let c, let id, let mesh):
                    guard id == anchorID, c.sessionID == context.sessionID,
                          c.generation == context.generation, c.revision == context.revision,
                          c.receiptUptime == context.receiptUptime,
                          mesh.revision == context.revision,
                          mesh.triangleIndices.allSatisfy({ $0 <= UInt32(Int32.max) }) else { gap(); return }
                    // Local vertices and unmodified column-major transform: package applies ONCE.
                    let event = MeshAnchorEvent(sessionID: epoch.uuidString, generation: 1,
                        anchorID: id.uuidString, revision: Int(c.revision), timestamp: c.receiptUptime,
                        vertices: mesh.localVertices.map(Double.init), triangles: mesh.triangleIndices.map(Int32.init),
                        columnMajorTransform: mesh.anchorTransform.map(Double.init), complete: true)
                    // Runtime itself marks a rejected offer as sticky unknown coverage.
                    _ = runtime.offer(event)
                }
            }
    }
    @discardableResult public func remove(anchorID: UUID, receiptUptime: Double) -> Bool {
        locked {
            guard let c = admit(anchorID, receiptUptime) else { return false }
            return runtime.offer(.init(sessionID: epoch.uuidString, generation: 1,
                anchorID: anchorID.uuidString, revision: Int(c.revision), timestamp: c.receiptUptime,
                vertices: [], triangles: [], columnMajorTransform: [], complete: false, removed: true))
        }
    }
    /// Fences only; NOT a privacy purge or acknowledgement that native work drained.
    public func stop() { locked { _ = advance(); stopped = true; runtime.stop() } }
    /// Terminal stop and acknowledged release of this owner's retained copies and
    /// runtime geometry. Does not erase ARKit/caller/system allocations. Captures
    /// already admitted must return; no slot is released early and no reset/restart
    /// is permitted after this call. Completion runs asynchronously outside locks.
    public func stopAndDiscard(completion: @escaping () -> Void) {
        locked {
            if discarded { DispatchQueue.global(qos: .utility).async { completion() }; return }
            discardWaiters.append(completion)
            guard !discarding else { return }
            discarding = true; _ = advance(); stopped = true
            revisions.removeAll(keepingCapacity: false); receipt = -1
            runtime.stopAndDiscard { [self] in
                locked { runtimeDiscarded = true; acknowledgeDiscardIfDrained() }
            }
        }
    }
    // Under ingress lock; runtime completion never calls back while holding its lock.
    private func acknowledgeDiscardIfDrained() {
        guard discarding, !discarded, runtimeDiscarded, copies == 0 else { return }
        discarded = true
        let waiters = discardWaiters; discardWaiters.removeAll(keepingCapacity: false)
        for waiter in waiters { DispatchQueue.global(qos: .utility).async { waiter() } }
    }
    /// Fresh UUID epoch prevents A->B->A generation reuse. Outstanding copies still
    /// consume their original aggregate slots until they actually return/drain.
    public func reset() throws {
        try locked {
            guard !discarding, advance() else { throw Failure.unavailable }
            let next = UUID()
            try runtime.reset(sessionID: next.uuidString, generation: 1)
            epoch = next; revisions.removeAll(keepingCapacity: false); receipt = -1; stopped = false
        }
    }
    public func isCurrent(_ candidate: Candidate) -> Bool {
        locked { !stopped && copies == 0 && epoch == candidate.epoch && token == candidate.token && runtime.isCurrent(candidate.route) }
    }
    public func request(start: [Float], goal: [Float], body: MeshCandidateBody,
                        completion: @escaping (Result<Candidate, Failure>) -> Void) {
        let accepted: Bool = locked {
            guard advance(), !stopped, copies == 0 else { return false }
            let e = epoch, t = token
            runtime.request(start: start, goal: goal, body: body) { [self] result in
                let value: Result<Candidate, Failure> = locked {
                    guard !stopped, copies == 0, epoch == e, token == t else { return .failure(.stale) }
                    switch result {
                    case .failure(let error): return .failure(.runtime(error))
                    case .success(let route):
                        guard runtime.isCurrent(route) else { return .failure(.stale) }
                        return .success(Candidate(route: route, epoch: e, token: t))
                    }
                }
                completion(value) // consumers MUST recheck isCurrent at use, not only callback
            }
            return true
        }
        if !accepted { completion(.failure(.unavailable)) }
    }
}
