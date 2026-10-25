import XCTest
import GRDB
@testable import BlindMemory

private final class ObservationProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var statements: [String] = []
    private var attemptedBytes = 0
    func statement(_ sql: String) { lock.withLock { statements.append(sql) } }
    func inserted(_ count: Int) { lock.withLock { attemptedBytes += count } }
    func reset() { lock.withLock { statements = []; attemptedBytes = 0 } }
    var snapshot: (statements: [String], attemptedBytes: Int) { lock.withLock { (statements, attemptedBytes) } }
}

final class NativeObservationStorageTests: XCTestCase {
    private var directories: [URL] = []
    override func tearDownWithError() throws {
        for directory in directories { try FileManager.default.removeItem(at: directory) }
    }
    private func path() throws -> String {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        directories.append(directory)
        return directory.appendingPathComponent("memory.sqlite").path
    }
    private func row(_ time: Double = 1, session: String = UUID().uuidString, bytes: Int = 32, id: String = UUID().uuidString, fill: UInt8 = 42) -> NativeObservationRow {
        NativeObservationRow(id: id, sessionID: session, capturedAt: time, payload: Data(repeating: fill, count: bytes))
    }
    private func observedStore(path: String, probe: ObservationProbe) throws -> NativeObservationStore {
        var configuration = Configuration()
        configuration.prepareDatabase { db in
            db.trace { event in
                if case let .statement(statement) = event { probe.statement(statement.sql) }
            }
            db.add(function: DatabaseFunction("recordObservationInsert", argumentCount: 1) { values in
                probe.inserted(Int.fromDatabaseValue(values[0])!)
                return nil
            })
        }
        let store = try NativeObservationStore(path: path, configuration: configuration)
        let audit = try DatabaseQueue(path: path)
        try audit.write { db in
            try db.execute(sql: """
                CREATE TABLE observationWriteAudit (insertedBytes INTEGER NOT NULL, insertedRows INTEGER NOT NULL);
                INSERT INTO observationWriteAudit VALUES (0,0);
                CREATE TRIGGER observationAuditInsert AFTER INSERT ON nativeObservation BEGIN
                    SELECT recordObservationInsert(NEW.encodedBytes);
                    UPDATE observationWriteAudit SET insertedBytes=insertedBytes+NEW.encodedBytes, insertedRows=insertedRows+1;
                END;
                CREATE TRIGGER rejectObservationRewrite BEFORE UPDATE ON nativeObservation BEGIN
                    SELECT RAISE(ABORT,'existing observation must not be rewritten');
                END;
                """)
        }
        probe.reset()
        return store
    }

    private func tracedStore(path: String, probe: ObservationProbe) throws -> NativeObservationStore {
        var configuration = Configuration()
        configuration.prepareDatabase { db in
            db.trace { event in
                if case let .statement(statement) = event { probe.statement(statement.sql) }
            }
        }
        return try NativeObservationStore(path: path, configuration: configuration)
    }
    private func assertRejectedBeforePayloadAccess(_ store: NativeObservationStore, probe: ObservationProbe, file: StaticString = #filePath, line: UInt = #line) {
        probe.reset()
        XCTAssertThrowsError(try store.load(), file: file, line: line)
        XCTAssertThrowsError(try store.append([row()]), file: file, line: line)
        XCTAssertThrowsError(try store.append([]), file: file, line: line)
        let statements = probe.snapshot.statements
        XCTAssertFalse(statements.contains { $0.hasPrefix("SELECT id,sessionID,capturedAt,payload") }, file: file, line: line)
        XCTAssertFalse(statements.contains { $0.hasPrefix("INSERT INTO nativeObservation") || $0.hasPrefix("DELETE FROM nativeObservation") || $0.hasPrefix("UPDATE nativeObservation") }, file: file, line: line)
    }
    private func insertRaw(_ row: NativeObservationRow, into db: Database, encodedBytes: Int? = nil) throws {
        try db.execute(sql: "INSERT INTO nativeObservation(profile,id,sessionID,capturedAt,payload,encodedBytes) VALUES ('local',?,?,?,?,?)", arguments: [row.id, row.sessionID, row.capturedAt, row.payload, encodedBytes ?? row.payload.count])
    }

