import Foundation
import CryptoKit
import XCTest
import simd
import BlindCore
import BlindRoomMesh
@testable import BlindAssist

/// Supplied-pose candidate replay, NOT finding a real person or modeling get-up
/// motion. Existing code formatters run into a test array; no physical sink exists.
@MainActor final class SavedRoomRouteJourneyAppleTests: XCTestCase {
    private let digest = "8e060627d0f570820fd00a427e22f6672eb50048611dfc9682986cac5c30cc9a"
    private let baselineDigest = "ee8f183ca4d7b6fd9aabecf2f7cd8d39bc472ce071873bceafe4c557f65f8123"
    private let width28Digest = "c52792a1213a1b3969e97a6201d43bac2426a444f3f39e8b906a5feb0e0f701d"
    private let sourceDigests = ["Hallway2":"f4cf3460fd9e746a86fe6538e2b1980e22e18207a2d3c7ea3f7679f58c8c6f4d",
                                 "Bedroom3":"44df7bd5f4d1961bf13344916384dcfa20d42c7ef8dc58b0e13d1c2f7c6a4d2e"]
    private struct Profile: Decodable {
        let id: String
        let width, depth, height, margin: Double
        var radius: Float { Float(hypot(width,depth)/2) }
        var effectiveRadius: Float { Float(hypot(width,depth)/2+margin) }
        var effectiveHeight: Float { Float(height+margin) }
    }
    private struct Stage: Decodable { let id: String; let goal: [Double]; let doorID: UUID?; let expectedWithhold: Bool }
    private struct Journey: Decodable {
        let id, room: String
        let seatedFeatureID: UUID?
        let standingFloorLocal: [Double]?
        let standingFeatureFootCenter: UUID?
        let expectsInvalidStandingStart: Bool?
        let stages: [Stage]
    }
    private struct Addendum: Decodable {
        let schema: Int
        let baseProtocolSHA256, width28ProfileSHA256: String
        let preregisteredBeforeFirstNativeExecution, physicalAuthority, cameraLocalizationTested, getUpKinematicsTested: Bool
        let profile: Profile
        let declaredHeadingFloorLocal: [Double]
        let journeys: [Journey]
    }
    private struct SuppliedPose {
        let sourceSHA256: String
        let position: SIMD3<Float>
        let standing: Bool
        let heading: SIMD3<Float>?
        func matches(_ expected: String) -> Bool {
            standing && sourceSHA256 == expected && [position.x,position.y,position.z].allSatisfy(\.isFinite)
        }
    }
    private struct CandidateSegment {
        let kind: String
        let from, to: SIMD3<Float>
    }
    private struct CodeGuidanceSink {
        private(set) var receipts: [[String:Any]] = []
        mutating func retire() { receipts.removeAll() }
        mutating func deliver(route: MeshCandidateRoute, owner: RoomMeshCandidateRuntime,
                              segments: [CandidateSegment], pose: SuppliedPose?,
                              expectedSource: String, stageID: String) -> Bool {
            guard owner.isCurrent(route), route.complete, let pose, pose.matches(expectedSource),
                  let heading=pose.heading, [heading.x,heading.y,heading.z].allSatisfy(\.isFinite),
                  hypot(heading.x,heading.z)>0, let first=segments.first,
                  first.from == pose.position else { return false }
            // These are precisely the independently scored edges, INCLUDING
            // requested/projected endpoint connectors; never cue a shortcut.
            var previous=pose.position
            for segment in segments {
                guard segment.from == previous,
                      [segment.from.x,segment.from.y,segment.from.z,
                       segment.to.x,segment.to.y,segment.to.z].allSatisfy(\.isFinite) else { return false }
                previous=segment.to
            }
            var cadence = GuidanceCadence(), pending: [[String:Any]] = []
            for (offset,segment) in segments.enumerated() {
                // Zero-horizontal connectors remain collision-scored, but the
                // production horizontal formatter cannot issue a vertical cue.
                if segment.from.x == segment.to.x && segment.from.z == segment.to.z { continue }
                let from = Point3(Double(segment.from.x),Double(segment.from.y),Double(segment.from.z))
                let to = Point3(Double(segment.to.x),Double(segment.to.y),Double(segment.to.z))
                let forward = Point3(Double(heading.x),Double(heading.y),Double(heading.z))
                guard let relation=SpatialFacts.relation(from:from,facing:forward,to:to) else { return false }
                let name="TEST \(stageID) \(segment.kind)", time=Double(offset+1)*2
                if let label=cadence.label(target:name,short:"TEST waypoint",relation:relation,now:time) {
                    let phrase=SpatialFacts.phrase(label:label,relation:relation,arabic:false,inView:nil)
                    guard owner.isCurrent(route) else { return false }
                    pending.append(["segmentIndex":offset,"segmentKind":segment.kind,
                        "from":[segment.from.x,segment.from.y,segment.from.z],
                        "to":[segment.to.x,segment.to.y,segment.to.z],"sector":relation.sector.rawValue,
                        "angleDegrees":relation.angleDegrees,"horizontalMetres":relation.distance,
                        "text":phrase,"source":"production SpatialFacts + GuidanceCadence; supplied heading",
                        "syntheticSeconds":time,"physicalAuthority":false])
                }
                // Exercise existing production duplicate-cue suppression without
                // adding a new wording/controller algorithm or moving the actor.
                guard cadence.label(target:name,short:"TEST waypoint",relation:relation,now:time)==nil else { return false }
            }
            guard owner.isCurrent(route) else { return false }
            receipts.append(contentsOf:pending)
            return !pending.isEmpty
        }
    }

