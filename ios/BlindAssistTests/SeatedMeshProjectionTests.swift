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
        let ownerDrained=expectation(description:"seated controller ownership drained")
        let controller = SeatedMeshDiagnosticController(testBackend: backend, clock: { backend.now },onStopped:{ownerDrained.fulfill()})
        addTeardownBlock {
            let drained = XCTestExpectation(description: "seated native teardown drained")
            await MainActor.run { controller.stop(); backend.stopAndDrain {
                    DispatchQueue.main.async {controller.acknowledgeTestBackendNativeDrainForTesting();drained.fulfill()}
                } }
            await self.fulfillment(of: [drained,ownerDrained], timeout: 10)
        }
        controller.sourcePhaseRecorderForTesting = { [weak backend] in backend?.sourcePhaseRecorder() }
        try controller.activate()
        await fulfillment(of: [XCTNSPredicateExpectation(predicate: NSPredicate { _,_ in controller.scene != nil }, object: nil)], timeout: 10)
        backend.printTiming(event: "happy_wait_finished")
        _ = try XCTUnwrap(controller.scene, "No admitted source scene; do not submit a query after source failure")
        let resultReady = expectation(description: "actual strict query held")
        backend.onHeld = { resultReady.fulfill() }
        controller.requestPreview(startText: "ignored",goalText: "1 0 0",radiusText: "0.3",heightText: "1.7",
            declaredMountText: "0 1.2 0",declaredYawText: "0",confirmed: true,marginText:"0.1")
        await fulfillment(of: [resultReady],timeout: 10)
        backend.printTiming(event: "happy_wait_finished")
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
        await fulfillment(of:[XCTNSPredicateExpectation(predicate:NSPredicate {_,_ in controller.collisionAudit != nil},object:nil)],timeout:10)
        let audit=try XCTUnwrap(controller.collisionAudit)
        XCTAssertFalse(audit.physicalAuthority)
        XCTAssertFalse(audit.raw.isEmpty);XCTAssertEqual(audit.raw.count,audit.margin.count)
        XCTAssertEqual(audit.revision,result.route.revision)
        XCTAssertEqual(audit.session,result.route.sessionID);XCTAssertEqual(audit.generation,result.route.generation)
        XCTAssertEqual(audit.request.start,submitted);XCTAssertEqual(audit.request.goal,result.route.endpointAdmission?.goal.requested)
        let details=audit.detailLines.joined(separator:"\n")
        for label in ["raw:","margin:"," initial:"," swept:"," terminal:","showing first","full bounded receipt retained"] {
            XCTAssertTrue(details.contains(label),"Missing retained receipt presentation: \(label)")
        }
        XCTAssertTrue(controller.collisionReceipt.contains("NOT clear space"))
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
            let ownerDrained=expectation(description:"seated rejection controller ownership drained")
            var stopped=false
            let controller = SeatedMeshDiagnosticController(testBackend: backend,clock: { backend.now },onStopped:{stopped=true;ownerDrained.fulfill()})
            addTeardownBlock {
                let drained = XCTestExpectation(description: "seated rejection teardown drained")
                await MainActor.run { controller.stop(); backend.stopAndDrain {
                    DispatchQueue.main.async {controller.acknowledgeTestBackendNativeDrainForTesting();drained.fulfill()}
                } }
                await self.fulfillment(of: [drained,ownerDrained], timeout: 10)
            }
            controller.sourcePhaseRecorderForTesting = { [weak backend] in backend?.sourcePhaseRecorder() }
            try controller.activate()
            await fulfillment(of: [XCTNSPredicateExpectation(predicate: NSPredicate { _,_ in controller.scene != nil },object: nil)],timeout: 10)
            backend.printTiming(event: "rejection_wait_finished")
            _ = try XCTUnwrap(controller.scene, "No admitted source scene; do not submit a query after source failure")
            let ready = expectation(description: "held real native result")
            backend.onHeld = { ready.fulfill() }
            controller.requestPreview(startText: "",goalText: "1 0 0",radiusText: "0.3",heightText: "1.7",
                declaredMountText: "0 1.2 0",declaredYawText: "0",confirmed: true,marginText:"0.1")
            await fulfillment(of: [ready],timeout: 10)
            backend.printTiming(event: "rejection_wait_finished")
            _ = try XCTUnwrap(backend.heldResult).get() // A native refusal is not a passing retirement test.
            if retireSource { backend.changeGeometry() }
            else { _ = backend.freezeCameraCapture() } // Explicit request replacement within same frame.
            backend.release()
            XCTAssertTrue(controller.routeReceipt.hasPrefix("WITHHELD"))
            XCTAssertNil(controller.scene?.rootNode.childNode(withName: "diagnostic-route",recursively: false))
            XCTAssertNil(controller.scene?.rootNode.childNode(withName: "diagnostic-foot-candidate",recursively: false))
            controller.stop(); XCTAssertNil(controller.scene)
            let drained = expectation(description: "rejection iteration native drain")
            backend.stopAndDrain { DispatchQueue.main.async {controller.acknowledgeTestBackendNativeDrainForTesting();drained.fulfill()} }
            await fulfillment(of: [drained,XCTNSPredicateExpectation(predicate:NSPredicate {_,_ in stopped},object:nil)], timeout: 10)
        }
    }

    @MainActor func testActualSourceAndStrictQueryCompleteWhileOptionalRenderIsHeld() async throws {
        let backend=try SeatedCandidateFixtureBackend()
        let ownerDone=expectation(description:"held-render controller ownership drained")
        var stopped=false
        let controller=SeatedMeshDiagnosticController(testBackend:backend,clock:{backend.now},onStopped:{stopped=true;ownerDone.fulfill()})
        let hold=DispatchSemaphore(value:0)
        defer {hold.signal()}
        addTeardownBlock {
            await MainActor.run {controller.stop();backend.stopAndDrain {
                DispatchQueue.main.async {controller.acknowledgeTestBackendNativeDrainForTesting()}
            }}
            await self.fulfillment(of:[ownerDone],timeout:10)
            await MainActor.run {backend.printTiming(event:"drain_complete")}
        }
        controller.sourcePhaseRecorderForTesting = { [weak backend] in backend?.sourcePhaseRecorder() }
        let entered=expectation(description:"optional render worker held")
        controller.enqueueSyntheticDisplayWorkForTesting(work:{entered.fulfill()},afterEnqueue:{hold.wait()},delivered:{})
        try controller.activate()
        await fulfillment(of:[entered,XCTNSPredicateExpectation(predicate:NSPredicate {_,_ in controller.hasCurrentSourceForTesting},object:nil)],timeout:10)
        backend.printTiming(event:"happy_wait_finished")
        guard controller.hasCurrentSourceForTesting else {XCTFail("No admitted source; no query attempted");return}
        XCTAssertTrue(controller.hasPendingRenderForTesting);XCTAssertNil(controller.scene)
        let ready=expectation(description:"real strict query while render held")
        backend.onHeld={ready.fulfill()}
        controller.requestPreview(startText:"",goalText:"1 0 0",radiusText:"0.3",heightText:"1.7",
            declaredMountText:"0 1.2 0",declaredYawText:"0",confirmed:true,marginText:"0.1")
        await fulfillment(of:[ready],timeout:10)
        backend.printTiming(event:"happy_wait_finished")
        let result=try XCTUnwrap(backend.heldResult).get()
        XCTAssertEqual(result.route.endpointPolicy,.requireSuppliedXZOverPolygon)
        XCTAssertEqual(result.route.endpointAdmission?.start.requested,backend.submittedStart)
        XCTAssertFalse(result.physicalAuthority)
        backend.release()
        await fulfillment(of:[XCTNSPredicateExpectation(predicate:NSPredicate {_,_ in
            controller.routeReceipt.hasPrefix("AVAILABLE SOURCE-ONLY DIAGNOSTIC") && controller.hasCurrentSourceForTesting
        },object:nil)],timeout:10)
        XCTAssertTrue(controller.sourceReceipt.contains("revision \(result.route.revision)"))
        XCTAssertFalse(controller.routePointReceipts.isEmpty)
        XCTAssertTrue(controller.footReceipt.contains("Native associated start"))
        await fulfillment(of:[XCTNSPredicateExpectation(predicate:NSPredicate {_,_ in controller.collisionAudit != nil},object:nil)],timeout:10)
        XCTAssertFalse(try XCTUnwrap(controller.collisionAudit).physicalAuthority)
        XCTAssertNil(controller.scene);XCTAssertTrue(controller.hasPendingRenderForTesting)
        controller.stop()
        let nativeDone=expectation(description:"actual native drain while renderer held")
        backend.stopAndDrain {DispatchQueue.main.async {controller.acknowledgeTestBackendNativeDrainForTesting();nativeDone.fulfill()}}
        await fulfillment(of:[nativeDone],timeout:10)
        XCTAssertFalse(stopped,"Native drain alone cannot release exclusive ownership")
        hold.signal()
        await fulfillment(of:[XCTNSPredicateExpectation(predicate:NSPredicate {_,_ in stopped},object:nil)],timeout:10)
        XCTAssertTrue(stopped);XCTAssertFalse(controller.hasPendingRenderForTesting)
    }

    @MainActor func testActualAuditRetirementAndDisposalAfterRealOracleProgress() async throws {
        for retirement in ["source","capture","edit","stop"] {
            let backend=try SeatedCandidateFixtureBackend(),gate=SeatedAuditProgressGate()
            let ownerDone=expectation(description:"audit owner drained \(retirement)")
            var stopped=false,progressed=false
            let controller=SeatedMeshDiagnosticController(testBackend:backend,clock:{backend.now},onStopped:{stopped=true;ownerDone.fulfill()})
            let renderHold=DispatchSemaphore(value:0)
            defer {renderHold.signal();gate.release()}
            addTeardownBlock {
                await MainActor.run {
                    gate.release();renderHold.signal();controller.stop()
                    backend.stopAndDrain {DispatchQueue.main.async {controller.acknowledgeTestBackendNativeDrainForTesting()}}
                }
                await self.fulfillment(of:[ownerDone],timeout:10)
            }
            controller.sourcePhaseRecorderForTesting = { [weak backend] in backend?.sourcePhaseRecorder() }
            controller.enqueueSyntheticDisplayWorkForTesting(work:{},afterEnqueue:{renderHold.wait()},delivered:{})
            let actualProgress=expectation(description:"real oracle raw sweep completed \(retirement)")
            let auditDone=expectation(description:"audit copies disposed \(retirement)")
            controller.onCollisionDrainedForTesting={auditDone.fulfill()}
            controller.collisionProgressForTesting={progress in
                if !progressed {
                    XCTAssertEqual(progress.envelope,"raw");progressed=true;actualProgress.fulfill()
                    await gate.wait()
                }
            }
            try controller.activate()
            await fulfillment(of:[XCTNSPredicateExpectation(predicate:NSPredicate {_,_ in controller.hasCurrentSourceForTesting},object:nil)],timeout:10)
            guard controller.hasCurrentSourceForTesting else {XCTFail("No admitted source");return}
            let nativeReady=expectation(description:"real native candidate \(retirement)")
            backend.onHeld={nativeReady.fulfill()}
            controller.requestPreview(startText:"",goalText:"1 0 0",radiusText:"0.3",heightText:"1.7",
                declaredMountText:"0 1.2 0",declaredYawText:"0",confirmed:true,marginText:"0.1")
            await fulfillment(of:[nativeReady],timeout:10)
            _=try XCTUnwrap(backend.heldResult).get()
            backend.release()
            await fulfillment(of:[actualProgress],timeout:10)
            guard progressed else {XCTFail("Oracle progress unavailable; not a passing retirement test");return}
            XCTAssertTrue(controller.hasPendingCollisionForTesting);XCTAssertNil(controller.collisionAudit)
            switch retirement {
            case "source":backend.changeGeometry()
            case "capture":_ = backend.freezeCameraCapture()
            case "edit":controller.retirePreview()
            default:controller.stop()
            }
            if retirement == "stop" {
                let nativeDone=expectation(description:"native before held audit")
                backend.stopAndDrain {DispatchQueue.main.async {controller.acknowledgeTestBackendNativeDrainForTesting();nativeDone.fulfill()}}
                await fulfillment(of:[nativeDone],timeout:10)
                XCTAssertFalse(stopped,"Held audit/render still own data")
            }
            gate.release()
            await fulfillment(of:[auditDone],timeout:10)
            XCTAssertFalse(controller.hasPendingCollisionForTesting)
            XCTAssertNil(controller.collisionAudit,"Retired audit must never publish its partial contact receipt")
            if retirement != "stop" {
                controller.stop()
                let nativeDone=expectation(description:"native after retired audit")
                backend.stopAndDrain {DispatchQueue.main.async {controller.acknowledgeTestBackendNativeDrainForTesting();nativeDone.fulfill()}}
                await fulfillment(of:[nativeDone],timeout:10)
            }
            XCTAssertFalse(stopped,"Renderer must drain too, not only native and collision tasks")
            renderHold.signal()
            await fulfillment(of:[XCTNSPredicateExpectation(predicate:NSPredicate {_,_ in stopped},object:nil)],timeout:10)
            XCTAssertTrue(stopped)
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
    private let timingLock = NSLock()
    private var submittedAt: Double?, nativeCompletedAt: Double?, mainHeldAt: Double?
    private let sourceTiming=SeatedSourceTimingRecorder()
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
        ingress = try LiveMeshBenchIngress(captureSyntheticTestTiming: true,
            syntheticTimingCompletion: { id, rows in Self.printWorkerTiming(id: id, rows) }, decodeQueue: decode)
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
    func stop() {
        active=false;snapshots.retire();ingress.stop()
        let retired=heldCompletion;heldCompletion=nil;heldResult=nil
        retired?(.failure(.stale)) // Same stopped-owner refusal as production, never a fabricated route.
    }
    func stopAndDrain(_ completion: @escaping () -> Void) {
        stop(); heldCompletion = nil; heldResult = nil; onHeld = nil
        ingress.stopAndDiscard { [self] in
            printTiming(event: "drain_complete")
            completion()
        }
    }
    func reacquireTrackedFrameAnchors() { snapshots.retire() }
    func requestStatus(completion: @escaping (String) -> Void) { completion("Synthetic owned geometry; no device capture") }
    func requestSourceSnapshot(completion: @escaping (Result<MeshCandidateIngress83.SourceSnapshot,MeshCandidateIngress83.SourceSnapshotFailure>) -> Void) {
        let timing=sourceTiming,context=sourceTiming.begin()
        timing.record("source_requested",context:context)
        ingress.requestSourceSnapshot(generation: ingress.generation) { result in
            let outcome: String
            switch result {
            case .success: outcome = "success"
            case .failure(.unavailable): outcome = "unavailable"
            case .failure(.stale): outcome = "stale"
            case .failure(.runtime(let failure)):
                switch failure {
                case .invalidLimits: outcome = "runtime_invalidLimits"
                case .budget: outcome = "runtime_budget"
                case .unavailable: outcome = "runtime_unavailable"
                case .stale: outcome = "runtime_stale"
                case .invalidRetainedState: outcome = "runtime_invalidRetainedState"
                }
            }
            timing.record("source_native_callback",context:context,outcome:outcome)
            DispatchQueue.main.async {
                timing.record("source_main_callback",context:context,outcome:outcome)
                completion(result)
            }
        }
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
        timingLock.lock(); submittedAt = ProcessInfo.processInfo.systemUptime; nativeCompletedAt = nil; mainHeldAt = nil; timingLock.unlock()
        ingress.request(generation: ingress.generation,start: start,goal: goal,body: body,expectedSource: expectedSource) { [weak self] result in
            if let self {
                self.timingLock.lock(); self.nativeCompletedAt = ProcessInfo.processInfo.systemUptime; self.timingLock.unlock()
            }
            DispatchQueue.main.async {
                guard let self,self.active else {completion(.failure(.stale));return}
                self.timingLock.lock(); self.mainHeldAt = ProcessInfo.processInfo.systemUptime; self.timingLock.unlock()
                self.heldResult = result; self.heldCompletion = completion; self.onHeld?()
            }
        }
    }
    func sourcePhaseRecorder() -> ((SeatedMeshDiagnosticController.SourcePhaseForTesting)->Void)? {
        let timing=sourceTiming
        guard let context=timing.latest else {return nil}
        return {phase in timing.record(phase.rawValue,context:context)}
    }
    func printSourceTiming() {sourceTiming.printRecords(id:ingress.diagnosticReceiptID?.uuidString ?? "none")}
    /// Called after XCTest's bounded wait or drain, never in native completion's
    /// critical path. Missing stages remain -1, not invented zero-time successes.
    func printTiming(event: String) {
        printSourceTiming()
        timingLock.lock()
        let submitted = submittedAt, native = nativeCompletedAt, main = mainHeldAt
        timingLock.unlock()
        let now = ProcessInfo.processInfo.systemUptime
        func elapsed(_ time: Double?) -> Int {
            guard let submitted, let time, time >= submitted else { return -1 }
            return Int((time-submitted)*1000)
        }
        let stages = ingress.diagnosticStageReceipts.map { "\($0.stage.rawValue):\($0.elapsedMilliseconds)" }.joined(separator: ";")
        print("SEATED_CANDIDATE_PHASE id=\(ingress.diagnosticReceiptID?.uuidString ?? "none") event=\(event) elapsed_ms=\(elapsed(now)) native_callback_ms=\(elapsed(native)) main_held_ms=\(elapsed(main)) stages=\(stages)")
    }
    private static func printWorkerTiming(id: UUID, _ rows: [RoomMeshCandidateRuntime.DiagnosticStageReceipt]) {
        func pair(_ begin: RoomMeshCandidateRuntime.DiagnosticStage, _ end: RoomMeshCandidateRuntime.DiagnosticStage) -> (Int,Int64,Bool) {
            guard let a = rows.first(where: { $0.stage == begin }), let b = rows.first(where: { $0.stage == end }),
                  b.elapsedMilliseconds >= a.elapsedMilliseconds else { return (-1,-1,false) }
            let wall = b.elapsedMilliseconds-a.elapsedMilliseconds
            guard let at = a.workerThreadID, let bt = b.workerThreadID, at == bt,
                  let ac = a.workerCPUTimeMicroseconds, let bc = b.workerCPUTimeMicroseconds, bc >= ac else { return (wall,-1,false) }
            return (wall,bc-ac,true)
        }
        let worker = pair(.workerStarted,.workerFinished), build = pair(.nativeBuildBegin,.nativeBuildEnd), route = pair(.routeBegin,.routeEnd)
        let workerBegin = rows.first(where: { $0.stage == .workerStarted })?.elapsedMilliseconds ?? -1
        print("SEATED_CANDIDATE_WORKER id=\(id.uuidString) worker_begin_ms=\(workerBegin) worker_wall_ms=\(worker.0) worker_cpu_us=\(worker.1) worker_pair_valid=\(worker.2) build_wall_ms=\(build.0) build_cpu_us=\(build.1) build_pair_valid=\(build.2) route_wall_ms=\(route.0) route_cpu_us=\(route.1) route_pair_valid=\(route.2) records=\(rows.count)")
    }
    func release() {
        guard let heldResult, let completion = heldCompletion else { return }
        heldCompletion = nil; completion(heldResult)
    }
}
/// Only scalar metadata is retained by render callbacks, never the native owner.
private final class SeatedSourceTimingRecorder {
    struct Context {let request:Int;let started:Double}
    private let lock=NSLock()
    private var current:Context?
    private var count=0
    private var rows:[(Int,String,Int,Bool,String)]=[]
    var latest:Context? {lock.lock();defer{lock.unlock()};return current}
    func begin()->Context {
        lock.lock();defer{lock.unlock()}
        let next=Context(request:(current?.request ?? 0)+1,started:ProcessInfo.processInfo.systemUptime)
        current=next;return next
    }
    func record(_ event:String,context:Context,outcome:String="none") {
        let now=ProcessInfo.processInfo.systemUptime,main=Thread.isMainThread
        lock.lock();defer{lock.unlock()}
        guard count<64,context.request>0,context.request<=64 else{return}
        let elapsed=now>=context.started ? Int((now-context.started)*1000) : -1
        rows.append((context.request,event,elapsed,main,outcome));count+=1
    }
    func printRecords(id:String) {
        lock.lock();let copy=rows;rows.removeAll(keepingCapacity:true);lock.unlock()
        for row in copy {print("SEATED_CANDIDATE_SOURCE id=\(id) request=\(row.0) event=\(row.1) elapsed_ms=\(row.2) main_thread=\(row.3) outcome=\(row.4)")}
    }
}
@MainActor private final class SeatedAuditProgressGate {
    private var released=false
    private var waiter:CheckedContinuation<Void,Never>?
    func wait() async {
        if released {return}
        await withCheckedContinuation {continuation in waiter=continuation}
    }
    func release() {released=true;let current=waiter;waiter=nil;current?.resume()}
}
#endif
