import XCTest
import CryptoKit
import BlindRoomMesh
import simd
@testable import BlindAssist

/// Separate opt-in admission candidate. Original baseline reports/defaults stay
/// unchanged; neither membership nor a complete path is physical authority.
@MainActor final class SavedRoomStrictEndpointTests: XCTestCase {
    private let identity: [Double] = [1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1]
    private final class ResultBox: @unchecked Sendable {
        private let lock = NSLock()
        private var value: Result<MeshCandidateRoute,MeshCandidateError>?
        func put(_ result: Result<MeshCandidateRoute,MeshCandidateError>) { lock.lock(); value=result; lock.unlock() }
        func get() -> Result<MeshCandidateRoute,MeshCandidateError>? { lock.lock(); defer { lock.unlock() }; return value }
    }
    private func owner(vertices:[Double], triangles:[Int32], support:[Bool],
                       policy:MeshEndpointPolicy? = nil) throws -> RoomMeshCandidateRuntime {
        let id=UUID().uuidString
        let runtime:RoomMeshCandidateRuntime
        if let policy { runtime=try .init(sessionID:id,supportPolicy:.classifiedFloorOnly,endpointPolicy:policy) }
        else { runtime=try .init(sessionID:id,supportPolicy:.classifiedFloorOnly) }
        XCTAssertTrue(runtime.offer(.init(sessionID:id,generation:0,anchorID:"explicit-test-input",revision:1,
            timestamp:0,vertices:vertices,triangles:triangles,columnMajorTransform:identity,complete:true,
            triangleSupport:support.map { $0 ? .floor : .obstacle })))
        return runtime
    }
    private func query(_ runtime:RoomMeshCandidateRuntime,start:[Float],goal:[Float],
                       radius:Float=0.225,height:Float=1.75) async throws -> Result<MeshCandidateRoute,MeshCandidateError> {
        let done=expectation(description:"strict endpoint native result"),box=ResultBox()
        runtime.request(start:start,goal:goal,body:try .init(radius:radius,height:height)) {
            box.put($0); done.fulfill() // no logging/formatting on completion critical path
        }
        await fulfillment(of:[done],timeout:10)
        if box.get() == nil { runtime.stopAndDiscard {} }
        return try XCTUnwrap(box.get(),"No native completion; no inferred route")
    }
    private func discard(_ runtime:RoomMeshCandidateRuntime) async {
        let done=expectation(description:"strict endpoint terminal release")
        runtime.stopAndDiscard { done.fulfill() }; await fulfillment(of:[done],timeout:10)
    }
    private func plane(_ policy:MeshEndpointPolicy? = nil) throws -> RoomMeshCandidateRuntime {
        try owner(vertices:[-3,0,-3, -3,0,3, 3,0,3, 3,0,-3],triangles:[0,1,2,0,2,3],support:[true,true],policy:policy)
    }
    func testDefaultLegacyAndOptInStrictPreserveInsidePathAndVerticalAssociation() async throws {
        let legacy=try plane(),strict=try plane(.requireSuppliedXZOverPolygon)
        defer { legacy.stopAndDiscard {}; strict.stopAndDiscard {} }
        let start:[Float]=[-1,-0.05,0],goal:[Float]=[1,-0.05,0]
        let a=try await query(legacy,start:start,goal:goal).get()
        let b=try await query(strict,start:start,goal:goal).get()
        XCTAssertEqual(a.endpointPolicy,.legacyNearestProjection); XCTAssertNil(a.endpointAdmission)
        XCTAssertEqual(b.endpointPolicy,.requireSuppliedXZOverPolygon)
        XCTAssertEqual(a.points.flatMap { $0 }.map(\.bitPattern),b.points.flatMap { $0 }.map(\.bitPattern))
        XCTAssertEqual(a.projectedStart.map(\.bitPattern),b.projectedStart.map(\.bitPattern))
        XCTAssertEqual(a.projectedGoal.map(\.bitPattern),b.projectedGoal.map(\.bitPattern))
        XCTAssertTrue(a.complete); XCTAssertTrue(b.complete)
        let receipt=try XCTUnwrap(b.endpointAdmission)
        XCTAssertTrue(receipt.start.found && receipt.start.isOverPolygon && receipt.goal.found && receipt.goal.isOverPolygon)
        XCTAssertEqual(receipt.start.requested,start); XCTAssertEqual(receipt.goal.requested,goal)
        XCTAssertEqual(receipt.start.projected,b.projectedStart)
        XCTAssertNotEqual(b.projectedStart[1],start[1]) // retained, not erased vertical connector
        XCTAssertFalse(receipt.authorizesPhysicalGuidance); XCTAssertFalse(b.authorizesPhysicalGuidance)
        await discard(legacy); await discard(strict)
    }
    func testStrictGoalOutsideMissingPolygonAndNonfiniteRefuseWithoutCandidate() async throws {
        let legacy=try plane(),strict=try plane(.requireSuppliedXZOverPolygon)
        defer { legacy.stopAndDiscard {}; strict.stopAndDiscard {} }
        let start:[Float]=[0,0,0],goal:[Float]=[2.8,0,0]
        let legacyGoalRoute=try await query(legacy,start:start,goal:goal).get()
        XCTAssertTrue(legacyGoalRoute.complete)
        let result=try await query(strict,start:start,goal:goal)
        guard case .failure(.endpointAssociationRejected(let receipt))=result else { return XCTFail("Strict goal must reject, not emit a candidate") }
        XCTAssertTrue(receipt.start.isOverPolygon); XCTAssertTrue(receipt.goal.found); XCTAssertFalse(receipt.goal.isOverPolygon)
        let missing=try await query(strict,start:start,goal:[20,0,0])
        guard case .failure(.endpointAssociationRejected(let absent))=missing else { return XCTFail("Missing polygon must reject") }
        XCTAssertTrue(absent.start.isOverPolygon); XCTAssertFalse(absent.goal.found); XCTAssertFalse(absent.goal.isOverPolygon)
        XCTAssertEqual(absent.goal.projected,[0,0,0])
        let invalid=try await query(strict,start:[.nan,0,0],goal:goal)
        guard case .failure(.invalidInput)=invalid else { return XCTFail("Nonfinite point must reject before native query") }
        await discard(legacy); await discard(strict)
    }
    func testThreeActualPublicMarginOverlappedStartsKeepInitialOracleAndRejectStrictAdmission() async throws {
        let digest="44df7bd5f4d1961bf13344916384dcfa20d42c7ef8dc58b0e13d1c2f7c6a4d2e"
        let url=try XCTUnwrap(Bundle(for:Self.self).url(forResource:"Bedroom3.capturedRoom",withExtension:"json",subdirectory:"RoomPlanApple"))
        let data=try Data(contentsOf:url)
        XCTAssertEqual(SHA256.hash(data:data).map { String(format:"%02x",$0) }.joined(),digest)
        let mesh=try await Task.detached(priority:.utility) { try SavedRoomRouteMeshAdapter.decode(data:data,expectedSHA256:digest) }.value
        let boxes=mesh.features.filter { $0.kind == .furniture }.map {
            SavedRoomRouteCollisionOracle.FurnitureBox(featureID:$0.id,dimensions:$0.dimensions,transform:$0.transform)
        }
        let oracle=try SavedRoomRouteCollisionOracle(vertices:mesh.vertices,triangles:mesh.triangles,
            floorSupport:mesh.floorSupport,triangleFeatureIDs:mesh.triangleFeatureIDs,furnitureBoxes:boxes)
        let legacy=try owner(vertices:mesh.vertices,triangles:mesh.triangles,support:mesh.floorSupport)
        let strict=try owner(vertices:mesh.vertices,triangles:mesh.triangles,support:mesh.floorSupport,policy:.requireSuppliedXZOverPolygon)
        defer { legacy.stopAndDiscard {}; strict.stopAndDiscard {} }
        // Frozen49a/b1 supplied endpoints: aisle, bed rise, chair rise. No replacement.
        let starts:[[Float]]=[[0.12442538887262344,-1.4659849405288696,15.277722358703613],
            [0.20171594619750977,-1.4659849405288696,14.733180046081543],
            [0.08194796741008759,-1.4659849405288696,15.221192359924316]]
        let goals:[[Float]]=[[0.3562970757484436,-1.4659849405288696,13.644095420837402],
            [0.3562970757484436,-1.4659849405288696,13.644095420837402],
            [0.257927268743515,-1.4659849405288696,14.337149620056152]]
        for i in starts.indices {
            let p=SIMD3<Float>(starts[i][0],starts[i][1],starts[i][2])
            // Preserve source collision evidence BEFORE admission can reject.
            let raw=try oracle.sweep(from:p,to:p,radius:0.17204650534085256,height:1.2)
            let margin=try oracle.sweep(from:p,to:p,radius:0.32204651832580566,height:1.350000023841858)
            XCTAssertFalse(raw.all.hasObstacleContact); XCTAssertTrue(margin.all.hasObstacleContact)
            let old=try await query(legacy,start:starts[i],goal:goals[i],radius:0.32204651832580566,height:1.350000023841858).get()
            XCTAssertTrue(old.complete); XCTAssertEqual(old.endpointPolicy,.legacyNearestProjection)
            let result=try await query(strict,start:starts[i],goal:goals[i],radius:0.32204651832580566,height:1.350000023841858)
            guard case .failure(.endpointAssociationRejected(let receipt))=result else { return XCTFail("Strict mode emitted candidate for supplied margin-overlapped start") }
            XCTAssertEqual(receipt.policy,.requireSuppliedXZOverPolygon)
            XCTAssertTrue(receipt.start.found); XCTAssertFalse(receipt.start.isOverPolygon)
            XCTAssertEqual(receipt.start.requested,starts[i]); XCTAssertEqual(receipt.goal.requested,goals[i])
            XCTAssertEqual(receipt.goal.isOverPolygon,i != 2)
            XCTAssertFalse(receipt.authorizesPhysicalGuidance)
        }
        await discard(legacy); await discard(strict)
    }
}

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

