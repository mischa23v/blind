import Foundation
import MeshBufferDecoder81
@testable import MeshSnapshot82
import MeshCandidateIngress83
import BlindRoomMesh

var checks = 0
func check(_ value: @autoclosure () -> Bool, _ name: String) { precondition(value(), name); checks += 1 }
let identity: [Float] = [1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1]
let body = try MeshCandidateBody(radius: 0.225, height: 1.75)
func capture(_ c: MeshSnapshot82.Context, _ id: UUID, translated: Float = 0, malformed: Bool = false) -> MeshSnapshot82.Capture {
    let vertices: [Float] = [-3,0,-3,-3,0,3,3,0,3,3,0,-3]
    let bytes = vertices.flatMap { value in (0..<4).map { UInt8(truncatingIfNeeded: value.bitPattern >> ($0 * 8)) } }
    let indices: [UInt8] = [0,0,1,0,2,0,0,0,2,0,3,0]
    let p = try! MeshSnapshot82.preflight(context: c,
        vertices: .init(count: 4, offset: 0, stride: 12, bufferLength: bytes.count, format: .float3),
        indices: .init(count: 6, offset: 0, stride: 2, bufferLength: indices.count, format: .uint16), classification: nil)
    var transform = identity; transform[12] = translated
    if malformed { transform[15] = 0 }
    return .owned(.init(context: c, anchorID: id, plan: p, vertexBytes: bytes,
                        indexBytes: indices, classificationBytes: nil, transform: transform))
}
func query(_ owner: MeshCandidateIngress83, offset: Float = 0) -> Result<MeshCandidateIngress83.Candidate, MeshCandidateIngress83.Failure> {
    let done = DispatchSemaphore(value: 0)
    var value: Result<MeshCandidateIngress83.Candidate, MeshCandidateIngress83.Failure>?
    owner.request(start: [-2+offset,0,0], goal: [2+offset,0,0], body: body) { value = $0; done.signal() }
    precondition(done.wait(timeout: .now()+10) == .success, "bounded real runtime completion")
    return value!
}
func candidate(_ owner: MeshCandidateIngress83, offset: Float = 0) -> MeshCandidateIngress83.Candidate {
    if case .success(let result) = query(owner, offset: offset) { return result }
    preconditionFailure("real runtime candidate expected")
}
let queue = DispatchQueue(label: "test.stage83.decode")
let owner = try MeshCandidateIngress83(maxAnchors: 2, decodeQueue: queue)
let a = UUID(), b = UUID()
check(owner.ingest(anchorID: a, receiptUptime: 1) { capture($0, a) }, "add admitted")
queue.sync {}
let first = candidate(owner)
check(owner.isCurrent(first), "initial candidate current")
check(first.route.complete && first.route.sourceDeliveryComplete, "real runtime complete source delivery")
check(!first.physicalAuthority && !first.coverageKnown && !first.route.authorizesPhysicalGuidance, "no physical authority")
check(owner.ingest(anchorID: a, receiptUptime: 2) { c in
    check(!owner.isCurrent(first), "outer token retired before copy")
    check(c.revision == 2 && c.captureUptime == nil, "monotonic revision and receipt not capture")
    return capture(c, a, translated: 10)
}, "replace admitted")
queue.sync {}
let second = candidate(owner, offset: 10)
check(second.route.complete && second.route.sourceDeliveryComplete, "ordinary update does not introduce sticky gap")
check(abs(second.route.projectedStart[0] - 8) < 0.5, "local transform applied exactly once by package")
check(!owner.isCurrent(first) && owner.isCurrent(second), "replacement retires old candidate")
check(owner.ingest(anchorID: a, receiptUptime: 3) { c in
    check(!owner.isCurrent(second), "failed copy invalidates before return")
    return .unknownGap(.init(context: c, anchorID: a, reason: .budget))
}, "copy failure admitted as gap")
queue.sync {}
let gap = candidate(owner, offset: 10)
check(!gap.route.sourceDeliveryComplete && gap.route.unknownCoverage.contains("ingress-or-lifecycle-gap"), "failed copy retains unknown")
check(owner.ingest(anchorID: a, receiptUptime: 4) { capture($0, a, translated: 10) }, "replacement after gap")
queue.sync {}
check(!candidate(owner, offset: 10).route.sourceDeliveryComplete, "ordinary success cannot clear missed delivery")
try owner.reset()
check(!owner.isCurrent(gap), "reset retires prior candidate")
check(owner.ingest(anchorID: a, receiptUptime: 1) { c in
    check(c.revision == 1, "new epoch restarts revision safely")
    check(c.sessionID.uuidString != second.route.sessionID, "fresh epoch prevents ABA")
    return capture(c, a)
}, "reset accepts new receipt domain")
queue.sync {}
check(candidate(owner).route.sourceDeliveryComplete, "new session resets unknown")
check(owner.ingest(anchorID: b, receiptUptime: 2) { capture($0, b, translated: 10) }, "second exact anchor")
queue.sync {}
check(owner.remove(anchorID: b, receiptUptime: 3), "exact remove accepted")
let afterRemove = candidate(owner)
check(afterRemove.route.unknownCoverage.contains("removed:" + b.uuidString), "exact removed anchor retains unknown")
check(afterRemove.route.complete, "other anchor survives exact remove")
var called = false
check(!owner.ingest(anchorID: UUID(), receiptUptime: 4) { c in called = true; return capture(c, a) }, "ledger overflow rejected")
check(!called, "overflow does not copy")
check(!owner.remove(anchorID: UUID(), receiptUptime: 5), "remove overflow rejected")
check(candidate(owner).route.unknownCoverage.contains("ingress-or-lifecycle-gap"), "remove overflow remains unknown")
check(!owner.ingest(anchorID: a, receiptUptime: 5) { capture($0, a) }, "replayed receipt rejected")
check(!owner.ingest(anchorID: a, receiptUptime: .nan) { capture($0, a) }, "nonfinite receipt rejected")