    func testExternallyOverfilledRowCountRejectsBeforePayloadReadOrInsert() throws {
        let path = try path(), probe = ObservationProbe()
        let store = try tracedStore(path: path, probe: probe)
        let raw = try DatabaseQueue(path: path)
        try raw.write { db in
            for _ in 0..<65 { try insertRaw(row(bytes: 1), into: db) }
        }
        assertRejectedBeforePayloadAccess(store, probe: probe)
        XCTAssertTrue(probe.snapshot.statements.contains { $0.contains("LIMIT ?") })
        XCTAssertEqual(try raw.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM nativeObservation") }, 65)
        // Explicit clear remains a recovery/deletion operation, even for corrupt history.
        try store.clear()
        XCTAssertTrue(try store.load().rows.isEmpty)
    }

    func testExternallyOverfilledAggregateBytesRejectBeforePayloadReadOrInsert() throws {
        let path = try path(), probe = ObservationProbe()
        let store = try tracedStore(path: path, probe: probe)
        let raw = try DatabaseQueue(path: path)
        try raw.write { db in
            try insertRaw(row(bytes: 1_048_577), into: db)
            try insertRaw(row(bytes: 1_048_576), into: db)
        }
        assertRejectedBeforePayloadAccess(store, probe: probe)
        XCTAssertEqual(try raw.read { try Int.fetchOne($0, sql: "SELECT SUM(encodedBytes) FROM nativeObservation") }, 2_097_153)
    }

    func testMalformedEvictionStateRejectsBeforePayloadReadOrInsert() throws {
        let path = try path(), probe = ObservationProbe()
        let store = try tracedStore(path: path, probe: probe)
        let original = row()
        _ = try store.append([original])
        let raw = try DatabaseQueue(path: path)
        try raw.write { db in
            try db.execute(sql: "PRAGMA ignore_check_constraints=ON")
            try db.execute(sql: "INSERT INTO nativeObservationState VALUES ('local',0)")
        }
        for invalid in ["-1", "1000000001", "1.25", "'invalid'", "zeroblob(3000000)"] {
            try raw.write { db in
                try db.execute(sql: "UPDATE nativeObservationState SET evictedRecordCount=\(invalid) WHERE profile='local'")
            }
            assertRejectedBeforePayloadAccess(store, probe: probe)
        }
        XCTAssertEqual(try raw.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM nativeObservation") }, 1)
    }

    func testMalformedCachedLengthRejectsBeforePayloadReadOrInsert() throws {
        let path = try path(), probe = ObservationProbe()
        let store = try tracedStore(path: path, probe: probe)
        let raw = try DatabaseQueue(path: path)
        try raw.write { db in
            try db.execute(sql: "PRAGMA ignore_check_constraints=ON")
            try insertRaw(row(bytes: 2_097_153), into: db, encodedBytes: 1)
        }
        assertRejectedBeforePayloadAccess(store, probe: probe)
        try store.clear()
        try raw.write { db in
            try insertRaw(row(bytes: 32), into: db, encodedBytes: 33)
        }
        assertRejectedBeforePayloadAccess(store, probe: probe)
    }

    func testAppendsWriteOnlyNewPayloadBytesInOneTransactionPerBatch() throws {
        let path = try path(), probe = ObservationProbe()
        let store = try observedStore(path: path, probe: probe)
        let session = UUID().uuidString
        let initial = (0..<64).map { row(Double($0), session: session, bytes: 32_768) }
        let first = try store.append(initial)
        XCTAssertEqual(first.insertedPayloadBytes, 2 * 1024 * 1024)
        probe.reset()
        var logicalCommittedBytes = 0
        for batch in 0..<10 {
            let rows = (0..<4).map { row(Double(64 + batch * 4 + $0), session: session, bytes: 1_000) }
            let result = try store.append(rows)
            XCTAssertEqual(result.insertedRecordCount, 4)
            XCTAssertEqual(result.insertedPayloadBytes, 4_000)
            logicalCommittedBytes += result.insertedPayloadBytes
        }
        let measured = probe.snapshot
        XCTAssertEqual(measured.attemptedBytes, 40_000)
        XCTAssertEqual(logicalCommittedBytes, measured.attemptedBytes)
        XCTAssertEqual(measured.statements.filter { $0.uppercased().hasPrefix("BEGIN ") }.count, 10)
        XCTAssertEqual(measured.statements.filter { $0.uppercased().hasPrefix("COMMIT") }.count, 10)
        XCTAssertEqual(measured.statements.filter { $0.hasPrefix("INSERT INTO nativeObservation(") }.count, 40)
        XCTAssertFalse(measured.statements.contains { $0.hasPrefix("UPDATE nativeObservation ") })
        // Payload reads are only individual incoming-ID duplicate checks, never a ring rewrite.
        XCTAssertFalse(measured.statements.contains { $0.hasPrefix("SELECT id,sessionID,capturedAt,payload") && !$0.contains("AND id=?") })
        let sql = try DatabaseQueue(path: path)
        try sql.read { db in
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT insertedBytes FROM observationWriteAudit"), 2 * 1024 * 1024 + 40_000)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT insertedRows FROM observationWriteAudit"), 104)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM nativeObservation WHERE encodedBytes!=length(payload)"), 0)
        }
        XCTAssertEqual(try store.load().rows.count, 64)
        XCTAssertEqual(try store.load().evictedRecordCount, 40)
    }

