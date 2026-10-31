// Isolated public-fixture comparison. No app activation or physical authority.
import Foundation
import SceneKit
import simd
import EDTNavigationProbe
import CryptoKit

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
// Typed reference values compare Float32 BIT PATTERNS, not rounded JSON doubles.
private struct F32: Decodable, Equatable {
    let bits: UInt32
    init(from decoder: Decoder) throws {
        let value=try decoder.singleValueContainer().decode(Float.self)
        guard value.isFinite else { throw ProbeFailure.invalidInput }
        bits=value.bitPattern
    }
}
private struct ContactReference: Decodable, Equatable {
    let kind: String
    let from,to:[F32]
    let bodyContact,marginContact,fullFootprintSupportVerified:Bool
    let obstacleSurfaceIDs,furnitureBoundIDs,floorContactIDs:[String]
}
private struct AssociationReference: Decodable, Equatable {
    let found,isOverPoly,physicalAuthority:Bool
    let requested,projected:[F32]
}
private struct StrictAssociationReference: Decodable, Equatable {
    let found,isOverPolygon:Bool
    let requested,projected:[F32]
    let nativeStatus:UInt32
}
private struct AdmissionReference: Decodable, Equatable {
    let policy:String
    let physicalAuthority:Bool
    let start,goal:StrictAssociationReference
}
private struct RowReference: Decodable, Equatable {
    let requestID,fixtureSHA256,profile,endpointPolicy:String
    let physicalAuthority,initialBodyContact,initialMarginContact,nativeSucceeded,baselineMatches49a:Bool
    let rawRadius,effectiveRadius,effectiveHeight,maxSimplificationErrorCells:F32
    let initialContactReceipt:[ContactReference]
    let buildFailed,endpointAdmissionRejected,nativeComplete,bodyContact,marginContact:Bool?
    let nativeStatus:UInt32?
    let nativeError:String?
    let routePoints:[[F32]]?
    let projectedStart,projectedGoal:[F32]?
    let startAssociation,goalAssociation:AssociationReference?
    let strictAdmission:AdmissionReference?
    let segments:[ContactReference]?
}
private struct NativeReference: Decodable {
    let schema,status:String
    let physicalAuthority,appActivation,baseline49aReproduced,acceptedStrictPathsMatchLegacy:Bool
    let strictAdmissionMatchesIndependentLegacyExpectation,bothCornerMarginContactsRemain:Bool
    let baselineSuccessfulCorridors,strictRetainedCorridors,requestsPerConfiguration,preservedUnrunJourneyStages:Int
    let knownProjectedSuccessfulStartsRejected:[String]
    let rows:[RowReference]
}
private struct MaskProfile: Decodable {
    let profileIndex,width,height,spanCount,originalKeepCount,candidateKeepCount:Int
    let fixtureSHA256,layoutSHA256,maskSHA256:String
    let radiusBits,heightBits:UInt32
    let keepMask:[UInt8]
}
private struct AcceptanceIDs: Decodable {
    let retainSixNoContactCorridors,seekTwoCompleteNoContactCorners:[String]
    let retainThreeTypedEndpointRefusals,otherPreviouslyFailedRequests:[String]
}
private struct Masks: Decodable {
    let schema,policy,geometrySHA256,requestsSHA256,nativeReferenceSHA256:String
    let physicalAuthority,sourceSurfaceClearanceEstablished,navigationExecuted:Bool
    let profiles:[MaskProfile]
    let fixedAcceptanceIDs:AcceptanceIDs
}
private enum Configuration:String {
    case originalLegacy="original-erosion-legacy-endpoints"
    case originalStrict="original-erosion-strict-endpoints"
    case edtStrict="original-keep-AND-exact-EDT-original-R-strict-endpoints"
    var strict:Bool { self != .originalLegacy }
    var mode:Int32 { self == .edtStrict ? 1:0 }
}
private func digest(_ data:Data)->String { SHA256.hash(data:data).map { String(format:"%02x",$0) }.joined() }
private func hashBytes(_ text:String)throws->[UInt8] {
    guard text.count==64,text.allSatisfy({("0123456789abcdef").contains($0)}) else { throw ProbeFailure.invalidInput }
    let chars=Array(text)
    return try stride(from:0,to:64,by:2).map {
        guard let value=UInt8(String(chars[$0...($0+1)]),radix:16) else { throw ProbeFailure.invalidInput }
        return value
    }
}
private func typed(_ row:[String:Any])throws->RowReference {
    try JSONDecoder().decode(RowReference.self,from:JSONSerialization.data(withJSONObject:row,options:[.sortedKeys]))
}
private func sameInputAndInitial(_ a:RowReference,_ b:RowReference)->Bool {
    a.requestID==b.requestID && a.fixtureSHA256==b.fixtureSHA256 && a.profile==b.profile &&
    a.endpointPolicy==b.endpointPolicy && a.rawRadius==b.rawRadius && a.effectiveRadius==b.effectiveRadius &&
    a.effectiveHeight==b.effectiveHeight && a.maxSimplificationErrorCells==b.maxSimplificationErrorCells &&
    !a.physicalAuthority && a.initialBodyContact==b.initialBodyContact && a.initialMarginContact==b.initialMarginContact &&
    a.initialContactReceipt==b.initialContactReceipt
}
private func receiptRequestsMatch(_ receipt:AdmissionReference,_ request:Request)->Bool {
    receipt.policy=="requireSuppliedXZOverPolygon" && !receipt.physicalAuthority &&
    receipt.start.requested.map(\.bits)==request.requestedStart.map(\.bitPattern) &&
    receipt.goal.requested.map(\.bits)==request.requestedGoal.map(\.bitPattern)
}
private func completeNoContact(_ row:RowReference,_ request:Request)->Bool {
    guard let receipt=row.strictAdmission,let points=row.routePoints,let segments=row.segments,
          !points.isEmpty,!segments.isEmpty else { return false }
    return row.nativeSucceeded && row.nativeComplete==true && row.endpointAdmissionRejected==false &&
        row.bodyContact==false && row.marginContact==false && !row.initialBodyContact && !row.initialMarginContact &&
        receiptRequestsMatch(receipt,request) && receipt.start.found && receipt.start.isOverPolygon &&
        receipt.goal.found && receipt.goal.isOverPolygon &&
        segments.allSatisfy { !$0.bodyContact && !$0.marginContact && !$0.fullFootprintSupportVerified }
}

