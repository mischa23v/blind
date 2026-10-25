import Foundation
import XCTest
@testable import BlindCore
#if canImport(NativeSpatialAdapter)
@testable import NativeSpatialAdapter
#else
@testable import BlindAssist
#endif

/// Only authored synthetic fixture data. The blocked filesystem is deliberate,
/// not a measured Apple storage, warning-audio latency or native localization test.
final class ControlledSpatialStorage: SpatialMapStorageIO, @unchecked Sendable {
    private let lock = NSLock()
    private var content: Data?
    private var writeEnd: DispatchSemaphore?
    private var readGate: (XCTestExpectation, DispatchSemaphore)?
    private var gate: (XCTestExpectation, DispatchSemaphore)?
    private var deleteFailure = false
    private var writeFailures = 0
    private var operations: [String] = []
    private var caps: [Int] = []
    init(_ bytes: Data? = nil) { content = bytes }
    func blockNextWrite(_ entered: XCTestExpectation) -> DispatchSemaphore {
        let release = DispatchSemaphore(value: 0)
        lock.lock(); gate = (entered, release); lock.unlock(); return release
    }
    func blockNextRead(_ entered: XCTestExpectation) -> DispatchSemaphore {
        let release = DispatchSemaphore(value: 0)
        lock.lock(); readGate = (entered, release); lock.unlock(); return release
    }
    func signalNextWriteEnd() -> DispatchSemaphore {
        let signal = DispatchSemaphore(value: 0)
        lock.lock(); writeEnd = signal; lock.unlock(); return signal
    }
    func failDeletes(_ value: Bool) { lock.lock(); deleteFailure = value; lock.unlock() }
    func failWrites(_ value: Bool) { failNextWrites(value ? 1 : 0) }
    func failNextWrites(_ count: Int) { lock.lock(); writeFailures = count; lock.unlock() }
    var bytes: Data? { lock.lock(); defer { lock.unlock() }; return content }
    var log: [String] { lock.lock(); defer { lock.unlock() }; return operations }
    var readCaps: [Int] { lock.lock(); defer { lock.unlock() }; return caps }
    func read(maximumBytes: Int) throws -> Data {
        XCTAssertFalse(Thread.isMainThread)
        lock.lock(); caps.append(maximumBytes); let bytes = content; let gate = readGate; readGate = nil; lock.unlock()
        gate?.0.fulfill(); if let gate { XCTAssertEqual(gate.1.wait(timeout: .now() + 10), .success) }
        guard let bytes else { throw CocoaError(.fileReadNoSuchFile) }
        guard bytes.count <= maximumBytes else { throw SpatialMapIOError.oversized }
        return bytes
    }
    func write(_ data: Data) throws {
        XCTAssertFalse(Thread.isMainThread)
        lock.lock(); let gate = self.gate; self.gate = nil; let fails = writeFailures > 0; writeFailures = max(0, writeFailures - 1); operations.append("write-start"); lock.unlock()
        gate?.0.fulfill(); if let gate { XCTAssertEqual(gate.1.wait(timeout: .now() + 10), .success) }
        if fails { throw CocoaError(.fileWriteUnknown) }
        lock.lock(); content = data; operations.append("write-end"); let signal = writeEnd; writeEnd = nil; lock.unlock()
        signal?.signal()
    }
    func delete() throws {
        XCTAssertFalse(Thread.isMainThread)
        lock.lock(); defer { lock.unlock() }
        operations.append("delete")
        if deleteFailure { throw CocoaError(.fileWriteUnknown) }
        content = nil
    }
}

/// Test scheduler holds the actual publication closure only after the worker has
/// passed its post-write CAS. This deterministically reaches the second CAS.
final class HeldSpatialPublication: @unchecked Sendable {
    let queued: XCTestExpectation
    private let lock = NSLock()
    private var callback: (() -> Void)?
    init(queued: XCTestExpectation) { self.queued = queued }
    func enqueue(_ callback: @escaping () -> Void) {
        lock.lock(); self.callback = callback; lock.unlock(); queued.fulfill()
    }
    func deliverOnMain() {
        precondition(Thread.isMainThread)
        lock.lock(); let next = callback; callback = nil; lock.unlock()
        next?()
    }
}

