import Foundation

public enum MeshCandidateError: Error { case invalidInput, unavailable, stale, nativeFailure }
/// Owned packed anchor-local geometry. Transform is ARKit column-major, +Y up, metres.
public struct MeshAnchorEvent {
 public let sessionID: String, anchorID: String
 public let generation: Int, revision: Int
 public let timestamp: Double
 public let vertices: [Double], triangles: [Int32], columnMajorTransform: [Double]
 public let complete: Bool, removed: Bool
 public init(sessionID: String, generation: Int, anchorID: String, revision: Int,
             timestamp: Double, vertices: [Double], triangles: [Int32],
             columnMajorTransform: [Double], complete: Bool, removed: Bool = false) {
  self.sessionID=sessionID;self.generation=generation;self.anchorID=anchorID;self.revision=revision
  self.timestamp=timestamp;self.vertices=vertices;self.triangles=triangles
  self.columnMajorTransform=columnMajorTransform;self.complete=complete;self.removed=removed
 }
 fileprivate var bounded: Bool {
  !sessionID.isEmpty && sessionID.utf8.count<=128 && !anchorID.isEmpty && anchorID.utf8.count<=128 && generation>=0 && revision>=0 && timestamp.isFinite && timestamp>=0 && vertices.count<=600000 && triangles.count<=300000 && (removed ? columnMajorTransform.isEmpty && vertices.isEmpty && triangles.isEmpty : columnMajorTransform.count==16)
 }
 var packet: Packet {
  let rows=removed ? [] : (0..<16).map{columnMajorTransform[($0%4)*4+$0/4]}
  return Packet(session:sessionID,generation:generation,anchor:anchorID,revision:revision,timestamp:timestamp,vertices:vertices,triangles:triangles,transform:rows,complete:complete,removed:removed)
 }
}
public struct MeshCandidateBody {
 public let radius: Float, height: Float
 public init(radius: Float, height: Float)throws {
  guard radius.isFinite,height.isFinite,(0.1...2).contains(radius),(0.5...3).contains(height) else{throw MeshCandidateError.invalidInput}
  self.radius=radius;self.height=height
 }
}
public struct MeshCandidateRoute {
 public let sessionID: String, generation: Int, revision: UInt64
 public let points: [[Float]], projectedStart: [Float], projectedGoal: [Float]
 public let complete: Bool, nativeStatus: UInt32, sourceDeliveryComplete: Bool
 public let unknownCoverage: [String]
 public let authorizesPhysicalGuidance=false, actualWorldCoverageKnown=false, rawDepthHazardImplemented=false, rawDepthHazardVeto=true
}
/// Candidate-only bounded mailbox. No ARKit, speech, haptics or motion outputs.
/// Ingress takes only a short metadata lock; native work executes on a utility queue.
/// Callers MUST recheck isCurrent before displaying/using a candidate snapshot.
/// This does not implement or weaken the independent live raw-depth hazard pipeline.
public final class RoomMeshCandidateRuntime {
 private let lock=NSLock()
 // Native adapter has process-global error text: serialize all package native calls.
 static let worker=DispatchQueue(label:"blind.room-mesh.native",qos:.utility)
 private var session: String, generation: Int, revision: UInt64=0
 private var lifecycle:UInt64=0, ownerLifecycle:UInt64?
 private var pending=0, pendingScalars=0, gap=false, stopped=false
 private let maxPending=8, maxPendingScalars=900000
 // Accessed only on worker. No native handles escape a single query.
 private var owner: Replay?
 public init(sessionID: String,generation: Int=0)throws {
  guard !sessionID.isEmpty,sessionID.utf8.count<=128,generation>=0 else{throw MeshCandidateError.invalidInput}
  session=sessionID;self.generation=generation
 }
 private func locked<T>(_ f:() throws ->T) rethrows ->T {lock.lock();defer{lock.unlock()};return try f()}
 private func advance(){if revision == UInt64.max {stopped=true;gap=true}else{revision+=1}}
 /// Tracking loss, body/goal changes and raw-depth veto call this before further query work.
 public func invalidate() {locked{advance();gap=true}}
 public func stop(){locked{advance();stopped=true;gap=true}}
 public func reset(sessionID:String,generation:Int)throws {
  try locked {
   guard !sessionID.isEmpty,sessionID.utf8.count<=128,generation>=0,(sessionID != session || generation>self.generation),revision<UInt64.max else{throw MeshCandidateError.invalidInput}
   advance();lifecycle=revision;session=sessionID;self.generation=generation;gap=false;stopped=false
  }
 }
 private func matches(_ s:String,_ g:Int,_ r:UInt64)->Bool {session==s && generation==g && revision==r && !stopped}
 /// False means rejected/overflow, never free space. Any missed in-session event
 /// makes delivery unknown until a new session/generation reset.
 @discardableResult public func offer(_ event:MeshAnchorEvent)->Bool {
  let scalarCount=event.vertices.count+event.triangles.count
  let shapeBounded=event.bounded
  lock.lock()
  let admitted: Bool = {
   guard !stopped,event.sessionID==session,event.generation==generation else{return false}
   advance()
   guard shapeBounded,pending<maxPending,scalarCount<=maxPendingScalars-pendingScalars else{gap=true;return false}
   pending+=1;pendingScalars+=scalarCount;return true
  }()
  guard admitted else{lock.unlock();return false}
  let eventLifecycle=lifecycle
  Self.worker.async { [self] in
   defer{locked{pending-=1;pendingScalars-=scalarCount}}
   guard locked({!stopped && lifecycle==eventLifecycle && session==event.sessionID && generation==event.generation})else{return}
   do {
    if ownerLifecycle != eventLifecycle || owner?.session != event.sessionID || owner?.generation != event.generation {owner=try Replay(event.sessionID,event.generation);ownerLifecycle=eventLifecycle}
    _ = try owner!.apply(event.packet)
   } catch {recordOfferFailure(sessionID:event.sessionID,generation:event.generation,lifecycle:eventLifecycle)}
  }
  lock.unlock()
  return true
 }
 // Internal failure-commit boundary: tests can reproduce a late throw without
 // timing a native operation or exposing a public injection/clearance hook.
 // Revision is deliberately not compared: a newer offer/query in the same
 // lifecycle does not make a missed event harmless. Only reset retires it.
 func recordOfferFailure(sessionID:String,generation:Int,lifecycle:UInt64) {
  locked {
   guard !stopped,self.lifecycle==lifecycle,session==sessionID,self.generation==generation else{return}
   gap=true
  }
 }
 public func isCurrent(_ candidate:MeshCandidateRoute)->Bool {
  locked{matches(candidate.sessionID,candidate.generation,candidate.revision)}
 }
 /// Explicit body and session-local query points; no projection is a movement command.
 /// Each new body/goal request invalidates older query snapshots at ingress.
 public func request(start:[Float],goal:[Float],body:MeshCandidateBody,
                     completion:@escaping(Result<MeshCandidateRoute,MeshCandidateError>)->Void) {
  let finish: (Result<MeshCandidateRoute,MeshCandidateError>)->Void = { result in DispatchQueue.global(qos:.utility).async { completion(result) } }
  guard start.count==3,goal.count==3,(start+goal).allSatisfy({$0.isFinite})else{locked{advance()};finish(.failure(.invalidInput));return}
  let token:(String,Int,UInt64,UInt64)?=locked {
   advance()
   guard !stopped,pending<maxPending else{return nil}
   pending+=1;return(session,generation,revision,lifecycle)
  }
  guard let (s,g,r,cycle)=token else{finish(.failure(.unavailable));return}
  Self.worker.async { [self] in
   defer{locked{pending-=1}}
   guard locked({matches(s,g,r)}),let owner=owner,ownerLifecycle==cycle,owner.session==s,owner.generation==g else{finish(.failure(.stale));return}
   do {
    let(v,t)=owner.geometry();let native=try Native(v,t,radius:body.radius,height:body.height)
    let path=try native.route(start,goal)
    let state=locked{(matches(s,g,r),gap)}
    guard state.0 else{finish(.failure(.stale));return}
    var unknown=owner.unknown.sorted();if state.1{unknown.append("ingress-or-lifecycle-gap")}
    finish(.success(MeshCandidateRoute(sessionID:s,generation:g,revision:r,points:path.points,projectedStart:path.projected_start,projectedGoal:path.projected_goal,complete:path.complete,nativeStatus:path.status,sourceDeliveryComplete:owner.sourceComplete && !state.1,unknownCoverage:unknown)))
   } catch {finish(.failure(.nativeFailure))}
  }
 }
}
