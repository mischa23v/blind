#if DEBUG && BLIND_MESH_CANDIDATE_DIAGNOSTICS
import XCTest
import CryptoKit
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
        let ownerDrained=XCTestExpectation(description:"seated controller ownership drained")
        ownerDrained.assertForOverFulfill=true // Cleanup owns its sole wait, after the test method exits.
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
            let ownerDrained=XCTestExpectation(description:"seated rejection controller ownership drained")
            ownerDrained.assertForOverFulfill=true // Cleanup owns its sole wait, after the test method exits.
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
        let ownerDone=XCTestExpectation(description:"held-render controller ownership drained")
        ownerDone.assertForOverFulfill=true // Cleanup owns its sole wait, after the test method exits.
        var stopped=false
        let controller=SeatedMeshDiagnosticController(testBackend:backend,clock:{backend.now},onStopped:{stopped=true;ownerDone.fulfill()})
        let hold=DispatchSemaphore(value:0)
        defer {hold.signal()}
        addTeardownBlock {
            await MainActor.run {controller.stop();backend.stopAndDrain {
                DispatchQueue.main.async {controller.acknowledgeTestBackendNativeDrainForTesting()}
            }}
            await self.fulfillment(of:[ownerDone],timeout:10)
            await MainActor.run {backend.printTiming(event:"controller_drain_wait_finished")}
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
            let ownerDone=XCTestExpectation(description:"audit owner drained \(retirement)")
            ownerDone.assertForOverFulfill=true // Cleanup owns its sole wait, after the test method exits.
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
            try controller.activate()
            await fulfillment(of:[XCTNSPredicateExpectation(predicate:NSPredicate {_,_ in controller.hasCurrentSourceForTesting},object:nil)],timeout:10)
            guard controller.hasCurrentSourceForTesting else {XCTFail("No admitted source");return}
            let nativeReady=expectation(description:"real native candidate \(retirement)")
            backend.onHeld={nativeReady.fulfill()}
            controller.requestPreview(startText:"",goalText:"1 0 0",radiusText:"0.3",heightText:"1.7",
                declaredMountText:"0 1.2 0",declaredYawText:"0",confirmed:true,marginText:"0.1")
            await fulfillment(of:[nativeReady],timeout:10)
            _=try XCTUnwrap(backend.heldResult).get()
            let actualProgress=expectation(description:"real oracle raw sweep completed \(retirement)")
            let auditDone=XCTestExpectation(description:"audit copies disposed \(retirement)")
            auditDone.assertForOverFulfill=true
            controller.onCollisionDrainedForTesting={auditDone.fulfill()}
            controller.collisionProgressForTesting={progress in
                if !progressed {
                    XCTAssertEqual(progress.envelope,"raw");progressed=true;actualProgress.fulfill()
                    await gate.wait()
                }
            }
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

    @MainActor func testMappedDestinationFeedsActualStrictQueryAndCollisionReceipt() async throws {
        let frame=SeatedMappedFixture.frame(),io=SeatedMappedIO()
        let installation=try SeatedMappedFixture.installation(frame:frame)
        let runtime=try await SeatedMappedFixture.runtime(installation,io:io)
        let destination=try XCTUnwrap(runtime.diagnosticDestination)
        let backend=try SeatedCandidateFixtureBackend(savedFrame:frame)
        let (controller,finish)=mappedController(backend,destinationProvider:{runtime.diagnosticDestination})
        try controller.activate();try await requireMappedSource(controller)
        let ready=expectation(description:"actual mapped-goal native query")
        backend.onHeld={ready.fulfill()}
        requestMappedPreview(controller)
        await fulfillment(of:[ready],timeout:10)
        let candidate=try XCTUnwrap(backend.heldResult).get()
        XCTAssertEqual(backend.submittedGoal,[1,0,0]) // Manual goal below is deliberately different.
        XCTAssertEqual(candidate.route.endpointAdmission?.goal.requested,[1,0,0])
        backend.now=10.1;backend.ordinaryFrame() // Do not rebind the frozen capture.
        backend.release()
        await fulfillment(of:[XCTNSPredicateExpectation(predicate:NSPredicate {_,_ in controller.collisionAudit != nil},object:nil)],timeout:10)
        let audit=try XCTUnwrap(controller.collisionAudit),binding=try XCTUnwrap(audit.request.mappedGoal)
        XCTAssertEqual(binding.destination,destination)
        XCTAssertEqual(binding.sourceSession,backend.submittedSource?.geometry.sessionID)
        XCTAssertEqual(binding.sourceGeneration,backend.submittedSource?.geometry.generation)
        XCTAssertEqual(binding.sourceRevision,backend.submittedSource?.geometry.revision)
        XCTAssertEqual(binding.cameraFrame,backend.submittedCapture?.frame)
        XCTAssertEqual(binding.cameraRequest,backend.submittedCapture?.snapshot)
        XCTAssertEqual(binding.association.capturedAt,10)
        XCTAssertEqual(audit.session,candidate.route.sessionID);XCTAssertEqual(audit.revision,candidate.route.revision)
        XCTAssertEqual(audit.request.goal,backend.submittedGoal)
        XCTAssertFalse(audit.raw.isEmpty);XCTAssertEqual(audit.raw.count,audit.margin.count)
        XCTAssertFalse(audit.physicalAuthority);XCTAssertFalse(binding.association.permitsPhysicalGuidance)
        XCTAssertTrue(controller.hierarchyReceipt.contains("SELECTED DESTINATION context"))
        XCTAssertTrue(controller.hierarchyReceipt.contains("Current room/floor/body/support NOT established"))
        XCTAssertNil(runtime.diagnosticOwnedRoute) // No physical route was issued by catalog lookup.
        try await finish()
    }

    @MainActor func testMappedDestinationRefusesMissingWrongStaleAndCrossFloorAssociation() async throws {
        // Paired hashes alone cannot turn a corrupt archive into an ARWorldMap.
        // Small synthetic bytes only; no capture/archive fixture is read or uploaded.
        let invalid=Data([1,2,3,4]),digest=SHA256.hash(data:Data([1,2,3,4])).map{String(format:"%02x",$0)}.joined()
        let descriptor=SavedWorldFrame(placeID:UUID().uuidString,revision:UUID().uuidString,
            worldMapSHA256:digest,roomCaptureSHA256:digest,originAnchorID:UUID().uuidString,capturedAt:Date(timeIntervalSince1970:1))
        XCTAssertThrowsError(try LiveMeshBenchSession.SavedWorldSeed.decode(world:invalid,room:invalid,frame:descriptor))
        XCTAssertThrowsError(try LiveMeshBenchSession.SavedWorldSeed.decode(world:Data(),room:invalid,frame:descriptor))
        XCTAssertThrowsError(try LiveMeshBenchSession.SavedWorldSeed.decode(world:invalid,room:invalid,frame:SeatedMappedFixture.frame()))
        for reason in ["missing","wrong-frame","reset","stale-frame","floors","floor-transition"] {
            let frame=SeatedMappedFixture.frame(),io=SeatedMappedIO()
            let installation=try SeatedMappedFixture.installation(frame:frame,twoFloors:reason == "floors",upperFloor:reason == "floor-transition")
            let runtime=try await SeatedMappedFixture.runtime(installation,io:io)
            let backend=try SeatedCandidateFixtureBackend(savedFrame:reason == "missing" ? nil : ["wrong-frame","floor-transition"].contains(reason) ? SeatedMappedFixture.frame() : frame)
            let (controller,finish)=mappedController(backend,destinationProvider:{runtime.diagnosticDestination})
            try controller.activate();try await requireMappedSource(controller)
            if reason == "reset" {backend.resetRecovery()}
            if reason == "stale-frame" {backend.now=10.6;backend.ordinaryFrame()} // Gap resets recovered epoch.
            requestMappedPreview(controller)
            XCTAssertNil(backend.submittedGoal,"Unregistered/wrong-floor targets cannot reach native admission")
            XCTAssertNotNil(controller.mappedGoalRefusal);XCTAssertNil(controller.collisionAudit)
            XCTAssertTrue(controller.routeReceipt.hasPrefix("WITHHELD"))
            if ["wrong-frame","floor-transition"].contains(reason) {XCTAssertEqual(controller.mappedGoalRefusal,.wrongFrame)}
            if reason == "floors" {XCTAssertEqual(controller.mappedGoalRefusal,.floorUnresolved)}
            if reason == "floor-transition" {XCTAssertEqual(runtime.diagnosticDestination?.reference.context.floorID,"upper")}
            try await finish()
        }
    }

    @MainActor func testMappedDestinationRetiresHeldResultsOnRestartMapGoalAndSourceChanges() async throws {
        for change in ["restart","map-reinstall","map-delete","destination","source","recovery-reset","audit-map-delete"] {
            let frame=SeatedMappedFixture.frame(),io=SeatedMappedIO()
            let installation=try SeatedMappedFixture.installation(frame:frame)
            var runtime=try await SeatedMappedFixture.runtime(installation,io:io)
            let original=try XCTUnwrap(runtime.diagnosticDestination)
            let backend=try SeatedCandidateFixtureBackend(savedFrame:frame)
            let (controller,finish)=mappedController(backend,destinationProvider:{runtime.diagnosticDestination})
            try controller.activate();try await requireMappedSource(controller)
            let ready=expectation(description:"held actual mapped native result \(change)")
            backend.onHeld={ready.fulfill()};requestMappedPreview(controller)
            await fulfillment(of:[ready],timeout:10)
            _=try XCTUnwrap(backend.heldResult).get() // Native refusal is not a passing stale-result case.
            let gate=SeatedAuditProgressGate()
            defer {gate.release()}
            if change == "audit-map-delete" {
                let progress=expectation(description:"real oracle before mapped catalog deletion")
                var didProgress=false
                controller.collisionProgressForTesting={_ in
                    if !didProgress {didProgress=true;progress.fulfill();await gate.wait()}
                }
                backend.release()
                await fulfillment(of:[progress],timeout:10)
                XCTAssertTrue(didProgress);XCTAssertTrue(controller.hasPendingCollisionForTesting)
            }
            switch change {
            case "restart":
                let restored=ConnectedJourneyRuntime(io:io,sha256:ConnectedFixture.sha256)
                restored.restore();try await restored.waitForPendingOperationsForTesting()
                let next=try XCTUnwrap(restored.diagnosticDestination)
                XCTAssertEqual(next.reference,original.reference);XCTAssertNotEqual(next.ownerID,original.ownerID)
                runtime=restored;backend.resetRecovery()
            case "map-reinstall":
                try runtime.install(installation);try await runtime.waitForPendingOperationsForTesting()
                XCTAssertNotEqual(runtime.diagnosticDestination?.catalogRevision,original.catalogRevision)
            case "map-delete","audit-map-delete":
                try runtime.withdrawMap(installation.binding);try await runtime.waitForPendingOperationsForTesting()
                XCTAssertNil(runtime.diagnosticDestination)
            case "destination":try runtime.setDestination(binding:installation.binding,nodeID:"other",origin:.trustedInterface)
            case "source":backend.changeGeometry()
            default:backend.resetRecovery()
            }
            backend.release();gate.release()
            if change == "audit-map-delete" {
                await fulfillment(of:[XCTNSPredicateExpectation(predicate:NSPredicate {_,_ in !controller.hasPendingCollisionForTesting && controller.routePointReceipts.isEmpty},object:nil)],timeout:10)
            }
            XCTAssertTrue(controller.routeReceipt.hasPrefix("WITHHELD"))
            XCTAssertNil(controller.collisionAudit);XCTAssertTrue(controller.routePointReceipts.isEmpty)
            XCTAssertNil(controller.scene?.rootNode.childNode(withName:"diagnostic-route",recursively:false))
            try await runtime.waitForPendingOperationsForTesting()
            try await finish()
        }
        try await exerciseHeldSavedWorldLoaderRetirement()
    }

    @MainActor private func exerciseHeldSavedWorldLoaderRetirement() async throws {
        for reason in ["deletion","goal","cancel"] {
            let root=FileManager.default.temporaryDirectory.appendingPathComponent("SeatedRestore-\(UUID().uuidString)")
            let directory=root.appendingPathComponent("Places")
            try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
            let frame=SeatedMappedFixture.frame(),place=SavedPlace(id:try XCTUnwrap(UUID(uuidString:frame.placeID)),name:"Synthetic restore",createdAt:frame.capturedAt,objects:[],worldFrame:frame)
            try JSONEncoder().encode(place).write(to:directory.appendingPathComponent("\(place.id).json"))
            let places=PlaceStore(directory:directory),source=try XCTUnwrap(places.diagnosticGeometrySource(for:frame))
            let runtime=try await SeatedMappedFixture.runtime(try SeatedMappedFixture.installation(frame:frame),io:SeatedMappedIO())
            let destination=try XCTUnwrap(runtime.diagnosticDestination),backend=try SeatedCandidateFixtureBackend()
            let entered=XCTestExpectation(description:"actual controller loader entered \(reason)"),ownerDone=XCTestExpectation(description:"restoration owner fully drained \(reason)")
            ownerDone.assertForOverFulfill=true
            let gate=DispatchSemaphore(value:0)
            var stopped=false,draining=false
            let request=SeatedMeshDiagnosticController.SavedWorldRequest(destination:destination,source:source,
                isCurrent:{places.ownsDiagnosticGeometrySource(source)})
            let controller=SeatedMeshDiagnosticController(testBackend:backend,clock:{backend.now},destinationProvider:{runtime.diagnosticDestination},
                savedWorldRequest:request,restoreLoader:{_ in
                    entered.fulfill();_ = gate.wait(timeout:.now()+10)
                    return .failure(LiveMeshBenchSession.Failure.unavailable) // No forged successful AR archive.
                },onStopped:{stopped=true;ownerDone.fulfill()})
            let retire: @MainActor () -> Void = {
                guard !draining else{return};draining=true;controller.stop()
                backend.stopAndDrain {DispatchQueue.main.async {controller.acknowledgeTestBackendNativeDrainForTesting()}}
            }
            addTeardownBlock {
                await MainActor.run {gate.signal();retire()}
                await self.fulfillment(of:[ownerDone],timeout:10)
                try? FileManager.default.removeItem(at:root)
            }
            try controller.activate()
            await fulfillment(of:[entered],timeout:10)
            XCTAssertTrue(controller.hasPendingRestorationForTesting);XCTAssertEqual(backend.activationCount,0)
            if reason == "deletion" {places.retireDiagnosticGeometry(for:place)}
            else if reason == "goal" {try runtime.setDestination(binding:destination.artifact.binding,nodeID:"other",origin:.trustedInterface)}
            else {
                retire()
                XCTAssertFalse(stopped,"Native stop cannot release ownership while actual loader stack is held")
            }
            gate.signal()
            await fulfillment(of:[XCTNSPredicateExpectation(predicate:NSPredicate {_,_ in !controller.hasPendingRestorationForTesting},object:nil)],timeout:10)
            XCTAssertTrue(controller.stopped);XCTAssertEqual(backend.activationCount,0)
            if reason != "cancel" {XCTAssertTrue(controller.sourceReceipt.contains("changed while loading"))}
            XCTAssertNil(controller.collisionAudit);XCTAssertNil(controller.scene)
            retire()
            await fulfillment(of:[XCTNSPredicateExpectation(predicate:NSPredicate {_,_ in stopped},object:nil)],timeout:10)
            guard stopped else{throw SeatedMappedFixtureFailure.noDrain}
            try await runtime.waitForPendingOperationsForTesting()
        }
    }

    @MainActor private func requestMappedPreview(_ controller:SeatedMeshDiagnosticController) {
        controller.requestPreview(startText:"",goalText:"99 99 99",radiusText:"0.3",heightText:"1.7",
            declaredMountText:"0 1.2 0",declaredYawText:"0",confirmed:true,marginText:"0.1",useMappedDestination:true)
    }
    @MainActor private func requireMappedSource(_ controller:SeatedMeshDiagnosticController) async throws {
        await fulfillment(of:[XCTNSPredicateExpectation(predicate:NSPredicate {_,_ in controller.hasCurrentSourceForTesting},object:nil)],timeout:10)
        guard controller.hasCurrentSourceForTesting else {
            XCTFail("No admitted source; mapped consumer not executed")
            throw SeatedMappedFixtureFailure.noSource
        }
    }
    @MainActor private func mappedController(_ backend:SeatedCandidateFixtureBackend,
        destinationProvider:@escaping () -> ConnectedJourneyRuntime.DiagnosticDestination?)
        -> (SeatedMeshDiagnosticController, @MainActor () async throws -> Void) {
        let hold=DispatchSemaphore(value:0)
        let ownerDone=XCTestExpectation(description:"mapped fixture complete controller ownership drain")
        ownerDone.assertForOverFulfill=true
        var stopped=false,stopping=false
        let controller=SeatedMeshDiagnosticController(testBackend:backend,clock:{backend.now},
            destinationProvider:destinationProvider,onStopped:{stopped=true;ownerDone.fulfill()})
        // Source and audit must NOT wait for optional visualization; preceding real
        // visualization tests remain unchanged, not replaced by this fixture.
        controller.enqueueSyntheticDisplayWorkForTesting(work:{},afterEnqueue:{hold.wait()},delivered:{})
        let retire: @MainActor () -> Void = {
            guard !stopping else {return};stopping=true
            hold.signal();controller.stop()
            backend.stopAndDrain {DispatchQueue.main.async {controller.acknowledgeTestBackendNativeDrainForTesting()}}
        }
        addTeardownBlock {
            await MainActor.run {retire()}
            // Sole waiter of this expectation, including thrown/refused outcomes.
            await self.fulfillment(of:[ownerDone],timeout:10)
        }
        let finish: @MainActor () async throws -> Void = {
            retire()
            // Fresh predicate, never a second wait of ownerDone. Iterations cannot
            // leave the actual native/source/render/audit owner active behind them.
            await self.fulfillment(of:[XCTNSPredicateExpectation(predicate:NSPredicate {_,_ in stopped},object:nil)],timeout:10)
            guard stopped else {XCTFail("Controller ownership did not drain");throw SeatedMappedFixtureFailure.noDrain}
        }
        return (controller,finish)
    }

}