    private final class Box: @unchecked Sendable {
        private let lock=NSLock()
        private var value:Result<MeshCandidateRoute,MeshCandidateError>?
        func put(_ result:Result<MeshCandidateRoute,MeshCandidateError>) { lock.lock(); value=result; lock.unlock() }
        func get()->Result<MeshCandidateRoute,MeshCandidateError>? { lock.lock(); defer { lock.unlock() }; return value }
    }
    private enum Failure: Error { case invalidProtocol, timedOut }
    private func sha(_ data:Data)->String { SHA256.hash(data:data).map { String(format:"%02x",$0) }.joined() }
    private func input() throws -> Addendum {
        let url=try XCTUnwrap(Bundle(for:Self.self).url(forResource:"JOURNEY_ADDENDUM",withExtension:"json",subdirectory:"RoomRouteDiagnostic"))
        let data=try Data(contentsOf:url)
        XCTAssertEqual(sha(data),digest)
        let value=try JSONDecoder().decode(Addendum.self,from:data)
        XCTAssertEqual(value.schema,1); XCTAssertEqual(value.baseProtocolSHA256,baselineDigest)
        XCTAssertEqual(value.width28ProfileSHA256,width28Digest); XCTAssertTrue(value.preregisteredBeforeFirstNativeExecution)
        XCTAssertFalse(value.physicalAuthority); XCTAssertFalse(value.cameraLocalizationTested); XCTAssertFalse(value.getUpKinematicsTested)
        XCTAssertEqual(value.journeys.count,5); XCTAssertEqual(value.journeys.reduce(0) { $0+$1.stages.count },16)
        XCTAssertEqual(value.declaredHeadingFloorLocal,[1,0,0])
        XCTAssertEqual(value.profile.width,0.28); XCTAssertEqual(value.profile.depth,0.20)
        XCTAssertEqual(value.profile.height,1.20); XCTAssertEqual(value.profile.margin,0.15)
        return value
    }
    private func mesh(_ room:String) async throws -> SavedRoomRouteMeshSnapshot {
        let expected=try XCTUnwrap(sourceDigests[room])
        let url=try XCTUnwrap(Bundle(for:Self.self).url(forResource:"\(room).capturedRoom",withExtension:"json",subdirectory:"RoomPlanApple"))
        let data=try Data(contentsOf:url); XCTAssertEqual(sha(data),expected)
        return try await Task.detached(priority:.utility) { try SavedRoomRouteMeshAdapter.decode(data:data,expectedSHA256:expected) }.value
    }
    private func world(_ p:[Double],floor:SavedRoomRouteMeshSnapshot.Feature)throws->SIMD3<Float> {
        guard p.count==3,p.allSatisfy(\.isFinite),floor.kind == .floor,floor.transform.count==16 else { throw Failure.invalidProtocol }
        let t=floor.transform
        var coordinates: [Float] = []
        for row in 0..<3 {
            let x: Double = t[row] * p[0]
            let y: Double = t[4 + row] * p[1]
            let z: Double = t[8 + row] * p[2]
            let component: Double = ((x + y) + z) + t[12 + row]
            coordinates.append(Float(component))
        }
        return SIMD3<Float>(coordinates[0], coordinates[1], coordinates[2])
    }
    private func standing(_ journey:Journey,snapshot:SavedRoomRouteMeshSnapshot,floor:SavedRoomRouteMeshSnapshot.Feature)throws->SIMD3<Float> {
        if let p=journey.standingFloorLocal { guard journey.standingFeatureFootCenter==nil else { throw Failure.invalidProtocol }; return try world(p,floor:floor) }
        let id=try XCTUnwrap(journey.standingFeatureFootCenter)
        let item=try XCTUnwrap(snapshot.features.first { $0.id==id && $0.kind == .furniture })
        let t=floor.transform,d=(0..<3).map { item.transform[12+$0]-t[12+$0] }
        let x=(0..<3).reduce(0.0) { $0+t[$1]*d[$1] },y=(0..<3).reduce(0.0) { $0+t[4+$1]*d[$1] }
        return try world([x,y,0],floor:floor)
    }
    private func query(_ owner:RoomMeshCandidateRuntime,from:SIMD3<Float>,to:SIMD3<Float>,profile:Profile)async throws->Result<MeshCandidateRoute,MeshCandidateError> {
        let done=expectation(description:"journey native candidate query"), box=Box()
        owner.request(start:[from.x,from.y,from.z],goal:[to.x,to.y,to.z],
            body:try .init(radius:profile.effectiveRadius,height:profile.effectiveHeight)) { box.put($0); done.fulfill() }
        await fulfillment(of:[done],timeout:15)
        guard let value=box.get() else { throw Failure.timedOut }; return value
    }
    private func discard(_ owner:RoomMeshCandidateRuntime)async {
        let done=expectation(description:"journey owner terminal discard")
        owner.stopAndDiscard { done.fulfill() }; await fulfillment(of:[done],timeout:15)
    }
    private func array(_ p:SIMD3<Float>)->[Float] { [p.x,p.y,p.z] }
    private func vector(_ p:[Float])throws->SIMD3<Float> { guard p.count==3,p.allSatisfy(\.isFinite) else { throw Failure.invalidProtocol }; return SIMD3(p[0],p[1],p[2]) }
    private func report(_ rows:[[String:Any]],errors:[String])throws {
        let data=try JSONSerialization.data(withJSONObject:["schema":1,"protocolSHA256":digest,
            "baseline18Unchanged":true,"suppliedPoseCandidateReplayOnly":true,"cameraLocalizationTested":false,
            "getUpKinematicsTested":false,"fullFootprintSupportVerified":false,"physicalAuthority":false,
            "productionGuidanceCode":["SpatialFacts.relation","SpatialFacts.phrase","GuidanceCadence.label"],
            "sustainedControllerTested":false,"VoiceOverTested":false,"outcomes":rows,"errors":errors],options:[.prettyPrinted,.sortedKeys])
        let attachment=XCTAttachment(data:data,uniformTypeIdentifier:"public.json")
        attachment.name="APPLE_SUPPLIED_POSTURE_JOURNEY_OUTCOMES.json"; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testSeatedMissingWrongFrameAndUnknownHeadingDoNotBecomePositionFinding() throws {
        let spec=try input(),expected=try XCTUnwrap(sourceDigests["Bedroom3"])
        let p=SIMD3<Float>(0,0,0)
        XCTAssertFalse(SuppliedPose(sourceSHA256:expected,position:p,standing:false,heading:nil).matches(expected))
        XCTAssertFalse(SuppliedPose(sourceSHA256:"wrong-room",position:p,standing:true,heading:nil).matches(expected))
        let absent:SuppliedPose?=nil; XCTAssertNil(absent)
        XCTAssertNil(SpatialFacts.relation(from:Point3(0,0,0),facing:Point3(0,0,0),to:Point3(1,0,0)))
        XCTAssertFalse(spec.cameraLocalizationTested); XCTAssertFalse(spec.getUpKinematicsTested)
    }

    func testPredeclaredSuppliedBedChairConnectorsAroundRoomDoorWithholdingAndReturn() async throws {
        let spec=try input(),profile=spec.profile
        var rows:[[String:Any]]=[],errors:[String]=[]
        var wroteReport=false,completedSegments=0,guidanceReceipts=0,collisionCandidates=0
        defer {
            if !wroteReport {
                let completed=Set(rows.compactMap { r -> String? in guard let j=r["journey"] as? String,let s=r["stage"] as? String else { return nil }; return j+":"+s })
                for journey in spec.journeys { for stage in journey.stages where !completed.contains(journey.id+":"+stage.id) {
                    rows.append(["journey":journey.id,"stage":stage.id,"outcome":"not-run-after-aborted-stage"])
                } }
                errors.append("Stage aborted; unexecuted schedules are not arrivals")
                try? report(rows,errors:errors)
            }
        }
        for room in Set(spec.journeys.map(\.room)).sorted() {
            let snapshot:SavedRoomRouteMeshSnapshot
            do { snapshot=try await mesh(room) }
            catch {
                for journey in spec.journeys where journey.room==room { for stage in journey.stages {
                    rows.append(["journey":journey.id,"stage":stage.id,"outcome":"unsupported-geometry","error":String(describing:error)])
                } }
                errors.append("\(room): \(error)"); continue
            }
            let floor=try XCTUnwrap(snapshot.features.first { $0.kind == .floor })
            guard snapshot.upwardFloorTriangles>0 else { throw Failure.invalidProtocol }
            let boxes=snapshot.features.filter { $0.kind == .furniture }.map { SavedRoomRouteCollisionOracle.FurnitureBox(featureID:$0.id,dimensions:$0.dimensions,transform:$0.transform) }
            let oracle=try SavedRoomRouteCollisionOracle(vertices:snapshot.vertices,triangles:snapshot.triangles,
                floorSupport:snapshot.floorSupport,triangleFeatureIDs:snapshot.triangleFeatureIDs,furnitureBoxes:boxes)
            let heading=try world(spec.declaredHeadingFloorLocal,floor:floor)-world([0,0,0],floor:floor)
            for journey in spec.journeys where journey.room==room {
                if let seated=journey.seatedFeatureID {
                    let feature=try XCTUnwrap(snapshot.features.first { $0.id==seated && $0.kind == .furniture })
                    XCTAssertTrue(["bed","chair"].contains(feature.category))
                }
                var current=try standing(journey,snapshot:snapshot,floor:floor)
                let originalStanding=current
                var stopped=false
                let session="journey-\(UUID().uuidString)"
                let owner=try RoomMeshCandidateRuntime(sessionID:session,supportPolicy:.classifiedFloorOnly)
                defer { owner.stopAndDiscard {} }
                XCTAssertTrue(owner.offer(.init(sessionID:session,generation:0,anchorID:snapshot.sourceSHA256,revision:1,
                    timestamp:0,vertices:snapshot.vertices,triangles:snapshot.triangles,
                    columnMajorTransform:[1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1],complete:true,
                    triangleSupport:snapshot.floorSupport.map { $0 ? .floor : .obstacle })))
                for stage in journey.stages {
                    if stopped { rows.append(["journey":journey.id,"stage":stage.id,"outcome":"not-run-after-journey-stop"]); continue }
                    let goal=try world(stage.goal,floor:floor)
                    let pose=SuppliedPose(sourceSHA256:snapshot.sourceSHA256,position:current,standing:true,heading:heading)
                    guard pose.matches(snapshot.sourceSHA256) else { throw Failure.invalidProtocol }
                    // Query always precedes independent scoring. No collision
                    // feedback is used to choose/repair a route or move furniture.
                    let candidate=try await query(owner,from:current,to:goal,profile:profile)
                    let startBody=try oracle.sweep(from:current,to:current,radius:profile.radius,height:Float(profile.height))
                    let startMargin=try oracle.sweep(from:current,to:current,radius:profile.effectiveRadius,height:profile.effectiveHeight)
                    let invalidStart=startBody.all.hasObstacleContact || startMargin.all.hasObstacleContact
                    if journey.expectsInvalidStandingStart == true { XCTAssertTrue(invalidStart,"Standing inside original furniture remains invalid") }
                    var row:[String:Any]=["journey":journey.id,"stage":stage.id,"sourceSHA256":snapshot.sourceSHA256,
                        "seatedFeatureID":journey.seatedFeatureID?.uuidString ?? "none","seatedObservationIsAuthored":true,
                        "originalSuppliedStandingPoint":array(originalStanding),"requestedStart":array(current),"requestedGoal":array(goal),
                        "declaredHeading":array(heading),"physicalAuthority":false,"cameraLocalizationTested":false,
                        "getUpKinematicsTested":false,"initialBodyContact":startBody.all.hasObstacleContact,
                        "initialMarginContact":startMargin.all.hasObstacleContact,"expectedWithhold":stage.expectedWithhold]
                    if let doorID=stage.doorID {
                        let door=try XCTUnwrap(snapshot.features.first { $0.id==doorID && $0.kind == .door })
                        row["historicalDoorOpen"]=try XCTUnwrap(door.capturedDoorOpen); row["currentDoorStateKnown"]=false
                        if stage.expectedWithhold,door.capturedDoorOpen == false {
                            let direct=try oracle.sweep(from:current,to:goal,radius:profile.effectiveRadius,height:profile.effectiveHeight)
                            row["closedDoorStraightProbeContactIDs"]=direct.all.obstacleSurfaceIDs.map(\.uuidString).sorted()
                            XCTAssertTrue(direct.all.obstacleSurfaceIDs.contains(doorID),"Closed original door must remain a blocking surface, separately from wall cutout")
                        }
                    }
                    switch candidate {
                    case .failure(let error):
                        row["outcome"]=invalidStart ? "invalid-standing-start-contact" : (stage.expectedWithhold ? "expected-withheld-outbound" : "native-query-failure")
                        row["nativeError"]=String(describing:error); row["guidanceDelivered"]=false
                        if !stage.expectedWithhold || invalidStart { stopped=true }
                    case .success(let route):
                        let ps=try vector(route.projectedStart),pg=try vector(route.projectedGoal)
                        row["nativeComplete"]=route.complete; row["nativeStatus"]=route.nativeStatus; row["routePoints"]=route.points
                        row["projectedStart"]=route.projectedStart; row["projectedGoal"]=route.projectedGoal
                        row["startProjectionMetres"]=simd_distance(current,ps); row["goalProjectionMetres"]=simd_distance(goal,pg)
                        let points=try route.points.map(vector)
                        guard let first=points.first,let last=points.last else { throw Failure.invalidProtocol }
                        var segments=[CandidateSegment(kind:"requested-start-to-projection",from:current,to:ps)]
                        // Detour may clamp a straight-path endpoint to its poly
                        // boundary. Preserve any exact discrepancy as its own
                        // scored/cued association connector, never a teleport.
                        if first != ps { segments.append(CandidateSegment(kind:"projection-to-detour-start",from:ps,to:first)) }
                        if points.count>1 { for i in 1..<points.count {
                            segments.append(CandidateSegment(kind:"detour-segment-\(i)",from:points[i-1],to:points[i]))
                        } }
                        if route.complete {
                            if last != pg { segments.append(CandidateSegment(kind:"detour-end-to-projection",from:last,to:pg)) }
                            segments.append(CandidateSegment(kind:"projection-to-requested-goal",from:pg,to:goal))
                        }
                        var sink=CodeGuidanceSink()
                        XCTAssertFalse(sink.deliver(route:route,owner:owner,segments:segments,pose:nil,expectedSource:snapshot.sourceSHA256,stageID:stage.id))
                        XCTAssertFalse(sink.deliver(route:route,owner:owner,segments:segments,pose:SuppliedPose(sourceSHA256:"wrong",position:current,standing:true,heading:heading),expectedSource:snapshot.sourceSHA256,stageID:stage.id))
                        XCTAssertFalse(sink.deliver(route:route,owner:owner,segments:segments,pose:SuppliedPose(sourceSHA256:snapshot.sourceSHA256,position:current,standing:true,heading:nil),expectedSource:snapshot.sourceSHA256,stageID:stage.id))
                        let delivered=sink.deliver(route:route,owner:owner,segments:segments,pose:pose,expectedSource:snapshot.sourceSHA256,stageID:stage.id)
                        row["guidanceDelivered"]=delivered; row["productionGuidanceReceipts"]=sink.receipts
                        guidanceReceipts += sink.receipts.count
                        for receipt in sink.receipts {
                            let index=try XCTUnwrap(receipt["segmentIndex"] as? Int)
                            XCTAssertTrue(segments.indices.contains(index))
                            guard segments.indices.contains(index) else { throw Failure.invalidProtocol }
                            XCTAssertEqual(receipt["from"] as? [Float],array(segments[index].from))
                            XCTAssertEqual(receipt["to"] as? [Float],array(segments[index].to))
                        }
                        var bodyContact=startBody.all.hasObstacleContact,marginContact=startMargin.all.hasObstacleContact
                        var floorIDs=startMargin.all.floorSurfaceIDs,surfaceIDs=startMargin.all.obstacleSurfaceIDs,boundIDs=startMargin.all.furnitureBoundIDs
                        var scored:[[String:Any]]=[]
                        for segment in segments {
                            let name=segment.kind,a=segment.from,b=segment.to
                            let raw=try oracle.sweep(from:a,to:b,radius:profile.radius,height:Float(profile.height))
                            let margin=try oracle.sweep(from:a,to:b,radius:profile.effectiveRadius,height:profile.effectiveHeight)
                            bodyContact = bodyContact || raw.all.hasObstacleContact; marginContact = marginContact || margin.all.hasObstacleContact
                            floorIDs.formUnion(margin.all.floorSurfaceIDs); surfaceIDs.formUnion(margin.all.obstacleSurfaceIDs); boundIDs.formUnion(margin.all.furnitureBoundIDs)
                            scored.append(["kind":name,"from":array(a),"to":array(b),"bodyContact":raw.all.hasObstacleContact,"marginContact":margin.all.hasObstacleContact])
                        }
                        row["segments"]=scored; row["bodyContact"]=bodyContact; row["marginContact"]=marginContact
                        row["floorContactIDs"]=floorIDs.map(\.uuidString).sorted(); row["obstacleSurfaceIDs"]=surfaceIDs.map(\.uuidString).sorted(); row["furnitureBoundIDs"]=boundIDs.map(\.uuidString).sorted()
                        row["fullFootprintSupportVerified"]=false
                        if invalidStart { row["outcome"]="invalid-standing-start-contact"; stopped=true }
                        else if !route.complete { row["outcome"]=stage.expectedWithhold ? "expected-withheld-partial" : "partial-route"; stopped = !stage.expectedWithhold }
                        else if bodyContact || marginContact { row["outcome"]="candidate-contact"; collisionCandidates += 1; stopped=true }
                        else if stage.expectedWithhold { row["outcome"]="unexpected-outbound-completion"; errors.append("\(journey.id)/\(stage.id) crossed withheld original support/state"); stopped=true }
                        else {
                            row["outcome"]="modeled-segment-candidate-no-contact"; completedSegments += 1
                            // Ideal replay progress only, after sweeping BOTH
                            // projection connectors; no person/camera is snapped.
                            current=goal
                        }
                        if invalidStart && route.complete { collisionCandidates += 1 }
                        if stage.expectedWithhold { XCTAssertFalse(route.complete,"No inferred open door or outside floor") }
                        owner.invalidate(); sink.retire()
                        XCTAssertFalse(sink.deliver(route:route,owner:owner,segments:segments,pose:pose,expectedSource:snapshot.sourceSHA256,stageID:stage.id))
                    }
                    row["replayPositionAfterStage"]=array(current); rows.append(row)
                }
                await discard(owner)
            }
        }
        try report(rows,errors:errors); wroteReport=true
        XCTAssertEqual(rows.count,16); XCTAssertTrue(errors.isEmpty,errors.joined(separator:"; "))
        XCTAssertGreaterThan(completedSegments,0,"No-path/stopped journeys are not successful motion")
        XCTAssertGreaterThan(guidanceReceipts,0,"Production formatter/cadence was not exercised")
        XCTAssertEqual(collisionCandidates,0,"Contacting candidate or invalid standing start is a failed proposed movement")
    }
}
