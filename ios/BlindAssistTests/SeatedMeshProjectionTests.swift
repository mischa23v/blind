#if DEBUG && BLIND_MESH_CANDIDATE_DIAGNOSTICS
import XCTest
import SceneKit
import ARKit
import BlindCore
import MeshCandidateIngress83
import BlindRoomMesh
@testable import MeshSnapshot82
@testable import LiveMeshClassifiedBench
@testable import BlindAssist

final class SeatedMeshProjectionTests: XCTestCase {
    private let identity: [Double] = [1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1]
    func testIdentityKeepsRawARKitAxesAndMetres() throws {
        let p = try XCTUnwrap(SeatedMeshProjection.worldVertices(local: [1,2,-3], transform: identity)?.first)
        XCTAssertEqual(p.x,1); XCTAssertEqual(p.y,2); XCTAssertEqual(p.z,-3)
    }
    func testColumnMajorRotationTranslationAppliedExactlyOnce() throws {
        // +90deg around Y; local(1,2,3) -> world(13,22,29).
        let m: [Double] = [0,0,-1,0, 0,1,0,0, 1,0,0,0, 10,20,30,1]
        let p = try XCTUnwrap(SeatedMeshProjection.worldVertices(local: [1,2,3], transform: m)?.first)
        XCTAssertEqual(p.x,13); XCTAssertEqual(p.y,22); XCTAssertEqual(p.z,29)
    }
    func testEachAnchorUsesItsOwnTransformWithoutFrameSubstitution() throws {
        var b = identity; b[12] = 5
        let a = try XCTUnwrap(SeatedMeshProjection.worldVertices(local: [0,1,0], transform: identity)?.first)
        let second = try XCTUnwrap(SeatedMeshProjection.worldVertices(local: [0,1,0], transform: b)?.first)
        XCTAssertEqual(a.x,0); XCTAssertEqual(second.x,5); XCTAssertEqual(a.y,second.y)
    }
    func testMalformedNonfiniteAndPerspectiveInputRejectWholeProjection() {
        XCTAssertNil(SeatedMeshProjection.worldVertices(local: [1,2], transform: identity))
        XCTAssertNil(SeatedMeshProjection.worldVertices(local: [1,2,3], transform: []))
        XCTAssertNil(SeatedMeshProjection.worldVertices(local: [1,.nan,3], transform: identity))
        var m = identity; m[3] = 1
        XCTAssertNil(SeatedMeshProjection.worldVertices(local: [1,2,3], transform: m))
        m = identity; m[12] = .infinity
        XCTAssertNil(SeatedMeshProjection.worldVertices(local: [1,2,3], transform: m))
    }
    func testWholeProjectionRejectsVertexBudgetAndFloatOverflow() {
        XCTAssertNil(SeatedMeshProjection.worldVertices(local: Array(repeating:0,count:600_003), transform: identity))
        XCTAssertNil(SeatedMeshProjection.worldVertices(local: [Double.greatestFiniteMagnitude,0,0], transform: identity))
    }
    func testDoubleLocalValuesCanCancelBeforeBoundedFloatProjection() throws {
        var m = identity; m[12] = -1e100
        let p = try XCTUnwrap(SeatedMeshProjection.worldVertices(local:[1e100,2,3], transform:m)?.first)
        XCTAssertEqual(p.x,0); XCTAssertEqual(p.y,2); XCTAssertEqual(p.z,3)
    }
    func testRouteMustMatchExactCurrentSourceSessionGenerationAndRevision() {
        typealias Revision = SeatedMeshProjection.Revision
        let source = Revision(session:"one", generation:2, revision:3)
        XCTAssertTrue(SeatedMeshProjection.matches(source:source, route:source, sourceCurrent:true, routeCurrent:true))
        XCTAssertFalse(SeatedMeshProjection.matches(source:source, route:source, sourceCurrent:false, routeCurrent:true))
        XCTAssertFalse(SeatedMeshProjection.matches(source:source, route:source, sourceCurrent:true, routeCurrent:false))
        for other in [Revision(session:"two",generation:2,revision:3), Revision(session:"one",generation:1,revision:3), Revision(session:"one",generation:2,revision:4)] {
            XCTAssertFalse(SeatedMeshProjection.matches(source:source, route:other, sourceCurrent:true, routeCurrent:true))
        }
    }