final class SpatialMapIOTests: XCTestCase {
    typealias F = SpatialIntegrationFixture
    func assertSuccess(_ result: Result<RegisteredIndoorNavigation.Loaded?, Error>, file: StaticString = #filePath, line: UInt = #line) {
        if case .failure(let error) = result { XCTFail("Unexpected failure: \(error)", file: file, line: line) }
    }
    @discardableResult func assertFailure(_ result: Result<RegisteredIndoorNavigation.Loaded?, Error>, file: StaticString = #filePath, line: UInt = #line) -> Error? {
        if case .failure(let error) = result { return error }
        XCTFail("Expected failure", file: file, line: line); return nil
    }
    func adapter(_ storage: ControlledSpatialStorage) -> RegisteredIndoorNavigation {
        .init(storage: URL(fileURLWithPath: "/unused-synthetic-path"), sha256: F.sha256, storageIO: storage)
    }
    @discardableResult func complete(_ operation: (@escaping RegisteredIndoorNavigation.Completion) -> Void,
                                     file: StaticString = #filePath, line: UInt = #line) throws -> RegisteredIndoorNavigation.Loaded? {
        let done = expectation(description: "actual IO completion")
        var result: Result<RegisteredIndoorNavigation.Loaded?, Error>?
        operation { value in XCTAssertTrue(Thread.isMainThread); result = value; done.fulfill() }
        wait(for: [done], timeout: 10)
        return try XCTUnwrap(result, file: file, line: line).get()
    }
    func ready(_ storage: ControlledSpatialStorage) throws -> RegisteredIndoorNavigation {
        let adapter = adapter(storage), bytes = try F.installation().encoded()
        try complete { adapter.install(bytes, completion: $0) }
        try adapter.configure(body: F.body, limits: F.limits)
        try adapter.plan(from: "start", to: "end", goal: UUID())
        let capture = SpatialLocalizationCapture(sessionID: try XCTUnwrap(adapter.sessionID),
            binding: try XCTUnwrap(adapter.installation).binding, floorID: "floor", position: Point3(1, 1.3, 3), bodyYaw: -.pi / 2,
            source: .alignedMapPose, headingSource: .bodyAligned, trackingNormal: true,
            positionUncertainty: 0.1, headingUncertainty: 0.1, capturedAt: 10)
        try adapter.accept(capture, floorSupport: F.support(capture), now: 10)
        return adapter
    }
    func testBlockedWriterLeavesIndependentMainWarningAndWatchdogResponsive() throws {
        let storage = ControlledSpatialStorage(), adapter = try ready(storage)
        let ticket = try adapter.next(now: 10)
        var retired = 0; adapter.onOutputRetired = { retired += 1 }
        let entered = expectation(description: "writer actually blocked"), release = storage.blockNextWrite(entered)
        let saved = expectation(description: "restriction completes"), probe = expectation(description: "independent control on main")
        var finished = false, warnings = 0
        adapter.addRestrictions(binding: try XCTUnwrap(adapter.installation).binding,
                                blocked: [MapConnection("middle", "end")], zones: []) { result in
            self.assertSuccess(result); finished = true; saved.fulfill()
        }
        XCTAssertEqual(retired, 1); XCTAssertFalse(adapter.permits(ticket, now: 10)); XCTAssertNil(adapter.currentPose(now: 10))
        wait(for: [entered], timeout: 5)
        DispatchQueue.main.async {
            warnings += 1 // Explicit independent warning/control stub, not audio.
            adapter.revalidate(now: 11); adapter.cancelRoute()
            XCTAssertFalse(finished); probe.fulfill()
        }
        wait(for: [probe], timeout: 1)
        XCTAssertEqual(warnings, 1); XCTAssertFalse(finished)
        release.signal(); wait(for: [saved], timeout: 5)
        XCTAssertThrowsError(try adapter.plan(from: "start", to: "end", goal: UUID()))
        XCTAssertNil(adapter.currentPose(now: 10)); XCTAssertFalse(adapter.ioBlocked)
    }
    func testDeleteWaitsBehindInFlightWriteAndNoLateSaveResurrects() throws {
        let storage = ControlledSpatialStorage(), adapter = try ready(storage)
        let r2 = try F.installation(map: F.map(revision: "r2"), prior: adapter.installation).encoded()
        let entered = expectation(description: "write entered"), release = storage.blockNextWrite(entered)
        let old = expectation(description: "superseded save"), deleted = expectation(description: "actual delete")
        var deleteDone = false
        adapter.install(r2) { result in self.assertFailure(result); old.fulfill() }
        wait(for: [entered], timeout: 5)
        adapter.delete { result in self.assertSuccess(result); deleteDone = true; deleted.fulfill() }
        XCTAssertNil(adapter.installation); XCTAssertNil(adapter.currentPose(now: 10)); XCTAssertFalse(deleteDone)
        release.signal(); wait(for: [old, deleted], timeout: 5)
        XCTAssertNil(storage.bytes); XCTAssertTrue(deleteDone)
        XCTAssertEqual(storage.log.suffix(3), ["write-start", "write-end", "delete"])
    }
    func testDeleteBarrierCannotDisappearBehindLaterReplacementOrReportFalseSuccess() throws {
        let storage = ControlledSpatialStorage(), adapter = try ready(storage)
        let first = try F.installation(map: F.map(revision: "r2"), prior: adapter.installation).encoded()
        let final = try F.installation().encoded()
        let entered = expectation(description: "first blocked"), release = storage.blockNextWrite(entered)
        let old = expectation(description: "old retired"), deletion = expectation(description: "delete receipt"), latest = expectation(description: "latest imported")
        adapter.install(first) { result in self.assertFailure(result); old.fulfill() }
        wait(for: [entered], timeout: 5)
        adapter.delete { result in
            XCTAssertEqual(self.assertFailure(result) as? SpatialMapIOError, .superseded); deletion.fulfill()
        }
        adapter.install(final) { result in self.assertSuccess(result); latest.fulfill() }
        release.signal(); wait(for: [old, deletion, latest], timeout: 5)
        XCTAssertEqual(try XCTUnwrap(adapter.installation).binding.revision, "r1")
        XCTAssertEqual(storage.bytes, final)
        XCTAssertEqual(storage.log.suffix(5), ["write-start", "write-end", "delete", "write-start", "write-end"])
    }
    func testDeleteFailureBlocksQueuedReplacementUntilExplicitRetryBarrier() throws {
        let storage = ControlledSpatialStorage(), adapter = try ready(storage), bytes = try F.installation().encoded()
        storage.failDeletes(true)
        XCTAssertThrowsError(try complete { adapter.delete(completion: $0) })
        XCTAssertTrue(adapter.ioBlocked); XCTAssertNil(adapter.installation)
        XCTAssertThrowsError(try complete { adapter.install(bytes, completion: $0) }) {
            XCTAssertEqual($0 as? SpatialMapIOError, .deleteBarrierFailed)
        }
        storage.failDeletes(false)
        try complete { adapter.delete(completion: $0) }
        try complete { adapter.install(bytes, completion: $0) }
        XCTAssertFalse(adapter.ioBlocked)
    }
    func testLatestSlotIsBoundedAndSupersededImportsNeverPublish() throws {
        let storage = ControlledSpatialStorage(), adapter = try ready(storage)
        let bytes = try F.installation().encoded()
        let entered = expectation(description: "first blocked"), release = storage.blockNextWrite(entered)
        let first = expectation(description: "first superseded"), latest = expectation(description: "latest success")
        var superseded = 0, published = 0
        adapter.install(bytes) { result in self.assertFailure(result); first.fulfill() }
        wait(for: [entered], timeout: 5)
        for _ in 0..<100 {
            adapter.install(bytes) { result in
                if case .failure(let error) = result { XCTAssertEqual(error as? SpatialMapIOError, .superseded); superseded += 1 }
                else { published += 1; latest.fulfill() }
            }
        }
        release.signal(); wait(for: [first, latest], timeout: 5)
        XCTAssertEqual(superseded, 99); XCTAssertEqual(published, 1)
        XCTAssertEqual(storage.log.filter { $0 == "write-start" }.count, 4) // setup + running + rollback + latest only
    }
    func testPendingRestrictionUnionCannotBeClearedByDelayedEmptyUpdate() throws {
        let storage = ControlledSpatialStorage(), adapter = try ready(storage), binding = try XCTUnwrap(adapter.installation).binding
        let entered = expectation(description: "first restriction blocked"), release = storage.blockNextWrite(entered)
        let first = expectation(description: "first superseded"), second = expectation(description: "second superseded"), latest = expectation(description: "union durable")
        adapter.addRestrictions(binding: binding, blocked: [MapConnection("start", "middle")], zones: []) { result in self.assertFailure(result); first.fulfill() }
        wait(for: [entered], timeout: 5)
        adapter.addRestrictions(binding: binding, blocked: [MapConnection("middle", "end")], zones: []) { result in self.assertFailure(result); second.fulfill() }
        adapter.addRestrictions(binding: binding, blocked: [], zones: []) { result in self.assertSuccess(result); latest.fulfill() }
        XCTAssertTrue(adapter.ioBlocked); XCTAssertThrowsError(try adapter.next(now: 10))
        release.signal(); wait(for: [first, second, latest], timeout: 5)
        XCTAssertEqual(adapter.installation?.currentRestrictions.blocked.count, 2)
        let restored = self.adapter(storage); try complete { restored.restore(completion: $0) }
        XCTAssertEqual(restored.installation?.currentRestrictions.blocked.count, 2)
        XCTAssertNil(restored.currentPose(now: 10))
    }
    func testFailedRestrictionPersistenceRetainsUnionForRetryAndBlocksConfigure() throws {
        let storage = ControlledSpatialStorage(), adapter = adapter(storage), bytes = try F.installation().encoded()
        try complete { adapter.install(bytes, completion: $0) }; storage.failWrites(true)
        let binding = try XCTUnwrap(adapter.installation).binding
        XCTAssertThrowsError(try complete { adapter.addRestrictions(binding: binding, blocked: [MapConnection("middle", "end")], zones: [], completion: $0) })
        XCTAssertThrowsError(try adapter.configure(body: F.body, limits: F.limits))
        storage.failWrites(false)
        try complete { adapter.addRestrictions(binding: binding, blocked: [], zones: [], completion: $0) }
        try adapter.configure(body: F.body, limits: F.limits)
        XCTAssertThrowsError(try adapter.plan(from: "start", to: "end", goal: UUID()))
    }
    func testRestoreAndFileImportUseBoundedReaderAndDoNotRestorePose() throws {
        let bytes = try F.installation().encoded(), storage = ControlledSpatialStorage(bytes), adapter = adapter(storage)
        try complete { adapter.restore(completion: $0) }
        XCTAssertEqual(storage.readCaps, [SpatialMapInstallation.maximumEnvelopeBytes]); XCTAssertNil(adapter.currentPose(now: 10))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("map.json"); try bytes.write(to: file)
        try complete { adapter.importFile(file, completion: $0) }
        XCTAssertEqual(adapter.installation?.envelope.mapBytes, try F.installation().envelope.mapBytes)
        let handle = try FileHandle(forWritingTo: file); try handle.truncate(atOffset: 2_000_000_000); try handle.close()
        XCTAssertThrowsError(try SpatialMapFileStorage.readBounded(file, maximumBytes: SpatialMapInstallation.maximumEnvelopeBytes)) {
            XCTAssertEqual($0 as? SpatialMapIOError, .oversized)
        }
        XCTAssertThrowsError(try complete { adapter.importFile(file, completion: $0) })
        XCTAssertTrue(adapter.ioBlocked)
    }
    func testInvalidLatestInputFencesAnAlreadyRunningWrite() throws {
        let storage = ControlledSpatialStorage(), adapter = try ready(storage), bytes = try F.installation().encoded()
        let entered = expectation(description: "write blocked"), release = storage.blockNextWrite(entered), retired = expectation(description: "write superseded")
        adapter.install(bytes) { result in self.assertFailure(result); retired.fulfill() }
        wait(for: [entered], timeout: 5)
        XCTAssertThrowsError(try complete { adapter.install(Data(), completion: $0) })
        release.signal(); wait(for: [retired], timeout: 5)
        XCTAssertTrue(adapter.ioBlocked); XCTAssertNil(adapter.currentPose(now: 10))
    }
    func testSupersededRestoreCannotOverwriteNewImport() throws {
        let original = try F.installation(), replacement = try F.installation(map: F.map(revision: "r2"), prior: original)
        let storage = ControlledSpatialStorage(try original.encoded()), adapter = adapter(storage)
        let restored = expectation(description: "restore superseded"), imported = expectation(description: "import wins")
        adapter.restore { result in self.assertFailure(result); restored.fulfill() }
        adapter.install(try replacement.encoded()) { result in self.assertSuccess(result); imported.fulfill() }
        wait(for: [restored, imported], timeout: 5)
        XCTAssertEqual(adapter.installation?.binding, replacement.binding)
        XCTAssertNil(adapter.currentPose(now: 10))
    }
    func testFailedNewerImportPreservesLastCommittedMapAfterStaleWrite() throws {
        let storage = ControlledSpatialStorage(), adapter = try ready(storage)
        let originalBytes = try XCTUnwrap(storage.bytes), original = try XCTUnwrap(adapter.installation)
        let next = try F.installation(map: F.map(revision: "r2"), prior: original).encoded()
        let entered = expectation(description: "replacement blocked"), release = storage.blockNextWrite(entered)
        let stale = expectation(description: "stale replacement")
        adapter.install(next) { result in self.assertFailure(result); stale.fulfill() }
        wait(for: [entered], timeout: 5)
        XCTAssertThrowsError(try complete { adapter.install(Data(), completion: $0) })
        release.signal(); wait(for: [stale], timeout: 5)
        XCTAssertEqual(storage.bytes, originalBytes)
        XCTAssertEqual(adapter.installation?.artifact, original.artifact)
        XCTAssertTrue(adapter.ioBlocked); XCTAssertNil(adapter.currentPose(now: 10))
        XCTAssertFalse(storage.log.contains("delete"))
    }
    func testTaskCancellationDuringRestrictionWriteDoesNotResurrectOldRoute() throws {
        let storage = ControlledSpatialStorage(), adapter = try ready(storage)
        let entered = expectation(description: "restriction blocked"), release = storage.blockNextWrite(entered)
        let saved = expectation(description: "restriction durable without old task")
        adapter.blockNextLegAndReplan { result in self.assertSuccess(result); saved.fulfill() }
        wait(for: [entered], timeout: 5)
        adapter.cancelRoute()
        release.signal(); wait(for: [saved], timeout: 5)
        XCTAssertTrue(adapter.route.isEmpty)
        XCTAssertEqual(adapter.installation?.currentRestrictions.blocked, [SpatialBlockedEdge(MapConnection("start", "middle"))])
        XCTAssertNil(adapter.currentPose(now: 10))
    }
    func testNewGoalAttemptDuringSaveRetiresOldReplanContinuation() throws {
        let storage = ControlledSpatialStorage(), adapter = try ready(storage)
        let entered = expectation(description: "restriction blocked"), release = storage.blockNextWrite(entered)
        let saved = expectation(description: "restriction durable")
        adapter.blockNextLegAndReplan { result in self.assertSuccess(result); saved.fulfill() }
        wait(for: [entered], timeout: 5)
        XCTAssertThrowsError(try adapter.plan(from: "middle", to: "end", goal: UUID()))
        release.signal(); wait(for: [saved], timeout: 5)
        XCTAssertTrue(adapter.route.isEmpty)
    }

