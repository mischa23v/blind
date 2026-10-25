import Foundation

/// A bounded scheduler for the existing store, not a second database. Every
/// submitted snapshot contains BOTH dialogue and task state. Encoding and writes
/// run off the main owner, in order; at most one active and one latest pending
/// snapshot are retained. New snapshots include already-retired source edits.
@MainActor public final class CompanionMemoryWriteQueue {
    nonisolated public static let maximumDialogueBytes = 128 * 1024
    nonisolated public static let maximumWorkingStateBytes = 8 * 1024 * 1024
    public struct Snapshot: Sendable {
        public let dialogue: Data
        public let workingState: Data
        public init(dialogue: Data, workingState: Data) { self.dialogue = dialogue; self.workingState = workingState }
    }
    public struct Receipt: Equatable, Sendable { public let owner: UUID; public let revision: UInt64 }
    private struct Job: Sendable {
        let owner: UUID
        let revision: UInt64
        let encode: @Sendable () throws -> Snapshot
        let write: @Sendable (Snapshot) throws -> Void
    }
    private struct Waiter {
        let revision: UInt64
        let continuation: CheckedContinuation<Bool, Never>
    }
    private var owner: UUID?
    private var latest: Job?
    private var pending: Job?
    private var waiters: [Waiter] = []
    public private(set) var requestedRevision: UInt64 = 0
    public private(set) var committedRevision: UInt64 = 0
    public private(set) var isWriting = false
    public private(set) var hasFailed = false
    public var pendingCount: Int { pending == nil ? 0 : 1 }
    public var onCompletion: (@MainActor (Receipt, Bool) -> Void)?
    public init() {}

    public func bindOwner(_ proposed: UUID) {
        guard proposed != owner else { return }
        owner = proposed; latest = nil; pending = nil; committedRevision = 0; hasFailed = false
        let retired = waiters; waiters = []
        retired.forEach { $0.continuation.resume(returning: false) }
    }
    @discardableResult public func submit(owner proposed: UUID, encode: @escaping @Sendable () throws -> Snapshot,
                                          write: @escaping @Sendable (Snapshot) throws -> Void) -> Receipt? {
        bindOwner(proposed)
        guard requestedRevision < UInt64.max else { return nil }
        requestedRevision += 1
        let job = Job(owner: proposed, revision: requestedRevision, encode: encode, write: write)
        latest = job; pending = job; hasFailed = false
        drain()
        return Receipt(owner: proposed, revision: job.revision)
    }
    /// Explicit retry, never a retry storm after storage failure. Retry the latest
    /// full state, not an old correction snapshot that could erase newer reports.
    @discardableResult public func retryLatest(owner proposed: UUID) -> Receipt? {
        guard owner == proposed, let latest else { return nil }
        if isWriting || pending != nil || committedRevision >= latest.revision { return Receipt(owner: proposed, revision: latest.revision) }
        return submit(owner: proposed, encode: latest.encode, write: latest.write)
    }
    public func waitForCommit(_ receipt: Receipt) async -> Bool {
        guard receipt.owner == owner else { return false }
        let revision = receipt.revision
        if revision <= committedRevision { return true }
        guard revision <= requestedRevision, isWriting || pending != nil, waiters.count < 8 else { return false }
        return await withCheckedContinuation { waiters.append(Waiter(revision: revision, continuation: $0)) }
    }
    private func drain() {
        guard !isWriting, pending != nil else { return }
        isWriting = true
        Task { [weak self] in
            guard let self else { return }
            // Let one synchronous owner turn finish before selecting the latest
            // pending pair. Coupled dialogue/state mutations do not emit an
            // intermediate snapshot merely because both old helpers were called.
            guard let job = self.pending else { self.isWriting = false; return }
            self.pending = nil
            let succeeded = await Task.detached(priority: .utility) {
                do {
                    let snapshot = try job.encode()
                    guard (1...Self.maximumDialogueBytes).contains(snapshot.dialogue.count), (1...Self.maximumWorkingStateBytes).contains(snapshot.workingState.count) else { return false }
                    try job.write(snapshot); return true
                } catch { return false }
            }.value
            self.isWriting = false
            guard job.owner == self.owner else { self.drain(); return }
            if succeeded { self.committedRevision = max(self.committedRevision, job.revision) }
            self.hasFailed = !succeeded && self.pending == nil
            var remaining: [Waiter] = []
            for waiter in self.waiters {
                if waiter.revision <= self.committedRevision { waiter.continuation.resume(returning: true) }
                else if self.hasFailed { waiter.continuation.resume(returning: false) }
                else { remaining.append(waiter) }
            }
            self.waiters = remaining
            self.onCompletion?(Receipt(owner: job.owner, revision: job.revision), succeeded)
            self.drain()
        }
    }
}
