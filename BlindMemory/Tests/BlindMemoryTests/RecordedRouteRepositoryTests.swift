import XCTest
import GRDB
@testable import BlindMemory

final class RecordedRouteRepositoryTests: XCTestCase {
    private let session = UUID().uuidString
    private func row(_ time: Double, bytes: Int = 1024) -> RecordedRouteRow {
        .init(id: UUID().uuidString, sessionID: session, sourceFrameID: "observed-source-frame", capturedAt: time, payload: Data(repeating: 42, count: bytes))
    }
    func testBlankTripStartNamedAnchorsPaginationAndReopen() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try RecordedRouteRepository(path: path), identity = try store.state()
        let rows = (0..<150).map { row(Double($0)*0.2) }
        for start in stride(from: 0, to: rows.count, by: 50) { _ = try store.append(Array(rows[start..<min(start+50,rows.count)]), trip: identity) }
        let entrance = try store.pin(sequence: 20, trip: identity, kind: .entrance, label: "Entrance used")
        _ = try store.pin(sequence: 80, trip: identity, kind: .meetingPoint, label: "Meeting point")
        XCTAssertEqual(try store.pin(sequence: 20, trip: identity, kind: .entrance, label: "Entrance used"), entrance)
        let reopened = try RecordedRouteRepository(path: path)
        XCTAssertEqual(try reopened.state().id, identity.id)
        XCTAssertEqual(try reopened.state().anchors.first?.sequence, 0)
        var cursor: RecordedRouteCursor?, sequence: [Int64] = []
        repeat {
            let page = try reopened.reversePage(cursor: cursor, returningTo: entrance.id, limit: 17)
            XCTAssertLessThanOrEqual(page.samples.count, 17); XCTAssertTrue(page.missingRanges.isEmpty)
            sequence += page.samples.map(\.sequence); cursor = page.next
            if cursor == nil { XCTAssertTrue(page.reachedReference) }
        } while cursor != nil
        XCTAssertEqual(sequence, Array((20..<150).reversed()).map(Int64.init))
    }
    func testQuotaKeepsPinnedStartAndMeetingWhileRecordingContinuesWithExplicitGaps() throws {
        let store = try RecordedRouteRepository(path: ":memory:", payloadQuota: 8192), trip = try store.state()
        _ = try store.append((0..<6).map { row(Double($0)) }, trip: trip)
        _ = try store.pin(sequence: 3, trip: trip, kind: .meetingPoint, label: "Family")
        for i in 6..<200 { _ = try store.append([row(Double(i))], trip: trip) }
        let state = try store.state()
        XCTAssertEqual(state.nextSequence, 200); XCTAssertEqual(state.retainedCount, 8); XCTAssertEqual(state.evictedCount, 192)
        let page = try store.reversePage()
        XCTAssertEqual(page.samples.last?.sequence, 0); XCTAssertTrue(page.samples.contains { $0.sequence == 3 })
        XCTAssertEqual(page.samples.first?.sequence, 199); XCTAssertFalse(page.missingRanges.isEmpty)
        XCTAssertTrue(page.reachedReference) // Reaching the old anchor does NOT mean the gaps vanished.
    }
    func testClearRetiresOldTripAppendAnchorAndPageOwnership() throws {
        let store = try RecordedRouteRepository(path: ":memory:"), trip = try store.state()
        _ = try store.append((0..<5).map { row(Double($0)) }, trip: trip)
        let cursor = try XCTUnwrap(store.reversePage(limit: 1).next)
        try store.clear(trip: trip)
        XCTAssertNotEqual(try store.state().id, trip.id)
        XCTAssertThrowsError(try store.append([row(6)], trip: trip))
        XCTAssertThrowsError(try store.pin(sequence: 0, trip: trip, kind: .entrance, label: "stale"))
        XCTAssertThrowsError(try store.reversePage(cursor: cursor))
        XCTAssertEqual(try store.state().retainedCount, 0)
    }
    func testSnapshotCursorExcludesLaterAppendAndDuplicateRetryIsIdempotent() throws {
        let store = try RecordedRouteRepository(path: ":memory:"), trip = try store.state()
        let batch = (0..<10).map { row(Double($0)) }
        _ = try store.append(batch, trip: trip)
        XCTAssertEqual(try store.append(batch, trip: trip).insertedCount, 0)
        let cursor = try XCTUnwrap(store.reversePage(limit: 2).next)
        _ = try store.append([row(11)], trip: trip)
        XCTAssertEqual(try store.reversePage(cursor: cursor).samples.first?.sequence, 7)
        XCTAssertThrowsError(try store.append([.init(id: batch[0].id, sessionID: session, sourceFrameID: "other", capturedAt: 0, payload: batch[0].payload)], trip: trip))
    }
    func testSeventyTwoHourSparseEpisodeUsesBoundedPagesAndRetentionNotTerminalRing() throws {
        // Sparse 10-second source interval, NOT a 72-hour/5-Hz device-performance claim.
        let store = try RecordedRouteRepository(path: ":memory:", payloadQuota: 65536), trip = try store.state()
        for start in stride(from: 0, to: 25920, by: 64) {
            _ = try store.append((start..<min(start+64,25920)).map { row(Double($0)*10, bytes: 128) }, trip: trip)
        }
        let state = try store.state()
        XCTAssertEqual(state.nextSequence, 25920); XCTAssertEqual(state.retainedCount, 256)
        XCTAssertEqual(state.anchors.first?.sequence, 0)
        let page = try store.reversePage(limit: 64)
        XCTAssertEqual(page.samples.count, 64); XCTAssertEqual(page.samples.first?.row.capturedAt, 259190)
    }
    func testTinyPayloadsHaveBoundedAccountedRowsAndBatchEviction() throws {
        let store = try RecordedRouteRepository(path: ":memory:", payloadQuota: 8192), trip = try store.state()
        _ = try store.append((0..<32).map { row(Double($0), bytes: 1) }, trip: trip)
        XCTAssertEqual(try store.state().retainedCount, 32)
        let receipt = try store.append((32..<96).map { row(Double($0), bytes: 4096) }, trip: trip)
        XCTAssertLessThanOrEqual(receipt.evictedCount, RecordedRouteRepository.maximumEvictionCandidates)
        XCTAssertLessThanOrEqual(receipt.state.retainedBytes, 8192)
        XCTAssertEqual(receipt.state.anchors.first?.sequence, 0)
        XCTAssertEqual(try store.reversePage().samples.first?.sequence, 95)
    }
    func testMalformedMetadataAndStaleClearCannotDeleteNewTrip() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try RecordedRouteRepository(path: path), old = try store.state()
        try store.clear(trip: old); let current = try store.state()
        _ = try store.append([row(0)], trip: current)
        XCTAssertThrowsError(try store.clear(trip: old))
        XCTAssertEqual(try store.state().retainedCount, 1)
        let raw = try DatabaseQueue(path: path)
        try raw.write { db in try db.execute(sql: "UPDATE recordedTrip SET id=?", arguments: [String(repeating: "x", count: 1000000)]) }
        XCTAssertThrowsError(try store.state())
        XCTAssertThrowsError(try store.reversePage())
    }
    func testMalformedNumericMetadataIsRejectedByBoundedSQLProjection() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try RecordedRouteRepository(path: path), trip = try store.state()
        _ = try store.append([row(0)], trip: trip)
        let raw = try DatabaseQueue(path: path)
        try raw.write { try $0.execute(sql: "UPDATE recordedTrip SET retainedBytes=?", arguments: [String(repeating: "z", count: 1000000)]) }
        XCTAssertThrowsError(try store.state())
        try raw.write { try $0.execute(sql: "UPDATE recordedTrip SET retainedBytes=1024"); try $0.execute(sql: "UPDATE recordedRouteSample SET capturedAt=?", arguments: [String(repeating: "z", count: 1000000)]) }
        XCTAssertThrowsError(try store.reversePage())
        XCTAssertThrowsError(try store.append([row(1)], trip: trip))
    }
    func testCursorCarriesReferenceAndEarlierGapAcrossPages() throws {
        let store = try RecordedRouteRepository(path: ":memory:", payloadQuota: 8192), trip = try store.state()
        _ = try store.append((0..<8).map { row(Double($0)) }, trip: trip)
        let anchor = try store.pin(sequence: 2, trip: trip, kind: .entrance, label: "Door")
        _ = try store.append((8..<30).map { row(Double($0)) }, trip: trip)
        var page = try store.reversePage(returningTo: anchor.id, limit: 2)
        var sawGap = page.hasMissingHistory
        while let cursor = page.next {
            XCTAssertThrowsError(try store.reversePage(cursor: cursor, returningTo: trip.anchors.first?.id ?? "other"))
            page = try store.reversePage(cursor: cursor, limit: 2)
            sawGap = sawGap || page.hasMissingHistory
        }
        XCTAssertEqual(page.samples.last?.sequence, 2); XCTAssertTrue(page.reachedReference)
        XCTAssertTrue(sawGap); XCTAssertTrue(page.hasMissingHistory)
    }
    func testOversizedSQLiteBlobRejectsBeforeMaterializingPayload() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try RecordedRouteRepository(path: path), trip = try store.state()
        _ = try store.append([row(0)], trip: trip)
        let database = try DatabaseQueue(path: path)
        try database.write { db in
            try db.execute(sql: "PRAGMA ignore_check_constraints=ON")
            try db.execute(sql: "UPDATE recordedRouteSample SET payload=zeroblob(10000000),encodedBytes=10000000")
        }
        XCTAssertThrowsError(try store.reversePage())
        XCTAssertThrowsError(try RecordedRouteRepository(path: path))
    }
}
