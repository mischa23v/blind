import XCTest
@testable import BlindMemory

final class MemoryStoreTests: XCTestCase {
    private func payload(_ text: String) -> Data { Data(text.utf8) }
    func testApprovalUsesStoredDraftAndKeepsHistory() throws {
        let store = try MemoryStore(path: ":memory:")
        let original = try store.importRoom(room: "bedroom", payload: payload("measured scan"))
        let draft = try store.propose(room: "bedroom", baseRevision: original.id, payload: payload("reviewed description"), source: "ai_reviewed")
        XCTAssertEqual(try store.current(room: "bedroom")?.id, original.id)
        let saved = try store.approve(room: "bedroom", proposalID: draft.id)
        XCTAssertEqual(saved.payload, draft.payload)
        XCTAssertEqual(try store.history(room: "bedroom").count, 2)
        XCTAssertThrowsError(try store.approve(room: "bedroom", proposalID: draft.id))
        XCTAssertEqual(try store.importRoom(room: "bedroom", payload: payload("old export")).id, saved.id)
    }
    func testStaleRejectedAndCrossRoomApprovalsNeverChangeHead() throws {
        let store = try MemoryStore(path: ":memory:")
        let original = try store.importRoom(room: "bedroom", payload: payload("original"))
        _ = try store.importRoom(room: "bathroom", payload: payload("bathroom"))
        let a = try store.propose(room: "bedroom", baseRevision: original.id, payload: payload("a"), source: "user")
        let b = try store.propose(room: "bedroom", baseRevision: original.id, payload: payload("b"), source: "ai_reviewed")
        XCTAssertThrowsError(try store.approve(room: "bathroom", proposalID: a.id))
        let current = try store.approve(room: "bedroom", proposalID: a.id)
        XCTAssertThrowsError(try store.approve(room: "bedroom", proposalID: b.id))
        try store.reject(room: "bedroom", proposalID: b.id)
        XCTAssertThrowsError(try store.approve(room: "bedroom", proposalID: b.id))
        XCTAssertEqual(try store.current(room: "bedroom")?.id, current.id)
        XCTAssertEqual(try store.history(room: "bedroom").count, 2)
        let undo = try store.propose(room: "bedroom", baseRevision: current.id, payload: original.payload, source: "restore")
        XCTAssertEqual(try store.approve(room: "bedroom", proposalID: undo.id).payload, original.payload)
        XCTAssertEqual(try store.history(room: "bedroom").count, 3)
    }
    func testReopenIsolationDeletionAndNoPersistedPose() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("test.sqlite").path
        var store: MemoryStore? = try MemoryStore(path: path, profile: "a")
        let original = try XCTUnwrap(store).importRoom(room: "bedroom", payload: payload("a"))
        try XCTUnwrap(store).saveValue(namespace: "objective", id: "active", payload: payload("bathroom"))
        XCTAssertThrowsError(try XCTUnwrap(store).saveValue(namespace: "livePose", id: "now", payload: payload("old position")))
        store = nil
        let reopened = try MemoryStore(path: path, profile: "a")
        XCTAssertEqual(try reopened.current(room: "bedroom")?.id, original.id)
        XCTAssertEqual(try reopened.value(namespace: "objective", id: "active"), payload("bathroom"))
        let other = try MemoryStore(path: path, profile: "b")
        XCTAssertNil(try other.current(room: "bedroom"))
        XCTAssertNil(try other.value(namespace: "objective", id: "active"))
        _ = try other.importRoom(room: "bedroom", payload: payload("other home"))
        try reopened.deleteRoom("bedroom")
        XCTAssertTrue(try reopened.isDeleted(room: "bedroom"))
        XCTAssertNil(try reopened.current(room: "bedroom"))
        XCTAssertTrue(try reopened.history(room: "bedroom").isEmpty)
        XCTAssertThrowsError(try reopened.importRoom(room: "bedroom", payload: payload("leftover export")))
        XCTAssertNotNil(try other.current(room: "bedroom"))
    }
    func testFailedRoomImportRollsBackBeforeRetry() throws {
        let store = try MemoryStore(path: ":memory:")
        // The room insert occurs before the revision constraint fails inside the same transaction.
        XCTAssertThrowsError(try store.importRoom(room: "entry", payload: Data()))
        XCTAssertNil(try store.current(room: "entry"))
        let saved = try store.importRoom(room: "entry", payload: payload("valid source"))
        XCTAssertEqual(try store.current(room: "entry")?.id, saved.id)
        XCTAssertEqual(try store.history(room: "entry").count, 1)
    }
    func testFailedPreferenceWriteKeepsPreviousValue() throws {
        let store = try MemoryStore(path: ":memory:")
        let original = payload("user preference")
        try store.saveValue(namespace: "preferences", id: "interests", payload: original)
        for invalid in [Data(), Data(repeating: 32, count: 64001)] {
            XCTAssertThrowsError(try store.saveValue(namespace: "preferences", id: "interests", payload: invalid))
            XCTAssertEqual(try store.value(namespace: "preferences", id: "interests"), original)
        }
        XCTAssertThrowsError(try store.saveValue(namespace: "preferences", id: "  ", payload: original))
        XCTAssertThrowsError(try store.saveValue(namespace: "livePose", id: "active", payload: original))
        try store.saveValue(namespace: "preferences", id: "interests", payload: payload("corrected"))
        XCTAssertEqual(try store.value(namespace: "preferences", id: "interests"), payload("corrected"))
    }
    func testTwoConnectionsCannotApproveDifferentDraftsFromTheSameBase() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("test.sqlite").path
        let first = try MemoryStore(path: path), second = try MemoryStore(path: path)
        let original = try first.importRoom(room: "living", payload: payload("original"))
        let a = try first.propose(room: "living", baseRevision: original.id, payload: payload("first"), source: "user")
        let b = try second.propose(room: "living", baseRevision: original.id, payload: payload("second"), source: "ai_reviewed")
        let saved = try second.approve(room: "living", proposalID: b.id)
        XCTAssertThrowsError(try first.approve(room: "living", proposalID: a.id))
        XCTAssertEqual(try first.current(room: "living")?.id, saved.id)
        XCTAssertEqual(try first.history(room: "living").count, 2)
    }
    func testDeletedRoomCannotBeRestoredFromPendingProposal() throws {
        let store = try MemoryStore(path: ":memory:")
        let original = try store.importRoom(room: "private-room", payload: payload("original"))
        let draft = try store.propose(room: "private-room", baseRevision: original.id, payload: payload("proposed"), source: "user")
        try store.deleteRoom("private-room")
        XCTAssertThrowsError(try store.approve(room: "private-room", proposalID: draft.id))
        XCTAssertThrowsError(try store.propose(room: "private-room", baseRevision: original.id, payload: original.payload, source: "restore"))
        XCTAssertNil(try store.current(room: "private-room"))
        XCTAssertTrue(try store.history(room: "private-room").isEmpty)
    }
}
