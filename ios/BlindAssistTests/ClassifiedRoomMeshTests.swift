import Foundation
import XCTest
import BlindRoomMesh

/// Explicit synthetic substrate tests, separate from original Apple room fixtures.
/// No sensor, localization, speech, haptic or physical guidance is invoked.
final class ClassifiedRoomMeshTests: XCTestCase {
    private let identity: [Double] = [1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1]
    private let vertices: [Double] = [-3,0,-3, -3,0,3, 3,0,3, 3,0,-3]
    private let triangles: [Int32] = [0,1,2, 0,2,3]
    private final class Box: @unchecked Sendable {
        private let lock = NSLock()
        private var stored: Result<MeshCandidateRoute, MeshCandidateError>?
        func put(_ result: Result<MeshCandidateRoute, MeshCandidateError>) { lock.lock(); stored = result; lock.unlock() }
        func get() -> Result<MeshCandidateRoute, MeshCandidateError>? { lock.lock(); defer { lock.unlock() }; return stored }
    }
    private func event(session: String, support: [MeshTriangleSupport]?) -> MeshAnchorEvent {
        .init(sessionID: session, generation: 0, anchorID: "authored-plane", revision: 1,
              timestamp: 1, vertices: vertices, triangles: triangles, columnMajorTransform: identity,
              complete: true, triangleSupport: support)
    }
    private func makeRuntime(sessionID: String, supportPolicy: MeshSupportPolicy = .legacySlope) throws -> RoomMeshCandidateRuntime {
#if DEBUG
        try RoomMeshCandidateRuntime(sessionID: sessionID, supportPolicy: supportPolicy, captureSyntheticTestTiming: true)
#else
        try RoomMeshCandidateRuntime(sessionID: sessionID, supportPolicy: supportPolicy)
#endif
    }
    private enum ReceiptEvent: String { case callback, waitFinished, failureDiscardCompleted, discardCompleted }
    private static func stageReceipt(_ runtime: RoomMeshCandidateRuntime, event: ReceiptEvent) {
#if DEBUG
        guard let id = runtime.diagnosticReceiptID else { return }
        let stages = runtime.diagnosticStageReceipts.map { "\($0.stage.rawValue):\($0.elapsedMilliseconds)" }.joined(separator: ";")
        // Fixed public-synthetic UUID, closed stage/event names, numeric elapsed
        // milliseconds only. No session/anchor identity, geometry or error text.
        print("CLASSIFIED_QUERY_STAGE_RECEIPT id=\(id.uuidString) event=\(event.rawValue) stages=\(stages)")
#endif
    }
    private func query(_ runtime: RoomMeshCandidateRuntime, start: [Float] = [-2,0,0], goal: [Float] = [2,0,0]) async throws -> Result<MeshCandidateRoute, MeshCandidateError> {
        let done = expectation(description: "native candidate result"), box = Box()
        // Test-only boundary receipts: elapsed callback time includes native-worker
        // queueing, build/query and callback-queue delay; it does not separate them.
        let receipt = UUID().uuidString, submittedAt = ProcessInfo.processInfo.systemUptime
        print("CLASSIFIED_QUERY_RECEIPT=id:\(receipt),stage:submitted")
        runtime.request(start: start, goal: goal, body: try .init(radius: 0.225, height: 1.75)) {
            box.put($0)
            let elapsedMS = Int((ProcessInfo.processInfo.systemUptime - submittedAt) * 1_000)
            print("CLASSIFIED_QUERY_RECEIPT=id:\(receipt),stage:callback,elapsed_ms:\(elapsedMS)")
            Self.stageReceipt(runtime, event: .callback)
            done.fulfill()
        }
        await fulfillment(of: [done], timeout: 10)
        let result = box.get()
        let elapsedMS = Int((ProcessInfo.processInfo.systemUptime - submittedAt) * 1_000)
        if case nil = result {
            // A thrown XCTUnwrap bypasses the test body's normal async discard.
            // Fence this owner now; do not wait longer or infer native completion.
            runtime.stopAndDiscard {
                print("CLASSIFIED_QUERY_RECEIPT=id:\(receipt),stage:failure-discard-completed")
                Self.stageReceipt(runtime, event: .failureDiscardCompleted)
            }
            print("CLASSIFIED_QUERY_RECEIPT=id:\(receipt),stage:failure-discard-requested,elapsed_ms:\(elapsedMS)")
        }
        Self.stageReceipt(runtime, event: .waitFinished)
        return try XCTUnwrap(result, "Native callback did not complete; no passing route inferred; receipt=\(receipt), wait_elapsed_ms=\(elapsedMS), terminal discard requested")
    }
    private func discard(_ runtime: RoomMeshCandidateRuntime) async {
        let done = expectation(description: "terminal geometry release")
        runtime.stopAndDiscard {
            Self.stageReceipt(runtime, event: .discardCompleted)
            done.fulfill()
        }
        await fulfillment(of: [done], timeout: 10)
    }
    func testClassifiedFloorRoutesWithoutGrantingPhysicalAuthority() async throws {
        let runtime = try makeRuntime(sessionID: "classified-floor", supportPolicy: .classifiedFloorOnly)
        XCTAssertTrue(runtime.offer(event(session: "classified-floor", support: [.floor, .floor])))
        let result = try await query(runtime)
        switch result {
        case .success(let route):
            XCTAssertTrue(route.complete); XCTAssertTrue(runtime.isCurrent(route))
            XCTAssertFalse(route.authorizesPhysicalGuidance); XCTAssertFalse(route.actualWorldCoverageKnown)
            XCTAssertTrue(route.rawDepthHazardVeto)
            runtime.invalidate(); XCTAssertFalse(runtime.isCurrent(route))
        case .failure(let error): XCTFail("Declared floor fixture did not route: \(error)")
        }
        await discard(runtime)
    }
    func testIdenticalUpwardObstaclePlaneIsNotPromotedToFloor() async throws {
        let runtime = try makeRuntime(sessionID: "classified-obstacle", supportPolicy: .classifiedFloorOnly)
        XCTAssertTrue(runtime.offer(event(session: "classified-obstacle", support: [.obstacle, .obstacle])))
        let result = try await query(runtime)
        if case .success = result { XCTFail("Slope-only promotion turned an obstacle surface into support") }
        await discard(runtime)
    }
    func testMissingAndMismatchedSupportAreRejectedAtIngress() async throws {
        let runtime = try makeRuntime(sessionID: "strict", supportPolicy: .classifiedFloorOnly)
        XCTAssertFalse(runtime.offer(event(session: "strict", support: nil)))
        XCTAssertFalse(runtime.offer(event(session: "strict", support: [.floor])))
        XCTAssertTrue(runtime.offer(event(session: "strict", support: [.floor, .floor])))
        let result = try await query(runtime)
        if case .success(let route) = result {
            XCTAssertFalse(route.sourceDeliveryComplete)
            XCTAssertTrue(route.unknownCoverage.contains("ingress-or-lifecycle-gap"))
        } else { XCTFail("Valid classified floor should remain queryable but incomplete after ingress loss") }
        await discard(runtime)
    }
    func testLegacyUnclassifiedAPIStillRoutesAndDoesNotIgnoreExplicitLabels() async throws {
        let runtime = try makeRuntime(sessionID: "legacy")
        XCTAssertFalse(runtime.offer(event(session: "legacy", support: [.floor, .floor])))
        try runtime.reset(sessionID: "legacy-next", generation: 0)
        XCTAssertTrue(runtime.offer(event(session: "legacy-next", support: nil)))
        let result = try await query(runtime)
        if case .success(let route) = result { XCTAssertTrue(route.complete) }
        else { XCTFail("The unchanged legacy slope-mode API regressed") }
        await discard(runtime)
    }
    func testFloorTouchingBedAndLowObjectNeverGainSupportUnderTriangleOrderPermutations() async throws {
        for height in [0.025, 0.65] {
            let boxVertices: [Double] = [-1,0,-1, 1,0,-1, 1,0,1, -1,0,1,
                                        -1,height,-1, 1,height,-1, 1,height,1, -1,height,1]
            let faces: [[Int32]] = [[4,6,5],[4,7,6], [0,1,2],[0,2,3],
                                   [0,4,5],[0,5,1], [1,5,6],[1,6,2],
                                   [2,6,7],[2,7,3], [3,7,4],[3,4,0]]
            let obstacleFaces = faces.map { $0.map { $0 + 4 } }
            let floorFaces: [[Int32]] = [[0,1,2],[0,2,3]]
            let labelled = floorFaces.map { ($0,MeshTriangleSupport.floor) } + obstacleFaces.map { ($0,MeshTriangleSupport.obstacle) }
            let orders = [labelled, Array(labelled.reversed()), Array(labelled.dropFirst(2)) + Array(labelled.prefix(2))]
            for (index, order) in orders.enumerated() {
                let session = "touching-\(height)-\(index)"
                let runtime = try makeRuntime(sessionID:session,supportPolicy:.classifiedFloorOnly)
                XCTAssertTrue(runtime.offer(.init(sessionID:session,generation:0,anchorID:"floor-and-solid",revision:1,
                    timestamp:1,vertices:vertices+boxVertices,triangles:order.flatMap { $0.0 },columnMajorTransform:identity,
                    complete:true,triangleSupport:order.map { $0.1 })))
                let result = try await query(runtime,start:[-0.4,Float(height),0],goal:[0.4,Float(height),0])
                if case .success = result { XCTFail("Obstacle top gained floor support at height \(height), permutation \(index)") }
                await discard(runtime)
            }
        }
    }
}