    func testFIFOUsesInsertionOrderAcrossSessionClockRebases() throws {
        let store = try NativeObservationStore(path: ":memory:")
        let oldSession = UUID().uuidString, newSession = UUID().uuidString
        let old = (0..<64).map { row(1_000 + Double($0), session: oldSession) }
        _ = try store.append(old)
        let rebooted = row(0, session: newSession)
        let result = try store.append([rebooted])
        XCTAssertEqual(result.retainedIDs, old.dropFirst().map(\.id) + [rebooted.id])
        XCTAssertEqual(result.evictedRecordCount, 1)
        XCTAssertEqual(try store.load().rows.last, rebooted)
    }

    func testByteQuotaEvictsOldestRowsAndCountsExactly() throws {
        let store = try NativeObservationStore(path: ":memory:")
        let first = row(bytes: 1_000_000), second = row(bytes: 1_000_000)
        _ = try store.append([first, second])
        let third = row(bytes: 1_100_000)
        let result = try store.append([third])
        XCTAssertEqual(result.retainedIDs, [third.id])
        XCTAssertEqual(result.evictedRecordCount, 2)
        XCTAssertEqual(result.insertedRecordCount, 1)
        XCTAssertEqual(result.insertedPayloadBytes, 1_100_000)
        let maximum = row(bytes: NativeObservationStore.maximumPayloadBytes)
        XCTAssertEqual(try store.append([maximum]).retainedIDs, [maximum.id])
        XCTAssertEqual(try store.load().evictedRecordCount, 3)
    }

    func testIdenticalDuplicatesAreNotRewrittenOrReordered() throws {
        let path = try path(), probe = ObservationProbe()
        let store = try observedStore(path: path, probe: probe)
        let first = row(), second = row()
        _ = try store.append([first, second])
        probe.reset()
        let result = try store.append([second, first, second])
        XCTAssertEqual(result.retainedIDs, [first.id, second.id])
        XCTAssertEqual(result.insertedRecordCount, 0)
        XCTAssertEqual(result.insertedPayloadBytes, 0)
        XCTAssertEqual(probe.snapshot.attemptedBytes, 0)
        XCTAssertEqual(try store.load().rows, [first, second])
    }

