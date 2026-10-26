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
for i in original.indices{try check("native pair \(i)",parity(original[i],replayed[i]));try check("Python58 pair \(i)",parity(original[i],input.reference[i]))}
let snapshot=try SnapshotOwner(input.exclusion);var excluded=[NativeRoute]();var marked=0
 do{let native=try snapshot.native(v,f);marked=native.markedSpans;for i in 0..<input.anchors.count-1{excluded.append(try native.route(input.anchors[i],input.anchors[i+1]))}}
 try check("real marked spans Python66 parity",marked==input.expectedMarkedSpans && marked>0)
 try check("five excluded reference pairs",excluded.count==5 && input.exclusionReference.count==5)
 for i in excluded.indices{try check("Python66 excluded pair \(i)",parity(excluded[i],input.exclusionReference[i]))}
let encoder=JSONEncoder();let paths=try JSONSerialization.jsonObject(with:encoder.encode([original,replayed,excluded]))
let result:[String:Any]=["scope":"Linux Swift static frozen tabletop exclusion snapshot to C ABI, not ARKit or movement","checks":checks,"passed":checks.values.allSatisfy{$0},"maxCoordinateErrorMetres":maxError,"float32TriangleCoordinatesExact":sameFloat,"coverage":store.receipt(),"markedSpans":marked,"observedRawHeightRange":input.exclusion.observedTopHeightRange,"nativeFloatHeightRange":input.exclusion.observedTopHeightRange.map{Double(Float($0))},"diagnosticFootHeightInterval":input.exclusion.diagnosticFootInterval,"exclusionUnknown":input.exclusion.unknown,"exclusionUpdatesSupported":false,"routes":paths,"authorizesPhysicalGuidance":false,"rawDepthImplemented":false,"wallSeconds":Date().timeIntervalSince(started)]
try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:CommandLine.arguments[2]));print("PASS \(checks.count) checks, five route pairs, max error \(maxError)")
