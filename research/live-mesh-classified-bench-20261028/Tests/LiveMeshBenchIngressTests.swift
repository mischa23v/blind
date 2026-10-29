import Foundation
import XCTest
@testable import MeshSnapshot82
import MeshCandidateIngress83
import BlindRoomMesh
@testable import LiveMeshClassifiedBench

/// Synthetic owned geometry exercises the actual existing decoder/83/native75
/// dependencies. It does NOT construct a fake live ARMeshAnchor or prove phone sensing.
final class LiveMeshBenchIngressTests: XCTestCase {
    private let identity: [Float] = [1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1]
    private func floor(_ context: MeshSnapshot82.Context, id: UUID, x: Float = 0, y: Float = 0,
                       malformed: Bool = false, labels: [UInt8]? = [2,2], transform: [Float]? = nil,
                       localVertices: [Float]? = nil) -> MeshSnapshot82.Capture {
        let vertices: [Float] = localVertices ?? [-3,0,-3,-3,0,3,3,0,3,3,0,-3]
        let bytes = vertices.flatMap { value in
            (0..<4).map { UInt8(truncatingIfNeeded: value.bitPattern >> ($0 * 8)) }
        }
        let indices: [UInt8] = [0,0,1,0,2,0,0,0,2,0,3,0]
        let classification: MeshSnapshot82.Descriptor? = labels.map {
            .init(count: $0.count, offset: 0, stride: 1, bufferLength: $0.count, format: .uint8)
        }
        let plan = try! MeshSnapshot82.preflight(context: context,
            vertices: .init(count: 4, offset: 0, stride: 12, bufferLength: bytes.count, format: .float3),
            indices: .init(count: 6, offset: 0, stride: 2, bufferLength: indices.count, format: .uint16), classification: classification)
        var matrix = identity; matrix[12] = x; matrix[13] = y
        if let transform { matrix = transform }
        if malformed { matrix[15] = 0 }
        return .owned(.init(context: context, anchorID: id, plan: plan, vertexBytes: bytes,
            indexBytes: indices, classificationBytes: labels, transform: matrix))
    }
    private final class ResultBox<T> {
        private let lock = NSLock()
        private var value: T?
        func put(_ value: T) { lock.lock(); self.value = value; lock.unlock() }
        func get() -> T? { lock.lock(); defer { lock.unlock() }; return value }
    }
    private func candidate(_ owner: LiveMeshBenchIngress, x: Float = 0, z: Float = 0, alongZ: Bool = false,
                           file: StaticString = #filePath, line: UInt = #line) throws -> MeshCandidateIngress83.Candidate {
        try query(owner, x: x, z: z, alongZ: alongZ, file: file, line: line).get()
    }
    private func query(_ owner: LiveMeshBenchIngress, x: Float = 0, z: Float = 0, alongZ: Bool = false,
                       file: StaticString = #filePath, line: UInt = #line) throws
        -> Result<MeshCandidateIngress83.Candidate, MeshCandidateIngress83.Failure> {
        let done = expectation(description: "actual native candidate completion")
        let box = ResultBox<Result<MeshCandidateIngress83.Candidate, MeshCandidateIngress83.Failure>>()
        let start: [Float] = alongZ ? [x,0,z-2] : [x-2,0,z]
        let goal: [Float] = alongZ ? [x,0,z+2] : [x+2,0,z]
        owner.request(generation: owner.generation, start: start, goal: goal,
            body: try MeshCandidateBody(radius: 0.225, height: 1.75)) { box.put($0); done.fulfill() }
        wait(for: [done], timeout: 10)
        return try XCTUnwrap(box.get(), file: file, line: line)
    }
    private func assertNoCandidate(_ result: Result<MeshCandidateIngress83.Candidate, MeshCandidateIngress83.Failure>,
                                   file: StaticString = #filePath, line: UInt = #line) {
        switch result {
        case .failure(.runtime(.nativeFailure)): break
        default: XCTFail("Expected native no-route refusal, not admission failure or a candidate", file: file, line: line)
        }
    }
    private func assertIncompletePreviewRefused(_ result: Result<MeshCandidateIngress83.Candidate, MeshCandidateIngress83.Failure>,
                                                file: StaticString = #filePath, line: UInt = #line) {
        switch result {
        case .failure(.unavailable): break // Consumer refuses75's otherwise usable but incomplete candidate.
        default: XCTFail("Expected incomplete-source preview refusal", file: file, line: line)
        }
    }
    private func discard(_ owner: LiveMeshBenchIngress) {
        let done = expectation(description: "terminal native drain")
        owner.stopAndDiscard { done.fulfill() }; wait(for: [done], timeout: 10)
    }
    /// Missing polygons in a built, displaced/rotated mesh are now an explicit
    /// strict endpoint refusal. This is intentionally separate from build/no-route
    /// refusal above: an arbitrary stale/unavailable error is not accepted here.
    private func assertMissingEndpointPolygons(_ result: Result<MeshCandidateIngress83.Candidate, MeshCandidateIngress83.Failure>,
                                               start: [Float], goal: [Float],
                                               file: StaticString = #filePath, line: UInt = #line) {
        guard case .failure(.runtime(.endpointAssociationRejected(let receipt))) = result else {
            return XCTFail("Expected typed missing endpoint polygons, not any failure", file: file, line: line)
        }
        XCTAssertEqual(receipt.policy, .requireSuppliedXZOverPolygon, file: file, line: line)
        XCTAssertEqual(receipt.start.requested, start, file: file, line: line)
        XCTAssertEqual(receipt.goal.requested, goal, file: file, line: line)
        XCTAssertFalse(receipt.start.found, file: file, line: line)
        XCTAssertFalse(receipt.goal.found, file: file, line: line)
        XCTAssertFalse(receipt.start.isOverPolygon, file: file, line: line)
        XCTAssertFalse(receipt.goal.isOverPolygon, file: file, line: line)
        XCTAssertEqual(receipt.start.projected, [0,0,0], file: file, line: line)
        XCTAssertEqual(receipt.goal.projected, [0,0,0], file: file, line: line)
        XCTAssertFalse(receipt.authorizesPhysicalGuidance, file: file, line: line)
    }
    private func queryEndpoints(_ owner: LiveMeshBenchIngress, start: [Float], goal: [Float]) throws
        -> Result<MeshCandidateIngress83.Candidate, MeshCandidateIngress83.Failure> {
        let done = expectation(description: "explicit strict bench endpoint result")
        let box = ResultBox<Result<MeshCandidateIngress83.Candidate, MeshCandidateIngress83.Failure>>()
        owner.request(generation: owner.generation, start: start, goal: goal,
            body: try MeshCandidateBody(radius: 0.225, height: 1.75)) { box.put($0); done.fulfill() }
        wait(for: [done], timeout: 10)
        return try XCTUnwrap(box.get())
    }
    private func queryIngressEndpoints(_ owner: MeshCandidateIngress83, start: [Float], goal: [Float]) throws
        -> Result<MeshCandidateIngress83.Candidate, MeshCandidateIngress83.Failure> {
        let done = expectation(description: "explicit ingress endpoint result")
        let box = ResultBox<Result<MeshCandidateIngress83.Candidate, MeshCandidateIngress83.Failure>>()
        owner.request(start: start, goal: goal, body: try MeshCandidateBody(radius: 0.225, height: 1.75)) {
            box.put($0); done.fulfill()
        }
        wait(for: [done], timeout: 10)
        return try XCTUnwrap(box.get())
    }
    func testActualDependencyRouteAndExactlyOneTransformRemainNonphysical() throws {
        let queue = DispatchQueue(label: "bench.test.decode")
        let owner = try LiveMeshBenchIngress(decodeQueue: queue), anchor = UUID()
        defer { discard(owner) }
        XCTAssertTrue(owner.observe(anchorID: anchor, generation: owner.generation, receiptUptime: 1) {
            XCTAssertNil($0.captureUptime) // Receipt time must not become sensor capture time.
            return floor($0, id: anchor, x: 10)
        })
        queue.sync {}
        let result = try candidate(owner, x: 10)
        XCTAssertTrue(result.route.complete); XCTAssertTrue(result.route.sourceDeliveryComplete)
        XCTAssertEqual(result.route.projectedStart[0], 8, accuracy: 0.5)
        XCTAssertTrue(owner.isCurrent(result, generation: owner.generation))
        XCTAssertFalse(owner.authorizesPhysicalGuidance); XCTAssertFalse(owner.phoneMonitoringAvailable)
        XCTAssertFalse(result.physicalAuthority); XCTAssertFalse(result.coverageKnown)
        XCTAssertFalse(result.route.authorizesPhysicalGuidance); XCTAssertFalse(result.route.actualWorldCoverageKnown)
    }
    func testForeignGenerationCannotInvokeBorrowedCapture() throws {
        let owner = try LiveMeshBenchIngress(), anchor = UUID()
        defer { discard(owner) }
        var copied = false
        XCTAssertFalse(owner.observe(anchorID: anchor, generation: UUID(), receiptUptime: 1) {
            copied = true; return floor($0, id: anchor)
        })
        XCTAssertFalse(copied)
        XCTAssertFalse(owner.remove(anchorID: anchor, generation: UUID(), receiptUptime: 2))
    }
    func testReplacementRetiresBeforeCopyAndExactRemovalWithholdsIncompletePreview() throws {
        let queue = DispatchQueue(label: "bench.test.replace")
        let owner = try LiveMeshBenchIngress(decodeQueue: queue), a = UUID(), b = UUID()
        defer { discard(owner) }
        XCTAssertTrue(owner.observe(anchorID: a, generation: owner.generation, receiptUptime: 1) { floor($0, id: a) })
        queue.sync {}; let first = try candidate(owner)
        XCTAssertTrue(owner.observe(anchorID: b, generation: owner.generation, receiptUptime: 2) {
            XCTAssertFalse(owner.isCurrent(first, generation: owner.generation)); return floor($0, id: b, x: 10)
        })
        queue.sync {}
        XCTAssertTrue(owner.remove(anchorID: b, generation: owner.generation, receiptUptime: 3))
        //75 retains the other tile, but removed-space coverage remains unknown.
        assertIncompletePreviewRefused(try query(owner))
    }
    func testMalformedReplacementCannotExposeRetainedOldFloorPreview() throws {
        let queue = DispatchQueue(label: "bench.test.reject")
        let owner = try LiveMeshBenchIngress(decodeQueue: queue), anchor = UUID()
        defer { discard(owner) }
        XCTAssertTrue(owner.observe(anchorID: anchor, generation: owner.generation, receiptUptime: 1) { floor($0, id: anchor) })
        queue.sync {}
        XCTAssertTrue(owner.observe(anchorID: anchor, generation: owner.generation, receiptUptime: 2) { floor($0, id: anchor, malformed: true) })
        queue.sync {}; assertIncompletePreviewRefused(try query(owner))
    }
    func testSingleCopyBackpressureDoesNotInvokeSecondCaptureAndRetainsGap() throws {
        let queue = DispatchQueue(label: "bench.test.backpressure")
        let owner = try LiveMeshBenchIngress(decodeQueue: queue), anchor = UUID()
        defer { discard(owner) }
        let release = DispatchSemaphore(value: 0)
        queue.async { _ = release.wait(timeout: .now() + 10) }
        XCTAssertTrue(owner.observe(anchorID: anchor, generation: owner.generation, receiptUptime: 1) { floor($0, id: anchor) })
        var secondCopied = false
        XCTAssertFalse(owner.observe(anchorID: anchor, generation: owner.generation, receiptUptime: 2) {
            secondCopied = true; return floor($0, id: anchor)
        })
        XCTAssertFalse(secondCopied)
        release.signal(); queue.sync {}
        XCTAssertTrue(owner.observe(anchorID: anchor, generation: owner.generation, receiptUptime: 3) { floor($0, id: anchor) })
        queue.sync {}; assertIncompletePreviewRefused(try query(owner))
    }
    func testStopDuringCaptureFencesLateCompletionAndDoesNotReleaseReservationEarly() throws {
        let queue = DispatchQueue(label: "bench.test.stop-copy")
        let owner = try LiveMeshBenchIngress(decodeQueue: queue), anchor = UUID()
        let drained = expectation(description: "drain waits until capture returns")
        let returned = ResultBox<Bool>()
        XCTAssertTrue(owner.observe(anchorID: anchor, generation: owner.generation, receiptUptime: 1) { context in
            owner.stopAndDiscard {
                XCTAssertEqual(returned.get(), true)
                drained.fulfill()
            }
            var copiedAgain = false
            XCTAssertFalse(owner.observe(anchorID: anchor, generation: owner.generation, receiptUptime: 2) {
                copiedAgain = true; return floor($0, id: anchor)
            })
            XCTAssertFalse(copiedAgain)
            let captured = floor(context, id: anchor)
            returned.put(true) // Before synchronous capture returns; release must follow it.
            return captured
        })
        wait(for: [drained], timeout: 10)
        XCTAssertFalse(owner.remove(anchorID: anchor, generation: owner.generation, receiptUptime: 3))
        let refused = expectation(description: "stopped native request refused")
        owner.request(generation: owner.generation, start: [-2,0,0], goal: [2,0,0],
            body: try MeshCandidateBody(radius: 0.225, height: 1.75)) {
            if case .success = $0 { XCTFail("A terminal owner cannot publish a candidate") }
            refused.fulfill()
        }
        wait(for: [refused], timeout: 10)
    }
    func testCallbackBudgetBoundsSumWorkWithFastDecoderAndRotatesOmissions() throws {
        let queue = DispatchQueue(label: "bench.test.fast-decode")
        let owner = try LiveMeshBenchIngress(decodeQueue: queue)
        defer { discard(owner) }
        let anchors = [UUID(), UUID(), UUID()]
        var budget = MeshBenchCallbackBudget(), selected: [Int] = [], receipt = 0.0
        for _ in 0..<3 {
            var copies = 0, omissions = 0
            XCTAssertTrue(budget.deliver(count: anchors.count) { index, mayCopy in
                receipt += 1
                XCTAssertTrue(owner.observe(anchorID: anchors[index], generation: owner.generation, receiptUptime: receipt) { context in
                    if mayCopy { copies += 1; selected.append(index); return floor(context, id: anchors[index]) }
                    omissions += 1
                    return .unknownGap(.init(context: context, anchorID: anchors[index], reason: .budget))
                })
                queue.sync {} // Deliberately frees83's slot between every anchor.
            })
            XCTAssertEqual(copies, 1); XCTAssertEqual(omissions, 2)
            assertIncompletePreviewRefused(try query(owner))
        }
        XCTAssertEqual(selected, [0, 1, 2])
        var invoked = false
        XCTAssertFalse(budget.deliver(count: 129) { _, _ in invoked = true })
        XCTAssertFalse(invoked)
    }
    func testBlockedSynchronousCapturePreventsDiscardAcknowledgement() throws {
        let owner = try LiveMeshBenchIngress(), anchor = UUID()
        let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        let acknowledged = DispatchSemaphore(value: 0), finished = expectation(description: "held capture returned")
        DispatchQueue.global(qos: .utility).async {
            _ = owner.observe(anchorID: anchor, generation: owner.generation, receiptUptime: 1) { context in
                entered.signal()
                XCTAssertEqual(release.wait(timeout: .now() + 10), .success)
                return self.floor(context, id: anchor)
            }
            finished.fulfill()
        }
        XCTAssertEqual(entered.wait(timeout: .now() + 10), .success)
        owner.stopAndDiscard { acknowledged.signal() }
        // The capture is still actually semaphore-blocked throughout this interval.
        XCTAssertEqual(acknowledged.wait(timeout: .now() + 0.05), .timedOut)
        release.signal()
        wait(for: [finished], timeout: 10)
        XCTAssertEqual(acknowledged.wait(timeout: .now() + 10), .success)
    }
    func testClassifiedConsumerNeverPromotesMissingUnknownOrNonFloorPlane() throws {
        // Identical upward geometry; only real82 classification bytes differ.
        // Positive control is testActualDependencyRouteAndExactlyOneTransformRemainNonphysical.
        let cases: [[UInt8]?] = [nil, [0,0], [1,1], [3,3], [4,4], [5,5], [6,6], [7,7], [255,255]]
        for labels in cases {
            let queue = DispatchQueue(label: "bench.classified.non-floor"), anchor = UUID()
            let owner = try LiveMeshBenchIngress(decodeQueue: queue)
            defer { discard(owner) }
            XCTAssertTrue(owner.observe(anchorID: anchor, generation: owner.generation, receiptUptime: 1) {
                floor($0, id: anchor, labels: labels)
            })
            queue.sync {}
            assertNoCandidate(try query(owner))
        }
    }
    func testNonFloorGeometryStillBlocksAndExactRemovalCannotDeclareClearance() throws {
        let queue = DispatchQueue(label: "bench.classified.obstacle"), ground = UUID(), table = UUID()
        let owner = try LiveMeshBenchIngress(decodeQueue: queue)
        defer { discard(owner) }
        XCTAssertTrue(owner.observe(anchorID: ground, generation: owner.generation, receiptUptime: 1) { floor($0, id: ground) })
        queue.sync {}; let original = try candidate(owner)
        XCTAssertTrue(original.route.complete)
        // Full synthetic footprint at 0.5m: dropping table faces would wrongly leave a route.
        XCTAssertTrue(owner.observe(anchorID: table, generation: owner.generation, receiptUptime: 2) {
            XCTAssertFalse(owner.isCurrent(original, generation: owner.generation))
            return floor($0, id: table, y: 0.5, labels: [4,4])
        })
        queue.sync {}; assertNoCandidate(try query(owner))
        XCTAssertTrue(owner.remove(anchorID: table, generation: owner.generation, receiptUptime: 3))
        // Removal is not proof the vacated footprint is currently supported/clear.
        assertIncompletePreviewRefused(try query(owner))
    }
    func testUnclassifiedReplacementAndLaterFloorCannotEraseGapInSameOwner() throws {
        let queue = DispatchQueue(label: "bench.classified.replacement"), anchor = UUID()
        let owner = try LiveMeshBenchIngress(decodeQueue: queue)
        defer { discard(owner) }
        XCTAssertTrue(owner.observe(anchorID: anchor, generation: owner.generation, receiptUptime: 1) { floor($0, id: anchor) })
        queue.sync {}; let original = try candidate(owner)
        XCTAssertTrue(owner.observe(anchorID: anchor, generation: owner.generation, receiptUptime: 2) {
            XCTAssertFalse(owner.isCurrent(original, generation: owner.generation))
            return floor($0, id: anchor, labels: nil)
        })
        queue.sync {}; assertNoCandidate(try query(owner))
        XCTAssertTrue(owner.observe(anchorID: anchor, generation: owner.generation, receiptUptime: 3) { floor($0, id: anchor, x: 10) })
        queue.sync {}
        //83 can build a route again, but this consumer refuses its retained gap.
        assertIncompletePreviewRefused(try query(owner, x: 10))
        assertMissingEndpointPolygons(try query(owner), start: [-2,0,0], goal: [2,0,0]) // Original position must not survive replacement.
    }
    func testNewTerminalOwnerCannotReusePriorGenerationOrGeometry() throws {
        let queue = DispatchQueue(label: "bench.classified.new-owner"), anchor = UUID()
        let old = try LiveMeshBenchIngress(decodeQueue: queue)
        XCTAssertTrue(old.observe(anchorID: anchor, generation: old.generation, receiptUptime: 1) { floor($0, id: anchor) })
        queue.sync {}; let original = try candidate(old)
        discard(old)
        let fresh = try LiveMeshBenchIngress(decodeQueue: queue)
        defer { discard(fresh) }
        XCTAssertNotEqual(fresh.generation, old.generation)
        XCTAssertFalse(old.isCurrent(original, generation: old.generation))
        var copied = false
        XCTAssertFalse(fresh.observe(anchorID: anchor, generation: old.generation, receiptUptime: 1) {
            copied = true; return floor($0, id: anchor)
        })
        XCTAssertFalse(copied)
        XCTAssertTrue(fresh.observe(anchorID: anchor, generation: fresh.generation, receiptUptime: 1) { floor($0, id: anchor, x: 10) })
        queue.sync {}; let replacement = try candidate(fresh, x: 10)
        XCTAssertTrue(replacement.route.complete); XCTAssertTrue(replacement.route.sourceDeliveryComplete)
        XCTAssertFalse(replacement.physicalAuthority); XCTAssertFalse(replacement.coverageKnown)
        assertMissingEndpointPolygons(try query(fresh), start: [-2,0,0], goal: [2,0,0])
    }
    func testQueuedFloorThenRefusedRemovalCannotExposeStaleFloorPreview() throws {
        let queue = DispatchQueue(label: "bench.classified.refused-removal"), anchor = UUID()
        let owner = try LiveMeshBenchIngress(decodeQueue: queue)
        defer { discard(owner) }
        let release = DispatchSemaphore(value: 0)
        queue.async { _ = release.wait(timeout: .now() + 10) }
        XCTAssertTrue(owner.observe(anchorID: anchor, generation: owner.generation, receiptUptime: 1) { floor($0, id: anchor) })
        // Equal receipt is refused before75 sees removal; old copy can still install.
        // This reproduces the retained-tile gap rather than assuming removal succeeded.
        XCTAssertFalse(owner.remove(anchorID: anchor, generation: owner.generation, receiptUptime: 1))
        release.signal(); queue.sync {}
        assertIncompletePreviewRefused(try query(owner))
    }
    func testRotatedTranslatedMetreGeometryUsesExactlyOneRigidTransform() throws {
        let queue = DispatchQueue(label: "bench.classified.rigid"), anchor = UUID()
        let owner = try LiveMeshBenchIngress(decodeQueue: queue)
        defer { discard(owner) }
        // ARKit column-major: +90-degree yaw, then10m X/4m Z translation.
        let matrix: [Float] = [0,0,-1,0, 0,1,0,0, 1,0,0,0, 10,0,4,1]
        //6m X by2m Z rectangle, deliberately NOT invariant under90-degree rotation.
        let rectangle: [Float] = [-3,0,-1,-3,0,1,3,0,1,3,0,-1]
        XCTAssertTrue(owner.observe(anchorID: anchor, generation: owner.generation, receiptUptime: 1) {
            floor($0, id: anchor, transform: matrix, localVertices: rectangle)
        })
        queue.sync {}; let result = try candidate(owner, x: 10, z: 4, alongZ: true)
        XCTAssertTrue(result.route.complete)
        XCTAssertEqual(result.route.projectedStart[0], 10, accuracy: 0.5)
        XCTAssertEqual(result.route.projectedStart[2], 2, accuracy: 0.5)
        XCTAssertEqual(result.route.projectedGoal[2], 6, accuracy: 0.5)
        XCTAssertFalse(result.physicalAuthority); XCTAssertFalse(result.coverageKnown)
        // This horizontal path would exist if translation were applied without rotation.
        assertMissingEndpointPolygons(try query(owner, x: 10, z: 4), start: [8,0,4], goal: [12,0,4])
        assertMissingEndpointPolygons(try query(owner), start: [-2,0,0], goal: [2,0,0])
    }
    func testScaleAndReflectionReplacementCannotExposePriorFloor() throws {
        let scales: [Float] = [2, -1]
        for xScale in scales {
            let queue = DispatchQueue(label: "bench.classified.non-rigid"), anchor = UUID()
            let owner = try LiveMeshBenchIngress(decodeQueue: queue)
            defer { discard(owner) }
            XCTAssertTrue(owner.observe(anchorID: anchor, generation: owner.generation, receiptUptime: 1) { floor($0, id: anchor) })
            queue.sync {}; let original = try candidate(owner)
            var matrix = identity; matrix[0] = xScale
            XCTAssertTrue(owner.observe(anchorID: anchor, generation: owner.generation, receiptUptime: 2) {
                XCTAssertFalse(owner.isCurrent(original, generation: owner.generation))
                return floor($0, id: anchor, transform: matrix)
            })
            queue.sync {}; assertIncompletePreviewRefused(try query(owner))
        }
    }
    func testStrictSelectionPreservesInsideAndVerticalEndpointReceipts() throws {
        let queue = DispatchQueue(label: "bench.strict.inside"), anchor = UUID()
        let owner = try LiveMeshBenchIngress(decodeQueue: queue)
        defer { discard(owner) }
        XCTAssertTrue(owner.observe(anchorID: anchor, generation: owner.generation, receiptUptime: 1) { floor($0, id: anchor) })
        queue.sync {}
        let start: [Float] = [-1,-0.05,0], goal: [Float] = [1,-0.05,0]
        let candidate = try queryEndpoints(owner, start: start, goal: goal).get()
        let receipt = try XCTUnwrap(candidate.route.endpointAdmission)
        XCTAssertEqual(candidate.route.endpointPolicy, .requireSuppliedXZOverPolygon)
        XCTAssertEqual(receipt.policy, .requireSuppliedXZOverPolygon)
        XCTAssertTrue(candidate.route.complete); XCTAssertTrue(owner.isCurrent(candidate, generation: owner.generation))
        XCTAssertTrue(receipt.start.found && receipt.start.isOverPolygon && receipt.goal.found && receipt.goal.isOverPolygon)
        XCTAssertEqual(receipt.start.requested, start); XCTAssertEqual(receipt.goal.requested, goal)
        XCTAssertEqual(receipt.start.projected, candidate.route.projectedStart)
        XCTAssertNotEqual(candidate.route.projectedStart[1], start[1])
        XCTAssertEqual(candidate.route.projectedStart[0], start[0]); XCTAssertEqual(candidate.route.projectedStart[2], start[2])
        XCTAssertFalse(receipt.authorizesPhysicalGuidance); XCTAssertFalse(candidate.physicalAuthority)
        XCTAssertFalse(candidate.coverageKnown); XCTAssertFalse(owner.authorizesPhysicalGuidance)
    }
    func testStrictSelectionRejectsGoalAndStartProjectionWithTypedReceipts() throws {
        let queue = DispatchQueue(label: "bench.strict.refusal"), anchor = UUID()
        let owner = try LiveMeshBenchIngress(decodeQueue: queue)
        defer { discard(owner) }
        XCTAssertTrue(owner.observe(anchorID: anchor, generation: owner.generation, receiptUptime: 1) { floor($0, id: anchor) })
        queue.sync {}; let original = try candidate(owner)
        let center: [Float] = [0,0,0], outsideGoal: [Float] = [2.8,0,0], outsideStart: [Float] = [-2.8,0,0]
        guard case .failure(.runtime(.endpointAssociationRejected(let goalReceipt))) = try queryEndpoints(owner, start: center, goal: outsideGoal) else {
            return XCTFail("Bench must not emit a projected-goal candidate or an untyped failure")
        }
        XCTAssertEqual(goalReceipt.policy, .requireSuppliedXZOverPolygon)
        XCTAssertEqual(goalReceipt.start.requested, center); XCTAssertEqual(goalReceipt.goal.requested, outsideGoal)
        XCTAssertTrue(goalReceipt.start.isOverPolygon); XCTAssertTrue(goalReceipt.goal.found)
        XCTAssertFalse(goalReceipt.goal.isOverPolygon); XCTAssertFalse(goalReceipt.authorizesPhysicalGuidance)
        XCTAssertFalse(owner.isCurrent(original, generation: owner.generation))
        guard case .failure(.runtime(.endpointAssociationRejected(let startReceipt))) = try queryEndpoints(owner, start: outsideStart, goal: center) else {
            return XCTFail("Bench must not emit a projected-start candidate or an untyped failure")
        }
        XCTAssertEqual(startReceipt.start.requested, outsideStart); XCTAssertEqual(startReceipt.goal.requested, center)
        XCTAssertTrue(startReceipt.start.found); XCTAssertFalse(startReceipt.start.isOverPolygon)
        XCTAssertTrue(startReceipt.goal.isOverPolygon); XCTAssertFalse(startReceipt.authorizesPhysicalGuidance)
        // A valid request still succeeds after refusals: all-rejected behavior is not a pass.
        let after = try queryEndpoints(owner, start: [-1,0,0], goal: [1,0,0]).get()
        XCTAssertTrue(after.route.complete); XCTAssertTrue(owner.isCurrent(after, generation: owner.generation))
        XCTAssertEqual(after.route.endpointPolicy, .requireSuppliedXZOverPolygon)
    }
    func testDebugIngressStrictPolicySurvivesResetWithoutChangingLegacyDefault() throws {
#if DEBUG
        let queue = DispatchQueue(label: "bench.strict.debug-forwarding"), anchor = UUID()
        let legacy = try MeshCandidateIngress83(supportPolicy: .classifiedFloorOnly, decodeQueue: queue)
        let strict = try MeshCandidateIngress83(supportPolicy: .classifiedFloorOnly,
            endpointPolicy: .requireSuppliedXZOverPolygon, captureSyntheticTestTiming: false, decodeQueue: queue)
        defer {
            let drained = expectation(description: "both direct ingress owners drained")
            drained.expectedFulfillmentCount = 2
            legacy.stopAndDiscard { drained.fulfill() }; strict.stopAndDiscard { drained.fulfill() }
            wait(for: [drained], timeout: 10)
        }
        XCTAssertTrue(legacy.ingest(anchorID: anchor, receiptUptime: 1) { floor($0, id: anchor) })
        XCTAssertTrue(strict.ingest(anchorID: anchor, receiptUptime: 1) { floor($0, id: anchor) })
        queue.sync {}
        let center: [Float] = [0,0,0], outside: [Float] = [2.8,0,0]
        let old = try queryIngressEndpoints(legacy, start: center, goal: outside).get()
        XCTAssertTrue(old.route.complete); XCTAssertEqual(old.route.endpointPolicy, .legacyNearestProjection)
        XCTAssertNil(old.route.endpointAdmission)
        guard case .failure(.runtime(.endpointAssociationRejected(let before))) = try queryIngressEndpoints(strict, start: center, goal: outside) else {
            return XCTFail("DEBUG initializer did not forward strict policy")
        }
        XCTAssertTrue(before.start.isOverPolygon && before.goal.found); XCTAssertFalse(before.goal.isOverPolygon)
        XCTAssertEqual(before.start.requested, center); XCTAssertEqual(before.goal.requested, outside)
        try strict.reset()
        XCTAssertTrue(strict.ingest(anchorID: anchor, receiptUptime: 1) { floor($0, id: anchor) })
        queue.sync {}
        let inside = try queryIngressEndpoints(strict, start: [-1,0,0], goal: [1,0,0]).get()
        XCTAssertTrue(inside.route.complete); XCTAssertEqual(inside.route.endpointPolicy, .requireSuppliedXZOverPolygon)
        guard case .failure(.runtime(.endpointAssociationRejected(let after))) = try queryIngressEndpoints(strict, start: center, goal: outside) else {
            return XCTFail("Reset changed immutable strict endpoint policy")
        }
        XCTAssertEqual(after.policy, .requireSuppliedXZOverPolygon); XCTAssertTrue(after.start.isOverPolygon)
        XCTAssertTrue(after.goal.found); XCTAssertFalse(after.goal.isOverPolygon)
        XCTAssertEqual(after.start.requested, center); XCTAssertEqual(after.goal.requested, outside)
        XCTAssertFalse(after.authorizesPhysicalGuidance); XCTAssertFalse(strict.isCurrent(inside))
#else
        throw XCTSkip("DEBUG-only initializer is absent in a Release build")
#endif
    }
}
