// Isolated public-fixture comparison. No app activation or physical authority.
import Foundation
import SceneKit
import simd
import StrictEndpointProbe

private enum ProbeFailure: Error { case invalidInput, outputLimit }
private struct Box: Decodable { let featureID: UUID; let dimensions, transform: [Double] }
private struct Fixture: Decodable {
    let fixtureID, sourceSHA256: String
    let worldPositionBits: [UInt32]
    let triangleIndices: [Int32]
    let floorSupport: [Bool]
    let triangleFeatureIDs: [UUID]
    let furnitureBoxes: [Box]
}
private struct Geometry: Decodable {
    let schema, representation, coordinateEncoding, frame: String
    let complete, physicalAuthority, fullFootprintSupportVerified: Bool
    let fixtures: [Fixture]
}
private struct ExpectedSegment: Decodable {
    let kind: String
    let from, to: [Float]
    let bodyContact, marginContact: Bool
}
private struct Request: Decodable {
    let id, fixtureSHA256, profile, expectedOutcome: String
    let requestedStart, requestedGoal: [Float]
    let rawRadius, rawHeight, effectiveRadius, effectiveHeight: Float
    let expectedNativeSucceeded, expectedComplete, expectedInitialBodyContact, expectedInitialMarginContact: Bool
    let expectedRoutePoints: [[Float]]?
    let expectedProjectedStart, expectedProjectedGoal: [Float]?
    let expectedBodyContact, expectedMarginContact: Bool?
    let expectedSegments: [ExpectedSegment]?
}
private struct Requests: Decodable {
    let schema, sourceCommit, unitCaseJSONSHA256: String
    let nativeRun: Int
    let physicalAuthority: Bool
    let requests: [Request]
}
private struct Segment { let kind: String; let from, to: [Float] }
private func vector(_ p: [Float]) throws -> SIMD3<Float> {
    guard p.count == 3, p.allSatisfy(\.isFinite) else { throw ProbeFailure.invalidInput }
    return SIMD3(p[0],p[1],p[2])
}
private func sameBits(_ a: [Float], _ b: [Float]) -> Bool { a.map(\.bitPattern) == b.map(\.bitPattern) }
private func sameBits(_ a: [[Float]], _ b: [[Float]]) -> Bool {
    a.count == b.count && zip(a,b).allSatisfy { sameBits($0.0,$0.1) }
}
private func chain(start: [Float], goal: [Float], projectedStart: [Float], projectedGoal: [Float],
                   points: [[Float]], complete: Bool) throws -> [Segment] {
    guard let first=points.first, let last=points.last else { throw ProbeFailure.invalidInput }
    var rows=[Segment(kind:"requested-start-to-projection",from:start,to:projectedStart)]
    if first != projectedStart { rows.append(.init(kind:"projection-to-detour-start",from:projectedStart,to:first)) }
    if points.count>1 { for i in 1..<points.count { rows.append(.init(kind:"detour-segment-\(i)",from:points[i-1],to:points[i])) } }
    if complete {
        if last != projectedGoal { rows.append(.init(kind:"detour-end-to-projection",from:last,to:projectedGoal)) }
        rows.append(.init(kind:"projection-to-requested-goal",from:projectedGoal,to:goal))
    }
    return rows
}
private func associate(_ h: UnsafeMutableRawPointer, _ p: [Float]) -> [String:Any] {
    let extents:[Float]=[0.2,0.3,0.2];var projected=[Float](repeating:0,count:3);var inside:Int32=0
    let found=p.withUnsafeBufferPointer { a in extents.withUnsafeBufferPointer { e in
        projected.withUnsafeMutableBufferPointer { q in
            bn_probe_association(h,a.baseAddress,e.baseAddress,q.baseAddress,&inside)
        }
    }}
    return ["found":found != 0,"isOverPoly":inside != 0,"requested":p,"projected":projected,
            "physicalAuthority":false]
}
@MainActor private func score(_ oracle: SavedRoomRouteCollisionOracle, _ r: Request,
                            _ segments: [Segment]) throws -> (Bool,Bool,[[String:Any]]) {
    var body=false,margin=false,rows:[[String:Any]]=[]
    for segment in segments {
        let a=try vector(segment.from),b=try vector(segment.to)
        let raw=try oracle.sweep(from:a,to:b,radius:r.rawRadius,height:r.rawHeight)
        let padded=try oracle.sweep(from:a,to:b,radius:r.effectiveRadius,height:r.effectiveHeight)
        body = body || raw.all.hasObstacleContact; margin = margin || padded.all.hasObstacleContact
        rows.append(["kind":segment.kind,"from":segment.from,"to":segment.to,
            "bodyContact":raw.all.hasObstacleContact,"marginContact":padded.all.hasObstacleContact,
            "obstacleSurfaceIDs":padded.all.obstacleSurfaceIDs.map(\.uuidString).sorted(),
            "furnitureBoundIDs":padded.all.furnitureBoundIDs.map(\.uuidString).sorted(),
            "floorContactIDs":padded.all.floorSurfaceIDs.map(\.uuidString).sorted(),
            "fullFootprintSupportVerified":false])
    }
    return (body,margin,rows)
}
@MainActor private func makeOracle(_ fixture: Fixture) throws -> SavedRoomRouteCollisionOracle {
    let vertices=fixture.worldPositionBits.map(Float.init(bitPattern:))
    let boxes=fixture.furnitureBoxes.map { SavedRoomRouteCollisionOracle.FurnitureBox(featureID:$0.featureID,
        dimensions:$0.dimensions,transform:$0.transform) }
    // Exact unchanged native collision oracle source is compiled into this probe.
    return try SavedRoomRouteCollisionOracle(vertices:vertices.map(Double.init),triangles:fixture.triangleIndices,
        floorSupport:fixture.floorSupport,triangleFeatureIDs:fixture.triangleFeatureIDs,furnitureBoxes:boxes)
}
@MainActor private func run(_ fixture: Fixture, _ r: Request, strict: Bool,
                           oracle: SavedRoomRouteCollisionOracle) throws -> [String:Any] {
    let vertices=fixture.worldPositionBits.map(Float.init(bitPattern:))
    let support:[UInt8]=fixture.floorSupport.map { $0 ? 1 : 0 }
    let initial=try score(oracle,r,[.init(kind:"initial",from:r.requestedStart,to:r.requestedStart)])
    var config=BNConfig(radius:r.effectiveRadius,height:r.effectiveHeight,cell_size:0.025,cell_height:0.025,
        max_climb:0.025,max_slope:15,max_cells:250000,max_nodes:4096)
    let handle=vertices.withUnsafeBufferPointer { v in fixture.triangleIndices.withUnsafeBufferPointer { t in
        support.withUnsafeBufferPointer { s in
            bn_build_classified(v.baseAddress,Int32(vertices.count/3),t.baseAddress,Int32(fixture.triangleIndices.count/3),&config,s.baseAddress)
        }
    }}
    var row:[String:Any]=["requestID":r.id,"fixtureSHA256":fixture.sourceSHA256,"profile":r.profile,
        "endpointPolicy":strict ? "requireSuppliedXZOverPolygon" : "legacyNearestProjection",
        "maxSimplificationErrorCells":0.5,"physicalAuthority":false,
        "initialBodyContact":initial.0,"initialMarginContact":initial.1,"initialContactReceipt":initial.2,
        "rawRadius":r.rawRadius,"effectiveRadius":r.effectiveRadius,"effectiveHeight":r.effectiveHeight]
    var matches=initial.0 == r.expectedInitialBodyContact && initial.1 == r.expectedInitialMarginContact
    guard let h=handle else {
        row["nativeSucceeded"]=false; row["buildFailed"]=true
        row["baselineMatches49a"]=matches && !r.expectedNativeSucceeded
        return row
    }
    defer { bn_destroy(h) }
    row["startAssociation"]=associate(h,r.requestedStart)
    row["goalAssociation"]=associate(h,r.requestedGoal)
    let extents:[Float]=[0.2,0.3,0.2]
    var flat=[Float](repeating:0,count:256*3),ps=[Float](repeating:0,count:3),pg=[Float](repeating:0,count:3)
    var status:UInt32=0,complete:Int32=0
    var strictStart=BNEndpointAssociation(),strictGoal=BNEndpointAssociation()
    let count=r.requestedStart.withUnsafeBufferPointer { a in r.requestedGoal.withUnsafeBufferPointer { b in
        extents.withUnsafeBufferPointer { e in flat.withUnsafeMutableBufferPointer { p in
            ps.withUnsafeMutableBufferPointer { s in pg.withUnsafeMutableBufferPointer { g in
                strict ? bn_path_strict(h,a.baseAddress,b.baseAddress,e.baseAddress,p.baseAddress,256,s.baseAddress,g.baseAddress,&status,&complete,&strictStart,&strictGoal) :
                       bn_path(h,a.baseAddress,b.baseAddress,e.baseAddress,p.baseAddress,256,s.baseAddress,g.baseAddress,&status,&complete)
            }}
        }}
    }}
    if strict {
        func receipt(_ value:BNEndpointAssociation,_ requested:[Float])->[String:Any] {
            ["requested":requested,"projected":[value.projected.0,value.projected.1,value.projected.2],
             "found":value.found != 0,"isOverPolygon":value.is_over_polygon != 0,"nativeStatus":value.status]
        }
        row["strictAdmission"]=["policy":"requireSuppliedXZOverPolygon","physicalAuthority":false,
            "start":receipt(strictStart,r.requestedStart),"goal":receipt(strictGoal,r.requestedGoal)]
        row["endpointAdmissionRejected"]=strictStart.is_over_polygon == 0 || strictGoal.is_over_polygon == 0
    }
    row["nativeSucceeded"]=count>=0;row["nativeStatus"]=status;row["nativeComplete"]=complete != 0
    matches = matches && (count>=0) == r.expectedNativeSucceeded && (complete != 0) == r.expectedComplete
    if count<0 {
        row["baselineMatches49a"]=matches
        if let error=bn_last_error() { row["nativeError"]=String(cString:error) }
        return row
    }
    guard count>0,count<=256 else { throw ProbeFailure.invalidInput }
    let points=stride(from:0,to:Int(count)*3,by:3).map { Array(flat[$0..<($0+3)]) }
    let segments=try chain(start:r.requestedStart,goal:r.requestedGoal,projectedStart:ps,projectedGoal:pg,points:points,complete:complete != 0)
    let contacts=try score(oracle,r,segments)
    row["routePoints"]=points;row["projectedStart"]=ps;row["projectedGoal"]=pg
    row["bodyContact"]=contacts.0 || initial.0;row["marginContact"]=contacts.1 || initial.1;row["segments"]=contacts.2
    if let expected=r.expectedRoutePoints { matches = matches && sameBits(points,expected) } else { matches=false }
    if let expected=r.expectedProjectedStart { matches = matches && sameBits(ps,expected) } else { matches=false }
    if let expected=r.expectedProjectedGoal { matches = matches && sameBits(pg,expected) } else { matches=false }
    if let expected=r.expectedBodyContact { matches = matches && (contacts.0 || initial.0) == expected } else { matches=false }
    if let expected=r.expectedMarginContact { matches = matches && (contacts.1 || initial.1) == expected } else { matches=false }
    if let expected=r.expectedSegments {
        matches = matches && expected.count == contacts.2.count
        for (actual,wanted) in zip(contacts.2,expected) {
            matches = matches && (actual["kind"] as? String) == wanted.kind && (actual["bodyContact"] as? Bool) == wanted.bodyContact &&
                (actual["marginContact"] as? Bool) == wanted.marginContact
            if let from=actual["from"] as? [Float], let to=actual["to"] as? [Float] {
                matches = matches && sameBits(from,wanted.from) && sameBits(to,wanted.to)
            } else { matches=false }
        }
    } else { matches=false }
    row["baselineMatches49a"]=matches
    return row
}
@main private struct Runner {
    @MainActor static func main() throws {
        guard CommandLine.arguments.count==4 else { throw ProbeFailure.invalidInput }
        let geometryData=try Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[1]))
        let requestData=try Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[2]))
        guard geometryData.count<=131072,requestData.count<=131072 else { throw ProbeFailure.invalidInput }
        let g=try JSONDecoder().decode(Geometry.self,from:geometryData),q=try JSONDecoder().decode(Requests.self,from:requestData)
        let allowed=["Hallway2":"f4cf3460fd9e746a86fe6538e2b1980e22e18207a2d3c7ea3f7679f58c8c6f4d",
                     "Bedroom3":"44df7bd5f4d1961bf13344916384dcfa20d42c7ef8dc58b0e13d1c2f7c6a4d2e"]
        guard g.schema=="blind.public-apple-packed-routing-geometry.v1",g.representation=="final-adapter-routing-input",
              g.coordinateEncoding=="float32-bit-patterns",g.frame=="original-saved-world-y-up-metres",g.complete,
              !g.physicalAuthority,!g.fullFootprintSupportVerified,g.fixtures.count==2,
              Set(g.fixtures.map(\.fixtureID)).count==2,q.schema=="blind.public-fixed-contour-requests.v1",
              q.sourceCommit=="49a9878c51dc97214cdfacf74946d8f2816597f0",q.nativeRun==40773062534,
              !q.physicalAuthority,q.requests.count==25,Set(q.requests.map(\.id)).count==25 else { throw ProbeFailure.invalidInput }
        for f in g.fixtures {
            guard allowed[f.fixtureID]==f.sourceSHA256,!f.worldPositionBits.isEmpty,f.worldPositionBits.count%3==0,
                  f.worldPositionBits.count<=6144,f.worldPositionBits.map(Float.init(bitPattern:)).allSatisfy({ $0.isFinite && abs($0)<=10000 }),
                  !f.triangleIndices.isEmpty,f.triangleIndices.count%3==0,f.triangleIndices.count<=3072,
                  f.triangleIndices.allSatisfy({$0>=0 && Int($0)<f.worldPositionBits.count/3}),
                  f.floorSupport.count==f.triangleIndices.count/3,f.triangleFeatureIDs.count==f.floorSupport.count,
                  f.furnitureBoxes.count<=64 else { throw ProbeFailure.invalidInput }
        }
        var rows:[[String:Any]]=[]
        for strict in [false,true] {
            // Match the original test's one static physics world per report/room,
            // and preserve original query order within that world.
            var currentGroup:String?=nil
            var currentOracle:SavedRoomRouteCollisionOracle?=nil
            for r in q.requests {
            guard let f=g.fixtures.first(where:{$0.sourceSHA256==r.fixtureSHA256}),
                  [r.rawRadius,r.rawHeight,r.effectiveRadius,r.effectiveHeight].allSatisfy(\.isFinite),
                  r.effectiveRadius>=r.rawRadius,r.effectiveHeight>=r.rawHeight else { throw ProbeFailure.invalidInput }
            _=try vector(r.requestedStart);_=try vector(r.requestedGoal)
            let key=String(r.id.prefix { $0 != ":" })+"|"+r.fixtureSHA256
            if currentGroup != key {
                currentOracle=nil // retire the previous room, not six retained worlds
                currentOracle=try autoreleasepool { try makeOracle(f) }
                currentGroup=key
            }
            guard let oracle=currentOracle else { throw ProbeFailure.invalidInput }
            rows.append(try autoreleasepool { try run(f,r,strict:strict,oracle:oracle) })
        }}
        let reproduced=rows.prefix(25).allSatisfy { $0["baselineMatches49a"] as? Bool == true }
        // A strict implementation that rejects every query must NOT pass. Derive
        // fixture-specific admission expectations from the independently queried
        // legacy associations, then require both known refusals and retained paths.
        let legacyRows=Array(rows.prefix(25)),strictRows=Array(rows.suffix(25))
        let knownRefusals:Set<String>=[
            "APPLE_ROOM_ROUTE_width28-addendum_OUTCOMES.json:bedroom-aisle:declared-width28-assumed-depth20-height120",
            "APPLE_SUPPLIED_POSTURE_JOURNEY_OUTCOMES.json:bed-supplied-rise-around-closed-door-return:connector-to-existing-aisle-route",
            "APPLE_SUPPLIED_POSTURE_JOURNEY_OUTCOMES.json:chair-supplied-rise-around-closed-door-return:connector-to-existing-aisle-route"]
        var admissionMatches=true,retained=0,baselineSucceeded=0,rejectedSuccessIDs=Set<String>()
        var admissionChecks:[[String:Any]]=[]
        func sameAssociation(_ strict:[String:Any]?,_ legacy:[String:Any]?) -> Bool {
            guard let a=strict,let b=legacy,
                  let ar=a["requested"] as? [Float],let br=b["requested"] as? [Float],
                  let ap=a["projected"] as? [Float],let bp=b["projected"] as? [Float] else { return false }
            return (a["found"] as? Bool)==(b["found"] as? Bool) &&
                (a["isOverPolygon"] as? Bool)==(b["isOverPoly"] as? Bool) && sameBits(ar,br) && sameBits(ap,bp)
        }
        for (legacy,strict) in zip(legacyRows,strictRows) {
            let id=legacy["requestID"] as? String ?? "missing-request-id"
            var matches=(strict["requestID"] as? String)==id &&
                (strict["initialBodyContact"] as? Bool)==(legacy["initialBodyContact"] as? Bool) &&
                (strict["initialMarginContact"] as? Bool)==(legacy["initialMarginContact"] as? Bool)
            var expectedAdmission=false
            if legacy["nativeSucceeded"] as? Bool == true {
                baselineSucceeded+=1
                let start=legacy["startAssociation"] as? [String:Any],goal=legacy["goalAssociation"] as? [String:Any]
                expectedAdmission=start?["found"] as? Bool == true && start?["isOverPoly"] as? Bool == true &&
                    goal?["found"] as? Bool == true && goal?["isOverPoly"] as? Bool == true
                let receipt=strict["strictAdmission"] as? [String:Any]
                matches = matches && sameAssociation(receipt?["start"] as? [String:Any],start) &&
                    sameAssociation(receipt?["goal"] as? [String:Any],goal)
                if expectedAdmission {
                    retained+=1
                    matches = matches && strict["nativeSucceeded"] as? Bool == true &&
                        strict["nativeComplete"] as? Bool == true && strict["baselineMatches49a"] as? Bool == true &&
                        strict["endpointAdmissionRejected"] as? Bool == false
                } else {
                    rejectedSuccessIDs.insert(id)
                    matches = matches && strict["nativeSucceeded"] as? Bool == false &&
                        strict["nativeComplete"] as? Bool == false && strict["nativeStatus"] as? UInt32 == 0 &&
                        strict["endpointAdmissionRejected"] as? Bool == true && strict["routePoints"] == nil
                }
            } else {
                matches = matches && strict["nativeSucceeded"] as? Bool == false && strict["routePoints"] == nil
            }
            admissionMatches = admissionMatches && matches
            admissionChecks.append(["requestID":id,"baselineNativeSucceeded":legacy["nativeSucceeded"] as? Bool ?? false,
                "expectedStrictAdmissionForBaselineSuccess":expectedAdmission,"matched":matches])
        }
        let strictSuccesses=strictRows.filter { $0["nativeSucceeded"] as? Bool == true }
        let retainedCorners=strictSuccesses.filter { ($0["requestID"] as? String)?.contains(":hall-corner:") == true }
        let cornersRemain=retainedCorners.count==2 && retainedCorners.allSatisfy {
            $0["bodyContact"] as? Bool == false && $0["marginContact"] as? Bool == true
        }
        admissionMatches = admissionMatches && baselineSucceeded==11 && retained==8 && strictSuccesses.count==8 &&
            rejectedSuccessIDs==knownRefusals && cornersRemain
        let acceptedStrictMatches=strictSuccesses.count==8 && strictSuccesses.allSatisfy { $0["baselineMatches49a"] as? Bool == true }
        let output:[String:Any]=["schema":"blind.public-strict-endpoint-contrast.v1","physicalAuthority":false,
            "fullFootprintSupportVerified":false,"appActivation":false,"baseline49aReproduced":reproduced,"acceptedStrictPathsMatchLegacy":acceptedStrictMatches,
            "strictAdmissionMatchesIndependentLegacyExpectation":admissionMatches,
            "strictAdmissionChecks":admissionChecks,"baselineSuccessfulCorridors":baselineSucceeded,
            "strictRetainedCorridors":strictSuccesses.count,"knownProjectedSuccessfulStartsRejected":rejectedSuccessIDs.sorted(),
            "bothCornerMarginContactsRemain":cornersRemain,
            "strictDefaultOff":true,"policyRevision":"requested-xz-over-polygon-v1",
            "status":reproduced && acceptedStrictMatches && admissionMatches ? "baseline-reproduced-strict-admission-observed-corner-contacts-unresolved" : "baseline-or-admission-mismatch-strict-contrast-inconclusive",
            "platform":"macOS diagnostic; iOS confirmation required","requestsPerConfiguration":25,
            "preservedUnrunJourneyStages":9,"rows":rows]
        let data=try JSONSerialization.data(withJSONObject:output,options:[.sortedKeys,.prettyPrinted])
        guard data.count<=1048576 else { throw ProbeFailure.outputLimit }
        try data.write(to:URL(fileURLWithPath:CommandLine.arguments[3]),options:.atomic)
        print("Probe completed; baseline49aReproduced=\(reproduced); no physical authority")
    }
}
