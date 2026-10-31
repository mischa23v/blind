import XCTest
import BlindRoomMesh

/// Authored candidate integration tests. No speech, camera, haptics or movement.
/// Add only to an explicitly admitted native validation target; unrun at staging.
@MainActor final class SeedRadiusVetoAppleTests: XCTestCase {
    private let identity:[Double]=[1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1]
    private let plane:[Double]=[-2,0,-2, -2,0,2, 2,0,2, 2,0,-2]
    private final class Box:@unchecked Sendable {
        private let lock=NSLock()
        private var value:Result<MeshCandidateRoute,MeshCandidateError>?
        func set(_ v:Result<MeshCandidateRoute,MeshCandidateError>){lock.lock();value=v;lock.unlock()}
        func get()->Result<MeshCandidateRoute,MeshCandidateError>?{lock.lock();defer{lock.unlock()};return value}
    }
    private func owner(policy:MeshSeedRadiusPolicy = .stock,vertices:[Double]?=nil,
                       triangles:[Int32]=[0,1,2,0,2,3],support:[MeshTriangleSupport]=[.floor,.floor])throws->RoomMeshCandidateRuntime {
        let session=UUID().uuidString
        let runtime=try RoomMeshCandidateRuntime(sessionID:session,supportPolicy:.classifiedFloorOnly,
            endpointPolicy:.requireSuppliedXZOverPolygon,seedRadiusPolicy:policy)
        XCTAssertTrue(runtime.offer(.init(sessionID:session,generation:0,anchorID:"authored-seed-veto-plane",
            revision:1,timestamp:1,vertices:vertices ?? plane,triangles:triangles,columnMajorTransform:identity,
            complete:true,triangleSupport:support)))
        return runtime
    }
    private func query(_ runtime:RoomMeshCandidateRuntime)async throws->Result<MeshCandidateRoute,MeshCandidateError>{
        let done=expectation(description:"actual seed-radius C ABI build/query completion"),box=Box()
        runtime.request(start:[-1,0,0],goal:[1,0,0],body:try .init(radius:0.225,height:1.75)){
            box.set($0);done.fulfill()
        }
        await fulfillment(of:[done],timeout:10)
        return try XCTUnwrap(box.get())
    }
    private func discard(_ runtime:RoomMeshCandidateRuntime)async{
        let done=expectation(description:"terminal release")
        runtime.stopAndDiscard{done.fulfill()};await fulfillment(of:[done],timeout:10)
    }
    func testExactPolicyRequiresClassifiedStrictAdmissionAndBoundedBudget()throws{
        let policy=MeshSeedRadiusPolicy.exactFlatLayer(maximumSeedTests:10_000_000)
        XCTAssertThrowsError(try RoomMeshCandidateRuntime(sessionID:"legacy",seedRadiusPolicy:policy))
        XCTAssertThrowsError(try RoomMeshCandidateRuntime(sessionID:"projection",supportPolicy:.classifiedFloorOnly,seedRadiusPolicy:policy))
        for limit in [UInt64(0),10_000_001] {
            XCTAssertThrowsError(try RoomMeshCandidateRuntime(sessionID:"budget",supportPolicy:.classifiedFloorOnly,
                endpointPolicy:.requireSuppliedXZOverPolygon,seedRadiusPolicy:.exactFlatLayer(maximumSeedTests:limit)))
        }
    }
    func testStockDefaultHasNoVetoReceiptAndFlatOptInNeverClaimsPhysicalClearance()async throws{
        let stock=try owner(),exact=try owner(policy:.exactFlatLayer(maximumSeedTests:10_000_000))
        defer{stock.stopAndDiscard{};exact.stopAndDiscard{}}
        let a=try await query(stock).get(),b=try await query(exact).get()
        XCTAssertNil(a.seedRadiusReceipt);XCTAssertTrue(a.complete);XCTAssertTrue(b.complete)
        XCTAssertEqual(a.points.flatMap{$0}.map(\.bitPattern),b.points.flatMap{$0}.map(\.bitPattern))
        let r=try XCTUnwrap(b.seedRadiusReceipt)
        XCTAssertEqual(r.schema,1);XCTAssertEqual(r.status,.applied);XCTAssertTrue(r.buildSucceeded)
        XCTAssertLessThanOrEqual(r.exactKeepCount,r.stockKeepCount)
        XCTAssertEqual(r.additionalRejectedCount,r.stockKeepCount-r.exactKeepCount)
        XCTAssertLessThanOrEqual(r.workPerformed,r.workBound);XCTAssertLessThanOrEqual(r.workBound,r.workLimit)
        XCTAssertFalse(r.authorizesPhysicalGuidance);XCTAssertFalse(r.continuousSourceClearanceVerified)
        XCTAssertFalse(r.fullFootprintSupportVerified);XCTAssertFalse(b.authorizesPhysicalGuidance)
        XCTAssertEqual(b.endpointPolicy,.requireSuppliedXZOverPolygon)
        XCTAssertTrue(try XCTUnwrap(b.endpointAdmission).start.isOverPolygon)
        await discard(stock);await discard(exact)
    }
    func testInsufficientWorkBudgetReturnsTypedRefusalNeverStockRoute()async throws{
        let runtime=try owner(policy:.exactFlatLayer(maximumSeedTests:1));defer{runtime.stopAndDiscard{}}
        let result=try await query(runtime)
        guard case .failure(.seedRadiusUnavailable(let r))=result else{return XCTFail("No legacy route fallback")}
        XCTAssertEqual(r.status,.workLimit);XCTAssertFalse(r.buildSucceeded)
        XCTAssertGreaterThan(r.workBound,r.workLimit);XCTAssertEqual(r.workPerformed,0)
        await discard(runtime)
    }
    func testTwoDistinctFloorHeightsRefuseRatherThanFlattenOrChooseOne()async throws{
        let vertices:[Double]=[-3,0,-3,-3,0,3,-0.5,0,3,-0.5,0,-3,
                              0.5,1,-3,0.5,1,3,3,1,3,3,1,-3]
        let runtime=try owner(policy:.exactFlatLayer(maximumSeedTests:10_000_000),vertices:vertices,
            triangles:[0,1,2,0,2,3,4,5,6,4,6,7],support:[.floor,.floor,.floor,.floor])
        defer{runtime.stopAndDiscard{}}
        let result=try await query(runtime)
        guard case .failure(.seedRadiusUnavailable(let r))=result else{return XCTFail("Unsupported layer must not emit a path")}
        XCTAssertEqual(r.status,.unsupportedLayer);XCTAssertFalse(r.buildSucceeded)
        await discard(runtime)
    }
    func testAllObstacleClassificationCannotBorrowSlopeSupport()async throws{
        let runtime=try owner(policy:.exactFlatLayer(maximumSeedTests:10_000_000),support:[.obstacle,.obstacle])
        defer{runtime.stopAndDiscard{}}
        let result=try await query(runtime)
        guard case .failure(.seedRadiusUnavailable(let r))=result else{return XCTFail("No support means no exact-policy handle")}
        XCTAssertFalse(r.buildSucceeded);XCTAssertFalse(r.authorizesPhysicalGuidance)
        await discard(runtime)
    }
}
