import Foundation

public enum MeshCandidateError: Error { case invalidInput, unavailable, stale, nativeFailure }
/// Source semantics, not live support evidence. Obstacles are still rasterized.
public enum MeshTriangleSupport: UInt8, Codable, Sendable { case obstacle = 0, floor = 1 }
/// Classified mode never promotes furniture tops or unclassified triangles to floor.
/// The default preserves the existing unclassified/legacy diagnostic API.
public enum MeshSupportPolicy: Equatable, Sendable { case legacySlope, classifiedFloorOnly }
/// Owned packed anchor-local geometry. Transform is ARKit column-major, +Y up, metres.
public struct MeshAnchorEvent {
 public let sessionID: String, anchorID: String
 public let generation: Int, revision: Int
 public let timestamp: Double
 public let vertices: [Double], triangles: [Int32], columnMajorTransform: [Double]
 public let triangleSupport: [MeshTriangleSupport]?
 public let complete: Bool, removed: Bool
 public init(sessionID: String, generation: Int, anchorID: String, revision: Int,
             timestamp: Double, vertices: [Double], triangles: [Int32],
             columnMajorTransform: [Double], complete: Bool, removed: Bool = false,
             triangleSupport: [MeshTriangleSupport]? = nil) {
  self.sessionID=sessionID;self.generation=generation;self.anchorID=anchorID;self.revision=revision
  self.timestamp=timestamp;self.vertices=vertices;self.triangles=triangles
  self.columnMajorTransform=columnMajorTransform;self.complete=complete;self.removed=removed
  self.triangleSupport=triangleSupport
 }
 fileprivate var bounded: Bool {
  !sessionID.isEmpty && sessionID.utf8.count<=128 && !anchorID.isEmpty && anchorID.utf8.count<=128 && generation>=0 && revision>=0 && timestamp.isFinite && timestamp>=0 && vertices.count<=600000 && triangles.count<=300000 && (triangleSupport?.count ?? 0)<=100000 && (removed ? columnMajorTransform.isEmpty && vertices.isEmpty && triangles.isEmpty && triangleSupport == nil : columnMajorTransform.count==16)
 }
 var packet: Packet {
  let rows=removed ? [] : (0..<16).map{columnMajorTransform[($0%4)*4+$0/4]}
  return Packet(session:sessionID,generation:generation,anchor:anchorID,revision:revision,timestamp:timestamp,vertices:vertices,triangles:triangles,transform:rows,complete:complete,removed:removed,triangleSupport:triangleSupport)
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
 private var discarding=false, discarded=false, discardScheduled=false
 private var discardWaiters:[()->Void]=[]
 private let maxPending=8, maxPendingScalars=900000
 private let supportPolicy: MeshSupportPolicy
 // Accessed only on worker. No native handles escape a single query.
 private var owner: Replay?
 public init(sessionID: String,generation: Int=0,supportPolicy: MeshSupportPolicy = .legacySlope)throws {
  guard !sessionID.isEmpty,sessionID.utf8.count<=128,generation>=0 else{throw MeshCandidateError.invalidInput}
  session=sessionID;self.generation=generation;self.supportPolicy=supportPolicy
 }
 private func locked<T>(_ f:() throws ->T) rethrows ->T {lock.lock();defer{lock.unlock()};return try f()}
 private func advance(){if revision == UInt64.max {stopped=true;gap=true}else{revision+=1}}
 /// Tracking loss, body/goal changes and raw-depth veto call this before further query work.
 public func invalidate() {locked{advance();gap=true}}
 public func stop(){locked{advance();stopped=true;gap=true}}
 /// Terminal fence plus asynchronous release of this runtime's retained geometry.
 /// Completion is not ARKit/caller/system-memory erasure, nor callback cancellation.
 /// Every caller is acknowledged off-lock after all admitted native work drains.
 /// Reset cannot revive this owner once discard starts; do not replace it to bypass
 /// outstanding work. Ordinary stop/reset retain their existing nonterminal behavior.
 public func stopAndDiscard(completion:@escaping ()->Void) {
  locked {
   if discarded {DispatchQueue.global(qos:.utility).async {completion()};return}
   if !discarding {advance();stopped=true;gap=true;discarding=true}
   discardWaiters.append(completion)
   scheduleDiscardIfDrained()
  }
 }
 // Called under lock. A last-job defer may run before its captured event dies;
 // the subsequent serial-worker block ensures that job has actually returned.
 private func scheduleDiscardIfDrained() {
  guard discarding,!discarded,!discardScheduled,pending==0 else{return}
  discardScheduled=true
  Self.worker.async { [self] in
   owner=nil;ownerLifecycle=nil
   let waiters=locked { ()->[()->Void] in
    discarded=true
    let result=discardWaiters;discardWaiters.removeAll(keepingCapacity:false)
    return result
   }
   for waiter in waiters {DispatchQueue.global(qos:.utility).async {waiter()}}
  }
 }
 public func reset(sessionID:String,generation:Int)throws {
  try locked {
   guard !discarding else{throw MeshCandidateError.unavailable}
   guard !sessionID.isEmpty,sessionID.utf8.count<=128,generation>=0,(sessionID != session || generation>self.generation),revision<UInt64.max else{throw MeshCandidateError.invalidInput}
   advance();lifecycle=revision;session=sessionID;self.generation=generation;gap=false;stopped=false
  }
 }
 private func matches(_ s:String,_ g:Int,_ r:UInt64)->Bool {session==s && generation==g && revision==r && !stopped}
 /// False means rejected/overflow, never free space. Any missed in-session event
 /// makes delivery unknown until a new session/generation reset.
 @discardableResult public func offer(_ event:MeshAnchorEvent)->Bool {
  let scalarCount=event.vertices.count+event.triangles.count+(event.triangleSupport?.count ?? 0)
  let shapeBounded=event.bounded
  let supportValid = event.removed ? event.triangleSupport == nil :
   (supportPolicy == .classifiedFloorOnly ? event.triangles.count%3 == 0 && event.triangleSupport?.count == event.triangles.count/3 : event.triangleSupport == nil)
  lock.lock()
  let admitted: Bool = {
   guard !stopped,event.sessionID==session,event.generation==generation else{return false}
   advance()
   guard shapeBounded,supportValid,pending<maxPending,scalarCount<=maxPendingScalars-pendingScalars else{gap=true;return false}
   pending+=1;pendingScalars+=scalarCount;return true
  }()
  guard admitted else{lock.unlock();return false}
  let eventLifecycle=lifecycle
  Self.worker.async { [self] in
   defer{locked{pending-=1;pendingScalars-=scalarCount;scheduleDiscardIfDrained()}}
   guard locked({!stopped && lifecycle==eventLifecycle && session==event.sessionID && generation==event.generation})else{return}
   do {
    if ownerLifecycle != eventLifecycle || owner?.session != event.sessionID || owner?.generation != event.generation {owner=try Replay(event.sessionID,event.generation,supportPolicy:supportPolicy);ownerLifecycle=eventLifecycle}
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
   defer{locked{pending-=1;scheduleDiscardIfDrained()}}
   guard locked({matches(s,g,r)}),let owner=owner,ownerLifecycle==cycle,owner.session==s,owner.generation==g else{finish(.failure(.stale));return}
   do {
    let(v,t)=owner.geometry();let native=try Native(v,t,radius:body.radius,height:body.height,triangleSupport:owner.geometrySupport())
    let path=try native.route(start,goal)
    let state=locked{(matches(s,g,r),gap)}
    guard state.0 else{finish(.failure(.stale));return}
    var unknown=owner.unknown.sorted();if state.1{unknown.append("ingress-or-lifecycle-gap")}
    finish(.success(MeshCandidateRoute(sessionID:s,generation:g,revision:r,points:path.points,projectedStart:path.projected_start,projectedGoal:path.projected_goal,complete:path.complete,nativeStatus:path.status,sourceDeliveryComplete:owner.sourceComplete && !state.1,unknownCoverage:unknown)))
   } catch {finish(.failure(.nativeFailure))}
  }
 }
}