    func testConfirmationIsExactSingleUseAndRetiresOnStopOrViewReplacement() throws {
        var lease = SeatedMeshPresentationLease()
        let first = lease.open(), confirmation = try XCTUnwrap(lease.confirm(view: first))
        XCTAssertFalse(lease.consume(view:UUID(), confirmation:confirmation))
        XCTAssertFalse(lease.consume(view:first, confirmation:UUID()))
        XCTAssertTrue(lease.consume(view:first, confirmation:confirmation))
        XCTAssertFalse(lease.consume(view:first, confirmation:confirmation))
        let cancelled = try XCTUnwrap(lease.confirm(view:first))
        lease.cancelConfirmation()
        XCTAssertFalse(lease.consume(view:first, confirmation:cancelled))
        let queued = try XCTUnwrap(lease.confirm(view:first)), second = lease.open()
        XCTAssertFalse(lease.close(view:first))
        XCTAssertTrue(lease.owns(view:second))
        XCTAssertFalse(lease.consume(view:first, confirmation:queued))
        let last = try XCTUnwrap(lease.confirm(view:second))
        XCTAssertTrue(lease.close(view:second))
        XCTAssertFalse(lease.consume(view:second, confirmation:last))
    }

    @MainActor func testStopKeepsOwnerUntilNativeAndHeldRendererBothDrain() async throws {
        final class Delegate: NSObject, ARSessionDelegate {}
        let session = ARSession(), original = Delegate()
        session.delegate = original; session.delegateQueue = .main
        let native = expectation(description:"native drain"), done = expectation(description:"display and native drain")
        let hold = DispatchSemaphore(value:0), began = expectation(description:"renderer began")
        defer { hold.signal() }
        var finished = false
        let controller = try SeatedMeshDiagnosticController(session:session, expectedDelegate:original) { finished = true; done.fulfill() }
        controller.onNativeDrainForTesting = { native.fulfill() }
        controller.enqueueSyntheticDisplayWorkForTesting(work: {
            began.fulfill(); hold.wait()
        }, afterEnqueue: {}, delivered: {})
        await fulfillment(of:[began],timeout:10)
        controller.stop()
        await fulfillment(of:[native],timeout:10)
        XCTAssertFalse(finished); XCTAssertNil(session.configuration)
        hold.signal()
        await fulfillment(of:[done],timeout:10)
        XCTAssertTrue(finished); XCTAssertTrue(session.delegate === original)
    }
    @MainActor func testMainDeliveryCannotReleaseOwnerBeforeWorkerClosureReturns() async throws {
        final class Delegate: NSObject, ARSessionDelegate {}
        final class Payload {}
        let session = ARSession(), original = Delegate()
        session.delegate = original; session.delegateQueue = .main
        let native = expectation(description:"native drain"), delivered = expectation(description:"main delivery")
        let done = expectation(description:"both stacks released"), hold = DispatchSemaphore(value:0)
        defer { hold.signal() }
        var finished = false, payload: Payload? = Payload()
        weak var released = payload
        let controller = try SeatedMeshDiagnosticController(session:session, expectedDelegate:original) { finished = true; done.fulfill() }
        controller.onNativeDrainForTesting = { native.fulfill() }
        controller.enqueueSyntheticDisplayWorkForTesting(work: {}, afterEnqueue: { [payload] in
            withExtendedLifetime(payload) { hold.wait() }
        }, delivered: { delivered.fulfill() })
        payload = nil
        await fulfillment(of:[delivered],timeout:10)
        controller.stop()
        await fulfillment(of:[native],timeout:10)
        XCTAssertFalse(finished); XCTAssertNotNil(released); XCTAssertNil(session.configuration)
        hold.signal()
        await fulfillment(of:[done],timeout:10)
        XCTAssertTrue(finished); XCTAssertNil(released)
    }

