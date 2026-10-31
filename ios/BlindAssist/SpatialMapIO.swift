import Foundation
import BlindCore

/// No storage operation is invoked on the control/main owner. Tests inject an
/// actually blocked writer; the production implementation uses Foundation only.
protocol SpatialMapStorageIO: Sendable {
    func read(maximumBytes: Int) throws -> Data
    func write(_ data: Data) throws
    func delete() throws
}

enum SpatialMapIOError: Error, Equatable {
    case oversized, superseded, deleteBarrierFailed, busy, revisionChanged, unavailable
}

struct SpatialMapFileStorage: SpatialMapStorageIO {
    let url: URL
    static func readBounded(_ url: URL, maximumBytes: Int) throws -> Data {
        guard maximumBytes > 0 else { throw SpatialMapIOError.oversized }
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        // Reject known oversized files before allocating payload memory. Still use
        // a bounded read loop: providers/files can grow after the size check.
        let size = try file.seekToEnd()
        guard size <= UInt64(maximumBytes) else { throw SpatialMapIOError.oversized }
        try file.seek(toOffset: 0)
        var bytes = Data()
        while bytes.count <= maximumBytes {
            let count = min(65_536, maximumBytes + 1 - bytes.count)
            guard let chunk = try file.read(upToCount: count), !chunk.isEmpty else { return bytes }
            bytes.append(chunk)
            guard bytes.count <= maximumBytes else { throw SpatialMapIOError.oversized }
        }
        throw SpatialMapIOError.oversized
    }
    func read(maximumBytes: Int) throws -> Data { try Self.readBounded(url, maximumBytes: maximumBytes) }
    func write(_ data: Data) throws {
        guard data.count <= SpatialMapInstallation.maximumEnvelopeBytes else { throw SpatialMapIOError.oversized }
        var directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
    func delete() throws {
        // A missing file is already deleted. Other failures must not become success.
        do { try FileManager.default.removeItem(at: url) }
        catch let error as CocoaError where error.code == .fileNoSuchFile { }
    }
}

/// The UUID is a process-local storage revision, including restrictions even when
/// geometry binding/digest is unchanged. No physical/localization claim is made.
struct SpatialMapIOContext: Equatable, Sendable {
    let revision: UUID
    let artifact: SpatialMapArtifactIdentity?
}
struct SpatialMapIOToken: Equatable, Sendable {
    let generation: UUID
    let expected: SpatialMapIOContext
}
struct SpatialMapPrepared<Value: Sendable>: Sendable {
    let value: Value
    let bytesToPersist: Data? // nil = read-only restore
}

/// One serial worker, at most one running request, one latest pending request and
/// one non-droppable deletion barrier. The lock protects only tiny value/slot
/// changes, NEVER validation, hashing, disk IO, callbacks or main-thread waiting.
///
/// A write already inside Foundation cannot be cancelled. If superseded, its
/// previous durable bytes are restored on this worker before any newer job. A delete receipt
/// is issued only after the barrier completed, never when merely queued. There is
/// no promise about crash recovery midway through an unfinished IO operation.
final class SpatialMapIO<Value: Sendable>: @unchecked Sendable {
    typealias Completion = (SpatialMapIOToken, Result<Value?, Error>) -> Void
    private struct Job {
        let token: SpatialMapIOToken
        let prepare: (@Sendable (any SpatialMapStorageIO) throws -> SpatialMapPrepared<Value>)?
        let completion: Completion
    }
    private let storage: any SpatialMapStorageIO
    private let publishOnMain: (@escaping () -> Void) -> Void
    private let queue = DispatchQueue(label: "BlindAssist.spatial-map-io", qos: .userInitiated)
    private let lock = NSLock()
    private var current: SpatialMapIOToken?
    private var pending: Job?
    private var deletion: Job?
    private var running = false
    private var failedDelete = false
    init(storage: any SpatialMapStorageIO,
         publishOnMain: @escaping (@escaping () -> Void) -> Void = { DispatchQueue.main.async(execute: $0) }) {
        self.storage = storage; self.publishOnMain = publishOnMain
    }
    func isCurrent(_ token: SpatialMapIOToken) -> Bool {
        lock.lock(); defer { lock.unlock() }; return current == token
    }
    /// Invalid/rejected requests also fence an older in-flight write. Otherwise
    /// its callback could restore authority after a positive restriction failed.
    func invalidate() {
        precondition(Thread.isMainThread)
        lock.lock(); current = nil; let old = pending; pending = nil; lock.unlock()
        old?.completion(old!.token, .failure(SpatialMapIOError.superseded))
    }
    /// All admission and completions use main; only immutable snapshots cross to
    /// the worker. Replaced callbacks receive superseded, never false success.
    @discardableResult func submit(expected: SpatialMapIOContext, delete: Bool = false,
        prepare: (@Sendable (any SpatialMapStorageIO) throws -> SpatialMapPrepared<Value>)? = nil,
        completion: @escaping Completion) -> SpatialMapIOToken {
        precondition(Thread.isMainThread)
        let token = SpatialMapIOToken(generation: UUID(), expected: expected)
        let job = Job(token: token, prepare: delete ? nil : prepare, completion: completion)
        lock.lock()
        current = token
        var superseded: [Job] = []
        if let pending { superseded.append(pending) }; pending = nil
        if delete {
            if let deletion { superseded.append(deletion) }
            deletion = job // barrier remains, even if a later import replaces the latest slot
        } else { pending = job }
        let start = !running; running = true
        lock.unlock()
        for old in superseded { old.completion(old.token, .failure(SpatialMapIOError.superseded)) }
        if start { queue.async { self.drain() } }
        return token
    }
    private func take() -> Job? {
        lock.lock(); defer { lock.unlock() }
        if let job = deletion { deletion = nil; return job }
        if let job = pending { pending = nil; return job }
        running = false; return nil
    }
    private func finish(_ job: Job, _ result: Result<Value?, Error>) {
        DispatchQueue.main.async {
            // Second CAS at actual main publication, not at callback enqueue time.
            job.completion(job.token, self.isCurrent(job.token) ? result : .failure(SpatialMapIOError.superseded))
        }
    }
    private func previousBytes() throws -> Data? {
        do { return try storage.read(maximumBytes: SpatialMapInstallation.maximumEnvelopeBytes) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile { return nil }
    }
    private func rollback(_ previous: Data?) throws {
        // Restore the last committed artifact, not arbitrary deletion of it.
        // Deletion here only removes a transient write when no file existed.
        if let previous { try storage.write(previous) } else { try storage.delete() }
    }
    private func publish(_ job: Job, candidate: SpatialMapPrepared<Value>, previous: Data?) {
        publishOnMain {
            precondition(Thread.isMainThread)
            let accepted = self.isCurrent(job.token)
            job.completion(job.token, accepted ? .success(candidate.value) : .failure(SpatialMapIOError.superseded))
            self.queue.async {
                // Main publication is part of the transaction. No newer file job
                // may run until this acknowledgement/obsolete-write cleanup.
                if !accepted, candidate.bytesToPersist != nil {
                    do { try self.rollback(previous) }
                    catch { self.failedDelete = true }
                }
                self.drain()
            }
        }
    }
    private func drain() {
        while let job = take() {
            guard let prepare = job.prepare else {
                do { try storage.delete(); failedDelete = false; finish(job, .success(nil)) }
                catch { failedDelete = true; finish(job, .failure(error)) }
                continue
            }
            guard !failedDelete else { finish(job, .failure(SpatialMapIOError.deleteBarrierFailed)); continue }
            guard isCurrent(job.token) else { finish(job, .failure(SpatialMapIOError.superseded)); continue }
            do {
                let candidate = try prepare(storage)
                // First CAS before changing durable bytes. Expected revision and
                // artifact are part of the same token, not a map-name comparison.
                guard isCurrent(job.token) else { throw SpatialMapIOError.superseded }
                var previous: Data?
                if let bytes = candidate.bytesToPersist {
                    guard bytes.count <= SpatialMapInstallation.maximumEnvelopeBytes else { throw SpatialMapIOError.oversized }
                    previous = try previousBytes()
                    guard isCurrent(job.token) else { throw SpatialMapIOError.superseded }
                    do { try storage.write(bytes) }
                    catch {
                        // A failing write can have an uncertain outcome. Attempt
                        // restoration before admitting any later file operation.
                        do { try rollback(previous) } catch { failedDelete = true }
                        throw error
                    }
                    if !isCurrent(job.token) {
                        // Ordered cleanup prevents a delayed save from resurrecting
                        // a completed delete or winning a newer replacement.
                        do { try rollback(previous) }
                        catch { failedDelete = true; throw error }
                        throw SpatialMapIOError.superseded
                    }
                }
                publish(job, candidate: candidate, previous: previous)
                return // worker resumes after main CAS, without blocking main
            } catch { finish(job, .failure(error)) }
        }
    }
}
