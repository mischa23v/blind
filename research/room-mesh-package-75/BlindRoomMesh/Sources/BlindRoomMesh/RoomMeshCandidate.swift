import Foundation
#if DEBUG && canImport(Darwin)
import Darwin
#elseif DEBUG && canImport(Glibc)
import Glibc
#endif

public enum MeshCandidateError: Error {
 case invalidInput, unavailable, stale, nativeFailure
 case endpointAssociationRejected(MeshEndpointAdmissionReceipt)
}
/// Default remains the original diagnostic comparator. Strict mode only checks
/// requested XZ membership; it does not establish physical support or clearance.
public enum MeshEndpointPolicy: String, Codable, Sendable {
 case legacyNearestProjection, requireSuppliedXZOverPolygon
}
public struct MeshEndpointAssociation: Codable, Sendable {
 public let requested: [Float], projected: [Float]
 public let found: Bool, isOverPolygon: Bool, nativeStatus: UInt32
}
public struct MeshEndpointAdmissionReceipt: Codable, Sendable {
 public let policy: MeshEndpointPolicy
 public let start: MeshEndpointAssociation, goal: MeshEndpointAssociation
 public let authorizesPhysicalGuidance: Bool
}
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
 public let endpointPolicy: MeshEndpointPolicy
 public let endpointAdmission: MeshEndpointAdmissionReceipt?
 public let authorizesPhysicalGuidance=false, actualWorldCoverageKnown=false, rawDepthHazardImplemented=false, rawDepthHazardVeto=true
}
/// Conservative logical retained-payload bounds (including reserved metadata),
/// not an exact encoded size or a claim about allocator/RSS or device timing.
public struct MeshSourceSnapshotLimits: Sendable {
 public let anchors:Int, records:Int, vertices:Int, triangles:Int, payloadBytes:Int
 public init(anchors:Int=64,records:Int=256,vertices:Int=200000,triangles:Int=100000,payloadBytes:Int=8000000) {
  self.anchors=anchors;self.records=records;self.vertices=vertices;self.triangles=triangles;self.payloadBytes=payloadBytes
 }
 var valid:Bool {(1...64).contains(anchors) && (1...256).contains(records) && (1...200000).contains(vertices) && (1...100000).contains(triangles) && (1...8000000).contains(payloadBytes)}
}
public enum MeshSourceSnapshotError: Error {case invalidLimits,budget,unavailable,stale,invalidRetainedState}
/// Ledger bookkeeping only: storedRevision is not a native mesh capture version.
public struct MeshSourceAnchorReceipt: Sendable {
 public let anchorID:String,storedRevision:Int,receiptUptime:Double
 public let removed:Bool,hasRetainedGeometry:Bool,complete:Bool
 public var captureUptime:Double? {nil}
}
/// Original admitted anchor-local values. Apply columnMajorTransform ONCE to
/// obtain the session-world frame; these vertices have NOT already been transformed.
public struct MeshSourceAnchorGeometry: Sendable {
 public let anchorID:String
 public let localVertices:[Double],triangleIndices:[Int32],columnMajorTransform:[Double]
 /// Normalized planner roles, NOT original ARKit classification labels.
 public let normalizedSupportRoles:[MeshTriangleSupport]?
 public var rawARKitClassificationsAvailable:Bool {false}
}
/// Immutable retained-source inspection, never a route, pose or clearance ticket.
/// isCurrent checks delivery identity, NOT real-world freshness. On incomplete
/// delivery, retained geometry may be superseded: inspect it only as diagnostics.
public struct MeshSourceGeometrySnapshot: Sendable {
 public let sessionID:String,generation:Int,revision:UInt64
 public let anchors:[MeshSourceAnchorGeometry],records:[MeshSourceAnchorReceipt]
 public let sourceDeliveryComplete:Bool,unknownCoverage:[String],logicalPayloadBytes:Int
 public let coordinateConvention="arkit-anchor-local-column-major-to-session-world-y-up"
 public let units="metres"
 public let authorizesPhysicalGuidance=false,actualWorldCoverageKnown=false
 public var captureUptime:Double? {nil}
 public var retainedGeometryMayBeSuperseded:Bool {!sourceDeliveryComplete}
 fileprivate let ownerID:UUID,lifecycle:UInt64,ingressHadGap:Bool
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
 private let snapshotOwnerID=UUID()
 private var sourceSnapshotPending=false
 // Serial diagnostic delivery also gives native tests an actual completion fence.
 static let sourceSnapshotDeliveryWorker=DispatchQueue(label:"blind.room-mesh.snapshot-delivery",qos:.utility)
 private final class SourceSnapshotDelivery {
  var value:Result<MeshSourceGeometrySnapshot,MeshSourceSnapshotError>?
  init(_ value:Result<MeshSourceGeometrySnapshot,MeshSourceSnapshotError>){self.value=value}
 }
 private var discarding=false, discarded=false, discardScheduled=false
 private var discardWaiters:[()->Void]=[]
 private let maxPending=8, maxPendingScalars=900000
 private let supportPolicy: MeshSupportPolicy
 private let endpointPolicy: MeshEndpointPolicy
 // Accessed only on worker. No native handles escape a single query.
 private var owner: Replay?
 public init(sessionID: String,generation: Int=0,supportPolicy: MeshSupportPolicy = .legacySlope,
             endpointPolicy: MeshEndpointPolicy = .legacyNearestProjection)throws {
  guard !sessionID.isEmpty,sessionID.utf8.count<=128,generation>=0 else{throw MeshCandidateError.invalidInput}
  session=sessionID;self.generation=generation;self.supportPolicy=supportPolicy;self.endpointPolicy=endpointPolicy
 }
#if DEBUG
 /// Explicit synthetic-test opt-in. Release builds contain no receipt storage,
 /// clock reads, stage locks or public diagnostic API. No geometry/identity is kept.
 public enum DiagnosticStage: String, Sendable {
  case requestEnqueued, workerStarted, nativeBuildBegin, nativeBuildEnd
  case workerFinished, requestRetired
  case routeBegin, routeEnd, nativeFailure, completionQueued, completionDelivered
  case discardRequested, discardWorkerStarted, discardReleased, discardCompletionDelivered
 }
 public struct DiagnosticStageReceipt: Sendable {
  public let stage: DiagnosticStage
  public let elapsedMilliseconds: Int
  /// Current worker thread only; nil is unavailable, never zero CPU evidence.
  public let workerCPUTimeMicroseconds: Int64?
  public let workerThreadID: UInt64?
 }
 private var diagnosticCompletion: ((UUID,[DiagnosticStageReceipt])->Void)?
 private var diagnosticDeliveryCount=0
 // Fixed process-wide pending bound, independent of owner/query lifetime.
 private final class DiagnosticDeliveryGate {
  let lock=NSLock()
  var pending=0
  let queue=DispatchQueue(label:"blind.room-mesh.synthetic-timing",qos:.utility)
  func submit(_ work:@escaping ()->Void) {
   lock.lock()
   guard pending<16 else{lock.unlock();return}
   pending+=1;lock.unlock()
   queue.async { [self] in
    defer{lock.lock();pending-=1;lock.unlock()}
    work()
   }
  }
 }
 private static let diagnosticDeliveryGate=DiagnosticDeliveryGate()
 private var diagnosticStartedAt: TimeInterval?
 private var diagnosticReceipts: [DiagnosticStageReceipt] = []
 public private(set) var diagnosticReceiptID: UUID?
 public convenience init(sessionID: String,generation: Int=0,supportPolicy: MeshSupportPolicy = .legacySlope,
                         endpointPolicy: MeshEndpointPolicy = .legacyNearestProjection,
                         captureSyntheticTestTiming: Bool,
                         syntheticTimingCompletion: ((UUID,[DiagnosticStageReceipt])->Void)? = nil)throws {
  try self.init(sessionID:sessionID,generation:generation,supportPolicy:supportPolicy,endpointPolicy:endpointPolicy)
  // Assigned before this owner escapes; never enabled/disabled during work.
  if captureSyntheticTestTiming {
   diagnosticCompletion=syntheticTimingCompletion
   diagnosticReceiptID=UUID()
   diagnosticStartedAt=ProcessInfo.processInfo.systemUptime
  }
 }
 public var diagnosticStageReceipts: [DiagnosticStageReceipt] { locked { diagnosticReceipts } }
 private static func workerCPUClock()->(Int64,UInt64)? {
#if canImport(Darwin) || canImport(Glibc)
  var time=timespec()
  guard clock_gettime(CLOCK_THREAD_CPUTIME_ID,&time)==0,
        time.tv_sec>=0,time.tv_sec<=Int((Int64.max-999_999)/1_000_000),
        time.tv_nsec>=0,time.tv_nsec<1_000_000_000 else{return nil}
#if canImport(Darwin)
  var thread:UInt64=0
  guard pthread_threadid_np(nil,&thread)==0 else{return nil}
#else
  let thread=UInt64(pthread_self())
#endif
  return (Int64(time.tv_sec)*1_000_000+Int64(time.tv_nsec)/1_000,thread)
#else
  return nil
#endif
 }
 private func diagnosticWorkerOffset()->Int? {
  guard diagnosticStartedAt != nil else{return nil}
  return locked{diagnosticReceipts.count}
 }
 private func deliverDiagnosticWorker(from offset:Int?) {
  guard let offset,let completion=diagnosticCompletion,let id=diagnosticReceiptID else{return}
  let snapshot:[DiagnosticStageReceipt]?=locked {
   guard diagnosticDeliveryCount<8,offset<diagnosticReceipts.count else{return nil}
   diagnosticDeliveryCount+=1
   return Array(diagnosticReceipts[offset...])
  }
  guard let snapshot else{return}
  // Snapshot contains scalar metadata only. Never retain self/geometry or invoke
  // the consumer on the native worker, under locks, or on the result callback.
  Self.diagnosticDeliveryGate.submit { completion(id,snapshot) }
 }
 private func recordDiagnosticStage(_ stage: DiagnosticStage, workerCPU:Bool=false) {
  guard let startedAt=diagnosticStartedAt else{return}
  let cpu=workerCPU ? Self.workerCPUClock():nil
  locked {
   if diagnosticReceipts.count<64 {
    let elapsed=max(0,Int((ProcessInfo.processInfo.systemUptime-startedAt)*1_000))
    diagnosticReceipts.append(.init(stage:stage,elapsedMilliseconds:elapsed,
     workerCPUTimeMicroseconds:cpu?.0,workerThreadID:cpu?.1))
   }
  }
 }
 private func diagnosticRecorder() -> (DiagnosticStage)->Void {
  guard diagnosticStartedAt != nil else{return { _ in }}
  // A queued diagnostic must not extend this runtime's lifetime, including in
  // ordinary DEBUG clients that never opt in. Native/caller ownership is unchanged.
  return { [weak self] stage in self?.recordDiagnosticStage(stage) }
 }
#endif
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
#if DEBUG
  recordDiagnosticStage(.discardRequested)
#endif
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
  guard discarding,!discarded,!discardScheduled,pending==0,!sourceSnapshotPending else{return}
  discardScheduled=true
  Self.worker.async { [self] in
#if DEBUG
   recordDiagnosticStage(.discardWorkerStarted)
#endif
   owner=nil;ownerLifecycle=nil
   let waiters=locked { ()->[()->Void] in
    discarded=true
    let result=discardWaiters;discardWaiters.removeAll(keepingCapacity:false)
    return result
   }
#if DEBUG
   recordDiagnosticStage(.discardReleased)
   let diagnostic=diagnosticRecorder()
#endif
   for waiter in waiters {DispatchQueue.global(qos:.utility).async {
#if DEBUG
    diagnostic(.discardCompletionDelivered)
#endif
    waiter()
   }}
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
 /// Snapshot currentness is exact owner/lifecycle/revision identity only. It
 /// never certifies capture age, pose, complete support or current obstacles.
 public func isCurrent(_ snapshot:MeshSourceGeometrySnapshot)->Bool {
  locked{snapshot.ownerID==snapshotOwnerID && snapshot.lifecycle==lifecycle &&
   snapshot.ingressHadGap==gap && matches(snapshot.sessionID,snapshot.generation,snapshot.revision)}
 }
 // Separate scope releases the delivered/stale value before releasing its box
 // and reservation. A consumer may retain its own copy, outside owner erasure.
 private func deliverSourceSnapshot(_ owned:SourceSnapshotDelivery,
  completion:(Result<MeshSourceGeometrySnapshot,MeshSourceSnapshotError>)->Void) {
  guard let result=owned.value else{return}
  if case .success(let snapshot)=result,!isCurrent(snapshot){completion(.failure(.stale))}
  else{completion(result)}
 }
 /// One outstanding immutable payload, including its asynchronous delivery.
 /// Read-only: this request does not advance revisions or invalidate a route.
 /// A caller may retain a delivered value; discard cannot erase caller memory.
 /// Completion runs off-lock on the serial diagnostic delivery queue. Return
 /// promptly; never synchronously wait for stopAndDiscard inside completion,
 /// because terminal drain correctly waits for this delivery to return.
 public func requestSourceSnapshot(limits:MeshSourceSnapshotLimits = .init(),
   completion:@escaping(Result<MeshSourceGeometrySnapshot,MeshSourceSnapshotError>)->Void) {
  guard limits.valid else{DispatchQueue.global(qos:.utility).async{completion(.failure(.invalidLimits))};return}
  let token:(String,Int,UInt64,UInt64)?=locked {
   guard !stopped,!sourceSnapshotPending,pending<maxPending else{return nil}
   sourceSnapshotPending=true;pending+=1;return(session,generation,revision,lifecycle)
  }
  guard let (s,g,r,cycle)=token else{DispatchQueue.global(qos:.utility).async{completion(.failure(.unavailable))};return}
  let finish:(Result<MeshSourceGeometrySnapshot,MeshSourceSnapshotError>)->Void={ [self] result in
   let owned=SourceSnapshotDelivery(result)
   Self.sourceSnapshotDeliveryWorker.async { [self] in
    // Fence at delivery and release all owner-held payload references before drain.
    deliverSourceSnapshot(owned,completion:completion)
    owned.value=nil
    locked{sourceSnapshotPending=false;scheduleDiscardIfDrained()}
   }
  }
  Self.worker.async { [self] in
   defer{locked{pending-=1;scheduleDiscardIfDrained()}}
   guard locked({matches(s,g,r) && lifecycle==cycle}) else{finish(.failure(.stale));return}
   guard let owner=owner,ownerLifecycle==cycle,owner.session==s,owner.generation==g else{finish(.failure(.unavailable));return}
   do {
    let (anchors,records,payloadBytes)=try owner.sourceSnapshotData(limits:limits)
    let state=locked{(matches(s,g,r) && lifecycle==cycle,gap)}
    guard state.0 else{finish(.failure(.stale));return}
    var unknown=owner.unknown.sorted();if state.1{unknown.append("ingress-or-lifecycle-gap")}
    // sourceSnapshotData reserves the optional gap label in its logical budget.
    let snapshot=MeshSourceGeometrySnapshot(sessionID:s,generation:g,revision:r,
     anchors:anchors,records:records,sourceDeliveryComplete:owner.sourceComplete && !state.1,
     unknownCoverage:unknown,logicalPayloadBytes:payloadBytes,
     ownerID:snapshotOwnerID,lifecycle:cycle,ingressHadGap:state.1)
    finish(.success(snapshot))
   } catch let error as MeshSourceSnapshotError {finish(.failure(error))}
   catch {finish(.failure(.invalidRetainedState))}
  }
 }
 /// Explicit body and session-local query points; no projection is a movement command.
 /// Each new body/goal request invalidates older query snapshots at ingress.
 public func request(start:[Float],goal:[Float],body:MeshCandidateBody,
                     completion:@escaping(Result<MeshCandidateRoute,MeshCandidateError>)->Void) {
#if DEBUG
  let diagnostic=diagnosticRecorder()
#endif
  let finish: (Result<MeshCandidateRoute,MeshCandidateError>)->Void = { result in
#if DEBUG
   diagnostic(.completionQueued)
#endif
   DispatchQueue.global(qos:.utility).async {
#if DEBUG
    diagnostic(.completionDelivered)
#endif
    completion(result)
   }
  }
  guard start.count==3,goal.count==3,(start+goal).allSatisfy({$0.isFinite})else{locked{advance()};finish(.failure(.invalidInput));return}
  let token:(String,Int,UInt64,UInt64)?=locked {
   advance()
   guard !stopped,pending<maxPending else{return nil}
   pending+=1;return(session,generation,revision,lifecycle)
  }
  guard let (s,g,r,cycle)=token else{finish(.failure(.unavailable));return}
#if DEBUG
  recordDiagnosticStage(.requestEnqueued)
#endif
  Self.worker.async { [self] in
#if DEBUG
   let diagnosticOffset=diagnosticWorkerOffset()
   recordDiagnosticStage(.workerStarted,workerCPU:true)
   defer {
    recordDiagnosticStage(.workerFinished,workerCPU:true)
    deliverDiagnosticWorker(from:diagnosticOffset)
   }
#endif
   defer{locked{pending-=1;scheduleDiscardIfDrained()}}
   guard locked({matches(s,g,r)}),let owner=owner,ownerLifecycle==cycle,owner.session==s,owner.generation==g else{
#if DEBUG
    recordDiagnosticStage(.requestRetired,workerCPU:true)
#endif
    finish(.failure(.stale));return}
   do {
    let(v,t)=owner.geometry()
#if DEBUG
    recordDiagnosticStage(.nativeBuildBegin,workerCPU:true)
#endif
    let native=try Native(v,t,radius:body.radius,height:body.height,triangleSupport:owner.geometrySupport())
#if DEBUG
    recordDiagnosticStage(.nativeBuildEnd,workerCPU:true)
    recordDiagnosticStage(.routeBegin,workerCPU:true)
#endif
    let path=try native.route(start,goal,endpointPolicy:endpointPolicy)
#if DEBUG
    recordDiagnosticStage(.routeEnd,workerCPU:true)
#endif
    let state=locked{(matches(s,g,r),gap)}
    guard state.0 else{
#if DEBUG
    recordDiagnosticStage(.requestRetired,workerCPU:true)
#endif
    finish(.failure(.stale));return}
    var unknown=owner.unknown.sorted();if state.1{unknown.append("ingress-or-lifecycle-gap")}
    finish(.success(MeshCandidateRoute(sessionID:s,generation:g,revision:r,points:path.points,projectedStart:path.projected_start,projectedGoal:path.projected_goal,complete:path.complete,nativeStatus:path.status,sourceDeliveryComplete:owner.sourceComplete && !state.1,unknownCoverage:unknown,endpointPolicy:endpointPolicy,endpointAdmission:path.endpointAdmission)))
   } catch MeshCandidateError.endpointAssociationRejected(let receipt) {
#if DEBUG
    recordDiagnosticStage(.nativeFailure,workerCPU:true)
#endif
    guard locked({matches(s,g,r)}) else{
#if DEBUG
    recordDiagnosticStage(.requestRetired,workerCPU:true)
#endif
    finish(.failure(.stale));return}
    finish(.failure(.endpointAssociationRejected(receipt)))
   } catch {
#if DEBUG
    recordDiagnosticStage(.nativeFailure,workerCPU:true)
#endif
    finish(.failure(.nativeFailure))
   }
  }
 }
}