    func testMismatchAfterNewInsertRollsBackPayloadAndCounter() throws {
        let path = try path(), probe = ObservationProbe()
        let store = try observedStore(path: path, probe: probe)
        let original = row(bytes: 100)
        _ = try store.append([original])
        let before = try store.load()
        probe.reset()
        let added = row(bytes: 123)
        let altered = NativeObservationRow(id: original.id, sessionID: original.sessionID, capturedAt: original.capturedAt, payload: Data([1]))
        XCTAssertThrowsError(try store.append([added, altered]))
        XCTAssertEqual(try store.load(), before)
        // The first INSERT was attempted before the mismatch; its bytes did not commit.
        XCTAssertEqual(probe.snapshot.attemptedBytes, 123)
        XCTAssertEqual(probe.snapshot.statements.filter { $0.uppercased().hasPrefix("ROLLBACK") }.count, 1)
        let sql = try DatabaseQueue(path: path)
        XCTAssertEqual(try sql.read { try Int.fetchOne($0, sql: "SELECT insertedBytes FROM observationWriteAudit") }, 100)
        XCTAssertEqual(try store.append([added]).insertedPayloadBytes, 123)
    }

    func testChangedMetadataAndInBatchDuplicateMismatchRollBack() throws {
        let store = try NativeObservationStore(path: ":memory:")
        let original = row()
        _ = try store.append([original])
        for changed in [NativeObservationRow(id: original.id, sessionID: UUID().uuidString, capturedAt: original.capturedAt, payload: original.payload), NativeObservationRow(id: original.id, sessionID: original.sessionID, capturedAt: 2, payload: original.payload)] {
            XCTAssertThrowsError(try store.append([changed]))
            XCTAssertEqual(try store.load().rows, [original])
        }
        let next = row()
        let changed = NativeObservationRow(id: next.id, sessionID: next.sessionID, capturedAt: next.capturedAt, payload: Data([0]))
        XCTAssertThrowsError(try store.append([next, changed]))
        XCTAssertEqual(try store.load().rows, [original])
        XCTAssertEqual(try store.append([next, next]).insertedRecordCount, 1)
    }

    func testOversizeRecordBatchCountAndAggregateBytesDoNotBeginWrite() throws {
        let path = try path(), probe = ObservationProbe()
        let store = try observedStore(path: path, probe: probe)
        let original = row()
        _ = try store.append([original])
        probe.reset()
        for rows in [[row(bytes: 2 * 1024 * 1024 + 1)], (0..<65).map { _ in row(bytes: 1) }, [row(bytes: 1_048_577), row(bytes: 1_048_576)]] {
            XCTAssertThrowsError(try store.append(rows))
        }
        XCTAssertEqual(probe.snapshot.attemptedBytes, 0)
        XCTAssertFalse(probe.snapshot.statements.contains { $0.uppercased().hasPrefix("BEGIN ") })
        XCTAssertEqual(try store.load().rows, [original])
    }

    func testMetadataValidationAndStrictPerSessionCaptureTimes() throws {
        let store = try NativeObservationStore(path: ":memory:")
        let session = UUID().uuidString
        let original = row(10, session: session)
        _ = try store.append([original])
        for invalid in [row(9, session: session), row(10, session: session), row(-1), row(.infinity), row(.nan), row(bytes: 0), row(id: "bad-id"), row(session: "bad-session")] {
            XCTAssertThrowsError(try store.append([invalid]))
        }
        let lowerCaseSession = session.lowercased()
        XCTAssertThrowsError(try store.append([row(10, session: lowerCaseSession)]))
        let valid = row(11, session: lowerCaseSession)
        XCTAssertEqual(try store.append([valid]).insertedRecordCount, 1)
        let lowerCaseDuplicate = NativeObservationRow(id: original.id.lowercased(), sessionID: lowerCaseSession, capturedAt: 10, payload: original.payload)
        XCTAssertEqual(try store.append([lowerCaseDuplicate]).insertedRecordCount, 0)
        let before = try store.load()
        XCTAssertThrowsError(try store.append([row(12, session: session), row(12, session: session)]))
        XCTAssertEqual(try store.load(), before)
        XCTAssertEqual(try store.append([row(0)]).insertedRecordCount, 1)
    }