    @MainActor func testDeclaredFootUsesActualStrictQueryAndHistoricalDisplayWithoutFrameRebinding() async throws {
        let backend = try SeatedCandidateFixtureBackend()
        let controller = SeatedMeshDiagnosticController(testBackend: backend, clock: { backend.now })
        addTeardownBlock {
            let drained = XCTestExpectation(description: "seated native teardown drained")
            await MainActor.run { controller.stop(); backend.stopAndDrain { drained.fulfill() } }
            await self.fulfillment(of: [drained], timeout: 10)
        }
        try controller.activate()
        await fulfillment(of: [XCTNSPredicateExpectation(predicate: NSPredicate { _,_ in controller.scene != nil }, object: nil)], timeout: 10)
        XCTAssertNotNil(controller.scene)
        let resultReady = expectation(description: "actual strict query held")
        backend.onHeld = { resultReady.fulfill() }
        controller.requestPreview(startText: "ignored",goalText: "1 0 0",radiusText: "0.3",heightText: "1.7",
            declaredMountText: "0 1.2 0",declaredYawText: "0",confirmed: true)
        await fulfillment(of: [resultReady],timeout: 10)
        let submitted = try XCTUnwrap(backend.submittedStart)
        let captured = try XCTUnwrap(backend.submittedCapture)
        XCTAssertEqual(submitted[0],0); XCTAssertEqual(submitted[1],0,accuracy: 1e-6); XCTAssertEqual(submitted[2],0)
        XCTAssertNotNil(backend.submittedSource)
        let result = try XCTUnwrap(backend.heldResult).get()
        XCTAssertEqual(result.route.endpointPolicy,.requireSuppliedXZOverPolygon)
        XCTAssertEqual(result.route.endpointAdmission?.start.requested,submitted)
        XCTAssertFalse(result.physicalAuthority); XCTAssertFalse(result.route.authorizesPhysicalGuidance)
        backend.now = 10.1
        backend.ordinaryFrame() // Latest capture changes, but held request remains exact.
        XCTAssertTrue(backend.isCurrent(captured))
        backend.release()
        await fulfillment(of: [XCTNSPredicateExpectation(predicate: NSPredicate { _,_ in
            controller.scene?.rootNode.childNode(withName: "diagnostic-route",recursively: false) != nil
        },object: nil)],timeout: 10)
        let marker = try XCTUnwrap(controller.scene?.rootNode.childNode(withName: "diagnostic-foot-candidate",recursively: false))
        XCTAssertEqual(marker.position.x,submitted[0]); XCTAssertEqual(marker.position.y,submitted[1]); XCTAssertEqual(marker.position.z,submitted[2])
        let expectedDelta = Double(result.route.projectedStart[1]) - Double(submitted[1])
        XCTAssertTrue(controller.footReceipt.contains("delta Y \(expectedDelta)m"))
        XCTAssertTrue(controller.footReceipt.contains(captured.frame.uuidString))
        XCTAssertTrue(controller.footReceipt.contains("Historical preview lease"))
        XCTAssertTrue(controller.sourceReceipt.contains("revision \(result.route.revision)"))
        controller.retirePreview() // Same path invoked by mount/heading edits.
        XCTAssertNil(controller.scene?.rootNode.childNode(withName: "diagnostic-route",recursively: false))
        XCTAssertNil(controller.scene?.rootNode.childNode(withName: "diagnostic-foot-candidate",recursively: false))
    }

    @MainActor func testHeldControllerResultCannotPublishAfterExplicitReplacementOrSourceChange() async throws {
        for retireSource in [false,true] {
            let backend = try SeatedCandidateFixtureBackend()
            let controller = SeatedMeshDiagnosticController(testBackend: backend,clock: { backend.now })
            addTeardownBlock {
                let drained = XCTestExpectation(description: "seated rejection teardown drained")
                await MainActor.run { controller.stop(); backend.stopAndDrain { drained.fulfill() } }
                await self.fulfillment(of: [drained], timeout: 10)
            }
            try controller.activate()
            await fulfillment(of: [XCTNSPredicateExpectation(predicate: NSPredicate { _,_ in controller.scene != nil },object: nil)],timeout: 10)
            let ready = expectation(description: "held real native result")
            backend.onHeld = { ready.fulfill() }
            controller.requestPreview(startText: "",goalText: "1 0 0",radiusText: "0.3",heightText: "1.7",
                declaredMountText: "0 1.2 0",declaredYawText: "0",confirmed: true)
            await fulfillment(of: [ready],timeout: 10)
            _ = try XCTUnwrap(backend.heldResult).get() // A native refusal is not a passing retirement test.
            if retireSource { backend.changeGeometry() }
            else { _ = backend.freezeCameraCapture() } // Explicit request replacement within same frame.
            backend.release()
            XCTAssertTrue(controller.routeReceipt.hasPrefix("WITHHELD"))
            XCTAssertNil(controller.scene?.rootNode.childNode(withName: "diagnostic-route",recursively: false))
            XCTAssertNil(controller.scene?.rootNode.childNode(withName: "diagnostic-foot-candidate",recursively: false))
            controller.stop(); XCTAssertNil(controller.scene)
            let drained = expectation(description: "rejection iteration native drain")
            backend.stopAndDrain { drained.fulfill() }
            await fulfillment(of: [drained], timeout: 10)
        }
    }

}

