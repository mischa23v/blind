#if DEBUG
import Foundation
import XCTest
@testable import BlindCore

/// Actual Foundation IO tests. Source prepared in the rebuild workspace; execution
/// requires the Mac/Swift toolchain. Node contracts do not execute these tests.
final class DebugSessionLogTests: XCTestCase {
    private var directories: [URL] = []

    override func tearDownWithError() throws {
        for url in directories { try? FileManager.default.removeItem(at: url) }
        directories = []
    }

    private func directory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("DebugSessionLogTests-" + UUID().uuidString)
        directories.append(url)
        return url
    }

    private func files(_ directory: URL, suffix: String) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == suffix }
    }

    private func records(_ directory: URL) throws -> [[String: Any]] {
        let logs = try files(directory, suffix: "jsonl")
        XCTAssertEqual(logs.count, 1)
        return try String(contentsOf: XCTUnwrap(logs.first), encoding: .utf8)
            .split(separator: "\n").map { line in
                try XCTUnwrap(JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
            }
    }

    func testDisabledDoesNotEvaluateDetailOrCreateDirectory() {
        let url = directory()
        let recorder = DebugSessionLog(directory: url, enabled: false)
        var evaluated = false
        XCTAssertNil(recorder.record(.userInput, source: .userTyped, session: recorder.sessionToken) {
            evaluated = true
            return .init(text: "must not be evaluated")
        })
        recorder.drainForTesting()
        XCTAssertFalse(evaluated)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testCleanFinishDrainsAdmittedEventsAndKeepsExactProvenance() throws {
        let url = directory()
        let recorder = DebugSessionLog(directory: url, enabled: true)
        let request = UUID()
        let utterance = UUID()
        let text = "Hello مرحباً 👋\nSecond line"
        let event = recorder.record(.speechRequested, source: .speechEngine, session: recorder.sessionToken,
                                    correlation: .init(requestID: request, utteranceID: utterance)) {
            .init(text: text, label: "ordinary")
        }
        recorder.finish(session: recorder.sessionToken)
        recorder.drainForTesting()
        let output = try records(url)
        XCTAssertEqual(output.map { $0["kind"] as? String }, ["sessionStarted", "speechRequested", "sessionEnded"])
        XCTAssertEqual((output[1]["text"] as? [String: Any])?["value"] as? String, text)
        XCTAssertEqual(output[1]["event"] as? String, event?.uuidString)
        let correlation = try XCTUnwrap(output[1]["correlation"] as? [String: Any])
        XCTAssertEqual(correlation["request"] as? String, request.uuidString)
        XCTAssertEqual(correlation["utterance"] as? String, utterance.uuidString)
        XCTAssertEqual(correlation["toolCall"] as? String, "unbound")
        XCTAssertEqual(output.compactMap { $0["sequence"] as? Int }, [0, 1, 2])
        XCTAssertTrue(try files(url, suffix: "open").isEmpty)
        XCTAssertEqual(recorder.snapshot().stopReason, .completed)
    }

    func testForeignSessionNeverEvaluatesDetail() {
        let recorder = DebugSessionLog(directory: directory(), enabled: true)
        let other = DebugSessionLog(directory: directory(), enabled: false)
        var evaluated = false
        XCTAssertNil(recorder.record(.toolResult, source: .toolRuntime, session: other.sessionToken) {
            evaluated = true
            return .init(text: "stale")
        })
        recorder.finish(session: recorder.sessionToken)
        recorder.drainForTesting()
        XCTAssertFalse(evaluated)
        XCTAssertEqual(recorder.snapshot().staleCallbacks, 1)
    }

    func testUTF8BoundAndRedactionAreVisibleNotSilent() throws {
        let url = directory()
        var limits = DebugSessionLog.Limits()
        limits.textBytes = 19
        let recorder = DebugSessionLog(directory: url, enabled: true, limits: limits)
        recorder.record(.userInput, source: .userTyped, session: recorder.sessionToken) {
            .init(text: String(repeating: "🙂", count: 100))
        }
        recorder.record(.modelRequest, source: .onDeviceModel, session: recorder.sessionToken) {
            .init(text: "password=secret")
        }
        recorder.finish(session: recorder.sessionToken)
        recorder.drainForTesting()
        let output = try records(url)
        let field = try XCTUnwrap(output[1]["text"] as? [String: Any])
        XCTAssertEqual(field["value"] as? String, "🙂🙂🙂🙂")
        XCTAssertEqual(field["truncated"] as? Bool, true)
        XCTAssertEqual((output[2]["text"] as? [String: Any])?["redacted"] as? Bool, true)
        XCTAssertEqual(recorder.snapshot().truncatedFields, 1)
        XCTAssertEqual(recorder.snapshot().redactedFields, 1)
        XCTAssertFalse(String(describing: output).contains("password=secret"))
    }

    func testPendingQueueIsBoundedBeforeDetailIsEvaluated() {
        let gate = DispatchSemaphore(value: 0)
        let started = DispatchSemaphore(value: 0)
        let counter = LockedCounter()
        var limits = DebugSessionLog.Limits()
        limits.pendingEvents = 1
        let recorder = DebugSessionLog(directory: directory(), enabled: true, limits: limits) { handle, data in
            if counter.increment() == 1 {
                started.signal()
                _ = gate.wait(timeout: .now() + 3)
            }
            try handle.write(contentsOf: data)
        }
        XCTAssertEqual(started.wait(timeout: .now() + 3), .success)
        XCTAssertNotNil(recorder.record(.userInput, source: .userTyped, session: recorder.sessionToken) { .init(text: "first") })
        var evaluated = false
        XCTAssertNil(recorder.record(.userInput, source: .userTyped, session: recorder.sessionToken) {
            evaluated = true
            return .init(text: "over capacity")
        })
        XCTAssertFalse(evaluated)
        gate.signal()
        recorder.finish(session: recorder.sessionToken)
        recorder.drainForTesting()
        XCTAssertEqual(recorder.snapshot().dropped, 1)
    }

    func testSessionLimitStopsAndPreservesTerminalReserve() throws {
        let url = directory()
        var limits = DebugSessionLog.Limits()
        limits.sessionBytes = 4096
        limits.retainedBytes = 8192
        limits.terminalReserve = 2048
        let recorder = DebugSessionLog(directory: url, enabled: true, limits: limits)
        for _ in 0..<10 {
            recorder.record(.modelResponseChunk, source: .onDeviceModel, session: recorder.sessionToken) {
                .init(text: String(repeating: "x", count: 1000))
            }
        }
        recorder.drainForTesting()
        XCTAssertEqual(recorder.snapshot().stopReason, .sessionLimit)
        XCTAssertGreaterThan(recorder.snapshot().dropped, 0)
        let log = try XCTUnwrap(files(url, suffix: "jsonl").first)
        XCTAssertLessThanOrEqual(try Data(contentsOf: log).count, 4096)
        XCTAssertEqual(try records(url).last?["kind"] as? String, "sessionEnded")
        XCTAssertTrue(try files(url, suffix: "open").isEmpty)
    }

    func testRetainedLimitNeverEvictsOldFiles() throws {
        let url = directory()
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let old = url.appendingPathComponent(UUID().uuidString + ".jsonl")
        let original = Data(repeating: 0x78, count: 8192)
        try original.write(to: old)
        var limits = DebugSessionLog.Limits()
        limits.sessionBytes = 4096
        limits.retainedBytes = 8192
        limits.terminalReserve = 2048
        let recorder = DebugSessionLog(directory: url, enabled: true, limits: limits)
        recorder.drainForTesting()
        XCTAssertEqual(recorder.snapshot().stopReason, .retentionLimit)
        XCTAssertEqual(try Data(contentsOf: old), original)
        XCTAssertEqual(try files(url, suffix: "jsonl").count, 1)
    }

    func testWriteFailureStopsAndLeavesUncleanMarker() throws {
        let url = directory()
        let recorder = DebugSessionLog(directory: url, enabled: true) { _, _ in throw Injected.failure }
        recorder.drainForTesting()
        XCTAssertEqual(recorder.snapshot().writeErrors, 1)
        XCTAssertEqual(recorder.snapshot().stopReason, .writeError)
        XCTAssertEqual(try files(url, suffix: "open").count, 1)
        var evaluated = false
        recorder.record(.modelResponse, source: .onDeviceModel, session: recorder.sessionToken) {
            evaluated = true
            return .init(text: "must not enqueue")
        }
        XCTAssertFalse(evaluated)
    }

    func testPriorUncleanMarkerIsCountedWithoutReadingPriorContent() throws {
        let url = directory()
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let old = url.appendingPathComponent(UUID().uuidString + ".open")
        try Data().write(to: old)
        let recorder = DebugSessionLog(directory: url, enabled: true)
        recorder.finish(session: recorder.sessionToken)
        recorder.drainForTesting()
        XCTAssertEqual(recorder.snapshot().priorUncleanSessions, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: old.path))
    }

    func testPrivacyClearPurgesPriorLogsFencesCallbacksAndCannotRestart() throws {
        let url = directory()
        let recorder = DebugSessionLog(directory: url, enabled: true)
        recorder.record(.userInput, source: .userTyped, session: recorder.sessionToken) { .init(text: "private test text") }
        recorder.drainForTesting()
        let done = expectation(description: "purge")
        recorder.purge { success in XCTAssertTrue(success); done.fulfill() }
        wait(for: [done], timeout: 3)
        var evaluated = false
        XCTAssertNil(recorder.record(.toolResult, source: .toolRuntime, session: recorder.sessionToken) {
            evaluated = true
            return .init(text: "late callback")
        })
        recorder.finish(session: recorder.sessionToken)
        recorder.drainForTesting()
        XCTAssertFalse(evaluated)
        XCTAssertEqual(recorder.snapshot().stopReason, .privacyCleared)
        XCTAssertTrue(try files(url, suffix: "jsonl").isEmpty)
        XCTAssertTrue(try files(url, suffix: "open").isEmpty)
    }

    func testFinishWaitsForAdmittedButNotYetEnqueuedDetail() throws {
        let url = directory()
        let recorder = DebugSessionLog(directory: url, enabled: true)
        recorder.drainForTesting()
        let entered = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        let recorded = expectation(description: "record finished")
        DispatchQueue.global().async {
            recorder.record(.toolResult, source: .toolRuntime, session: recorder.sessionToken) {
                entered.signal()
                _ = release.wait(timeout: .now() + 3)
                return .init(text: "admitted before finish")
            }
            recorded.fulfill()
        }
        XCTAssertEqual(entered.wait(timeout: .now() + 3), .success)
        recorder.finish(session: recorder.sessionToken)
        recorder.drainForTesting()
        XCTAssertEqual(try files(url, suffix: "open").count, 1)
        release.signal()
        wait(for: [recorded], timeout: 3)
        recorder.drainForTesting()
        XCTAssertEqual(try records(url).map { $0["kind"] as? String }, ["sessionStarted", "toolResult", "sessionEnded"])
        XCTAssertTrue(try files(url, suffix: "open").isEmpty)
    }

    func testPurgeWinsAgainstAdmittedButNotYetEnqueuedDetail() throws {
        let url = directory()
        let recorder = DebugSessionLog(directory: url, enabled: true)
        recorder.drainForTesting()
        let entered = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        let recorded = expectation(description: "late record returned")
        DispatchQueue.global().async {
            recorder.record(.toolResult, source: .toolRuntime, session: recorder.sessionToken) {
                entered.signal()
                _ = release.wait(timeout: .now() + 3)
                return .init(text: "must not survive purge")
            }
            recorded.fulfill()
        }
        XCTAssertEqual(entered.wait(timeout: .now() + 3), .success)
        let purged = expectation(description: "privacy clear finished")
        recorder.purge { success in XCTAssertTrue(success); purged.fulfill() }
        wait(for: [purged], timeout: 3)
        release.signal()
        wait(for: [recorded], timeout: 3)
        recorder.drainForTesting()
        XCTAssertEqual(recorder.snapshot().dropped, 1)
        XCTAssertTrue(try files(url, suffix: "jsonl").isEmpty)
        XCTAssertTrue(try files(url, suffix: "open").isEmpty)
    }

    private enum Injected: Error { case failure }
    private final class LockedCounter: @unchecked Sendable {
        private let lock = NSLock()
        private var value = 0
        func increment() -> Int {
            lock.lock(); defer { lock.unlock() }
            value += 1
            return value
        }
    }
}
#endif