import XCTest
import BlindRoomMesh

/// Authored candidate integration tests. No speech, camera, haptics or movement.
/// Add only to an explicitly admitted native validation target; unrun at staging.
@MainActor final class SeedRadiusEnvelopeAppleTests: XCTestCase {
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
        let done=expectation(description:"actual envelope schema2 C ABI build/query completion"),box=Box()
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
        let policy=MeshSeedRadiusPolicy.exactFlatLayerEnvelope(maximumEnvelopeWork:10_000_000)
        XCTAssertThrowsError(try RoomMeshCandidateRuntime(sessionID:"legacy",seedRadiusPolicy:policy))
        XCTAssertThrowsError(try RoomMeshCandidateRuntime(sessionID:"projection",supportPolicy:.classifiedFloorOnly,seedRadiusPolicy:policy))
        for limit in [UInt64(0),10_000_001] {
            XCTAssertThrowsError(try RoomMeshCandidateRuntime(sessionID:"budget",supportPolicy:.classifiedFloorOnly,
                endpointPolicy:.requireSuppliedXZOverPolygon,seedRadiusPolicy:.exactFlatLayerEnvelope(maximumEnvelopeWork:limit)))
        }
    }
    func testStockDefaultHasNoVetoReceiptAndFlatOptInNeverClaimsPhysicalClearance()async throws{
        let stock=try owner(),exact=try owner(policy:.exactFlatLayerEnvelope(maximumEnvelopeWork:10_000_000))
        defer{stock.stopAndDiscard{};exact.stopAndDiscard{}}
        let a=try await query(stock).get(),b=try await query(exact).get()
        XCTAssertNil(a.seedRadiusEnvelopeReceipt);XCTAssertNil(b.seedRadiusReceipt);XCTAssertTrue(a.complete);XCTAssertTrue(b.complete)
        XCTAssertEqual(a.points.flatMap{$0}.map(\.bitPattern),b.points.flatMap{$0}.map(\.bitPattern))
        let r=try XCTUnwrap(b.seedRadiusEnvelopeReceipt)
        XCTAssertEqual(r.schema,.version2);XCTAssertEqual(r.algorithm,.maurerIntegerV1);XCTAssertEqual(r.workUnit,.loopVisitOrComparisonV1);XCTAssertEqual(r.status,.applied);XCTAssertTrue(r.buildSucceeded)
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
        let runtime=try owner(policy:.exactFlatLayerEnvelope(maximumEnvelopeWork:1));defer{runtime.stopAndDiscard{}}
        let result=try await query(runtime)
        guard case .failure(.seedRadiusEnvelopeUnavailable(let r))=result else{return XCTFail("No legacy route fallback")}
        XCTAssertEqual(r.status,.workLimit);XCTAssertFalse(r.buildSucceeded)
        XCTAssertGreaterThan(r.workBound,r.workLimit);XCTAssertEqual(r.workPerformed,0)
        await discard(runtime)
    }
    func testTwoDistinctFloorHeightsRefuseRatherThanFlattenOrChooseOne()async throws{
        let vertices:[Double]=[-3,0,-3,-3,0,3,-0.5,0,3,-0.5,0,-3,
                              0.5,1,-3,0.5,1,3,3,1,3,3,1,-3]
        let runtime=try owner(policy:.exactFlatLayerEnvelope(maximumEnvelopeWork:10_000_000),vertices:vertices,
            triangles:[0,1,2,0,2,3,4,5,6,4,6,7],support:[.floor,.floor,.floor,.floor])
        defer{runtime.stopAndDiscard{}}
        let result=try await query(runtime)
        guard case .failure(.seedRadiusEnvelopeUnavailable(let r))=result else{return XCTFail("Unsupported layer must not emit a path")}
        XCTAssertEqual(r.status,.unsupportedLayer);XCTAssertFalse(r.buildSucceeded)
        await discard(runtime)
    }
    func testAllObstacleClassificationCannotBorrowSlopeSupport()async throws{
        let runtime=try owner(policy:.exactFlatLayerEnvelope(maximumEnvelopeWork:10_000_000),support:[.obstacle,.obstacle])
        defer{runtime.stopAndDiscard{}}
        let result=try await query(runtime)
        guard case .failure(.seedRadiusEnvelopeUnavailable(let r))=result else{return XCTFail("No support means no exact-policy handle")}
        XCTAssertFalse(r.buildSucceeded);XCTAssertFalse(r.authorizesPhysicalGuidance)
        await discard(runtime)
    }
    func testEnvelopeReceiptRejectsUnknownSchemaAlgorithmAndWorkUnit()async throws{
        let runtime=try owner(policy:.exactFlatLayerEnvelope(maximumEnvelopeWork:10_000_000))
        defer{runtime.stopAndDiscard{}}
        let route=try await query(runtime).get(),receipt=try XCTUnwrap(route.seedRadiusEnvelopeReceipt)
        let data=try JSONEncoder().encode(receipt)
        XCTAssertEqual(try JSONDecoder().decode(MeshSeedRadiusEnvelopeReceipt.self,from:data).schema,.version2)
        let original=try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])
        for key in ["schema","algorithm","workUnit"] {
            var changed=original;changed[key]=999
            let altered=try JSONSerialization.data(withJSONObject:changed)
            XCTAssertThrowsError(try JSONDecoder().decode(MeshSeedRadiusEnvelopeReceipt.self,from:altered))
        }
        await discard(runtime)
    }

}
