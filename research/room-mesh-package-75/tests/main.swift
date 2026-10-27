import Foundation
struct Input:Codable {let vertices:[Double];let triangles:[Int32];let packets:[Packet];let anchors:[[Float]];let reference:[NativeRoute];let exclusion:Exclusion;let exclusionReference:[NativeRoute];let expectedMarkedSpans:Int}
var checks=[String:Bool]()
func check(_ name:String,_ condition:Bool)throws{checks[name]=condition;if !condition{throw Failure.invalid("fixture: "+name)}}
func rejected(_ f:()throws->Void)->Bool{do{try f();return false}catch{return true}}
func packet()->Packet{Packet(session:"s",generation:0,anchor:"a",revision:1,timestamp:1,vertices:[0,0,0,1,0,0,0,0,1],triangles:[0,2,1],transform:[1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1],complete:true,removed:false)}
func fixtures()throws {
 let s=try Replay("s");try check("empty snapshot unknown",!s.sourceComplete)
 var p=packet();p.transform=[0,0,1,3,0,1,0,2,-1,0,0,4,0,0,0,1];_ = try s.apply(p)
 try check("transform exactly once",s.geometry().0 == [3,2,4,3,2,3,4,2,4]);let t=s.ticket();let e=s.epoch
 try check("duplicate",try s.apply(p)=="duplicate" && s.epoch==e)
 p.revision=0;p.timestamp=0;try check("stale",try s.apply(p)=="stale")
 p=packet();p.revision=2;p.timestamp=2;_ = try s.apply(p);try check("replacement not append",s.geometry().0.count==9 && !s.current(t))
 p.vertices[3]=2;try check("conflict",try s.apply(p)=="conflict" && s.tiles.isEmpty && !s.sourceComplete)
 let x=try Replay("s");var q=packet();q.vertices=[];q.triangles=[];_ = try x.apply(q);try check("empty tile unknown",!x.sourceComplete)
 let z=try Replay("s");q=packet();q.complete=false;_ = try z.apply(q);try check("truncated unknown",!z.sourceComplete)
 q.revision=2;q.timestamp=2;q.removed=true;q.vertices=[];q.triangles=[];q.transform=[];_ = try z.apply(q);try check("removal unknown",!z.sourceComplete && z.tiles.isEmpty)
 try z.reset("s",1);try check("generation fence",try z.apply(packet())=="wrong-session")
 for (name,edit) in [("scale",{(p:inout Packet)in p.transform[0]=2}),("nonfinite",{(p:inout Packet)in p.vertices[0] = .nan}),("indices",{(p:inout Packet)in p.triangles[0]=100}),("reflection",{(p:inout Packet)in p.transform[0] = -1})] {
  let r=try Replay("s");var a=packet();edit(&a);try check(name+" rejected",rejected{_ = try r.apply(a)} && !r.sourceComplete && r.unknown.contains("invalid-input"))
 }
 let b=try Replay("s",maxTiles:1);_ = try b.apply(packet());q=packet();q.anchor="b";_ = try b.apply(q);try check("eviction unknown",b.unknown.contains("evicted:a") && !b.sourceComplete)
 let m=try Replay("s",maxRecords:1);_ = try m.apply(packet());try check("metadata cap",try m.apply(q)=="metadata-budget")
 let cap=try Replay("s",maxTriangles:1);q=packet();q.triangles=[0,2,1,0,2,1];try check("triangle cap",rejected{_ = try cap.apply(q)})
 let lc=try Replay("s",maxVertices:3);_ = try lc.apply(packet());q=packet();q.anchor="b";try check("ledger geometry cap",try lc.apply(q)=="ledger-geometry-budget")
 let rm=try Replay("s");q=packet();q.removed=true;q.transform=Array(repeating:0,count:10000)
 try check("oversized removal payload rejected",rejected{_ = try rm.apply(q)} && rm.ledger.isEmpty && !rm.sourceComplete)
 try check("authority false",s.receipt()["authorizesPhysicalGuidance"] as? Bool == false)
}
func parity(_ a:NativeRoute,_ b:NativeRoute)->Bool {
 guard a.complete==b.complete,a.status==b.status,a.error==b.error,a.points.count==b.points.count else{return false}
 let x=a.points.flatMap{$0}+a.projected_start+a.projected_goal,y=b.points.flatMap{$0}+b.projected_start+b.projected_goal
 return x.count==y.count && zip(x,y).allSatisfy{$0.isFinite && $1.isFinite && abs($0-$1)<=1e-5}
}
func authoredExclusion(_ polygon:[Double]=[-0.4,-0.4,0.4,-0.4,0.4,0.4,-0.4,0.4],_ heights:[Double]=[1,1.1],frame:String="phone-corrected-level-game-yup-v1")->Exclusion {
 let n=polygon.count/2;return Exclusion(id:"test",revision:1,meshFrameID:frame,polygonFrameID:frame,heightFrameID:frame,polygonLevelXY:(0..<n).flatMap{[polygon[$0*2],-polygon[$0*2+1]]},polygonPlannerXZ:polygon,observedTopHeightRange:heights,unknown:true,authority:false,bodyInflationApplied:false)
}
func exclusionFixtures()throws {
 let v:[Double]=[-3,0,-3,-3,0,3,3,0,3,3,0,-3],t:[Int32]=[0,1,2,0,2,3]
 let a=try Native(v,t),e=try Native(v,t,exclusion:authoredExclusion())
 try check("zero exclusion spans",a.markedSpans==0);try check("exclusion marks spans",e.markedSpans>0)
 let rev=try Native(v,t,exclusion:authoredExclusion([-0.4,0.4,0.4,0.4,0.4,-0.4,-0.4,-0.4]))
 try check("winding span parity",rev.markedSpans==e.markedSpans)
 try check("winding route parity",parity(try e.route([-2,0,0],[2,0,0]),try rev.route([-2,0,0],[2,0,0])))
 for (label,h) in [("overhead",[3.0,3.1]),("below",[-3.0,-2.9])]{let far=try Native(v,t,exclusion:authoredExclusion([-0.4,-0.4,0.4,-0.4,0.4,0.4,-0.4,0.4],h));try check(label+" disjoint spans",far.markedSpans==0)}
 for (label,p) in [("duplicate",[-0.4,-0.4,0.4,-0.4,0.4,0.4,-0.4,-0.4]),("bowtie",[0.0,0,1,1,0,1,1,0]),("concave",[0.0,0,2,0,1,0.5,2,2,0,2]),("nonfinite",[Double.nan,0,1,0,0,1])]{try check(label+" polygon reject",rejected{_ = try authoredExclusion(p).validatedPolygon(expectedFrame:"phone-corrected-level-game-yup-v1")})}
 try check("Float32 collapsed polygon rejected",rejected{_ = try authoredExclusion([1e8,1e8,1e8+1,1e8,1e8+1,1e8+1,1e8,1e8+1]).validatedPolygon(expectedFrame:"phone-corrected-level-game-yup-v1")})
 try check("wrong exclusion frame reject",rejected{_ = try SnapshotOwner(authoredExclusion(frame:"other"))})
 let owner=try SnapshotOwner(authoredExclusion());try check("unsupported removal retires",rejected{try owner.unsupportedUpdateOrRemoval()} && !owner.usable && rejected{_ = try owner.native(v,t)})
 try check("raw height not double expanded",authoredExclusion().diagnosticFootInterval == [-0.75,1.1])
}
let started=Date();try fixtures();try exclusionFixtures()
guard CommandLine.arguments.count==3 else{throw Failure.invalid("arguments")}
let data=try Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[1]));guard data.count<=8<<20 else{throw Failure.invalid("fixture size")}
let input=try JSONDecoder().decode(Input.self,from:data);let store=try Replay(input.packets[0].session)
for p in input.packets{_ = try store.apply(p)}
let (v,f)=store.geometry();try check("triangle count",f.count==input.triangles.count)
var maxError=0.0,sameFloat=true
for i in input.triangles.indices{for d in 0..<3{let a=input.vertices[Int(input.triangles[i])*3+d],b=v[Int(f[i])*3+d];maxError=max(maxError,abs(a-b));sameFloat = sameFloat && Float(a).bitPattern==Float(b).bitPattern}}
try check("double transform parity",maxError<=1e-9);try check("float32 exact geometry",sameFloat)
var original=[NativeRoute](),replayed=[NativeRoute]()
do{let native=try Native(input.vertices,input.triangles);for i in 0..<input.anchors.count-1{original.append(try native.route(input.anchors[i],input.anchors[i+1]))}}
do{let native=try Native(v,f);for i in 0..<input.anchors.count-1{replayed.append(try native.route(input.anchors[i],input.anchors[i+1]))}}
try check("five routes",original.count==5 && replayed.count==5 && input.reference.count==5)

