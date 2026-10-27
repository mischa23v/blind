import Foundation
import BlindRoomMesh // Intentionally NOT @testable: validates the public API/module.
let runtime=try RoomMeshCandidateRuntime(sessionID:"client")
let identity:[Double]=[1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1]
let added=runtime.offer(MeshAnchorEvent(sessionID:"client",generation:0,anchorID:"floor",revision:1,timestamp:1,vertices:[-3,0,-3,-3,0,3,3,0,3,3,0,-3],triangles:[0,1,2,0,2,3],columnMajorTransform:identity,complete:true))
precondition(added)
let done=DispatchSemaphore(value:0)
let lock=NSLock();var ok=false
runtime.request(start:[-2,0,0],goal:[2,0,0],body:try MeshCandidateBody(radius:0.225,height:1.75)){result in
 if case .success(let candidate)=result {
  let pass=candidate.complete && candidate.sourceDeliveryComplete && !candidate.authorizesPhysicalGuidance && !candidate.actualWorldCoverageKnown && candidate.rawDepthHazardVeto && runtime.isCurrent(candidate)
  let removed=runtime.offer(MeshAnchorEvent(sessionID:"client",generation:0,anchorID:"floor",revision:2,timestamp:2,vertices:[],triangles:[],columnMajorTransform:[],complete:false,removed:true))
  lock.lock();ok=pass && removed && !runtime.isCurrent(candidate);lock.unlock()
 }
 done.signal()
}
precondition(done.wait(timeout:.now()+10) == .success)
lock.lock();let passed=ok;lock.unlock();precondition(passed)
print("PUBLIC API PASS: imported package, candidate query, removal retirement, authority false")