/// Copied synthetic frame scalars + an actual owned classified floor packet.
/// No ARFrame/ARSession activation, forged route/snapshot, validator or guidance.
private final class SeatedCandidateFixtureBackend: SeatedMeshDiagnosticBackend {
    private let ingress: LiveMeshBenchIngress
    private let snapshots = MeshBenchCameraSnapshot()
    private let sessionID = UUID(), anchorID = UUID()
    private var active = true
    var now = 10.0
    var state: LiveMeshBenchSession.State { active ? .capturing : .stopped(restored: false) }
    var hasCurrentTrackedSession: Bool { active }
    var submittedStart: [Float]?
    var submittedCapture: LiveMeshBenchSession.CameraCapture?
    var submittedSource: MeshCandidateIngress83.SourceSnapshot?
    var heldResult: Result<MeshCandidateIngress83.Candidate,MeshCandidateIngress83.Failure>?
    var onHeld: (() -> Void)?
    private var heldCompletion: ((Result<MeshCandidateIngress83.Candidate,MeshCandidateIngress83.Failure>) -> Void)?
    init() throws {
        let decode = DispatchQueue(label: "seated.candidate.fixture.decode")
        ingress = try LiveMeshBenchIngress(decodeQueue: decode)
        let values: [Float] = [-3,0,-3,-3,0,3,3,0,3,3,0,-3]
        let bytes = values.flatMap { value in (0..<4).map { UInt8(truncatingIfNeeded: value.bitPattern >> ($0*8)) } }
        let indices: [UInt8] = [0,0,1,0,2,0,0,0,2,0,3,0]
        let id = anchorID
        let accepted = ingress.observe(anchorID: id,generation: ingress.generation,receiptUptime: now) { context in
            do {
                let plan = try MeshSnapshot82.preflight(context: context,
                    vertices: .init(count: 4,offset: 0,stride: 12,bufferLength: bytes.count,format: .float3),
                    indices: .init(count: 6,offset: 0,stride: 2,bufferLength: indices.count,format: .uint16),
                    classification: .init(count: 2,offset: 0,stride: 1,bufferLength: 2,format: .uint8))
                return .owned(.init(context: context,anchorID: id,plan: plan,vertexBytes: bytes,indexBytes: indices,
                    classificationBytes: [2,2],transform: [1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1]))
            } catch { return .unknownGap(.init(context: context,anchorID: id,reason: .invalidDescriptor)) }
        }
        guard accepted else { throw LiveMeshBenchSession.Failure.unavailable }
        decode.sync {}
        ordinaryFrame()
    }
    func ordinaryFrame() {
        snapshots.observe(.init(session: sessionID,frame: UUID(),capturedAt: now,
            columnMajorCameraToWorld: [1,0,0,0,0,1,0,0,0,0,1,0,0,Double(Float(1.2)),0,1]))
    }
    func activateForSeatedBench() throws {}
    func stop() { active = false; snapshots.retire(); ingress.stop() }
    func stopAndDrain(_ completion: @escaping () -> Void) {
        stop(); heldCompletion = nil; heldResult = nil; onHeld = nil
        ingress.stopAndDiscard(completion: completion)
    }
    func reacquireTrackedFrameAnchors() { snapshots.retire() }
    func requestStatus(completion: @escaping (String) -> Void) { completion("Synthetic owned geometry; no device capture") }
    func requestSourceSnapshot(completion: @escaping (Result<MeshCandidateIngress83.SourceSnapshot,MeshCandidateIngress83.SourceSnapshotFailure>) -> Void) {
        ingress.requestSourceSnapshot(generation: ingress.generation) { result in DispatchQueue.main.async { completion(result) } }
    }
    func isCurrent(_ source: MeshCandidateIngress83.SourceSnapshot) -> Bool { active && ingress.isCurrent(source,generation: ingress.generation) }
    func isCurrent(_ candidate: MeshCandidateIngress83.Candidate) -> Bool { active && ingress.isCurrent(candidate,generation: ingress.generation) }
    func isCurrent(_ capture: LiveMeshBenchSession.CameraCapture) -> Bool { active && snapshots.isCurrent(capture,at: now) }
    func freezeCameraCapture() -> LiveMeshBenchSession.CameraCapture? { snapshots.freeze(at: now) }
    func retireCameraCapture() { snapshots.retire() }
    func changeGeometry() { _ = ingress.remove(anchorID: anchorID,generation: ingress.generation,receiptUptime: now+0.01) }
    func requestPreview(start: [Float],goal: [Float],body: MeshCandidateBody,
                        capture: LiveMeshBenchSession.CameraCapture?,expectedSource: MeshCandidateIngress83.SourceSnapshot?,
                        completion: @escaping (Result<MeshCandidateIngress83.Candidate,MeshCandidateIngress83.Failure>) -> Void) {
        guard let capture, snapshots.canAdmit(capture,at: now), expectedSource != nil else { completion(.failure(.stale)); return }
        submittedStart = start; submittedCapture = capture; submittedSource = expectedSource
        ingress.request(generation: ingress.generation,start: start,goal: goal,body: body,expectedSource: expectedSource) { [weak self] result in
            DispatchQueue.main.async {
                self?.heldResult = result; self?.heldCompletion = completion; self?.onHeld?()
            }
        }
    }
    func release() {
        guard let heldResult, let completion = heldCompletion else { return }
        heldCompletion = nil; completion(heldResult)
    }
}
#endif
