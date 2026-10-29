#if DEBUG && BLIND_MESH_CANDIDATE_DIAGNOSTICS
import XCTest
import SceneKit
import ARKit
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

}
#endif