@MainActor private func run(_ fixture:Fixture,_ r:Request,configuration:Configuration,
                           mask:MaskProfile,oracle:SavedRoomRouteCollisionOracle)throws->[String:Any] {
    let strict=configuration.strict
    let vertices=fixture.worldPositionBits.map(Float.init(bitPattern:))
    let support:[UInt8]=fixture.floorSupport.map { $0 ? 1:0 }
    // Original source/body contact is retained even when endpoint admission refuses.
    let initial=try score(oracle,r,[.init(kind:"initial",from:r.requestedStart,to:r.requestedStart)])
    var row:[String:Any]=["requestID":r.id,"fixtureSHA256":fixture.sourceSHA256,"profile":r.profile,
        "endpointPolicy":strict ? "requireSuppliedXZOverPolygon":"legacyNearestProjection",
        "maxSimplificationErrorCells":0.5,"physicalAuthority":false,
        "initialBodyContact":initial.0,"initialMarginContact":initial.1,"initialContactReceipt":initial.2,
        "rawRadius":r.rawRadius,"effectiveRadius":r.effectiveRadius,"effectiveHeight":r.effectiveHeight,
        "configuration":configuration.rawValue,"maskProfileIndex":mask.profileIndex,
        "requestedStart":r.requestedStart,"requestedGoal":r.requestedGoal,"routeQueryAttempted":false]
    let expectedHash=try hashBytes(mask.layoutSHA256)
    return try expectedHash.withUnsafeBufferPointer { hash in
      try mask.keepMask.withUnsafeBufferPointer { keep in
        guard bn_edt_begin(Int32(mask.profileIndex),configuration.mode,hash.baseAddress,keep.baseAddress,Int32(mask.spanCount))==1 else {
            bn_edt_reset()
            row["fullLayoutValidated"]=false;row["diagnosticFailure"]="edt-context-setup-refused"
            row["nativeSucceeded"]=false;row["baselineMatches49a"]=false
            return row
        }
        defer { bn_edt_reset() }
        var actualHash=[UInt8](repeating:0,count:32)
        var originalKeep:Int32=0,candidateKeep:Int32=0,applied:Int32=0,layoutMatch:Int32=0,invalid:Int32=0
        var config=BNConfig(radius:r.effectiveRadius,height:r.effectiveHeight,cell_size:0.025,cell_height:0.025,
            max_climb:0.025,max_slope:15,max_cells:250000,max_nodes:4096)
        let handle=vertices.withUnsafeBufferPointer { v in fixture.triangleIndices.withUnsafeBufferPointer { t in
            support.withUnsafeBufferPointer { s in
                bn_build_classified(v.baseAddress,Int32(vertices.count/3),t.baseAddress,Int32(fixture.triangleIndices.count/3),&config,s.baseAddress)
            }
        }}
        // Receipt is queried immediately, including expected no-mesh builds. No
        // nearest-poly/path query is allowed until the full native layout matches.
        let receiptOK=actualHash.withUnsafeMutableBufferPointer { out in
            bn_edt_receipt(out.baseAddress,&originalKeep,&candidateKeep,&applied,&layoutMatch,&invalid)
        }
        defer { if let handle { bn_destroy(handle) } }
        let layoutValid=receiptOK==1 && layoutMatch==1 && invalid==0 && actualHash==expectedHash &&
            originalKeep==Int32(mask.originalKeepCount) && candidateKeep==Int32(mask.candidateKeepCount) &&
            applied==configuration.mode
        row["edtReceipt"]=["receiptValid":receiptOK==1,"layoutMatch":layoutMatch==1,"invalid":invalid != 0,
            "actualLayoutSHA256":actualHash.map { String(format:"%02x",$0) }.joined(),
            "expectedLayoutSHA256":mask.layoutSHA256,"maskSHA256":mask.maskSHA256,
            "originalKeep":originalKeep,"candidateKeep":candidateKeep,"applied":applied==1]
        row["fullLayoutValidated"]=layoutValid
        guard layoutValid else {
            row["diagnosticFailure"]="full-native-layout-or-mask-receipt-mismatch-no-query"
            row["nativeSucceeded"]=false;row["baselineMatches49a"]=false
            return row
        }
    var matches=initial.0 == r.expectedInitialBodyContact && initial.1 == r.expectedInitialMarginContact
    guard let h=handle else {
        row["nativeSucceeded"]=false; row["buildFailed"]=true
        row["baselineMatches49a"]=matches && !r.expectedNativeSucceeded
        return row
    }
    row["routeQueryAttempted"]=true
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
    }
}
@main private struct Runner {
    @MainActor static func main()throws {
        guard CommandLine.arguments.count==6 else { throw ProbeFailure.invalidInput }
        guard !FileManager.default.fileExists(atPath:CommandLine.arguments[5]) else { throw ProbeFailure.invalidInput }
        let geometryData=try Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[1]))
        let requestData=try Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[2]))
        let maskData=try Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[3]))
        let referenceData=try Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[4]))
        guard geometryData.count<=131072,requestData.count<=131072,maskData.count<=1048576,
              referenceData.count<=1048576,
              digest(geometryData)=="0731735bf24f198288efea26d79c8a29929d49b10d3be0637e9e15fb983c63b7",
              digest(requestData)=="e5d2e07c7564869d2abde1d4a947e022d1a166c64641a81f2b92fcdbab73ac51",
              digest(referenceData)=="0858272d1faca7e16268b772f0cd164652c08eb22277d36514d2eae72b803893" else { throw ProbeFailure.invalidInput }
        let decoder=JSONDecoder()
        let g=try decoder.decode(Geometry.self,from:geometryData),q=try decoder.decode(Requests.self,from:requestData)
        let masks=try decoder.decode(Masks.self,from:maskData),reference=try decoder.decode(NativeReference.self,from:referenceData)
        let allowed=["Hallway2":"f4cf3460fd9e746a86fe6538e2b1980e22e18207a2d3c7ea3f7679f58c8c6f4d",
                     "Bedroom3":"44df7bd5f4d1961bf13344916384dcfa20d42c7ef8dc58b0e13d1c2f7c6a4d2e"]
        guard g.schema=="blind.public-apple-packed-routing-geometry.v1",g.representation=="final-adapter-routing-input",
              g.coordinateEncoding=="float32-bit-patterns",g.frame=="original-saved-world-y-up-metres",g.complete,
              !g.physicalAuthority,!g.fullFootprintSupportVerified,g.fixtures.count==2,
              Set(g.fixtures.map(\.fixtureID)).count==2,q.schema=="blind.public-fixed-contour-requests.v1",
              q.sourceCommit=="49a9878c51dc97214cdfacf74946d8f2816597f0",q.nativeRun==40773062534,
              !q.physicalAuthority,q.requests.count==25,Set(q.requests.map(\.id)).count==25,
              masks.schema=="blind.fixed-full-layer-edt-masks.v1",
              masks.policy=="original-erosion-keep-AND-exact-grid-seed-EDT-at-original-R-v1",
              !masks.physicalAuthority,!masks.sourceSurfaceClearanceEstablished,!masks.navigationExecuted,
              masks.geometrySHA256==digest(geometryData),masks.requestsSHA256==digest(requestData),
              masks.nativeReferenceSHA256==digest(referenceData),masks.profiles.count==6,
              Set(masks.profiles.map(\.profileIndex))==Set(0..<6),
              reference.schema=="blind.public-strict-endpoint-contrast.v1",
              reference.status=="baseline-reproduced-strict-admission-observed-corner-contacts-unresolved",
              !reference.physicalAuthority,!reference.appActivation,reference.baseline49aReproduced,
              reference.acceptedStrictPathsMatchLegacy,reference.strictAdmissionMatchesIndependentLegacyExpectation,
              reference.bothCornerMarginContactsRemain,reference.baselineSuccessfulCorridors==11,
              reference.strictRetainedCorridors==8,reference.requestsPerConfiguration==25,
              reference.preservedUnrunJourneyStages==9,reference.rows.count==50 else { throw ProbeFailure.invalidInput }
        for f in g.fixtures {
            guard allowed[f.fixtureID]==f.sourceSHA256,!f.worldPositionBits.isEmpty,f.worldPositionBits.count%3==0,
                  f.worldPositionBits.count<=6144,f.worldPositionBits.map(Float.init(bitPattern:)).allSatisfy({$0.isFinite && abs($0)<=10000}),
                  !f.triangleIndices.isEmpty,f.triangleIndices.count%3==0,f.triangleIndices.count<=3072,
                  f.triangleIndices.allSatisfy({$0>=0 && Int($0)<f.worldPositionBits.count/3}),
                  f.floorSupport.count==f.triangleIndices.count/3,f.triangleFeatureIDs.count==f.floorSupport.count,
                  f.furnitureBoxes.count<=64 else { throw ProbeFailure.invalidInput }
        }
        var maskTuples=Set<String>(),spanTotal=0,usedProfiles=Set<Int>()
        for p in masks.profiles {
            let radius=Float(bitPattern:p.radiusBits),height=Float(bitPattern:p.heightBits)
            guard p.spanCount>0,p.spanCount<=65536,p.keepMask.count==p.spanCount,
                  p.keepMask.allSatisfy({$0<=1}),p.width>0,p.height>0,p.width<=250000,p.height<=250000,
                  Int64(p.width)*Int64(p.height)<=250000,p.originalKeepCount>=0,p.originalKeepCount<=p.spanCount,
                  p.candidateKeepCount>=0,p.candidateKeepCount<=p.originalKeepCount,
                  p.keepMask.reduce(0,{$0+Int($1)})==p.candidateKeepCount,
                  digest(Data(p.keepMask))==p.maskSHA256,radius.isFinite,height.isFinite,
                  (0.1...2).contains(radius),(0.5...3).contains(height),
                  allowed.values.contains(p.fixtureSHA256) else { throw ProbeFailure.invalidInput }
            _=try hashBytes(p.layoutSHA256)
            guard maskTuples.insert(p.fixtureSHA256+"|\(p.radiusBits)|\(p.heightBits)").inserted else { throw ProbeFailure.invalidInput }
            spanTotal += p.spanCount
        }
        guard spanTotal<=200000 else { throw ProbeFailure.invalidInput }
        for r in q.requests {
            guard allowed.values.contains(r.fixtureSHA256),
                  [r.rawRadius,r.rawHeight,r.effectiveRadius,r.effectiveHeight].allSatisfy(\.isFinite),
                  r.effectiveRadius>=r.rawRadius,r.effectiveHeight>=r.rawHeight else { throw ProbeFailure.invalidInput }
            _=try vector(r.requestedStart);_=try vector(r.requestedGoal)
            let matches=masks.profiles.filter { $0.fixtureSHA256==r.fixtureSHA256 && $0.radiusBits==r.effectiveRadius.bitPattern && $0.heightBits==r.effectiveHeight.bitPattern }
            guard matches.count==1 else { throw ProbeFailure.invalidInput };usedProfiles.insert(matches[0].profileIndex)
        }
        guard usedProfiles==Set(0..<6) else { throw ProbeFailure.invalidInput }
        let referenceLegacy=reference.rows.filter {$0.endpointPolicy=="legacyNearestProjection"}
        let referenceStrict=reference.rows.filter {$0.endpointPolicy=="requireSuppliedXZOverPolygon"}
        guard referenceLegacy.count==25,referenceStrict.count==25,
              referenceLegacy.map(\.requestID)==q.requests.map(\.id),referenceStrict.map(\.requestID)==q.requests.map(\.id) else { throw ProbeFailure.invalidInput }
        let ids=masks.fixedAcceptanceIDs
        let six=Set(ids.retainSixNoContactCorridors),two=Set(ids.seekTwoCompleteNoContactCorners)
        let three=Set(ids.retainThreeTypedEndpointRefusals),fourteen=Set(ids.otherPreviouslyFailedRequests)
        let declared=ids.retainSixNoContactCorridors+ids.seekTwoCompleteNoContactCorners+ids.retainThreeTypedEndpointRefusals+ids.otherPreviouslyFailedRequests
        let derivedSix=Set(referenceStrict.filter {$0.nativeSucceeded && $0.nativeComplete==true && $0.bodyContact==false && $0.marginContact==false}.map(\.requestID))
        let derivedTwo=Set(referenceStrict.filter {$0.nativeSucceeded && $0.nativeComplete==true && $0.bodyContact==false && $0.marginContact==true && $0.requestID.contains(":hall-corner:")}.map(\.requestID))
        let derivedThree=Set(zip(referenceLegacy,referenceStrict).filter {$0.0.nativeSucceeded && !$0.1.nativeSucceeded && $0.1.endpointAdmissionRejected==true}.map {$0.1.requestID})
        guard six.count==6,two.count==2,three.count==3,fourteen.count==14,declared.count==25,
              Set(declared)==Set(q.requests.map(\.id)),six==derivedSix,two==derivedTwo,three==derivedThree,
              three==Set(reference.knownProjectedSuccessfulStartsRejected),
              fourteen==Set(referenceStrict.filter {!$0.nativeSucceeded}.map(\.requestID)).subtracting(three) else { throw ProbeFailure.invalidInput }

        @MainActor func runConfiguration(_ configuration:Configuration)throws->[[String:Any]] {
            var rows:[[String:Any]]=[],currentGroup:String?=nil,currentOracle:SavedRoomRouteCollisionOracle?=nil
            for r in q.requests {
                guard let f=g.fixtures.first(where:{$0.sourceSHA256==r.fixtureSHA256}),
                      let mask=masks.profiles.first(where:{$0.fixtureSHA256==r.fixtureSHA256 && $0.radiusBits==r.effectiveRadius.bitPattern && $0.heightBits==r.effectiveHeight.bitPattern}) else { throw ProbeFailure.invalidInput }
                let group=String(r.id.prefix {$0 != ":"})+"|"+r.fixtureSHA256
                if currentGroup != group {
                    currentOracle=nil
                    currentOracle=try autoreleasepool {try makeOracle(f)};currentGroup=group
                }
                guard let oracle=currentOracle else { throw ProbeFailure.invalidInput }
                rows.append(try autoreleasepool {try run(f,r,configuration:configuration,mask:mask,oracle:oracle)})
            }
            return rows
        }
        var legacyRows=try runConfiguration(.originalLegacy)
        var strictRows=try runConfiguration(.originalStrict)
        var controlChecks:[[String:Any]]=[]
        for i in 0..<25 {
            let a=try typed(legacyRows[i]),b=try typed(strictRows[i])
            let legacyMatch=a==referenceLegacy[i] && legacyRows[i]["fullLayoutValidated"] as? Bool == true
            let strictMatch=b==referenceStrict[i] && strictRows[i]["fullLayoutValidated"] as? Bool == true
            legacyRows[i]["baselineMatchesCeaaaReference"]=legacyMatch
            strictRows[i]["baselineMatchesCeaaaReference"]=strictMatch
            controlChecks.append(["requestID":q.requests[i].id,"legacyMatch":legacyMatch,"strictMatch":strictMatch])
        }
        let controlsMatch=legacyRows.count==25 && strictRows.count==25 &&
            legacyRows.allSatisfy {$0["baselineMatches49a"] as? Bool == true && $0["baselineMatchesCeaaaReference"] as? Bool == true} &&
            strictRows.allSatisfy {$0["baselineMatchesCeaaaReference"] as? Bool == true}
        // EXECUTION gate, not merely an interpretation gate: never run candidate
        // navigation if any of the50 exact original controls differs.
        var candidateRows:[[String:Any]]=[]
        if controlsMatch { candidateRows=try runConfiguration(.edtStrict) }
        var acceptance:[[String:Any]]=[],acceptedSix=0,acceptedTwo=0,refusedThree=0,preservedFourteen=0
        var initialIdentityAll=controlsMatch && candidateRows.count==25
        var allCandidateLayouts=controlsMatch && candidateRows.count==25
        for (index,row) in candidateRows.enumerated() {
            let actual=try typed(row),request=q.requests[index],original=referenceStrict[index]
            let initialMatches=sameInputAndInitial(actual,original)
            let layoutOK=row["fullLayoutValidated"] as? Bool == true
            initialIdentityAll = initialIdentityAll && initialMatches
            allCandidateLayouts = allCandidateLayouts && layoutOK
            var passed=false,group=""
            if six.contains(request.id) {
                group="retain-six-no-contact";passed=completeNoContact(actual,request)
                if passed {acceptedSix+=1}
            } else if two.contains(request.id) {
                group="seek-two-clear-corners";passed=completeNoContact(actual,request)
                if passed {acceptedTwo+=1}
            } else if three.contains(request.id) {
                group="retain-three-typed-endpoint-refusals"
                if let receipt=actual.strictAdmission {
                    passed = !actual.nativeSucceeded && actual.nativeComplete==false && actual.nativeStatus==0 &&
                        actual.routePoints==nil && actual.endpointAdmissionRejected==true &&
                        receiptRequestsMatch(receipt,request) && !receipt.start.isOverPolygon
                }
                if passed {refusedThree+=1}
            } else if fourteen.contains(request.id) {
                group="preserve-fourteen-original-failures"
                passed = !actual.nativeSucceeded && actual.routePoints==nil
                if passed {preservedFourteen+=1}
            }
            acceptance.append(["requestID":request.id,"group":group,"criterionPassed":passed,
                               "initialSourceContactUnchanged":initialMatches,"fullLayoutValidated":layoutOK])
        }
        let goalsMet=controlsMatch && candidateRows.count==25 && initialIdentityAll && allCandidateLayouts &&
            acceptedSix==6 && acceptedTwo==2 && refusedThree==3 && preservedFourteen==14 && acceptance.count==25
        let status = !controlsMatch ? "original-controls-mismatch-candidate-not-executed" :
            (goalsMet ? "fixed-public-fixture-edt-candidate-met-declared-goals" : "fixed-public-fixture-edt-candidate-failed-declared-goals")
        let output:[String:Any]=["schema":"blind.public-fixed-full-layer-edt-navigation.v1",
            "status":status,"physicalAuthority":false,"appActivation":false,"fullFootprintSupportVerified":false,
            "continuousSourceClearanceGuarantee":false,"centerClearanceObjectiveImplemented":false,"iOSValidated":false,
            "platform":"macOS diagnostic; production and iOS replacement not adopted","maskPolicy":masks.policy,
            "geometrySHA256":digest(geometryData),"requestsSHA256":digest(requestData),"maskInputsSHA256":digest(maskData),
            "nativeReferenceSHA256":digest(referenceData),"legacyControls":25,"strictControls":25,
            "all50OriginalControlsReproduced":controlsMatch,"controlChecks":controlChecks,
            "candidateExecuted":controlsMatch,"candidateRequests":candidateRows.count,"candidateGoalsMet":goalsMet,
            "retainedSixNoContactCorridors":acceptedSix,"completeNoContactCorners":acceptedTwo,
            "retainedThreeTypedRefusals":refusedThree,"preservedOtherFourteenFailures":preservedFourteen,
            "allCandidateInitialContactsUnchanged":initialIdentityAll,"allCandidateLayoutsMatched":allCandidateLayouts,
            "candidateAcceptanceChecks":acceptance,"preservedUnrunJourneyStages":9,
            "configurationOrder":[Configuration.originalLegacy.rawValue,Configuration.originalStrict.rawValue,Configuration.edtStrict.rawValue],
            "rows":legacyRows+strictRows+candidateRows]
        let data=try JSONSerialization.data(withJSONObject:output,options:[.sortedKeys,.prettyPrinted])
        guard data.count<=1048576 else {throw ProbeFailure.outputLimit}
        try data.write(to:URL(fileURLWithPath:CommandLine.arguments[5]),options:.atomic)
        print("Fixed EDT diagnostic complete: \(status); no physical authority")
    }
}
