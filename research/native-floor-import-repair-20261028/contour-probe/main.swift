// Isolated public-fixture comparison. No app activation or physical authority.
import Foundation
import SceneKit
import simd
import ContourProbe

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
private func associate(_ h: UnsafeMutableRawPointer, _ p: [Float], zero: Bool) -> [String:Any] {
    let extents:[Float]=[0.2,0.3,0.2];var projected=[Float](repeating:0,count:3);var inside:Int32=0
    let found=p.withUnsafeBufferPointer { a in extents.withUnsafeBufferPointer { e in
        projected.withUnsafeMutableBufferPointer { q in
            zero ? bn_zero_association(h,a.baseAddress,e.baseAddress,q.baseAddress,&inside) :
                   bn_base_association(h,a.baseAddress,e.baseAddress,q.baseAddress,&inside)
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
@MainActor private func run(_ fixture: Fixture, _ r: Request, zero: Bool,
                           oracle: SavedRoomRouteCollisionOracle) throws -> [String:Any] {
    let vertices=fixture.worldPositionBits.map(Float.init(bitPattern:))
    let support:[UInt8]=fixture.floorSupport.map { $0 ? 1 : 0 }
    let initial=try score(oracle,r,[.init(kind:"initial",from:r.requestedStart,to:r.requestedStart)])
    var config=BNConfig(radius:r.effectiveRadius,height:r.effectiveHeight,cell_size:0.025,cell_height:0.025,
        max_climb:0.025,max_slope:15,max_cells:250000,max_nodes:4096)
    let handle=vertices.withUnsafeBufferPointer { v in fixture.triangleIndices.withUnsafeBufferPointer { t in
        support.withUnsafeBufferPointer { s in
            zero ? bn_zero_build_classified(v.baseAddress,Int32(vertices.count/3),t.baseAddress,Int32(fixture.triangleIndices.count/3),&config,s.baseAddress) :
                   bn_base_build_classified(v.baseAddress,Int32(vertices.count/3),t.baseAddress,Int32(fixture.triangleIndices.count/3),&config,s.baseAddress)
        }
    }}
    var row:[String:Any]=["requestID":r.id,"fixtureSHA256":fixture.sourceSHA256,"profile":r.profile,
        "maxSimplificationErrorCells":zero ? 0.0 : 0.5,"physicalAuthority":false,
        "initialBodyContact":initial.0,"initialMarginContact":initial.1,"initialContactReceipt":initial.2,
        "rawRadius":r.rawRadius,"effectiveRadius":r.effectiveRadius,"effectiveHeight":r.effectiveHeight]
    var matches=initial.0 == r.expectedInitialBodyContact && initial.1 == r.expectedInitialMarginContact
    guard let h=handle else {
        row["nativeSucceeded"]=false; row["buildFailed"]=true
        row["baselineMatches49a"]=matches && !r.expectedNativeSucceeded
        return row
    }
    defer { if zero { bn_zero_destroy(h) } else { bn_base_destroy(h) } }
    row["startAssociation"]=associate(h,r.requestedStart,zero:zero)
    row["goalAssociation"]=associate(h,r.requestedGoal,zero:zero)
    let extents:[Float]=[0.2,0.3,0.2]
    var flat=[Float](repeating:0,count:256*3),ps=[Float](repeating:0,count:3),pg=[Float](repeating:0,count:3)
    var status:UInt32=0,complete:Int32=0
    let count=r.requestedStart.withUnsafeBufferPointer { a in r.requestedGoal.withUnsafeBufferPointer { b in
        extents.withUnsafeBufferPointer { e in flat.withUnsafeMutableBufferPointer { p in
            ps.withUnsafeMutableBufferPointer { s in pg.withUnsafeMutableBufferPointer { g in
                zero ? bn_zero_path(h,a.baseAddress,b.baseAddress,e.baseAddress,p.baseAddress,256,s.baseAddress,g.baseAddress,&status,&complete) :
                       bn_base_path(h,a.baseAddress,b.baseAddress,e.baseAddress,p.baseAddress,256,s.baseAddress,g.baseAddress,&status,&complete)
            }}
        }}
    }}
    row["nativeSucceeded"]=count>=0;row["nativeStatus"]=status;row["nativeComplete"]=complete != 0
    matches = matches && (count>=0) == r.expectedNativeSucceeded && (complete != 0) == r.expectedComplete
    if count<0 {
        row["baselineMatches49a"]=matches
        if let error=zero ? bn_zero_last_error() : bn_base_last_error() { row["nativeError"]=String(cString:error) }
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
        for zero in [false,true] {
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
            rows.append(try autoreleasepool { try run(f,r,zero:zero,oracle:oracle) })
        }}
        let reproduced=rows.prefix(25).allSatisfy { $0["baselineMatches49a"] as? Bool == true }
        let output:[String:Any]=["schema":"blind.public-contour-contrast.v1","physicalAuthority":false,
            "fullFootprintSupportVerified":false,"appActivation":false,"baseline49aReproduced":reproduced,
            "status":reproduced ? "baseline-reproduced-contrast-observed" : "baseline-mismatch-contrast-inconclusive",
            "platform":"macOS diagnostic; iOS confirmation required","requestsPerConfiguration":25,
            "preservedUnrunJourneyStages":9,"rows":rows]
        let data=try JSONSerialization.data(withJSONObject:output,options:[.sortedKeys,.prettyPrinted])
        guard data.count<=1048576 else { throw ProbeFailure.outputLimit }
        try data.write(to:URL(fileURLWithPath:CommandLine.arguments[3]),options:.atomic)
        print("Probe completed; baseline49aReproduced=\(reproduced); no physical authority")
    }
}
