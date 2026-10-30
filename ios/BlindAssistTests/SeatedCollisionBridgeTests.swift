#if DEBUG && BLIND_MESH_CANDIDATE_DIAGNOSTICS
import XCTest
import BlindRoomMesh
@testable import BlindAssist

/// Authored original-source surfaces, not device or physical-navigation evidence.
@MainActor
final class SeatedCollisionBridgeTests: XCTestCase {
    private let identity:[Double]=[1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1]
    private func table(roles: Bool=true) throws -> SeatedMeshRouteAudit.Geometry {
        try SeatedMeshRouteAudit.prepare([.init(id:"mixed-floor-table",
            local:[-3,0,-3,3,0,-3,3,0,3,-3,0,3, -1,0.7,-1,1,0.7,-1,1,0.7,1,-1,0.7,1],
            transform:identity,triangles:[0,1,2,0,2,3,4,5,6,4,6,7],
            roles:roles ? [.floor,.floor,.obstacle,.obstacle] : nil)])
    }
    private func request(start:[Float]=[-2,0,0],goal:[Float]=[2,0,0],margin:Float=0.1)->SeatedMeshRouteAudit.Request {
        .init(id:UUID(),start:start,goal:goal,radius:0.2,height:1.6,margin:margin)
    }
    func testCrossingTableAndClearRouteUseRealOracleWithMixedRoleIdentity() async throws {
        let geometry=try table(),crossing=request()
        XCTAssertEqual(geometry.triangles.count,12)
        XCTAssertEqual(Set(geometry.origins.values.map(\.anchorID)),["mixed-floor-table"])
        XCTAssertEqual(Set(geometry.origins.values.map(\.role)),[.floor,.obstacle])
        let chain=try SeatedMeshRouteAudit.segments(request:crossing,projectedStart:crossing.start,projectedGoal:crossing.goal,points:[crossing.start,crossing.goal],complete:true)
        let blocked=try await SeatedMeshRouteAudit.query(geometry:geometry,segments:chain,request:crossing,isCurrent:{true})
        XCTAssertTrue(blocked.0.contains(where:{$0.blocked}))
        let clear=request(start:[-2,0,2],goal:[2,0,2])
        let clearChain=try SeatedMeshRouteAudit.segments(request:clear,projectedStart:clear.start,projectedGoal:clear.goal,points:[clear.start,clear.goal],complete:true)
        let result=try await SeatedMeshRouteAudit.query(geometry:geometry,segments:clearChain,request:clear,isCurrent:{true})
        XCTAssertFalse(result.0.contains(where:{$0.blocked}))
        XCTAssertFalse(result.1.contains(where:{$0.blocked}))
    }
    func testMarginIsSeparateAndRequestedGoalConnectorRetainsContact() async throws {
        let geometry=try table(),near=request(start:[-2,0,1.25],goal:[2,0,1.25])
        let chain=try SeatedMeshRouteAudit.segments(request:near,projectedStart:near.start,projectedGoal:near.goal,points:[near.start,near.goal],complete:true)
        let result=try await SeatedMeshRouteAudit.query(geometry:geometry,segments:chain,request:near,isCurrent:{true})
        XCTAssertFalse(result.0.contains(where:{$0.blocked}))
        XCTAssertTrue(result.1.contains(where:{$0.blocked}))
        let connected=request(start:[-2,0,2],goal:[0,0,0])
        let connector=try SeatedMeshRouteAudit.segments(request:connected,projectedStart:connected.start,projectedGoal:[2,0,2],points:[connected.start,[2,0,2]],complete:true)
        let hit=try await SeatedMeshRouteAudit.query(geometry:geometry,segments:connector,request:connected,isCurrent:{true})
        XCTAssertTrue(hit.0.contains(where:{$0.segment == "projection-to-requested-goal" && $0.blocked}))
    }
    func testUnknownRoleNoDeletionAndZeroLengthHeightAssociation() async throws {
        let geometry=try table(roles:false)
        XCTAssertEqual(geometry.triangles.count,12);XCTAssertEqual(geometry.floor,[false,false,false,false])
        XCTAssertEqual(Set(geometry.origins.values.map(\.role)),[.unavailable])
        let r=request(start:[0,0.17,0],goal:[0,0.17,0])
        let chain=try SeatedMeshRouteAudit.segments(request:r,projectedStart:[0,0,0],projectedGoal:[0,0,0],points:[[0,0,0]],complete:true)
        XCTAssertEqual(chain.first?.from.y,0.17);XCTAssertEqual(chain.first?.to.y,0)
        XCTAssertEqual(chain.last?.to.y,0.17)
        let zero=try await SeatedMeshRouteAudit.query(geometry:try table(),segments:chain,request:r,isCurrent:{true})
        XCTAssertTrue(zero.0.contains(where:{$0.initial.hasObstacleContact}))
        let incomplete=try SeatedMeshRouteAudit.segments(request:r,projectedStart:[0,0,0],projectedGoal:[0,0,0],points:[[0,0,0]],complete:false)
        XCTAssertFalse(incomplete.contains(where:{$0.name == "projection-to-requested-goal"}))
    }
    func testRetiredOrOverBudgetNeverProducesEmptyClearResult() async throws {
        let geometry=try table(),r=request()
        let chain=try SeatedMeshRouteAudit.segments(request:r,projectedStart:r.start,projectedGoal:r.goal,points:[r.start,r.goal],complete:true)
        do { _=try await SeatedMeshRouteAudit.query(geometry:geometry,segments:chain,request:r,isCurrent:{false});XCTFail("Retired source must throw") }
        catch SeatedMeshRouteAudit.Failure.retired {} catch {XCTFail("Unexpected \(error)")}
        let duplicated=SeatedMeshRouteAudit.Anchor(id:"same",local:[0,0,0,1,0,0,0,0,1],transform:identity,triangles:[0,1,2],roles:[.floor])
        XCTAssertThrowsError(try SeatedMeshRouteAudit.prepare([duplicated,duplicated]))
        XCTAssertThrowsError(try SeatedMeshRouteAudit.segments(request:r,projectedStart:r.start,projectedGoal:r.goal,points:Array(repeating:r.start,count:65),complete:true))
    }
}
#endif
