import XCTest
@testable import BlindCore

final class NativeObservationPipelineTests: XCTestCase {
    final class Clock: @unchecked Sendable {
        private let lock = NSLock(); private var time: Double
        init(_ time: Double = 2.5) { self.time = time }
        func read() -> Double { lock.lock(); defer { lock.unlock() }; return time }
        func set(_ value: Double) { lock.lock(); time = value; lock.unlock() }
    }
    final class Store: @unchecked Sendable {
        let lock = NSLock()
        private var saved = NativeObservationHistory()
        private var transactions = 0
        var failAppend = false, failDelete = false, failLoad = false
        var onAppend: (() -> Void)?
        private(set) var deletes = 0
        var writes: Int { lock.lock(); defer { lock.unlock() }; return transactions }
        var history: NativeObservationHistory { lock.lock(); defer { lock.unlock() }; return saved }
        func seed(_ record: NativeObservationRecord) throws { lock.lock(); defer { lock.unlock() }; try saved.append(record) }
        var backend: NativeObservationStorage {
            NativeObservationStorage(load: { [self] in
                lock.lock(); defer { lock.unlock() }; if failLoad { throw NativeObservationError.invalidArchive }; return saved
            }, append: { [self] records in
                onAppend?()
                lock.lock(); defer { lock.unlock() }
                if failAppend { throw NativeObservationError.sizeLimit }
                var next = saved, inserted = 0, bytes = 0
                for row in records where !next.encodedRecords.contains(where: { $0.id == row.id }) {
                    try next.append(row); inserted += 1; bytes += row.encodedBytes
                }
                saved = next; transactions += 1
                return .init(retainedIDs: Set(saved.encodedRecords.map(\.id)), evictedRecordCount: saved.evictedRecordCount,
                             insertedRecordCount: inserted, insertedPayloadBytes: bytes)
            }, delete: { [self] in
                lock.lock(); defer { lock.unlock() }; if failDelete { throw NativeObservationError.invalidArchive }
                saved = NativeObservationHistory(); deletes += 1
            })
        }
    }
    func record(session: UUID, time: Double = 1) -> NativeObservationRecord {
        NativeObservationRecord(sessionID: session, coordinateFrameID: "session-world", producer: .arkit, sourceID: "synthetic",
            capturedAt: time, receivedAt: time + 0.1, observedAt: Date(timeIntervalSince1970: 1000), tracking: .normal,
            cameraConvention: .arKitRightUpBack, cameraToSessionWorld: .identity,
            intrinsics: NativeCameraIntrinsics(width: 4, height: 4, fx: 4, fy: 4, cx: 2, cy: 2), depth: nil)
    }
    func begin(_ pipeline: NativeObservationPipeline, store: Store, session: UUID) {
        let ready = expectation(description: "ready")
        pipeline.begin(sessionID: session, storage: store.backend) { outcome in XCTAssertEqual(outcome, .ready); ready.fulfill() }
        wait(for: [ready], timeout: 3)
    }
    func observe(_ pipeline: NativeObservationPipeline, session: UUID, time: Double = 1) {
        let observed = expectation(description: "volatile observation")
        XCTAssertTrue(pipeline.offer(sessionID: session, capturedAt: time, extract: { [self] in record(session: session, time: time) }) {
            XCTAssertEqual($0, .observed); observed.fulfill()
        })
        wait(for: [observed], timeout: 3)
    }
    func snapshot(_ pipeline: NativeObservationPipeline) -> NativeObservationSnapshot {
        let read = expectation(description: "nonblocking memory read")
        var value: NativeObservationSnapshot?
        XCTAssertTrue(pipeline.readSnapshot { value = $0; read.fulfill() })
        wait(for: [read], timeout: 2); return value!
    }
    func eventually(_ predicate: () -> Bool, file: StaticString = #filePath, line: UInt = #line) {
        let until = Date().addingTimeInterval(3)
        while !predicate(), Date() < until { Thread.sleep(forTimeInterval: 0.005) }
        XCTAssertTrue(predicate(), file: file, line: line)
    }
    func testBusyExtractionDoesNotQueueAnotherFrame() {
        let pipeline = NativeObservationPipeline(durability: .unboundedForTesting, now: { 2.5 }), store = Store(), session = UUID()
        begin(pipeline, store: store, session: session)
        let entered = expectation(description: "extracting"), observed = expectation(description: "observed")
        let release = DispatchSemaphore(value: 0)
        XCTAssertTrue(pipeline.offer(sessionID: session, capturedAt: 1, extract: { [self] in
            entered.fulfill(); _ = release.wait(timeout: .now() + 5); return record(session: session)
        }) { XCTAssertEqual($0, .observed); observed.fulfill() })
        wait(for: [entered], timeout: 2)
        XCTAssertFalse(pipeline.offer(sessionID: session, capturedAt: 2, extract: { [self] in XCTFail(); return record(session: session, time: 2) }))
        release.signal(); wait(for: [observed], timeout: 3)
        eventually { pipeline.statistics().committedRecords == 1 }
        XCTAssertEqual(pipeline.statistics().droppedBusy, 1)
    }
    func testBlockedWriterDoesNotBlockFurtherObservationsOrReads() {
        let pipeline = NativeObservationPipeline(durability: .unboundedForTesting, now: { 2.5 }), store = Store(), session = UUID()
        begin(pipeline, store: store, session: session)
        let writing = expectation(description: "writer entered"), release = DispatchSemaphore(value: 0)
        store.onAppend = { writing.fulfill(); _ = release.wait(timeout: .now() + 5) }
        observe(pipeline, session: session); wait(for: [writing], timeout: 2)
        observe(pipeline, session: session, time: 2)
        let live = snapshot(pipeline)
        XCTAssertEqual(live.history.records.count, 2); XCTAssertEqual(live.volatileRecordIDs.count, 2)
        XCTAssertTrue(live.durableRecordIDs.isEmpty); XCTAssertTrue(live.writeInFlight)
        XCTAssertEqual(store.writes, 0)
        store.onAppend = nil; release.signal()
        eventually { pipeline.statistics().committedRecords == 2 }
        XCTAssertEqual(snapshot(pipeline).durableRecordIDs.count, 2)
    }
    func testFailedWriteKeepsUsefulVolatileHistoryWithoutClaimingDurability() throws {
        let pipeline = NativeObservationPipeline(durability: .unboundedForTesting, now: { 2.5 }), store = Store(), session = UUID()
        try store.seed(record(session: session)); begin(pipeline, store: store, session: session)
        let prior = store.history; store.failAppend = true
        observe(pipeline, session: session, time: 2)
        eventually { pipeline.statistics().writeFailures == 1 }
        let live = snapshot(pipeline)
        XCTAssertEqual(live.history.records.count, 2); XCTAssertEqual(live.durableRecordIDs.count, 1)
        XCTAssertEqual(live.volatileRecordIDs.count, 1); XCTAssertEqual(store.history, prior)
        Thread.sleep(forTimeInterval: 0.03); XCTAssertEqual(pipeline.statistics().attemptedTransactions, 1)
    }
    func testStopInvalidatesExtractingFrameBeforeAnyObservationOrWrite() {
        let pipeline = NativeObservationPipeline(durability: .unboundedForTesting, now: { 2.5 }), store = Store(), session = UUID()
        begin(pipeline, store: store, session: session)
        let entered = expectation(description: "extracting"), release = DispatchSemaphore(value: 0)
        XCTAssertTrue(pipeline.offer(sessionID: session, capturedAt: 1, extract: { [self] in
            entered.fulfill(); _ = release.wait(timeout: .now() + 5); return record(session: session)
        }))
        wait(for: [entered], timeout: 2); pipeline.stop(); release.signal()
        XCTAssertTrue(snapshot(pipeline).history.records.isEmpty); XCTAssertEqual(store.writes, 0)
    }
    func testClearFollowsActiveWriteAndDropsPendingBatchWithoutResurrection() {
        let pipeline = NativeObservationPipeline(durability: .unboundedForTesting, now: { 2.5 }), store = Store(), session = UUID()
        begin(pipeline, store: store, session: session)
        let writing = expectation(description: "writing"), cleared = expectation(description: "cleared"), release = DispatchSemaphore(value: 0)
        store.onAppend = { writing.fulfill(); _ = release.wait(timeout: .now() + 5) }
        observe(pipeline, session: session); wait(for: [writing], timeout: 2)
        observe(pipeline, session: session, time: 2)
        pipeline.clear(storage: store.backend) { XCTAssertEqual($0, .cleared); cleared.fulfill() }
        XCTAssertFalse(pipeline.offer(sessionID: session, capturedAt: 2.5, extract: { [self] in record(session: session, time: 2.5) }))
        store.onAppend = nil; release.signal(); wait(for: [cleared], timeout: 3)
        XCTAssertTrue(store.history.records.isEmpty); XCTAssertTrue(snapshot(pipeline).history.records.isEmpty)
        XCTAssertEqual(store.writes, 1); XCTAssertEqual(store.deletes, 1)
    }
    func testFailedDeleteStaysDisabledAndRetainsTruthfulHistory() throws {
        let pipeline = NativeObservationPipeline(durability: .unboundedForTesting, now: { 2.5 }), store = Store(), session = UUID()
        try store.seed(record(session: session)); begin(pipeline, store: store, session: session); store.failDelete = true
        let cleared = expectation(description: "failure")
        pipeline.clear(storage: store.backend) { XCTAssertEqual($0, .clearFailed); cleared.fulfill() }
        wait(for: [cleared], timeout: 3)
        XCTAssertFalse(pipeline.offer(sessionID: session, capturedAt: 2, extract: { [self] in record(session: session, time: 2) }))
        XCTAssertEqual(store.history.records.count, 1); XCTAssertEqual(snapshot(pipeline).history.records.count, 1)
    }
    func testCorruptRestoreDoesNotOverwriteDurableStore() throws {
        let pipeline = NativeObservationPipeline(durability: .unboundedForTesting, now: { 2.5 }), store = Store(), session = UUID()
        try store.seed(record(session: session)); store.failLoad = true
        let failure = expectation(description: "restore rejected")
        pipeline.begin(sessionID: session, storage: store.backend) { XCTAssertEqual($0, .storageFailed); failure.fulfill() }
        wait(for: [failure], timeout: 3)
        XCTAssertFalse(pipeline.offer(sessionID: session, capturedAt: 1, extract: { [self] in record(session: session) }))
        XCTAssertEqual(store.history.records.count, 1); XCTAssertEqual(store.writes, 0)
    }
    func testWrongSessionAndTooFrequentFramesAreRejected() {
        let pipeline = NativeObservationPipeline(durability: .unboundedForTesting, now: { 2.5 }), store = Store(), session = UUID()
        begin(pipeline, store: store, session: session)
        XCTAssertFalse(pipeline.offer(sessionID: UUID(), capturedAt: 1, extract: { [self] in record(session: session) }))
        observe(pipeline, session: session)
        XCTAssertFalse(pipeline.offer(sessionID: session, capturedAt: 1.1, extract: { [self] in record(session: session, time: 1.1) }))
    }
    func testExtractionCannotChangeCaptureIdentity() {
        let pipeline = NativeObservationPipeline(durability: .unboundedForTesting, now: { 2.5 }), store = Store(), session = UUID()
        begin(pipeline, store: store, session: session)
        let rejected = expectation(description: "rejected")
        XCTAssertTrue(pipeline.offer(sessionID: session, capturedAt: 1, extract: { [self] in record(session: UUID()) }) {
            XCTAssertEqual($0, .invalidObservation); rejected.fulfill()
        })
        wait(for: [rejected], timeout: 3); XCTAssertTrue(snapshot(pipeline).history.records.isEmpty)
    }
    func testRestartRejectsLateOldSessionExtraction() {
        let pipeline = NativeObservationPipeline(durability: .unboundedForTesting, now: { 2.5 }), store = Store(), old = UUID(), next = UUID()
        begin(pipeline, store: store, session: old)
        let entered = expectation(description: "old extraction"), ready = expectation(description: "new ready"), release = DispatchSemaphore(value: 0)
        XCTAssertTrue(pipeline.offer(sessionID: old, capturedAt: 1, extract: { [self] in
            entered.fulfill(); _ = release.wait(timeout: .now() + 5); return record(session: old)
        }))
        wait(for: [entered], timeout: 2)
        pipeline.begin(sessionID: next, storage: store.backend) { XCTAssertEqual($0, .ready); ready.fulfill() }
        release.signal(); wait(for: [ready], timeout: 3)
        observe(pipeline, session: next, time: 2)
        eventually { pipeline.statistics().committedRecords == 1 }
        XCTAssertEqual(store.history.records.map(\.sessionID), [next]); XCTAssertEqual(pipeline.statistics().rejectedObsolete, 1)
    }
    func testCaptureAgeRecheckedAfterSlowExtraction() {
        let clock = Clock(), pipeline = NativeObservationPipeline(durability: .unboundedForTesting, now: { clock.read() }), store = Store(), session = UUID()
        begin(pipeline, store: store, session: session)
        let entered = expectation(description: "extract"), release = DispatchSemaphore(value: 0)
        XCTAssertTrue(pipeline.offer(sessionID: session, capturedAt: 1, extract: { [self] in
            entered.fulfill(); _ = release.wait(timeout: .now() + 5); return record(session: session)
        }))
        wait(for: [entered], timeout: 2); clock.set(5); release.signal()
        XCTAssertTrue(snapshot(pipeline).history.records.isEmpty); XCTAssertEqual(store.writes, 0)
        XCTAssertEqual(pipeline.statistics().rejectedObsolete, 1)
    }
    func testRepeatedClearAndBeginHaveOneControlSlot() {
        let pipeline = NativeObservationPipeline(durability: .unboundedForTesting, now: { 2.5 }), store = Store(), session = UUID()
        begin(pipeline, store: store, session: session)
        let writing = expectation(description: "writing"), cleared = expectation(description: "cleared"), release = DispatchSemaphore(value: 0)
        store.onAppend = { writing.fulfill(); _ = release.wait(timeout: .now() + 5) }
        observe(pipeline, session: session); wait(for: [writing], timeout: 2)
        pipeline.clear(storage: store.backend) { XCTAssertEqual($0, .cleared); cleared.fulfill() }
        var rejected = 0
        for _ in 0..<100 {
            pipeline.clear(storage: store.backend) { XCTAssertEqual($0, .controlBusy); rejected += 1 }
            pipeline.begin(sessionID: UUID(), storage: store.backend) { XCTAssertEqual($0, .controlBusy); rejected += 1 }
        }
        XCTAssertEqual(rejected, 200); store.onAppend = nil; release.signal(); wait(for: [cleared], timeout: 3)
        XCTAssertEqual(store.deletes, 1)
    }
    func testBlockedWriterCoalescesBoundedRecordsWithoutRetainingFramesOrRenewingTimes() {
        let clock = Clock(1), pipeline = NativeObservationPipeline(durability: .unboundedForTesting, now: { clock.read() }), store = Store(), session = UUID()
        begin(pipeline, store: store, session: session)
        let writing = expectation(description: "writing"), release = DispatchSemaphore(value: 0)
        store.onAppend = { writing.fulfill(); _ = release.wait(timeout: .now() + 10) }
        observe(pipeline, session: session); wait(for: [writing], timeout: 2)
        for n in 1...100 { let t = 1 + Double(n) * 0.5; clock.set(t); observe(pipeline, session: session, time: t) }
        let live = snapshot(pipeline)
        XCTAssertEqual(live.history.records.count, 64); XCTAssertEqual(live.history.evictedRecordCount, 37)
        XCTAssertLessThanOrEqual(live.pendingRecordCount, 64); XCTAssertLessThanOrEqual(live.history.payloadByteCount, 2*1024*1024)
        XCTAssertEqual(live.history.records.last?.capturedAt, 51)
        XCTAssertEqual(pipeline.statistics().observed, 101); XCTAssertEqual(pipeline.statistics().droppedBusy, 0)
        store.onAppend = nil; release.signal()
        eventually { pipeline.statistics().committedTransactions == 2 }
        XCTAssertEqual(store.history.records.count, 2) // active oldest + freshest eligible pending record only
        XCTAssertEqual(store.history.records.first?.capturedAt, 1)
        XCTAssertEqual(store.history.records.last?.capturedAt, 51)
        XCTAssertEqual(pipeline.statistics().pendingBatchReplacements, 99)
    }
    func testRestartRestoresDurableSubsetNotFailedVolatileRecords() throws {
        let store = Store(), session = UUID(), first = NativeObservationPipeline(durability: .unboundedForTesting, now: { 2.5 })
        try store.seed(record(session: session)); begin(first, store: store, session: session)
        store.failAppend = true; observe(first, session: session, time: 2)
        eventually { first.statistics().writeFailures == 1 }
        XCTAssertEqual(snapshot(first).history.records.count, 2)
        first.stop(); store.failAppend = false
        let reopened = NativeObservationPipeline(durability: .unboundedForTesting, now: { 2.5 }); begin(reopened, store: store, session: UUID())
        let restored = snapshot(reopened)
        XCTAssertEqual(restored.history.records.count, 1); XCTAssertTrue(restored.volatileRecordIDs.isEmpty)
    }
    func testIncrementalSubmittedPayloadEqualsNewEncodedBytesWhenWriterKeepsUp() {
        let clock = Clock(1), pipeline = NativeObservationPipeline(durability: .unboundedForTesting, now: { clock.read() }), store = Store(), session = UUID()
        begin(pipeline, store: store, session: session)
        for n in 1...100 {
            let t = Double(n); clock.set(t); observe(pipeline, session: session, time: t)
            eventually { pipeline.statistics().committedRecords == n }
        }
        let stats = pipeline.statistics()
        XCTAssertEqual(stats.logicalBytesSubmitted, stats.encodedRecordBytes)
        XCTAssertEqual(stats.committedPayloadBytes, stats.encodedRecordBytes)
        XCTAssertEqual(stats.attemptedTransactions, 100); XCTAssertEqual(stats.committedRecords, 100)
        XCTAssertEqual(snapshot(pipeline).history.records.count, 64)
    }
}
