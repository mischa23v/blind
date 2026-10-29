import Foundation
import XCTest
@testable import BlindRoomMesh
@testable import MeshSnapshot82
import MeshCandidateIngress83
@testable import LiveMeshClassifiedBench

/// Owned synthetic source only. No ARSession, native route build, device or
/// physical-world freshness is established by these fixtures.
final class SourceGeometrySnapshotTests: XCTestCase {
    private let identity: [Double] = [1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1]
    private let vertices: [Double] = [-3,0,-1,-3,0,1,3,0,1,3,0,-1]
    private let indices: [Int32] = [0,1,2,0,2,3]
    private final class Box<T> {
        private let lock = NSLock()
        private var value: T?
        func put(_ value: T) { lock.lock(); self.value = value; lock.unlock() }
        func get() -> T? { lock.lock(); defer { lock.unlock() }; return value }
    }
    private func event(_ id: String = "A", revision: Int = 1, time: Double = 1,
                       transform: [Double]? = nil, removed: Bool = false,
                       roles: [MeshTriangleSupport] = [.floor,.obstacle]) -> MeshAnchorEvent {
        .init(sessionID: "test", generation: 1, anchorID: id, revision: revision, timestamp: time,
              vertices: removed ? [] : vertices, triangles: removed ? [] : indices,
              columnMajorTransform: removed ? [] : (transform ?? identity), complete: !removed,
              removed: removed, triangleSupport: removed ? nil : roles)
    }
    private func runtime() throws -> RoomMeshCandidateRuntime {
        try RoomMeshCandidateRuntime(sessionID: "test", generation: 1,
            supportPolicy: .classifiedFloorOnly, endpointPolicy: .requireSuppliedXZOverPolygon)
    }
    private func drain(_ owner: RoomMeshCandidateRuntime) {
        let done = expectation(description: "snapshot owner drain")
        owner.stopAndDiscard { done.fulfill() }; wait(for: [done], timeout: 10)
    }
    private func snapshot(_ owner: RoomMeshCandidateRuntime, limits: MeshSourceSnapshotLimits = .init()) throws
        -> Result<MeshSourceGeometrySnapshot,MeshSourceSnapshotError> {
        let done = expectation(description: "source snapshot result")
        let box = Box<Result<MeshSourceGeometrySnapshot,MeshSourceSnapshotError>>()
        owner.requestSourceSnapshot(limits: limits) { box.put($0); done.fulfill() }
        wait(for: [done], timeout: 10)
        RoomMeshCandidateRuntime.sourceSnapshotDeliveryWorker.sync {}
        return try XCTUnwrap(box.get())
    }
    /// Gate the actual existing serial source/native worker, not a mock mapper.
    private func blockWorker() -> DispatchSemaphore {
        let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        RoomMeshCandidateRuntime.worker.async { entered.signal(); release.wait() }
        XCTAssertEqual(entered.wait(timeout: .now() + 10), .success)
        return release
    }
    func testSnapshotPreservesLocalValuesTransformRolesAndUnknownPhysicalAuthority() throws {
        let owner = try runtime(); defer { drain(owner) }
        let matrix: [Double] = [0,0,-1,0,0,1,0,0,1,0,0,0,10,2,20,1]
        XCTAssertTrue(owner.offer(event(transform: matrix)))
        let source = try snapshot(owner).get(), anchor = try XCTUnwrap(source.anchors.first)
        XCTAssertEqual(anchor.localVertices, vertices); XCTAssertEqual(anchor.triangleIndices, indices)
        XCTAssertEqual(anchor.columnMajorTransform, matrix)
        XCTAssertEqual(anchor.normalizedSupportRoles, [.floor,.obstacle])
        XCTAssertFalse(anchor.rawARKitClassificationsAvailable)
        var world: [Double] = []
        for i in stride(from: 0, to: vertices.count, by: 3) {
            for r in 0..<3 {
                world.append(matrix[r]*anchor.localVertices[i] + matrix[4+r]*anchor.localVertices[i+1] +
                             matrix[8+r]*anchor.localVertices[i+2] + matrix[12+r])
            }
        }
        XCTAssertEqual(world, [9,2,23,11,2,23,11,2,17,9,2,17])
        XCTAssertEqual(source.units, "metres"); XCTAssertNil(source.captureUptime)
        XCTAssertNil(source.records.first?.captureUptime)
        XCTAssertEqual(source.records.first?.receiptUptime, 1)
        XCTAssertTrue(source.sourceDeliveryComplete); XCTAssertTrue(owner.isCurrent(source))
        XCTAssertFalse(source.authorizesPhysicalGuidance); XCTAssertFalse(source.actualWorldCoverageKnown)
    }
    func testStableAnchorOrderReadOnlyRevisionAndExactOwnerIdentity() throws {
        let owner = try runtime(), other = try runtime(); defer { drain(owner); drain(other) }
        XCTAssertTrue(owner.offer(event("B"))); XCTAssertTrue(owner.offer(event("A", time: 2)))
        let first = try snapshot(owner).get(), second = try snapshot(owner).get()
        XCTAssertEqual(first.anchors.map(\.anchorID), ["A","B"])
        XCTAssertEqual(first.records.map(\.anchorID), ["A","B"])
        XCTAssertEqual(first.revision, second.revision)
        XCTAssertTrue(owner.isCurrent(first)); XCTAssertFalse(other.isCurrent(first))
        XCTAssertTrue(other.offer(event("B"))); XCTAssertTrue(other.offer(event("A", time: 2)))
        let foreign = try snapshot(other).get()
        XCTAssertEqual(first.revision, foreign.revision)
        XCTAssertFalse(owner.isCurrent(foreign)); XCTAssertFalse(other.isCurrent(first))
    }
    func testNoOwnerReturnsUnavailableNotSyntheticEmptyRoom() throws {
        let owner = try runtime(); defer { drain(owner) }
        guard case .failure(.unavailable) = try snapshot(owner) else { return XCTFail("No source was admitted") }
    }
    func testWholeSnapshotBudgetsAndInvalidLimitsNeverReturnPrefixes() throws {
        let owner = try runtime(); defer { drain(owner) }
        XCTAssertTrue(owner.offer(event("A"))); XCTAssertTrue(owner.offer(event("B", time: 2)))
        let source = try snapshot(owner).get()
        for limits in [MeshSourceSnapshotLimits(anchors: 1), .init(records: 1), .init(vertices: 7),
                       .init(triangles: 3), .init(payloadBytes: 1)] {
            guard case .failure(.budget) = try snapshot(owner, limits: limits) else { return XCTFail("Must reject whole snapshot") }
        }
        for limits in [MeshSourceSnapshotLimits(anchors: 0), .init(records: 257), .init(payloadBytes: 8000001)] {
            guard case .failure(.invalidLimits) = try snapshot(owner, limits: limits) else { return XCTFail("Invalid ceiling") }
        }
        XCTAssertTrue(owner.isCurrent(source)) // inspection failure is not a geometry mutation
        let exact = try snapshot(owner, limits: .init(payloadBytes: source.logicalPayloadBytes)).get()
        XCTAssertEqual(exact.anchors.count, 2)
        guard case .failure(.budget) = try snapshot(owner, limits: .init(payloadBytes: source.logicalPayloadBytes - 1)) else {
            return XCTFail("Exact payload boundary must be honored")
        }
    }
    func testRemovalRetiresSnapshotKeepsTombstoneAndUnknownNotFreeSpace() throws {
        let owner = try runtime(); defer { drain(owner) }
        XCTAssertTrue(owner.offer(event())); let before = try snapshot(owner).get()
        XCTAssertTrue(owner.offer(event(revision: 2, time: 2, removed: true)))
        XCTAssertFalse(owner.isCurrent(before))
        let after = try snapshot(owner).get()
        XCTAssertTrue(after.anchors.isEmpty); XCTAssertEqual(after.records.count, 1)
        XCTAssertEqual(after.records.first?.storedRevision, 2)
        XCTAssertEqual(after.records.first?.removed, true)
        XCTAssertEqual(after.records.first?.hasRetainedGeometry, false)
        XCTAssertFalse(after.sourceDeliveryComplete); XCTAssertTrue(after.unknownCoverage.contains("removed:A"))
        XCTAssertFalse(after.actualWorldCoverageKnown)
    }
    func testMalformedReplacementRetainsOnlyExplicitlyIncompleteDiagnosticHistory() throws {
        let owner = try runtime(); defer { drain(owner) }
        XCTAssertTrue(owner.offer(event())); let before = try snapshot(owner).get()
        var invalid = identity; invalid[0] = 2
        XCTAssertTrue(owner.offer(event(revision: 2, time: 2, transform: invalid)))
        XCTAssertFalse(owner.isCurrent(before))
        let after = try snapshot(owner).get()
        XCTAssertEqual(after.anchors.first?.columnMajorTransform, identity)
        XCTAssertEqual(after.records.first?.storedRevision, 1) // not relabelled as revision 2
        XCTAssertFalse(after.sourceDeliveryComplete); XCTAssertTrue(after.retainedGeometryMayBeSuperseded)
        XCTAssertTrue(after.unknownCoverage.contains("invalid-input"))
        XCTAssertTrue(after.unknownCoverage.contains("ingress-or-lifecycle-gap"))
    }
    func testProjectedOverflowCannotPairNewLedgerWithOldRetainedTile() throws {
        let owner = try runtime(); defer { drain(owner) }
        XCTAssertTrue(owner.offer(event())); _ = try snapshot(owner).get()
        var invalid = identity; invalid[12] = 1e300 // finite Double, nonrepresentable native Float
        XCTAssertTrue(owner.offer(event(revision: 2, time: 2, transform: invalid)))
        guard case .failure(.invalidRetainedState) = try snapshot(owner) else {
            return XCTFail("Rejected new packet must not masquerade as retained source geometry")
        }
    }
    func testQueuedDeliveryRetainsReservationAndDiscardUntilPayloadReleased() throws {
        let owner = try runtime()
        XCTAssertTrue(owner.offer(event())); _ = try snapshot(owner).get()
        let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        RoomMeshCandidateRuntime.sourceSnapshotDeliveryWorker.async { entered.signal(); release.wait() }
        XCTAssertEqual(entered.wait(timeout: .now() + 10), .success)
        let delivered = expectation(description: "stale queued delivery")
        owner.requestSourceSnapshot { result in
            guard case .failure(.stale) = result else { delivered.fulfill(); return XCTFail("Stop must suppress queued payload") }
            delivered.fulfill()
        }
        RoomMeshCandidateRuntime.worker.sync {} // real payload now waits on delivery queue
        let refused = expectation(description: "queued delivery still occupies slot")
        owner.requestSourceSnapshot { result in
            guard case .failure(.unavailable) = result else { refused.fulfill(); return XCTFail("Queued payload reservation lost") }
            refused.fulfill()
        }
        wait(for: [refused], timeout: 10)
        let discarded = DispatchSemaphore(value: 0), done = expectation(description: "discard waits for payload release")
        owner.stopAndDiscard { discarded.signal(); done.fulfill() }
        XCTAssertEqual(discarded.wait(timeout: .now()), .timedOut)
        release.signal(); wait(for: [delivered,done], timeout: 10)
    }
    func testInvalidateAndResetRetireExactSnapshot() throws {
        let owner = try runtime(); defer { drain(owner) }
        XCTAssertTrue(owner.offer(event())); let before = try snapshot(owner).get()
        owner.invalidate(); XCTAssertFalse(owner.isCurrent(before))
        let unknown = try snapshot(owner).get()
        XCTAssertFalse(unknown.sourceDeliveryComplete)
        try owner.reset(sessionID: "new-session", generation: 1)
        XCTAssertFalse(owner.isCurrent(unknown))
        guard case .failure(.unavailable) = try snapshot(owner) else { return XCTFail("Old owner geometry must not cross reset") }
    }
    func testQueuedSnapshotCannotDeliverAfterNewerUpdate() throws {
        let owner = try runtime(); defer { drain(owner) }
        XCTAssertTrue(owner.offer(event())); _ = try snapshot(owner).get()
        let release = blockWorker(), done = expectation(description: "stale queued snapshot")
        let box = Box<Result<MeshSourceGeometrySnapshot,MeshSourceSnapshotError>>()
        owner.requestSourceSnapshot { box.put($0); done.fulfill() }
        XCTAssertTrue(owner.offer(event(revision: 2, time: 2)))
        release.signal(); wait(for: [done], timeout: 10)
        RoomMeshCandidateRuntime.sourceSnapshotDeliveryWorker.sync {}
        guard case .failure(.stale) = try XCTUnwrap(box.get()) else { return XCTFail("Newer update must fence result") }
        XCTAssertEqual(try snapshot(owner).get().records.first?.storedRevision, 2)
    }
    func testOnlyOneOutstandingSnapshotAndDiscardWaitsForAdmittedWorker() throws {
        let owner = try runtime()
        XCTAssertTrue(owner.offer(event())); _ = try snapshot(owner).get()
        let release = blockWorker(), first = expectation(description: "first snapshot"), second = expectation(description: "bounded refusal")
        let firstBox = Box<Result<MeshSourceGeometrySnapshot,MeshSourceSnapshotError>>()
        owner.requestSourceSnapshot { firstBox.put($0); first.fulfill() }
        owner.requestSourceSnapshot { result in
            guard case .failure(.unavailable) = result else { second.fulfill(); return XCTFail("Second payload must not be admitted") }
            second.fulfill()
        }
        wait(for: [second], timeout: 10)
        let discarded = DispatchSemaphore(value: 0), drainDone = expectation(description: "drain after worker")
        owner.stopAndDiscard { discarded.signal(); drainDone.fulfill() }
        XCTAssertEqual(discarded.wait(timeout: .now()), .timedOut)
        release.signal(); wait(for: [first,drainDone], timeout: 10)
        guard case .failure(.stale) = try XCTUnwrap(firstBox.get()) else { return XCTFail("Stop must retire queued snapshot") }
    }
    func testLateFailureGapRetiresPreviouslyCompleteSnapshotWithoutRevisionChange() throws {
        let owner = try runtime(); defer { drain(owner) }
        XCTAssertTrue(owner.offer(event())); let source = try snapshot(owner).get()
        owner.recordOfferFailure(sessionID: "test", generation: 1, lifecycle: 0)
        XCTAssertFalse(owner.isCurrent(source))
        let after = try snapshot(owner).get()
        XCTAssertEqual(source.revision, after.revision)
        XCTAssertFalse(after.sourceDeliveryComplete)
    }
    private func captured(_ context: MeshSnapshot82.Context, id: UUID, labels: [UInt8]?) -> MeshSnapshot82.Capture {
        let values = vertices.map(Float.init)
        let bytes = values.flatMap { value in (0..<4).map { UInt8(truncatingIfNeeded: value.bitPattern >> ($0 * 8)) } }
        let indices: [UInt8] = [0,0,1,0,2,0,0,0,2,0,3,0]
        let classification = labels.map { MeshSnapshot82.Descriptor(count: $0.count, offset: 0, stride: 1, bufferLength: $0.count, format: .uint8) }
        let plan = try! MeshSnapshot82.preflight(context: context,
            vertices: .init(count: 4, offset: 0, stride: 12, bufferLength: bytes.count, format: .float3),
            indices: .init(count: 6, offset: 0, stride: 2, bufferLength: indices.count, format: .uint16), classification: classification)
        return .owned(.init(context: context, anchorID: id, plan: plan, vertexBytes: bytes,
            indexBytes: indices, classificationBytes: labels, transform: identity.map(Float.init)))
    }
    func testActualIngressAndBenchForwardOwnedGeometryAndKeepMissingClassesUnknown() throws {
        let queue = DispatchQueue(label: "source.snapshot.decode"), owner = try LiveMeshBenchIngress(decodeQueue: queue)
        let id = UUID(), done = expectation(description: "forwarded source"), box = Box<MeshCandidateIngress83.SourceSnapshot>()
        XCTAssertTrue(owner.observe(anchorID: id, generation: owner.generation, receiptUptime: 1) { captured($0, id: id, labels: nil) })
        queue.sync {}
        owner.requestSourceSnapshot(generation: owner.generation) { result in
            switch result {
            case .success(let source): box.put(source)
            case .failure: XCTFail("Incomplete geometry is inspectable, not silently replaced")
            }
            done.fulfill()
        }
        wait(for: [done], timeout: 10)
        RoomMeshCandidateRuntime.sourceSnapshotDeliveryWorker.sync {}
        let source = try XCTUnwrap(box.get())
        XCTAssertEqual(source.geometry.anchors.first?.localVertices, vertices)
        XCTAssertEqual(source.geometry.anchors.first?.normalizedSupportRoles, [.obstacle,.obstacle])
        XCTAssertFalse(source.geometry.sourceDeliveryComplete); XCTAssertFalse(source.physicalAuthority)
        XCTAssertFalse(source.coverageKnown); XCTAssertTrue(owner.isCurrent(source, generation: owner.generation))
        XCTAssertFalse(owner.isCurrent(source, generation: UUID()))
        owner.stop(); XCTAssertFalse(owner.isCurrent(source, generation: owner.generation))
        let drained = expectation(description: "bench snapshot drain")
        owner.stopAndDiscard { drained.fulfill() }; wait(for: [drained], timeout: 10)
    }
    private func ingressSnapshot(_ owner: MeshCandidateIngress83) throws
        -> Result<MeshCandidateIngress83.SourceSnapshot,MeshCandidateIngress83.SourceSnapshotFailure> {
        let done = expectation(description: "ingress source result")
        let box = Box<Result<MeshCandidateIngress83.SourceSnapshot,MeshCandidateIngress83.SourceSnapshotFailure>>()
        owner.requestSourceSnapshot { box.put($0); done.fulfill() }
        wait(for: [done], timeout: 10)
        RoomMeshCandidateRuntime.sourceSnapshotDeliveryWorker.sync {}
        return try XCTUnwrap(box.get())
    }
    func testIngressResetRetiresSnapshotAndCannotExposePreviousEpochGeometry() throws {
        let queue = DispatchQueue(label: "snapshot.reset.decode")
        let owner = try MeshCandidateIngress83(supportPolicy: .classifiedFloorOnly, decodeQueue: queue), id = UUID()
        XCTAssertTrue(owner.ingest(anchorID: id, receiptUptime: 1) { captured($0, id: id, labels: [2,2]) })
        queue.sync {}
        let source = try ingressSnapshot(owner).get()
        XCTAssertTrue(owner.isCurrent(source))
        try owner.reset(); XCTAssertFalse(owner.isCurrent(source))
        guard case .failure(.runtime(.unavailable)) = try ingressSnapshot(owner) else {
            return XCTFail("Previous epoch must not supply new snapshot")
        }
        let done = expectation(description: "reset ingress drain")
        owner.stopAndDiscard { done.fulfill() }; wait(for: [done], timeout: 10)
    }
    func testIngressOutstandingDecodeRefusesSnapshotWithoutCopyingAgain() throws {
        let queue = DispatchQueue(label: "snapshot.busy.decode")
        let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        queue.async { entered.signal(); release.wait() }
        defer { release.signal() } // thrown setup/assertion errors must not strand the decode queue
        XCTAssertEqual(entered.wait(timeout: .now() + 10), .success)
        let owner = try MeshCandidateIngress83(supportPolicy: .classifiedFloorOnly, decodeQueue: queue), id = UUID()
        var captures = 0
        XCTAssertTrue(owner.ingest(anchorID: id, receiptUptime: 1) {
            captures += 1; return captured($0, id: id, labels: [2,2])
        })
        guard case .failure(.unavailable) = try ingressSnapshot(owner) else {
            release.signal(); return XCTFail("In-flight copy must prevent snapshot admission")
        }
        XCTAssertEqual(captures, 1)
        release.signal(); queue.sync {}
        let source = try ingressSnapshot(owner).get()
        XCTAssertEqual(source.geometry.anchors.count, 1); XCTAssertEqual(captures, 1)
        let done = expectation(description: "busy ingress drain")
        owner.stopAndDiscard { done.fulfill() }; wait(for: [done], timeout: 10)
    }
    func testForeignBenchGenerationCannotRequestSnapshot() throws {
        let owner = try LiveMeshBenchIngress(), done = expectation(description: "foreign source request")
        owner.requestSourceSnapshot(generation: UUID()) { result in
            guard case .failure(.unavailable) = result else { done.fulfill(); return XCTFail("Foreign owner admitted") }
            done.fulfill()
        }
        wait(for: [done], timeout: 10)
        let drained = expectation(description: "empty bench drain")
        owner.stopAndDiscard { drained.fulfill() }; wait(for: [drained], timeout: 10)
    }
}
