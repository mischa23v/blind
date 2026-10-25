import Foundation
import BlindCore

/// Uses the existing serial, generation-owned IO transaction worker. The main
/// owner only submits snapshots; JSON and all filesystem work run off-main.
@MainActor final class BodyProfileStore {
    static let shared = BodyProfileStore() // One process-wide writer across reopened helper views.
    typealias Completion = (Result<LocalBodyProfile?, Error>) -> Void
    private let io: SpatialMapIO<LocalBodyProfile>
    private var currentRevision: UUID?
    private var pendingMutation: UUID?
    private var deferredRead: Completion?
    init(directory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
         .appendingPathComponent("PrivateBodyProfile", isDirectory: true)) {
        io = SpatialMapIO(storage: BodyProfileFileStorage(directory: directory))
    }
    init(storage: any SpatialMapStorageIO) { io = SpatialMapIO(storage: storage) }
    private var context: SpatialMapIOContext { .init(revision: currentRevision ?? UUID(), artifact: nil) }
    func load(completion: @escaping Completion) {
        // Reopening is read-only: never supersede/roll back an admitted save.
        // Keep only the latest waiting read; every replaced caller is notified.
        if pendingMutation != nil {
            let old = deferredRead; deferredRead = completion
            old?(.failure(SpatialMapIOError.superseded)); return
        }
        if let old = deferredRead { deferredRead = nil; old(.failure(SpatialMapIOError.superseded)) }
        io.submit(expected: context, prepare: { storage in
            let value: LocalBodyProfile
            do { value = try LocalBodyProfile.decodeLocal(storage.read(maximumBytes: 16_384)) }
            catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
                value = try LocalBodyProfile()
            }
            return .init(value: value, bytesToPersist: nil)
        }) { [weak self] token, result in self?.finish(token, result, completion) }
    }
    func save(_ value: LocalBodyProfile, replacing expected: UUID, completion: @escaping Completion) {
        guard value.valid, currentRevision == expected else {
            completion(.failure(SpatialMapIOError.revisionChanged)); return
        }
        let operation = UUID(); pendingMutation = operation
        io.submit(expected: .init(revision: expected, artifact: nil), prepare: { _ in
            let bytes = try JSONEncoder().encode(value)
            guard bytes.count <= 16_384 else { throw BodyProfileError.invalidInput }
            return .init(value: value, bytesToPersist: bytes)
        }) { [weak self] token, result in self?.finishMutation(operation, token, result, completion) }
    }
    /// A deletion is an ordered non-droppable barrier; an older blocked write
    /// cannot resurrect the profile after a successful deletion receipt.
    func erase(completion: @escaping Completion) {
        let operation = UUID(); pendingMutation = operation
        io.submit(expected: context, delete: true) { [weak self] token, result in
            self?.finishMutation(operation, token, result, completion)
        }
    }
    private func finishMutation(_ operation: UUID, _ token: SpatialMapIOToken, _ result: Result<LocalBodyProfile?, Error>, _ completion: Completion) {
        if pendingMutation == operation { pendingMutation = nil }
        finish(token, result, completion)
        if pendingMutation == nil, let read = deferredRead { deferredRead = nil; load(completion: read) }
    }
    private func finish(_ token: SpatialMapIOToken, _ result: Result<LocalBodyProfile?, Error>, _ completion: Completion) {
        guard io.isCurrent(token) else { completion(.failure(SpatialMapIOError.superseded)); return }
        if case .success(let value) = result { currentRevision = value?.revision }
        completion(result)
    }
}

/// Separate private file, never conversation/public-map/backup storage. Protection
/// and backup exclusion are established BEFORE data write. No identity is changed.
struct BodyProfileFileStorage: SpatialMapStorageIO {
    let directory: URL
    private var file: URL { directory.appendingPathComponent("profile.json") }
    func read(maximumBytes: Int) throws -> Data {
        try SpatialMapFileStorage.readBounded(file, maximumBytes: min(16_384, maximumBytes))
    }
    func write(_ bytes: Data) throws {
        guard bytes.count <= 16_384 else { throw BodyProfileError.invalidInput }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: directory.path)
        var protected = directory, resource = URLResourceValues()
        resource.isExcludedFromBackup = true; try protected.setResourceValues(resource)
        try bytes.write(to: file, options: [.atomic, .completeFileProtection])
        #else
        try bytes.write(to: file, options: .atomic) // Portable storage tests only.
        #endif
    }
    func delete() throws {
        do { try FileManager.default.removeItem(at: file) }
        catch let error as CocoaError where error.code == .fileNoSuchFile { }
    }
}