let snapshot=try SnapshotOwner(input.exclusion);var excluded=[NativeRoute]();var marked=0
 do{let native=try snapshot.native(v,f);marked=native.markedSpans;for i in 0..<input.anchors.count-1{excluded.append(try native.route(input.anchors[i],input.anchors[i+1]))}}
// Persist measured Apple/native routes before parity can throw. No acceptance change.
func difference(_ a:NativeRoute,_ b:NativeRoute)->[String:Any] {
 let x=a.points.flatMap{$0}+a.projected_start+a.projected_goal,y=b.points.flatMap{$0}+b.projected_start+b.projected_goal
 return ["passesUnchangedParity":parity(a,b),"actualPointCount":a.points.count,"expectedPointCount":b.points.count,"sameStatus":a.status==b.status,"sameCompletion":a.complete==b.complete,"sameError":a.error==b.error,"alignedMaxAbsoluteDelta":zip(x,y).map{abs(Double($0)-Double($1))}.max() ?? 0,"alignedDeltaMeaningful":x.count==y.count]
}
let diagnosticEncoder=JSONEncoder()
let routeDiagnostic:[String:Any]=["schema":1,"physicalAuthority":false,"toleranceUnchanged":1e-5,"markedSpans":marked,"expectedMarkedSpans":input.expectedMarkedSpans,"actualOriginal":try JSONSerialization.jsonObject(with:diagnosticEncoder.encode(original)),"actualReplayed":try JSONSerialization.jsonObject(with:diagnosticEncoder.encode(replayed)),"expectedPython58":try JSONSerialization.jsonObject(with:diagnosticEncoder.encode(input.reference)),"actualExcluded":try JSONSerialization.jsonObject(with:diagnosticEncoder.encode(excluded)),"expectedPython66":try JSONSerialization.jsonObject(with:diagnosticEncoder.encode(input.exclusionReference)),"originalVsReplayed":zip(original,replayed).map{difference($0,$1)},"originalVsPython58":zip(original,input.reference).map{difference($0,$1)},"excludedVsPython66":zip(excluded,input.exclusionReference).map{difference($0,$1)},"checksBeforeComparison":checks]
let diagnosticURL=URL(fileURLWithPath:CommandLine.arguments[2]).deletingLastPathComponent().appendingPathComponent("ROUTE_DIAGNOSTIC.json")
try JSONSerialization.data(withJSONObject:routeDiagnostic,options:[.prettyPrinted,.sortedKeys]).write(to:diagnosticURL)
for i in original.indices{try check("native pair \(i)",parity(original[i],replayed[i]));try check("Python58 pair \(i)",parity(original[i],input.reference[i]))}
 try check("real marked spans Python66 parity",marked==input.expectedMarkedSpans && marked>0)
 try check("five excluded reference pairs",excluded.count==5 && input.exclusionReference.count==5)
 for i in excluded.indices{try check("Python66 excluded pair \(i)",parity(excluded[i],input.exclusionReference[i]))}