    func testRestartKeepsRowsOrderCounterAndTimestampEnforcement() throws {
        let path = try path(), session = UUID().uuidString
        var store: NativeObservationStore? = try NativeObservationStore(path: path)
        _ = try XCTUnwrap(store).append((0..<64).map { row(Double($0), session: session, bytes: 16_000) })
        _ = try XCTUnwrap(store).append((64..<80).map { row(Double($0), session: session, bytes: 16_000) })
        let before = try XCTUnwrap(store).load()
        store = nil
        let reopened = try NativeObservationStore(path: path)
        XCTAssertEqual(try reopened.load(), before)
        XCTAssertEqual(before.evictedRecordCount, 16)
        XCTAssertThrowsError(try reopened.append([row(79, session: session)]))
        XCTAssertEqual(try reopened.append([row(80, session: session)]).evictedRecordCount, 17)
    }

    func testClearIsIdempotentProfileScopedAndResetsCounter() throws {
        let path = try path()
        let first = try NativeObservationStore(path: path, profile: "first")
        let second = try NativeObservationStore(path: path, profile: "second")
        let shared = row()
        _ = try first.append([shared])
        _ = try first.append((0..<64).map { _ in row() })
        _ = try second.append([shared])
        XCTAssertEqual(try first.load().evictedRecordCount, 1)
        try first.clear()
        try first.clear()
        XCTAssertEqual(try first.load(), NativeObservationStoreSnapshot(rows: [], evictedRecordCount: 0))
        XCTAssertEqual(try second.load().rows, [shared])
        XCTAssertEqual(try NativeObservationStore(path: path, profile: "first").load().evictedRecordCount, 0)
        XCTAssertEqual(try first.append([shared]).insertedRecordCount, 1)
    }

    func testExactEvictionCounterRejectsOverflowAndRollsBack() throws {
        let path = try path(), store = try NativeObservationStore(path: path)
        let rows = (0..<64).map { _ in row() }
        _ = try store.append(rows)
        let sql = try DatabaseQueue(path: path)
        try sql.write { db in
            try db.execute(sql: "INSERT INTO nativeObservationState VALUES ('local',999999999)")
        }
        XCTAssertEqual(try store.append([row()]).evictedRecordCount, 1_000_000_000)
        let before = try store.load()
        XCTAssertThrowsError(try store.append([row()]))
        XCTAssertEqual(try store.load(), before)
        XCTAssertEqual(try NativeObservationStore(path: path).load(), before)
        XCTAssertThrowsError(try sql.write { db in
            try db.execute(sql: "UPDATE nativeObservationState SET evictedRecordCount=1000000001")
        })
    }

    func testSQLFailureAfterEvictionRestoresDeletedRowsAndNewInsert() throws {
        let path = try path(), store = try NativeObservationStore(path: path)
        _ = try store.append((0..<64).map { _ in row() })
        let before = try store.load()
        let sql = try DatabaseQueue(path: path)
        try sql.write { db in
            try db.execute(sql: """
                CREATE TRIGGER failEvictionCounter BEFORE INSERT ON nativeObservationState BEGIN
                    SELECT RAISE(ABORT,'injected counter write failure');
                END;
                """)
        }
        let next = row()
        XCTAssertThrowsError(try store.append([next]))
        XCTAssertEqual(try store.load(), before)
        XCTAssertEqual(try NativeObservationStore(path: path).load(), before)
        try sql.write { db in try db.execute(sql: "DROP TRIGGER failEvictionCounter") }
        let retried = try store.append([next])
        XCTAssertEqual(retried.evictedRecordCount, 1)
        XCTAssertEqual(retried.insertedRecordCount, 1)
        XCTAssertEqual(retried.retainedIDs, before.rows.dropFirst().map(\.id) + [next.id])
    }

    func testEmptyAppendDoesNotOpenWriteTransaction() throws {
        let path = try path(), probe = ObservationProbe()
        let store = try observedStore(path: path, probe: probe)
        let result = try store.append([])
        XCTAssertEqual(result.insertedPayloadBytes, 0)
        XCTAssertEqual(result.insertedRecordCount, 0)
        XCTAssertEqual(result.retainedIDs, [])
        // DatabaseQueue.read may use a deferred snapshot transaction; no immediate write.
        XCTAssertFalse(probe.snapshot.statements.contains { $0.uppercased().contains("BEGIN IMMEDIATE") })
    }