    func testSupersededMainPublicationRestoresPriorBytesBeforeFailedNewerJob() throws {
        let original = Data("synthetic original A".utf8), storage = ControlledSpatialStorage(Data("synthetic original A".utf8))
        let queued = expectation(description: "publication actually enqueued after post-write CAS")
        let publication = HeldSpatialPublication(queued: queued)
        let io = SpatialMapIO<Int>(storage: storage, publishOnMain: publication.enqueue)
        let context = SpatialMapIOContext(revision: UUID(), artifact: nil)
        let stale = expectation(description: "stale main publication"), latest = expectation(description: "new invalid import")
        io.submit(expected: context, prepare: { _ in .init(value: 2, bytesToPersist: Data("synthetic B".utf8)) }) { _, result in
            if case .success = result { XCTFail("Superseded B published") }; stale.fulfill()
        }
        wait(for: [queued], timeout: 5)
        XCTAssertEqual(storage.bytes, Data("synthetic B".utf8))
        io.submit(expected: context, prepare: { _ in throw SpatialInstallationError.invalidEnvelope }) { _, result in
            if case .success = result { XCTFail("Invalid C published") }; latest.fulfill()
        }
        publication.deliverOnMain()
        wait(for: [stale, latest], timeout: 5)
        XCTAssertEqual(storage.bytes, original)
        XCTAssertFalse(storage.log.contains("delete"))
    }
    func testSupersededValidationCannotReachDurableCommit() throws {
        let storage = ControlledSpatialStorage(Data("A".utf8)), io = SpatialMapIO<Int>(storage: storage)
        let context = SpatialMapIOContext(revision: UUID(), artifact: nil)
        let entered = expectation(description: "actual preparation blocked"), release = DispatchSemaphore(value: 0)
        let old = expectation(description: "old validation superseded"), current = expectation(description: "new validation committed")
        io.submit(expected: context, prepare: { _ in
            entered.fulfill(); _ = release.wait(timeout: .now() + 5)
            return .init(value: 2, bytesToPersist: Data("B".utf8))
        }) { _, result in if case .success = result { XCTFail("Stale validation committed") }; old.fulfill() }
        wait(for: [entered], timeout: 5)
        io.submit(expected: context, prepare: { _ in .init(value: 3, bytesToPersist: Data("C".utf8)) }) { _, result in
            if case .failure(let error) = result { XCTFail("Unexpected: \(error)") }; current.fulfill()
        }
        release.signal(); wait(for: [old, current], timeout: 5)
        XCTAssertEqual(storage.bytes, Data("C".utf8))
        XCTAssertEqual(storage.log, ["write-start", "write-end"])
    }

    func testPersistentRollbackFailureFencesLaterWritesUntilDeleteBarrierSucceeds() throws {
        let storage = ControlledSpatialStorage(), adapter = try ready(storage), original = try XCTUnwrap(storage.bytes)
        storage.failNextWrites(2) // attempted commit and its rollback both fail
        XCTAssertThrowsError(try complete { adapter.install(original, completion: $0) })
        XCTAssertTrue(adapter.ioBlocked); XCTAssertNil(adapter.currentPose(now: 10))
        let writes = storage.log.filter { $0 == "write-start" }.count
        XCTAssertThrowsError(try complete { adapter.install(original, completion: $0) }) {
            XCTAssertEqual($0 as? SpatialMapIOError, .deleteBarrierFailed)
        }
        XCTAssertEqual(storage.log.filter { $0 == "write-start" }.count, writes)
        try complete { adapter.delete(completion: $0) }
        XCTAssertNil(storage.bytes)
        try complete { adapter.install(original, completion: $0) }
        XCTAssertEqual(storage.bytes, original); XCTAssertFalse(adapter.ioBlocked)
    }

}
