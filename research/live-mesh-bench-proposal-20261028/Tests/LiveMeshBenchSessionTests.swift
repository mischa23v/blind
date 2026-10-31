#if DEBUG && os(iOS) && canImport(ARKit)
import ARKit
import UIKit
import XCTest
@testable import LiveMeshBenchProposal

/// Actual ARSession ownership fixtures, WITHOUT run(), permission prompts or camera.
/// Requires Apple iOS-hosted execution; host macOS tests do not execute these cases.
@MainActor final class LiveMeshBenchSessionTests: XCTestCase {
    private final class Delegate: NSObject, ARSessionDelegate {}
    func testWrongExpectedDelegateDoesNotTakeSession() throws {
        let session = ARSession(), original = Delegate(), wrong = Delegate()
        session.delegate = original
        XCTAssertThrowsError(try LiveMeshBenchSession(stoppedSession: session, expectedDelegate: wrong, onStopped: { _ in }))
        XCTAssertTrue(session.delegate === original); XCTAssertNil(session.configuration)
    }
    func testPrepareDoesNotRunAndDrainRestoresExactDelegateAndQueueWithoutRestart() async throws {
        let session = ARSession(), original = Delegate()
        let queue = DispatchQueue(label: "bench.test.original")
        session.delegate = original; session.delegateQueue = queue
        let stopped = expectation(description: "restored after terminal drain")
        var calls = 0
        let owner = try LiveMeshBenchSession(stoppedSession: session, expectedDelegate: original) { restored in
            calls += 1; XCTAssertTrue(restored); stopped.fulfill()
        }
        XCTAssertEqual(owner.state, .prepared); XCTAssertNil(session.configuration)
        XCTAssertFalse(owner.phoneMonitoringAvailable); XCTAssertFalse(owner.authorizesPhysicalGuidance)
        owner.stop(); owner.stop()
        await fulfillment(of: [stopped], timeout: 10)
        XCTAssertEqual(calls, 1); XCTAssertEqual(owner.state, .stopped(restored: true))
        XCTAssertTrue(session.delegate === original); XCTAssertTrue(session.delegateQueue === queue)
        XCTAssertNil(session.configuration)
        XCTAssertThrowsError(try owner.activateForSeatedBench())
    }
    func testLateDrainCannotRestoreOverNewOwner() async throws {
        let session = ARSession(), original = Delegate(), replacement = Delegate()
        session.delegate = original
        let stopped = expectation(description: "superseded owner acknowledged without restoration")
        let owner = try LiveMeshBenchSession(stoppedSession: session, expectedDelegate: original) { restored in
            XCTAssertFalse(restored); stopped.fulfill()
        }
        let hold = DispatchSemaphore(value: 0)
        owner.producerQueueForTesting.async { _ = hold.wait(timeout: .now() + 10) }
        owner.stop()
        let replacementQueue = DispatchQueue(label: "bench.test.replacement")
        session.delegate = replacement; session.delegateQueue = replacementQueue
        hold.signal()
        await fulfillment(of: [stopped], timeout: 10)
        XCTAssertTrue(session.delegate === replacement); XCTAssertTrue(session.delegateQueue === replacementQueue)
        owner.stop() // Idempotent late stop must not mutate this replacement either.
        XCTAssertTrue(session.delegate === replacement); XCTAssertNil(session.configuration)
    }
    func testBackgroundRetiresPreparedOwnerWithoutStartingCamera() async throws {
        let session = ARSession(), original = Delegate()
        session.delegate = original
        let stopped = expectation(description: "background terminal drain")
        let owner = try LiveMeshBenchSession(stoppedSession: session, expectedDelegate: original) { restored in
            XCTAssertTrue(restored); stopped.fulfill()
        }
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        await fulfillment(of: [stopped], timeout: 10)
        XCTAssertEqual(owner.state, .stopped(restored: true))
        XCTAssertTrue(session.delegate === original); XCTAssertNil(session.configuration)
    }
    func testDroppedOwnerDrainsAndRestoresWithoutStartingCamera() async throws {
        let session = ARSession(), original = Delegate()
        session.delegate = original
        let stopped = expectation(description: "deinit terminal drain")
        var owner: LiveMeshBenchSession? = try LiveMeshBenchSession(stoppedSession: session, expectedDelegate: original) { restored in
            XCTAssertTrue(restored); stopped.fulfill()
        }
        XCTAssertEqual(owner?.state, .prepared)
        owner = nil
        await fulfillment(of: [stopped], timeout: 10)
        XCTAssertTrue(session.delegate === original); XCTAssertNil(session.configuration)
    }
}
#endif
