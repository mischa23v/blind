import Foundation
import BlindCore

actor MemoryIO: ConnectedJourneyRuntimeIO {
 let data: Data
 init(_ data: Data) { self.data=data }
 func read() -> Data? { data }
 func write(_ payload: JourneyRuntimeWrite) {}
}
@MainActor final class JourneyAdapter {
 var runtime: ConnectedJourneyRuntime?
 func breakTracking() { runtime?.cameraRestarted() }
}
@main struct RuntimeWitness {
 @MainActor static func main() async throws {
  typealias F = ConnectedFixture
  let catalog = try F.catalog()
  var owner = try F.prepared()
  try F.observe(&owner,F.endpoint(F.a,"m"),time:2)
  try owner.saveReference(at:F.endpoint(F.a,"m"),origin:.trustedInterface,now:2,recordedAt:F.date,persist:{_ in})
  try owner.setDestination(F.endpoint(F.a,"p"),origin:.trustedInterface,recordedAt:F.date,persist:{_ in})
  let seed = try JourneyRuntimeEnvelope(journey:owner.snapshot, installations:catalog.installations.values.map { try $0.encoded() }, portals:catalog.portals).encoded()
  for old in [true,false] {
   let runtime = ConnectedJourneyRuntime(io:MemoryIO(seed),sha256:F.sha256)
   try runtime.configure(body:F.body,limits:F.limits)
   runtime.restore()
   let deadline=ProcessInfo.processInfo.systemUptime+5
   while runtime.loading && ProcessInfo.processInfo.systemUptime < deadline { try await Task.sleep(nanoseconds:1_000_000) }
   precondition(!runtime.loading && !runtime.storageError,"real runtime restore")
   let session = try runtime.beginLocalization(in:F.a)
   let endpoint = F.endpoint(F.a,"m")
   let point = try catalog.node(endpoint).position
   let capture = SpatialLocalizationCapture(sessionID:session,binding:F.a,floorID:endpoint.floorID,roomID:endpoint.roomID,
    position:.init(point.x,1.3,point.z),bodyYaw: -.pi/2,source:.alignedMapPose,headingSource:.bodyAligned,
    trackingNormal:true,positionUncertainty:0.05,headingUncertainty:0.05,capturedAt:2)
   try runtime.accept(capture,support:SpatialIntegrationFixture.support(capture),now:2)
   let ticket=try runtime.next(now:2)
   precondition(runtime.permits(ticket.route,now:2),"authored live route before recovery entry")
   let priorGoal=runtime.goal
   runtime.cameraRestarted() // once at either entry, including when launch refuses
   precondition(!runtime.permits(ticket.route,now:2) && runtime.goal == priorGoal && runtime.goal != nil,
    "entry withdraws actual route authority but retains nonnil goal")
   guard case .clarify(let question) = try runtime.requestReturn(origin:.trustedInterface,arabic:false) else { fatalError("expected seeded choice") }
   precondition(runtime.beginClarificationSpeech(question))
   let snapshot = runtime.snapshot
   var retired=0, changed=0
   runtime.onClarificationRetired={_ in retired+=1}
   runtime.onChange={changed+=1}
   if old {
    let model=OldModel(); model.journeys.runtime=runtime
    for _ in 0..<8 { model.run(ARFrame(observation:Observation(trackingNormal:true))) }
   } else {
    let model=Model(); model.journeys.runtime=runtime
    for _ in 0..<8 { model.run(ARFrame(observation:Observation(trackingNormal:true))) }
   }
   let delivered=runtime.clarificationSpeechFinished(id:question.id,text:question.text,outcome:.completed,now:3)
   precondition(runtime.snapshot.goal == snapshot.goal && runtime.snapshot.references == snapshot.references,"goal/reference survive both revisions")
   if old {
    precondition(retired > 0 && changed == 8 && !delivered,"old helper must reproduce real ownership failure")
    print("EXPECTED FAILURE WITNESS: old helper retires pending clarification; eight runtime changes")
   } else {
    precondition(retired == 0 && changed == 0 && delivered,"corrected helper retains real clarification ownership")
    precondition(!runtime.permits(ticket.route,now:2),"normal recovery frames cannot revive old route ticket")
    print("PASS: corrected helper preserves real runtime clarification and goal/reference; no new pose authority")
   }
  }
 }
}