// Deterministic queued decoder work; only owned values cross the queue.
try owner.reset()
let gate = DispatchSemaphore(value: 0)
queue.async { precondition(gate.wait(timeout: .now()+10) == .success) }
check(owner.ingest(anchorID: a, receiptUptime: 1) { capture($0, a) }, "old owned copy queued")
check(!owner.ingest(anchorID: a, receiptUptime: 2) { capture($0, a) }, "newer frame overflow fences old revision")
if case .failure = query(owner) { checks += 1 } else { preconditionFailure("query during copy") }
gate.signal(); queue.sync {}
// Install a fresh floor; rejected newest copy must not silently erase the gap.
check(owner.ingest(anchorID: a, receiptUptime: 3) { capture($0, a) }, "fresh after overflow")
queue.sync {}
check(!candidate(owner).route.sourceDeliveryComplete, "late older completion cannot restore coverage")
let oldEpochGate = DispatchSemaphore(value: 0)
queue.async { precondition(oldEpochGate.wait(timeout: .now()+10) == .success) }
check(owner.ingest(anchorID: a, receiptUptime: 4) { capture($0, a) }, "pre-reset copy queued")
try owner.reset()
check(!owner.ingest(anchorID: a, receiptUptime: 1) { capture($0, a) }, "old copy retains aggregate slot after reset")
oldEpochGate.signal(); queue.sync {}
// The rejected in-new-epoch event above remains unknown, while old completion never installs.
check(owner.ingest(anchorID: a, receiptUptime: 2) { capture($0, a) }, "new epoch after drain")
queue.sync {}
let beforeStop = candidate(owner)
check(!beforeStop.route.sourceDeliveryComplete, "new epoch overflow not erased by old completion")
owner.stop()
check(!owner.isCurrent(beforeStop), "stop fences candidate")
if case .failure = query(owner) { checks += 1 } else { preconditionFailure("stopped query") }
check(!owner.ingest(anchorID: a, receiptUptime: 3) { capture($0, a) }, "stopped callback does not copy")
// Accepted supersession is not loss: do not add a sticky ingress gap.
let supersedeQueue = DispatchQueue(label: "test.stage83.supersede")
let supersede = try MeshCandidateIngress83(maxCopies: 2, decodeQueue: supersedeQueue)
let hold = DispatchSemaphore(value: 0)
supersedeQueue.async { precondition(hold.wait(timeout: .now()+10) == .success) }
check(supersede.ingest(anchorID: a, receiptUptime: 1) { capture($0, a) }, "first overlapping copy")
check(supersede.ingest(anchorID: a, receiptUptime: 2) { capture($0, a) }, "accepted newer overlapping copy")
hold.signal(); supersedeQueue.sync {}
check(candidate(supersede).route.sourceDeliveryComplete, "accepted supersession adds no sticky gap")
check(supersede.ingest(anchorID: b, receiptUptime: 3) { capture($0, b, translated: 10) }, "second floor for removal")
supersedeQueue.sync {}
let removeHold = DispatchSemaphore(value: 0)
supersedeQueue.async { precondition(removeHold.wait(timeout: .now()+10) == .success) }
check(supersede.ingest(anchorID: b, receiptUptime: 4) { capture($0, b, translated: 10) }, "update held before remove")
check(supersede.remove(anchorID: b, receiptUptime: 5), "remove supersedes held update")
removeHold.signal(); supersedeQueue.sync {}
let removed = candidate(supersede)
check(removed.route.unknownCoverage.contains("removed:" + b.uuidString), "held update cannot undo removal")
check(!removed.route.unknownCoverage.contains("ingress-or-lifecycle-gap"), "removal supersession adds no ingress gap")

// Decoder rejection reaches the real runtime as unknown, not prior full coverage.
check(supersede.ingest(anchorID: a, receiptUptime: 6) { capture($0, a, malformed: true) }, "malformed snapshot queued")
supersedeQueue.sync {}
check(candidate(supersede).route.unknownCoverage.contains("ingress-or-lifecycle-gap"), "malformed decode retains unknown")
try supersede.reset()
check(supersede.ingest(anchorID: a, receiptUptime: 1) { c in
    // Lifecycle changes while the synchronous copy is in progress.
    try! supersede.reset()
    return capture(c, a)
}, "reset during capture")
supersedeQueue.sync {}
check(supersede.ingest(anchorID: a, receiptUptime: 1) { capture($0, a) }, "new epoch following late copy")
supersedeQueue.sync {}
check(candidate(supersede).route.sourceDeliveryComplete, "copy completion from old epoch cannot contaminate current runtime")

print("RESULT: \(checks) stage83 real-runtime synthetic checks passed; no ARKit execution or privacy purge proof")
