import XCTest
@testable import BlindMemory

final class NarrationHistoryTests: XCTestCase {
    private func start(_ store: MemoryStore, id: String, text: String = "A painting is visible.") throws {
        try store.startNarration(id: id, sessionID: "session", goalRevision: "goal", snapshotID: "frame",
                                 sourceIDs: ["room-revision", "observation"], text: text, at: Date(timeIntervalSince1970: 100))
    }
    func testDispatchIsNotCompletionAndLateCallbacksCannotRewriteOutcome() throws {
        let store = try MemoryStore(path: ":memory:")
        try start(store, id: "a")
        XCTAssertEqual(try store.recentNarrations().first?.outcome, "pending")
        try store.finishNarration(id: "a", outcome: "interrupted", at: Date())
        try store.finishNarration(id: "a", outcome: "completed", at: Date())
        let record = try XCTUnwrap(store.recentNarrations().first)
        XCTAssertEqual(record.outcome, "interrupted")
        XCTAssertEqual(record.sourceIDs, ["room-revision", "observation"])
        try start(store, id: "b")
        try store.finishNarration(id: "b", outcome: "completed", at: Date())
        XCTAssertEqual(try store.recentNarrations().first?.outcome, "completed")
    }
    func testRestartMakesPendingUnknownAndProfileRemainsIsolated() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("history.sqlite").path
        var store: MemoryStore? = try MemoryStore(path: path)
        try start(XCTUnwrap(store), id: "unfinished"); store = nil
        let reopened = try MemoryStore(path: path)
        try reopened.recoverPendingNarrations()
        XCTAssertEqual(try reopened.recentNarrations().first?.outcome, "unknown")
        let other = try MemoryStore(path: path, profile: "someone-else")
        XCTAssertTrue(try other.recentNarrations().isEmpty)
    }
    func testBoundedHistoryClearAndDelayedCompletionDoNotResurrectText() throws {
        let store = try MemoryStore(path: ":memory:")
        for index in 0..<25 { try start(store, id: "item-\(index)") }
        let recent = try store.recentNarrations()
        XCTAssertEqual(recent.count, 20); XCTAssertEqual(recent.first?.id, "item-24"); XCTAssertEqual(recent.last?.id, "item-5")
        try store.clearNarrations()
        try store.finishNarration(id: "item-24", outcome: "completed", at: Date())
        XCTAssertTrue(try store.recentNarrations().isEmpty)
    }
    func testInvalidOrDuplicateStartDoesNotReplaceSavedRecord() throws {
        let store = try MemoryStore(path: ":memory:")
        try start(store, id: "original")
        XCTAssertThrowsError(try start(store, id: "original", text: "Replacement"))
        XCTAssertThrowsError(try start(store, id: "long", text: String(repeating: "a", count: 2001)))
        XCTAssertThrowsError(try store.finishNarration(id: "original", outcome: "assumed-heard", at: Date()))
        XCTAssertEqual(try store.recentNarrations().count, 1)
        XCTAssertEqual(try store.recentNarrations().first?.text, "A painting is visible.")
    }
}