let encoder=JSONEncoder();let paths=try JSONSerialization.jsonObject(with:encoder.encode([original,replayed,excluded]))
let result:[String:Any]=["scope":"Linux Swift static frozen tabletop exclusion snapshot to C ABI, not ARKit or movement","checks":checks,"passed":checks.values.allSatisfy{$0},"maxCoordinateErrorMetres":maxError,"float32TriangleCoordinatesExact":sameFloat,"coverage":store.receipt(),"markedSpans":marked,"observedRawHeightRange":input.exclusion.observedTopHeightRange,"nativeFloatHeightRange":input.exclusion.observedTopHeightRange.map{Double(Float($0))},"diagnosticFootHeightInterval":input.exclusion.diagnosticFootInterval,"exclusionUnknown":input.exclusion.unknown,"exclusionUpdatesSupported":false,"routes":paths,"authorizesPhysicalGuidance":false,"rawDepthImplemented":false,"wallSeconds":Date().timeIntervalSince(started)]
try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:CommandLine.arguments[2]));print("PASS \(checks.count) checks, five route pairs, max error \(maxError)")

// Portable asynchronous ingress and lifecycle fixtures, separate from legacy55.
var runtimeChecks=[String:Bool]()
func rc(_ name:String,_ value:Bool)throws{runtimeChecks[name]=value;if !value{throw Failure.invalid("runtime: "+name)}}
let identity:[Double]=[1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1]
func event(_ revision:Int=1,session:String="live",generation:Int=0,removed:Bool=false,complete:Bool=true)->MeshAnchorEvent {
 MeshAnchorEvent(sessionID:session,generation:generation,anchorID:"floor",revision:revision,timestamp:Double(revision),vertices:removed ? [] : [-3,0,-3,-3,0,3,3,0,3,3,0,-3],triangles:removed ? [] : [0,1,2,0,2,3],columnMajorTransform:removed ? [] : identity,complete:complete,removed:removed)
}
let body=try MeshCandidateBody(radius:0.225,height:1.75)
func drain(){RoomMeshCandidateRuntime.worker.sync{}}
func query(_ rt:RoomMeshCandidateRuntime)throws->MeshCandidateRoute {
 let done=DispatchSemaphore(value:0);let box=NSLock();var result:Result<MeshCandidateRoute,MeshCandidateError>?
 rt.request(start:[-2,0,0],goal:[2,0,0],body:body){r in box.lock();result=r;box.unlock();done.signal()}
 guard done.wait(timeout:.now()+5) == .success else{throw Failure.invalid("query timeout")}
 box.lock();defer{box.unlock()};return try result!.get()
}
let rt=try RoomMeshCandidateRuntime(sessionID:"live");try rc("admit add",rt.offer(event()));drain()
let one=try query(rt);try rc("floor candidate route",one.complete && one.sourceDeliveryComplete)
try rc("authority permanently false",!one.authorizesPhysicalGuidance && !one.actualWorldCoverageKnown && one.rawDepthHazardVeto && !one.rawDepthHazardImplemented)
try rc("current ticket",rt.isCurrent(one))
try rc("replace event admitted",rt.offer(event(2)));try rc("event ingress retires old ticket",!rt.isCurrent(one));drain()
let two=try query(rt);rt.invalidate();try rc("hazard invalidation immediate",!rt.isCurrent(two));let uncertain=try query(rt);try rc("hazard gap not cleared by mesh",!uncertain.sourceDeliveryComplete && uncertain.unknownCoverage.contains("ingress-or-lifecycle-gap"))
try rt.reset(sessionID:"live",generation:1);try rc("old generation rejected",!rt.offer(event(3)));try rc("new generation accepted",rt.offer(event(session:"live",generation:1)));drain();let three=try query(rt)
try rc("removal accepted",rt.offer(event(2,session:"live",generation:1,removed:true)));try rc("removal revokes ticket immediately",!rt.isCurrent(three));drain();try rc("removed geometry cannot route",rejected{_ = try query(rt)})
let truncated=try RoomMeshCandidateRuntime(sessionID:"live");_ = truncated.offer(event(complete:false));drain();try rc("truncated unknown",!(try query(truncated)).sourceDeliveryComplete)
let overflow=try RoomMeshCandidateRuntime(sessionID:"live");let gate=DispatchSemaphore(value:0);let began=DispatchSemaphore(value:0)
RoomMeshCandidateRuntime.worker.async{began.signal();gate.wait()};_ = began.wait(timeout:.now()+2)
var admitted=0;for i in 1...9{if overflow.offer(event(i)){admitted+=1}};try rc("bounded mailbox eight",admitted==8);gate.signal();drain();try rc("overflow never certifies delivery",!(try query(overflow)).sourceDeliveryComplete)
let race=try RoomMeshCandidateRuntime(sessionID:"live");_ = race.offer(event());drain();let barrier=DispatchSemaphore(value:0),startedBarrier=DispatchSemaphore(value:0),finished=DispatchSemaphore(value:0);var oldQueryRejected=false
RoomMeshCandidateRuntime.worker.async{startedBarrier.signal();barrier.wait()};_ = startedBarrier.wait(timeout:.now()+2)
race.request(start:[-2,0,0],goal:[2,0,0],body:body){r in if case .failure(.stale)=r{oldQueryRejected=true};finished.signal()}
_ = race.offer(event(2,removed:true));barrier.signal();_ = finished.wait(timeout:.now()+5);try rc("queued removal fences pending query",oldQueryRejected)
let stopped=try RoomMeshCandidateRuntime(sessionID:"live");_ = stopped.offer(event());drain();let beforeStop=try query(stopped);stopped.stop();try rc("stop fences output",!stopped.isCurrent(beforeStop));try rc("stopped event rejected",!stopped.offer(event(2)))
let matrix=MeshAnchorEvent(sessionID:"s",generation:0,anchorID:"a",revision:1,timestamp:1,vertices:[0,0,0,1,0,0,0,0,1],triangles:[0,1,2],columnMajorTransform:[0,0,-1,0,0,1,0,0,1,0,0,0,3,2,4,1],complete:true)
let replay=try Replay("s");_ = try replay.apply(matrix.packet);try rc("column-major transform exactly once",replay.geometry().0 == [3,2,4,3,2,3,4,2,4])
let c=Double(Float(cos(0.7))),sn=Double(Float(sin(0.7)));var rotation=packet();rotation.transform=[c,0,sn,0,0,1,0,0,-sn,0,c,0,0,0,0,1];let real=try Replay("s");try rc("Float32 rigid rotation accepted",try real.apply(rotation)=="accepted")
let goalRuntime=try RoomMeshCandidateRuntime(sessionID:"live");_ = goalRuntime.offer(event());drain();let oldGoal=try query(goalRuntime);_ = try query(goalRuntime);try rc("new goal request revokes old snapshot",!goalRuntime.isCurrent(oldGoal))
let validBeforeBad=try query(goalRuntime);let badDone=DispatchSemaphore(value:0);goalRuntime.request(start:[Float.nan,0,0],goal:[2,0,0],body:body){_ in badDone.signal()};try rc("invalid goal revokes old snapshot",!goalRuntime.isCurrent(validBeforeBad));_ = badDone.wait(timeout:.now()+2)
let badRuntime=try RoomMeshCandidateRuntime(sessionID:"live");_ = badRuntime.offer(event());drain();let badBefore=try query(badRuntime);let badEvent=MeshAnchorEvent(sessionID:"live",generation:0,anchorID:"floor",revision:2,timestamp:2,vertices:[Double.nan,0,0],triangles:[0,0,0],columnMajorTransform:identity,complete:true);try rc("invalid event admitted bounded then flagged",badRuntime.offer(badEvent));try rc("invalid event retires old snapshot",!badRuntime.isCurrent(badBefore));drain();try rc("invalid event never restores completeness",!(try query(badRuntime)).sourceDeliveryComplete)
let aba=try RoomMeshCandidateRuntime(sessionID:"live");_ = aba.offer(event());drain();_ = try query(aba);try aba.reset(sessionID:"other",generation:0);try aba.reset(sessionID:"live",generation:0);try rc("ABA reset does not reuse retained owner",rejected{_ = try query(aba)})
let queuedABA=try RoomMeshCandidateRuntime(sessionID:"live");let abaGate=DispatchSemaphore(value:0),abaStart=DispatchSemaphore(value:0)
RoomMeshCandidateRuntime.worker.async{abaStart.signal();abaGate.wait()};_ = abaStart.wait(timeout:.now()+2);_ = queuedABA.offer(event());try queuedABA.reset(sessionID:"other",generation:0);try queuedABA.reset(sessionID:"live",generation:0);abaGate.signal();drain();try rc("ABA reset drops old queued event",rejected{_ = try query(queuedABA)});_ = queuedABA.offer(event());drain();try rc("fresh event after ABA can rebuild",(try query(queuedABA)).sourceDeliveryComplete)
let capacity=try RoomMeshCandidateRuntime(sessionID:"live");_ = capacity.offer(event());drain();let capOld=try query(capacity);let capGate=DispatchSemaphore(value:0),capStarted=DispatchSemaphore(value:0),capDone=DispatchSemaphore(value:0)
RoomMeshCandidateRuntime.worker.async{capStarted.signal();capGate.wait()};_ = capStarted.wait(timeout:.now()+2)
let eighthDone=DispatchSemaphore(value:0);var eighthStale=false
for i in 0..<8 {capacity.request(start:[-2,0,0],goal:[2,0,0],body:body){r in if i==7{if case .failure(.stale)=r{eighthStale=true};eighthDone.signal()}}}
capacity.request(start:[-1,0,0],goal:[1,0,0],body:body){r in if case .failure(.unavailable)=r{capDone.signal()}}
try rc("capacity rejected query completes unavailable",capDone.wait(timeout:.now()+2) == .success);try rc("capacity rejected goal invalidates old snapshot",!capacity.isCurrent(capOld));capGate.signal();drain();_ = eighthDone.wait(timeout:.now()+2);try rc("rejected ninth query retires eighth queued query",eighthStale)
let runtimeResult:[String:Any]=["passed":runtimeChecks.values.allSatisfy{$0},"checks":runtimeChecks,"physicalAuthority":false,"ARKitExecuted":false,"scope":"Portable candidate package asynchronous lifecycle only"]
try JSONSerialization.data(withJSONObject:runtimeResult,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:CommandLine.arguments[2]).deletingLastPathComponent().appendingPathComponent("RUNTIME_RESULT.json"));print("PASS \(runtimeChecks.count) runtime checks")