    func testV4MemoryStaysUntouchedAndObservationsUseSeparateFile() throws {
        let path = try path(), queue = try DatabaseQueue(path: path)
        var migrator = DatabaseMigrator()
        for (identifier, resource) in [("assistant-memory-v1", "schema"), ("assistant-memory-v2-deletion", "deletion"), ("assistant-memory-v3-narration", "narration"), ("assistant-memory-v4-private-values", "private_values")] {
            migrator.registerMigration(identifier) { db in try db.execute(sql: MemoryStore.sql(resource)) }
        }
        try migrator.migrate(queue)
        let old = Data("existing-private-memory".utf8)
        try queue.write { db in
            try db.execute(sql: "INSERT INTO memoryValue(profile,namespace,id,payload,updated) VALUES (?,?,?,?,?)", arguments: ["owner", "companion", "memory", old, 1_000])
        }
        let store = try MemoryStore(path: path, profile: "owner")
        XCTAssertFalse(FileManager.default.fileExists(atPath: path + ".native-observations.sqlite"))
        XCTAssertEqual(try store.value(namespace: "companion", id: "memory"), old)
        let history = try store.makeNativeObservationStore()
        let observation = row(bytes: 70_000)
        _ = try history.append([observation])
        XCTAssertTrue(FileManager.default.fileExists(atPath: path + ".native-observations.sqlite"))
        let observationSQL = try DatabaseQueue(path: path + ".native-observations.sqlite")
        try observationSQL.read { db in
            XCTAssertFalse(try db.tableExists("memoryValue"))
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM grdb_migrations"), 1)
        }
        XCTAssertEqual(try NativeObservationStore(path: path + ".native-observations.sqlite", profile: "owner").load().rows, [observation])
        XCTAssertTrue(try NativeObservationStore(path: path + ".native-observations.sqlite", profile: "other").load().rows.isEmpty)
        XCTAssertThrowsError(try store.saveValue(namespace: "native-observations", id: "history", payload: old))
        XCTAssertThrowsError(try store.value(namespace: "native-observations", id: "history"))
        try queue.read { db in
            XCTAssertEqual(try Double.fetchOne(db, sql: "SELECT updated FROM memoryValue WHERE profile='owner'"), 1_000)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM grdb_migrations"), 4)
            XCTAssertFalse(try db.tableExists("nativeObservation"))
        }
    }

    func testBlockedActualObservationWriterDoesNotBlockMainThreadMemory() throws {
        // XCTest invokes this synchronous test on the actual main thread. The SQL
        // gate has a timeout solely to terminate a broken shared-writer regression.
        XCTAssertTrue(Thread.isMainThread)
        let path = try path(), normal = try MemoryStore(path: path)
        let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        let writerTimedOut = DispatchSemaphore(value: 0)
        let observations = try NativeObservationStore(path: path + ".native-observations.sqlite", configuration: Configuration(), beforeAppend: {
            entered.signal()
            guard release.wait(timeout: .now() + 5) == .success else {
                writerTimedOut.signal()
                throw MemoryError.invalid
            }
        })
        let captured = row()
        let appendFinished = expectation(description: "Observation transaction eventually commits")
        DispatchQueue.global(qos: .utility).async {
            defer { appendFinished.fulfill() }
            do { _ = try observations.append([captured]) }
            catch { XCTFail("Observation append failed: \(error)") }
        }
        XCTAssertEqual(entered.wait(timeout: .now() + 2), .success)
        // This is the normal memory call's real main-thread execution context,
        // while the observation transaction remains blocked on a utility queue.
        do {
            let payload = Data("normal memory".utf8)
            try normal.saveValue(namespace: "companion", id: "active", payload: payload)
            XCTAssertEqual(try normal.value(namespace: "companion", id: "active"), payload)
        } catch { XCTFail("Main-thread normal memory failed: \(error)") }
        XCTAssertEqual(writerTimedOut.wait(timeout: .now()), .timedOut, "Normal memory must finish before the observation writer's timeout escape")
        release.signal()
        wait(for: [appendFinished], timeout: 2)
        XCTAssertEqual(try observations.load().rows, [captured])
    }
}
