import Foundation
import CDetour

enum Failure: Error { case invalid(String) }
struct Packet: Codable, Equatable {
 var session:String; var generation:Int; var anchor:String; var revision:Int; var timestamp:Double
 var vertices:[Double]; var triangles:[Int32]; var transform:[Double]; var complete:Bool; var removed:Bool
 var triangleSupport:[MeshTriangleSupport]? = nil
}
struct Tile { let vertices:[Double]; let triangles:[Int32]; let triangleSupport:[MeshTriangleSupport]? }
struct Ticket { let session:String; let generation:Int; let epoch:Int }
final class Replay {
 var session:String; var generation:Int; var epoch=0
 var tiles:[String:Tile]=[:]; var ledger:[String:Packet]=[:]; var unknown=Set<String>()
 let maxTiles:Int,maxVertices:Int,maxTriangles:Int,maxRecords:Int
 let supportPolicy:MeshSupportPolicy
 let deliveryPolicy:MeshDeliveryRecoveryPolicy
 init(_ session:String,_ generation:Int=0,maxTiles:Int=64,maxVertices:Int=200000,maxTriangles:Int=100000,maxRecords:Int=256,supportPolicy:MeshSupportPolicy = .legacySlope,deliveryPolicy:MeshDeliveryRecoveryPolicy = .legacyStickyGap)throws {
  guard !session.isEmpty,session.utf8.count<=128,generation>=0,maxTiles>0,maxTiles<=64,maxVertices>0,maxVertices<=200000,maxTriangles>0,maxTriangles<=100000,maxRecords>0,maxRecords<=256 else {throw Failure.invalid("limits")}
  self.session=session;self.generation=generation;self.maxTiles=maxTiles;self.maxVertices=maxVertices;self.maxTriangles=maxTriangles;self.maxRecords=maxRecords
  self.supportPolicy=supportPolicy;self.deliveryPolicy=deliveryPolicy
 }
 func reset(_ s:String,_ g:Int)throws {
  guard !s.isEmpty,s.utf8.count<=128,g>=0,(s != session || g>generation) else {throw Failure.invalid("reset")}
  session=s;generation=g;epoch+=1;tiles.removeAll();ledger.removeAll();unknown.removeAll()
 }
 func ticket()->Ticket {Ticket(session:session,generation:generation,epoch:epoch)}
 func current(_ t:Ticket)->Bool {t.session==session && t.generation==generation && t.epoch==epoch}
 var sourceComplete:Bool {!tiles.isEmpty && unknown.isEmpty && tiles.values.allSatisfy{!$0.vertices.isEmpty && !$0.triangles.isEmpty}}
 func apply(_ p:Packet)throws ->String {
  if p.session != session || p.generation != generation {return "wrong-session"}
  do {return try accept(p)} catch {if deliveryPolicy == .legacyStickyGap {unknown.insert("invalid-input")};epoch+=1;throw error}
 }
 private func accept(_ p:Packet)throws ->String {
  guard !p.anchor.isEmpty,p.anchor.utf8.count<=128,p.revision>=0,p.timestamp.isFinite,p.timestamp>=0 else {throw Failure.invalid("metadata")}
  if ledger[p.anchor]==nil && ledger.count>=maxRecords {unknown.insert("metadata-budget");epoch+=1;return "metadata-budget"}
  if p.removed {
   guard p.vertices.isEmpty,p.triangles.isEmpty,p.transform.isEmpty,p.triangleSupport == nil else {throw Failure.invalid("removal payload must be empty")}
  }
  if !p.removed {
   guard p.vertices.count%3==0,p.triangles.count%3==0,p.vertices.count/3<=maxVertices,p.triangles.count/3<=maxTriangles,p.vertices.allSatisfy({$0.isFinite}),p.triangles.allSatisfy({$0>=0 && Int($0)<p.vertices.count/3}) else {throw Failure.invalid("geometry")}
   guard supportPolicy == .classifiedFloorOnly ? p.triangleSupport?.count == p.triangles.count/3 : p.triangleSupport == nil else {throw Failure.invalid("triangle support")}
   let m=p.transform
   guard m.count==16,m.allSatisfy({$0.isFinite}),abs(m[12])<1e-10,abs(m[13])<1e-10,abs(m[14])<1e-10,abs(m[15]-1)<1e-10 else {throw Failure.invalid("matrix")}
   for a in 0..<3 {for b in 0..<3 {var d=0.0;for r in 0..<3 {d+=m[r*4+a]*m[r*4+b]};guard abs(d-(a==b ? 1:0))<=1e-5 else {throw Failure.invalid("orthogonal")}}}
   let determinant=m[0]*(m[5]*m[10]-m[6]*m[9])-m[1]*(m[4]*m[10]-m[6]*m[8])+m[2]*(m[4]*m[9]-m[5]*m[8])
   guard abs(determinant-1)<=1e-5 else {throw Failure.invalid("handedness")}
  }
  if let old=ledger[p.anchor] {
   if p.revision<old.revision || p.timestamp<old.timestamp {return "stale"}
   if p.revision==old.revision {
    if p==old{return "duplicate"}
    tiles.removeValue(forKey:p.anchor);if deliveryPolicy == .legacyStickyGap {unknown.insert("conflict:"+p.anchor)};epoch+=1;return "conflict"
   }
   guard p.timestamp>old.timestamp else {throw Failure.invalid("timestamp")}
  }
  let retained=ledger.filter{$0.key != p.anchor}.values
  if retained.reduce(0,{$0+$1.vertices.count/3})+p.vertices.count/3>maxVertices || retained.reduce(0,{$0+$1.triangles.count/3})+p.triangles.count/3>maxTriangles {unknown.insert("ledger-geometry-budget");epoch+=1;return "ledger-geometry-budget"}
  ledger[p.anchor]=p;epoch+=1
  if p.removed {tiles.removeValue(forKey:p.anchor);unknown.insert("removed:"+p.anchor);return "removed"}
  var world=[Double]();world.reserveCapacity(p.vertices.count)
  for i in stride(from:0,to:p.vertices.count,by:3){for r in 0..<3 {let j=r*4;world.append(p.transform[j]*p.vertices[i]+p.transform[j+1]*p.vertices[i+1]+p.transform[j+2]*p.vertices[i+2]+p.transform[j+3])}}
  guard world.allSatisfy({$0.isFinite && Float($0).isFinite}) else {throw Failure.invalid("projected geometry")}
  tiles[p.anchor]=Tile(vertices:world,triangles:p.triangles,triangleSupport:p.triangleSupport)
  if deliveryPolicy == .legacyStickyGap && (p.vertices.isEmpty || p.triangles.isEmpty){unknown.insert("empty:"+p.anchor)}
  if deliveryPolicy == .legacyStickyGap && !p.complete{unknown.insert("truncated:"+p.anchor)}
  while tiles.count>maxTiles || tiles.values.reduce(0,{$0+$1.vertices.count/3})>maxVertices || tiles.values.reduce(0,{$0+$1.triangles.count/3})>maxTriangles {
   let key=tiles.keys.sorted().first!;tiles.removeValue(forKey:key);unknown.insert("evicted:"+key)
  }
  return "accepted"
 }
 func geometry(excluding:Set<String>=[])->([Double],[Int32]) {
  var v=[Double](),f=[Int32]()
  for key in tiles.keys.sorted() where !excluding.contains(key){let t=tiles[key]!;let n=Int32(v.count/3);v.append(contentsOf:t.vertices);f.append(contentsOf:t.triangles.map{$0+n})}
  return(v,f)
 }
 /// Same stable tile order as geometry(); no fallback for missing classifications.
 func geometrySupport(excluding:Set<String>=[])throws->[MeshTriangleSupport]? {
  guard supportPolicy == .classifiedFloorOnly else{return nil}
  var result=[MeshTriangleSupport]()
  for key in tiles.keys.sorted() where !excluding.contains(key){let t=tiles[key]!;guard let support=t.triangleSupport,support.count==t.triangles.count/3 else{throw Failure.invalid("missing triangle support")};result.append(contentsOf:support)}
  return result
 }
 /// Read the same admitted ledger/tiles as geometry(), without a second mapper.
 /// Preflight ALL counts/bytes before constructing any output geometry arrays.
 /// Failed/rejected replacements may leave old tiles: unknown/sourceComplete
 /// must travel with this diagnostic payload and never imply current clearance.
 func sourceSnapshotData(limits:MeshSourceSnapshotLimits,excluding:Set<String>=[],additionalPayloadBytes:Int=0)throws->([MeshSourceAnchorGeometry],[MeshSourceAnchorReceipt],Int) {
  guard limits.valid else{throw MeshSourceSnapshotError.invalidLimits}
  let selected=tiles.keys.filter{!excluding.contains($0)}.sorted()
  guard selected.count<=limits.anchors,ledger.count<=limits.records,additionalPayloadBytes>=0,additionalPayloadBytes<=limits.payloadBytes else{throw MeshSourceSnapshotError.budget}
  var bytes=1024+additionalPayloadBytes,vertices=0,triangles=0 // reserves bounded headers/session/frame/unit IDs and the optional ingress-gap label
  func add(_ a:Int,_ b:Int)throws->Int {let(n,o)=a.addingReportingOverflow(b);guard !o else{throw MeshSourceSnapshotError.budget};return n}
  func mul(_ a:Int,_ b:Int)throws->Int {let(n,o)=a.multipliedReportingOverflow(by:b);guard !o else{throw MeshSourceSnapshotError.budget};return n}
  for (id,p) in ledger {bytes=try add(bytes,add(id.utf8.count,64));guard p.anchor==id else{throw MeshSourceSnapshotError.invalidRetainedState}}
  for label in unknown {bytes=try add(bytes,add(label.utf8.count,16))}
  for id in selected {
   guard let p=ledger[id],let tile=tiles[id],!p.removed,p.vertices.count==tile.vertices.count,
    p.triangles==tile.triangles,p.triangleSupport==tile.triangleSupport,p.transform.count==16 else{throw MeshSourceSnapshotError.invalidRetainedState}
   vertices=try add(vertices,p.vertices.count/3);triangles=try add(triangles,p.triangles.count/3)
   bytes=try add(bytes,add(mul(p.vertices.count,8),mul(p.triangles.count,4)))
   bytes=try add(bytes,add(128,add(id.utf8.count,p.triangleSupport?.count ?? 0)))
  }
  guard vertices<=limits.vertices,triangles<=limits.triangles,bytes<=limits.payloadBytes else{throw MeshSourceSnapshotError.budget}
  // Replay can commit a ledger packet before rejecting projected overflow.
  // Never pair that newer packet with an older tile just because counts match.
  // Verify the exact transform-once world values against the retained tile;
  // reject the WHOLE snapshot on divergence without changing route/mutation policy.
  for id in selected {
   let p=ledger[id]!,tile=tiles[id]!
   for i in stride(from:0,to:p.vertices.count,by:3) {for r in 0..<3 {
    let j=r*4
    let world=p.transform[j]*p.vertices[i]+p.transform[j+1]*p.vertices[i+1]+p.transform[j+2]*p.vertices[i+2]+p.transform[j+3]
    guard world.isFinite,Float(world).isFinite,world==tile.vertices[i+r] else{throw MeshSourceSnapshotError.invalidRetainedState}
   }}
  }
  let records=ledger.keys.sorted().map {id -> MeshSourceAnchorReceipt in
   let p=ledger[id]!
   return MeshSourceAnchorReceipt(anchorID:id,storedRevision:p.revision,receiptUptime:p.timestamp,
    removed:p.removed,hasRetainedGeometry:tiles[id] != nil,includedInSnapshot:tiles[id] != nil && !excluding.contains(id),complete:p.complete)
  }
  let anchors=selected.map {id -> MeshSourceAnchorGeometry in
   let p=ledger[id]!
   // Packet stores rows; transpose back to the unchanged source column layout.
   let columns=(0..<16).map{p.transform[($0%4)*4+$0/4]}
   return MeshSourceAnchorGeometry(anchorID:id,localVertices:p.vertices,triangleIndices:p.triangles,
    columnMajorTransform:columns,normalizedSupportRoles:p.triangleSupport)
  }
  return(anchors,records,bytes)
 }
 func receipt()->[String:Any]{["authorizesPhysicalGuidance":false,"actualWorldCoverageKnown":false,"rawDepthHazard":"notImplemented","rawHazardVeto":true,"sourceDeliveryComplete":sourceComplete,"unknownCoverage":unknown.sorted(),"epoch":epoch]}
}
struct NativeRoute:Codable {
 let points:[[Float]];let projected_start:[Float];let projected_goal:[Float];let complete:Bool;let status:UInt32;let error:String?
 let endpointAdmission:MeshEndpointAdmissionReceipt?
}
final class Native {
 let handle:UnsafeMutableRawPointer
 let seedRadiusReceipt:MeshSeedRadiusVetoReceipt?
 let seedRadiusEnvelopeReceipt:MeshSeedRadiusEnvelopeReceipt?
 init(_ vertices:[Double],_ triangles:[Int32],exclusion:Exclusion?=nil,radius:Float=0.225,height:Float=1.75,triangleSupport:[MeshTriangleSupport]?=nil,seedRadiusPolicy:MeshSeedRadiusPolicy = .stock)throws {
  guard vertices.count%3==0,triangles.count%3==0,vertices.count/3<=200000,triangles.count/3<=100000,vertices.allSatisfy({$0.isFinite && Float($0).isFinite}),triangles.allSatisfy({$0>=0 && Int($0)<vertices.count/3}) else {throw Failure.invalid("native input")}
  let packed:[Float]=vertices.map(Float.init)
  guard triangleSupport == nil || (exclusion == nil && triangleSupport!.count==triangles.count/3) else{throw Failure.invalid("native triangle support")}
  guard seedRadiusPolicy.valid, seedRadiusPolicy == .stock || (triangleSupport != nil && exclusion == nil) else {throw MeshCandidateError.invalidInput}
  let supportBytes=triangleSupport?.map(\.rawValue)
  var seedReceipt=BNSeedRadiusVetoReceipt()
  var envelopeReceipt=BNSeedRadiusEnvelopeReceipt()
  var c=BNConfig(radius:radius,height:height,cell_size:0.025,cell_height:0.025,max_climb:0.025,max_slope:15,max_cells:250000,max_nodes:4096)
  let polygon=try exclusion?.validatedPolygon(expectedFrame:"phone-corrected-level-game-yup-v1")
  let h=packed.withUnsafeBufferPointer{v in triangles.withUnsafeBufferPointer{t -> UnsafeMutableRawPointer? in
   if let supportBytes=supportBytes{return supportBytes.withUnsafeBufferPointer{s in
    if let limit=seedRadiusPolicy.maximumSeedTests {
     return bn_build_classified_seed_radius(v.baseAddress,Int32(packed.count/3),t.baseAddress,Int32(triangles.count/3),&c,s.baseAddress,limit,&seedReceipt)
    }
    if let limit=seedRadiusPolicy.maximumEnvelopeWork {
     return bn_build_classified_seed_radius_envelope(v.baseAddress,Int32(packed.count/3),t.baseAddress,Int32(triangles.count/3),&c,s.baseAddress,limit,&envelopeReceipt)
    }
    return bn_build_classified(v.baseAddress,Int32(packed.count/3),t.baseAddress,Int32(triangles.count/3),&c,s.baseAddress)
   }}
   if let e=exclusion,let polygon=polygon{return polygon.withUnsafeBufferPointer{p in bn_build_excluded(v.baseAddress,Int32(packed.count/3),t.baseAddress,Int32(triangles.count/3),&c,p.baseAddress,Int32(polygon.count/3),Float(e.observedTopHeightRange[0]),Float(e.observedTopHeightRange[1]))}}
   return bn_build(v.baseAddress,Int32(packed.count/3),t.baseAddress,Int32(triangles.count/3),&c)
  }}
  if seedRadiusPolicy.maximumSeedTests != nil {
   seedRadiusEnvelopeReceipt=nil
   let receipt=MeshSeedRadiusVetoReceipt(schema:Int(seedReceipt.schema),
    status:MeshSeedRadiusVetoStatus(rawValue:Int(seedReceipt.status)) ?? .invalidInput,
    width:Int(seedReceipt.width),height:Int(seedReceipt.height),spanCount:Int(seedReceipt.span_count),
    radiusCells:Int(seedReceipt.radius_cells),commonYVoxel:Int(seedReceipt.common_y_voxel),
    realSeedCount:Int(seedReceipt.real_seed_count),exteriorSeedCount:Int(seedReceipt.exterior_seed_count),
    stockKeepCount:Int(seedReceipt.stock_keep_count),exactKeepCount:Int(seedReceipt.exact_keep_count),
    additionalRejectedCount:Int(seedReceipt.additional_rejected_count),buildSucceeded:seedReceipt.build_succeeded != 0,
    workLimit:seedReceipt.work_limit,workBound:seedReceipt.work_bound,workPerformed:seedReceipt.work_performed)
   seedRadiusReceipt=receipt
   guard let h else {throw MeshCandidateError.seedRadiusUnavailable(receipt)}
   guard receipt.schema==1,receipt.status == .applied,receipt.buildSucceeded,
    receipt.workPerformed<=receipt.workBound,receipt.workBound<=receipt.workLimit else {
    bn_destroy(h);throw MeshCandidateError.seedRadiusUnavailable(receipt)
   }
   handle=h
  } else if let limit=seedRadiusPolicy.maximumEnvelopeWork {
   seedRadiusReceipt=nil
   guard let schema=MeshSeedRadiusEnvelopeSchema(rawValue:Int(envelopeReceipt.schema)),
    let algorithm=MeshSeedRadiusEnvelopeAlgorithm(rawValue:Int(envelopeReceipt.algorithm)),
    let unit=MeshSeedRadiusEnvelopeWorkUnit(rawValue:Int(envelopeReceipt.work_unit)),
    let status=MeshSeedRadiusEnvelopeStatus(rawValue:Int(envelopeReceipt.status)) else {
     if let h {bn_destroy(h)};throw MeshCandidateError.invalidInput
   }
   let receipt=MeshSeedRadiusEnvelopeReceipt(schema:schema,algorithm:algorithm,workUnit:unit,status:status,
    width:Int(envelopeReceipt.width),height:Int(envelopeReceipt.height),spanCount:Int(envelopeReceipt.span_count),
    radiusCells:Int(envelopeReceipt.radius_cells),commonYVoxel:Int(envelopeReceipt.common_y_voxel),
    realSeedCount:Int(envelopeReceipt.real_seed_count),exteriorSeedCount:Int(envelopeReceipt.exterior_seed_count),
    stockKeepCount:Int(envelopeReceipt.stock_keep_count),exactKeepCount:Int(envelopeReceipt.exact_keep_count),
    additionalRejectedCount:Int(envelopeReceipt.additional_rejected_count),buildSucceeded:envelopeReceipt.build_succeeded != 0,
    workLimit:envelopeReceipt.work_limit,workBound:envelopeReceipt.work_bound,workPerformed:envelopeReceipt.work_performed,
    paddedCellCount:envelopeReceipt.padded_cell_count,workspaceBytesDeclared:envelopeReceipt.workspace_bytes_declared)
   seedRadiusEnvelopeReceipt=receipt
   guard let h else {throw MeshCandidateError.seedRadiusEnvelopeUnavailable(receipt)}
   guard receipt.status == .applied,receipt.buildSucceeded,receipt.workLimit==limit,
    receipt.workPerformed<=receipt.workBound,receipt.workBound<=receipt.workLimit,
    receipt.workspaceBytesDeclared<=2*1024*1024,receipt.paddedCellCount<=250000,
    receipt.exactKeepCount>=0,receipt.exactKeepCount<=receipt.stockKeepCount,
    receipt.additionalRejectedCount==receipt.stockKeepCount-receipt.exactKeepCount else {
     bn_destroy(h);throw MeshCandidateError.seedRadiusEnvelopeUnavailable(receipt)
   }
   handle=h
  } else {
   seedRadiusReceipt=nil
   seedRadiusEnvelopeReceipt=nil
   guard let h else {throw Failure.invalid("native build")};handle=h
  }
 }
 var markedSpans:Int{Int(bn_excluded_span_count(handle))}
 deinit{bn_destroy(handle)}
 func route(_ start:[Float],_ goal:[Float],endpointPolicy:MeshEndpointPolicy = .legacyNearestProjection)throws->NativeRoute {
  guard start.count==3,goal.count==3,(start+goal).allSatisfy({$0.isFinite}) else{throw Failure.invalid("query")}
  let extents:[Float]=[0.2,0.3,0.2];var points=[Float](repeating:0,count:768),ps=[Float](repeating:0,count:3),pg=ps;var status:UInt32=0,complete:Int32=0
  var startAssociation=BNEndpointAssociation(),goalAssociation=BNEndpointAssociation()
  let count=start.withUnsafeBufferPointer{a in goal.withUnsafeBufferPointer{b in extents.withUnsafeBufferPointer{e in points.withUnsafeMutableBufferPointer{o in ps.withUnsafeMutableBufferPointer{x in pg.withUnsafeMutableBufferPointer{y in
   if endpointPolicy == .requireSuppliedXZOverPolygon {
    return bn_path_strict(handle,a.baseAddress,b.baseAddress,e.baseAddress,o.baseAddress,256,x.baseAddress,y.baseAddress,&status,&complete,&startAssociation,&goalAssociation)
   }
   return bn_path(handle,a.baseAddress,b.baseAddress,e.baseAddress,o.baseAddress,256,x.baseAddress,y.baseAddress,&status,&complete)
  }}}}}}
  let receipt:MeshEndpointAdmissionReceipt?
  if endpointPolicy == .requireSuppliedXZOverPolygon {
   func association(_ value:BNEndpointAssociation,_ requested:[Float])->MeshEndpointAssociation {
    .init(requested:requested,projected:[value.projected.0,value.projected.1,value.projected.2],
          found:value.found != 0,isOverPolygon:value.is_over_polygon != 0,nativeStatus:value.status)
   }
   receipt = .init(policy:endpointPolicy,start:association(startAssociation,start),goal:association(goalAssociation,goal),authorizesPhysicalGuidance:false)
   if let receipt, !receipt.start.isOverPolygon || !receipt.goal.isOverPolygon {
    throw MeshCandidateError.endpointAssociationRejected(receipt)
   }
  } else { receipt=nil }
  let text=bn_last_error().map{String(cString:$0)};let err=text == "" ? nil:text
  guard count>=0,count<=256 else{throw Failure.invalid("native query: \(err ?? "unknown")")}
  return NativeRoute(points:stride(from:0,to:Int(count)*3,by:3).map{Array(points[$0..<$0+3])},projected_start:ps,projected_goal:pg,complete:complete != 0,status:status,error:err,endpointAdmission:receipt)
 }
}