/// Copied synthetic frame scalars + an actual owned classified floor packet.
/// No ARFrame/ARSession activation, forged route/snapshot, validator or guidance.
private final class SeatedCandidateFixtureBackend: SeatedMeshDiagnosticBackend {
    private let ingress: LiveMeshBenchIngress
    private let snapshots = MeshBenchCameraSnapshot()
    private let sessionID = UUID(), anchorID = UUID()
    private var active = true
    private let recovery=MeshBenchSavedWorldRecovery()
    private var recoveryTime: Double?
    private var savedFrame: SavedWorldFrame?
    private let timingLock = NSLock()
    private var submittedAt: Double?, nativeCompletedAt: Double?, mainHeldAt: Double?
    private let sourceTiming=SeatedSourceTimingRecorder()
    var now = 10.0
    var state: LiveMeshBenchSession.State { active ? .capturing : .stopped(restored: false) }
    var hasCurrentTrackedSession: Bool { active }
    var activationCount=0
    var submittedGoal: [Float]?
    var submittedStart: [Float]?
    var submittedCapture: LiveMeshBenchSession.CameraCapture?
    var submittedSource: MeshCandidateIngress83.SourceSnapshot?
    var heldResult: Result<MeshCandidateIngress83.Candidate,MeshCandidateIngress83.Failure>?
    var onHeld: (() -> Void)?
    private var heldCompletion: ((Result<MeshCandidateIngress83.Candidate,MeshCandidateIngress83.Failure>) -> Void)?
    init(savedFrame: SavedWorldFrame? = nil) throws {
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
        self.savedFrame=savedFrame
        if let savedFrame {
            recovery.begin(frame:savedFrame,session:sessionID,now:9.7)
            recovery.observe(session:sessionID,tracking:.relocalizing,mappingAvailable:true,originMatches:true,capturedAt:9.7,now:9.7)
            for t in [9.8,9.9,10.0] {
                recovery.observe(session:sessionID,tracking:.normal,mappingAvailable:true,originMatches:true,capturedAt:t,now:t)
            }
            recoveryTime=10.0
        }
        ordinaryFrame()
    }
    func ordinaryFrame() {
        if savedFrame != nil,let previous=recoveryTime,now > previous {
            recovery.observe(session:sessionID,tracking:.normal,mappingAvailable:true,originMatches:true,capturedAt:now,now:now)
            recoveryTime=now
        }
        snapshots.observe(.init(session: sessionID,frame: UUID(),capturedAt: now,
            columnMajorCameraToWorld: [1,0,0,0,0,1,0,0,0,0,1,0,0,Double(Float(1.2)),0,1]))
    }
    func activateForSeatedBench() throws {activationCount+=1}
    func stop() {
        active=false;snapshots.retire();ingress.stop()
        let retired=heldCompletion;heldCompletion=nil;heldResult=nil
        retired?(.failure(.stale)) // Same stopped-owner refusal as production, never a fabricated route.
    }
    func stopAndDrain(_ completion: @escaping () -> Void) {
        stop(); heldCompletion = nil; heldResult = nil; onHeld = nil
        ingress.stopAndDiscard { [self] in
            printTiming(event: "native_discard_acknowledged")
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
    func resetRecovery() { recovery.retire();recoveryTime=nil }
    func savedFrameAssociation(for capture: LiveMeshBenchSession.CameraCapture, now: Double) -> SavedWorldFrameCameraAssociation? {
        guard isCurrent(capture) else {return nil}
        return recovery.association(session:capture.session,capturedAt:capture.capturedAt,now:now)
    }
    func isCurrent(_ association: SavedWorldFrameCameraAssociation,
                   capture: LiveMeshBenchSession.CameraCapture, now: Double) -> Bool {
        return isCurrent(capture) && capture.session == association.sessionID
            && capture.capturedAt == association.capturedAt && recovery.isCurrent(association,now:now)
    }
    func changeGeometry() { _ = ingress.remove(anchorID: anchorID,generation: ingress.generation,receiptUptime: now+0.01) }
    func requestPreview(start: [Float],goal: [Float],body: MeshCandidateBody,
                        capture: LiveMeshBenchSession.CameraCapture?,expectedSource: MeshCandidateIngress83.SourceSnapshot?,
                        completion: @escaping (Result<MeshCandidateIngress83.Candidate,MeshCandidateIngress83.Failure>) -> Void) {
        guard let capture, snapshots.canAdmit(capture,at: now), expectedSource != nil else { completion(.failure(.stale)); return }
        submittedGoal = goal; submittedStart = start; submittedCapture = capture; submittedSource = expectedSource
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
/// Supplied synthetic registry and copied frame sequence, not real saved-world
/// relocalization. Uses the real installation/hash/catalog and recovery adapters.
private enum SeatedMappedFixtureFailure: Error {case noSource,noDrain}
private enum SeatedMappedFixture {
    static func frame() -> SavedWorldFrame {
        .init(placeID:UUID().uuidString,revision:UUID().uuidString,
            worldMapSHA256:String(repeating:"a",count:64),roomCaptureSHA256:String(repeating:"b",count:64),
            originAnchorID:UUID().uuidString,capturedAt:Date(timeIntervalSince1970:1))
    }
    static func installation(frame:SavedWorldFrame, twoFloors:Bool=false, upperFloor:Bool=false) throws -> SpatialMapInstallation {
        let binding=SpatialMapBinding(mapID:"synthetic-mapped-seated",frameID:frame.frameID,revision:frame.revision)
        let nodes:[SpatialPlaceNode]=[
            .init(id:"world",kind:.world),.init(id:"place",kind:.place,parentID:"world"),
            .init(id:"building",kind:.building,parentID:"place"),
            .init(id:"floor",kind:.floor,parentID:"building"),
            .init(id:"upper",kind:.floor,parentID:"building"),
            .init(id:"room",kind:.room,parentID:upperFloor ? "upper" : "floor")]
        let record=SpatialMapRevision(binding:binding,nodeID:twoFloors ? "building" : "room",metersPerUnit:1,
            floorLevels:twoFloors ? ["ground":"floor","up":"upper"] : ["ground":upperFloor ? "upper" : "floor"],savedWorldFrame:frame)
        let registry=SpatialRegistrySnapshot(nodes:nodes,maps:[record],activeBindings:[binding])
        var map=IndoorMap(name:"SYNTHETIC selected destination",nodes:[
            .init(id:"goal",name:"Goal",level:"ground",position:.init(1,0,0)),
            .init(id:"other",name:"Other",level:"ground",position:.init(-1,0,0))],edges:[])
        map.packageID=binding.mapID;map.packageRevision=binding.revision
        let bytes=try SpatialMapInstallation.canonicalMapBytes(map)
        return try .init(envelope:.init(snapshot:registry,binding:binding,mapBytes:bytes,
            artifactHistory:[.init(binding:binding,sha256:try ConnectedFixture.sha256(bytes))]),sha256:ConnectedFixture.sha256)
    }
    @MainActor static func runtime(_ installation: SpatialMapInstallation, io:SeatedMappedIO) async throws -> ConnectedJourneyRuntime {
        let runtime=ConnectedJourneyRuntime(io:io,sha256:ConnectedFixture.sha256)
        runtime.restore();try await runtime.waitForPendingOperationsForTesting()
        try runtime.install(installation);try await runtime.waitForPendingOperationsForTesting()
        try runtime.setDestination(binding:installation.binding,nodeID:"goal",origin:.trustedInterface)
        try await runtime.waitForPendingOperationsForTesting()
        return runtime
    }
}
private actor SeatedMappedIO: ConnectedJourneyRuntimeIO {
    private var data:Data?
    func read() -> Data? {data}
    func write(_ payload:JourneyRuntimeWrite) throws {data=try payload.envelope().encoded()}
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
