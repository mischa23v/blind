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

// Terminal release acknowledges this owner's reservations only, not ARKit/caller memory.
// All callback observations are locked; no timing-sensitive native-work injection.
final class DiscardReceipts {
    private let lock = NSLock()
    private var counts: [Int: Int] = [:]
    func record(_ id: Int) { lock.lock(); defer { lock.unlock() }; counts[id, default: 0] += 1 }
    func count(_ id: Int) -> Int { lock.lock(); defer { lock.unlock() }; return counts[id, default: 0] }
    var total: Int { lock.lock(); defer { lock.unlock() }; return counts.values.reduce(0, +) }
}
func resetRejected(_ owner: MeshCandidateIngress83) -> Bool {
    do { try owner.reset(); return false } catch { return true }
}
// Ordinary stop remains restartable; terminal discard alone forbids reset.
try owner.reset()
check(owner.ingest(anchorID: a, receiptUptime: 1) { capture($0, a) }, "ordinary stop permits normal reset")
queue.sync {}
check(candidate(owner).route.sourceDeliveryComplete, "normal reset after stop rebuilds runtime")

let discardQueue = DispatchQueue(label: "test.stage83.discard")
let discarded = try MeshCandidateIngress83(decodeQueue: discardQueue)
check(discarded.ingest(anchorID: a, receiptUptime: 1) { capture($0, a) }, "discard owner initial floor")
discardQueue.sync {}
let discardCandidate = candidate(discarded)
let discardGate = DispatchSemaphore(value: 0), discardEntered = DispatchSemaphore(value: 0)
discardQueue.async {
    discardEntered.signal()
    precondition(discardGate.wait(timeout: .now()+10) == .success)
}
check(discardEntered.wait(timeout: .now()+5) == .success, "discard decoder hold established")
check(discarded.ingest(anchorID: a, receiptUptime: 2) { capture($0, a) }, "discard retains queued owned copy")
let discardReceipts = DiscardReceipts(), discardDone = DispatchGroup()
discardDone.enter()
discarded.stopAndDiscard { discardReceipts.record(0); discardDone.leave() }
check(!discarded.isCurrent(discardCandidate), "terminal discard immediately fences candidate")
check(resetRejected(discarded), "terminal discard rejects reset before drain")
var copiedAfterDiscard = false
check(!discarded.ingest(anchorID: a, receiptUptime: 3) { c in
    copiedAfterDiscard = true; return capture(c, a)
}, "terminal discard rejects new ingest")
check(!copiedAfterDiscard, "terminal discard never calls new capture")
check(!discarded.remove(anchorID: a, receiptUptime: 4), "terminal discard rejects remove")
if case .failure = query(discarded) { checks += 1 } else { preconditionFailure("terminal discarded query") }
let discardCalls = DispatchGroup()
for id in 1...3 {
    discardCalls.enter(); discardDone.enter()
    DispatchQueue.global(qos: .utility).async {
        discarded.stopAndDiscard { discardReceipts.record(id); discardDone.leave() }
        discardCalls.leave()
    }
}
check(discardCalls.wait(timeout: .now()+5) == .success, "concurrent discard calls return without blocking")
check(discardDone.wait(timeout: .now()+0.05) == .timedOut && discardReceipts.total == 0,
      "discard acknowledgement waits for held owned copy")
discardGate.signal(); discardQueue.sync {}
check(discardDone.wait(timeout: .now()+5) == .success, "all duplicate discard calls acknowledged after drain")
check((0...3).allSatisfy { discardReceipts.count($0) == 1 }, "concurrent discard callbacks exactly once")
check(resetRejected(discarded), "terminal discard rejects reset after acknowledgement")
let repeatedDone = DispatchSemaphore(value: 0)
discarded.stopAndDiscard { discardReceipts.record(4); repeatedDone.signal() }
check(repeatedDone.wait(timeout: .now()+5) == .success && discardReceipts.count(4) == 1,
      "repeat discard after acknowledgement completes exactly once")
check(!discarded.ingest(anchorID: b, receiptUptime: 5) { capture($0, b) }, "drained owner cannot rebuild geometry")

// A synchronous capture reservation exists before its owned value even returns.
let captureQueue = DispatchQueue(label: "test.stage83.discard.capture")
let duringCapture = try MeshCandidateIngress83(decodeQueue: captureQueue)
let captureReceipts = DiscardReceipts(), captureDone = DispatchSemaphore(value: 0)
check(duringCapture.ingest(anchorID: a, receiptUptime: 1) { c in
    duringCapture.stopAndDiscard { captureReceipts.record(0); captureDone.signal() }
    check(captureDone.wait(timeout: .now()+0.05) == .timedOut && captureReceipts.total == 0,
          "discard waits for synchronous capture reservation")
    check(resetRejected(duringCapture), "discard during capture rejects reset")
    return capture(c, a)
}, "already admitted capture returns after terminal discard")
captureQueue.sync {}
check(captureDone.wait(timeout: .now()+5) == .success && captureReceipts.count(0) == 1,
      "capture discard acknowledgement follows late owned-copy release")
if case .failure = query(duringCapture) { checks += 1 } else { preconditionFailure("late capture installed after discard") }

// Reset does not erase the prior epoch's reservation, and discard drains both epochs.
let resetDiscardQueue = DispatchQueue(label: "test.stage83.discard.reset")
let resetDiscard = try MeshCandidateIngress83(decodeQueue: resetDiscardQueue)
let resetDiscardGate = DispatchSemaphore(value: 0), resetDiscardDone = DispatchSemaphore(value: 0)
resetDiscardQueue.async { precondition(resetDiscardGate.wait(timeout: .now()+10) == .success) }
check(resetDiscard.ingest(anchorID: a, receiptUptime: 1) { capture($0, a) }, "old epoch copy before terminal discard")
try resetDiscard.reset()
resetDiscard.stopAndDiscard { resetDiscardDone.signal() }
check(resetDiscardDone.wait(timeout: .now()+0.05) == .timedOut,
      "reset cannot release old copy ahead of terminal acknowledgement")
check(resetRejected(resetDiscard), "second reset cannot reopen terminal owner")
resetDiscardGate.signal(); resetDiscardQueue.sync {}
check(resetDiscardDone.wait(timeout: .now()+5) == .success, "old epoch copy drains before terminal acknowledgement")
if case .failure = query(resetDiscard) { checks += 1 } else { preconditionFailure("old epoch restored terminal runtime") }

print("RESULT: \(checks) stage83 real-runtime synthetic checks passed; no ARKit execution or privacy purge proof")

// Explicit current caller-policy controls. The original83 checks/result above
// remain the legacy comparator; this block does not grant physical authority.
var endpointChecks = 0
func endpointCheck(_ value: @autoclosure () -> Bool, _ name: String) {
    precondition(value(), name); endpointChecks += 1
}
final class EndpointResultBox {
    private let lock = NSLock()
    private var value: Result<MeshCandidateIngress83.Candidate, MeshCandidateIngress83.Failure>?
    func put(_ value: Result<MeshCandidateIngress83.Candidate, MeshCandidateIngress83.Failure>) {
        lock.lock(); self.value = value; lock.unlock()
    }
    func get() -> Result<MeshCandidateIngress83.Candidate, MeshCandidateIngress83.Failure>? {
        lock.lock(); defer { lock.unlock() }; return value
    }
}
func endpointQuery(_ owner: MeshCandidateIngress83, start: [Float], goal: [Float])
    -> Result<MeshCandidateIngress83.Candidate, MeshCandidateIngress83.Failure> {
    let done = DispatchSemaphore(value: 0), box = EndpointResultBox()
    owner.request(start: start, goal: goal, body: body) { box.put($0); done.signal() }
    precondition(done.wait(timeout: .now()+10) == .success, "bounded endpoint-policy result")
    guard let result = box.get() else { preconditionFailure("missing endpoint-policy result") }
    return result
}
func endpointRefusal(_ result: Result<MeshCandidateIngress83.Candidate, MeshCandidateIngress83.Failure>)
    -> MeshEndpointAdmissionReceipt {
    guard case .failure(.runtime(.endpointAssociationRejected(let receipt))) = result else {
        preconditionFailure("expected typed strict endpoint refusal, not any failure")
    }
    return receipt
}
func endpointDiscard(_ owner: MeshCandidateIngress83) {
    let done = DispatchSemaphore(value: 0)
    owner.stopAndDiscard { done.signal() }
    precondition(done.wait(timeout: .now()+10) == .success, "bounded endpoint-policy drain")
}
let endpointQueue = DispatchQueue(label: "test.stage83.endpoint-policy")
let endpointLegacy = try MeshCandidateIngress83(decodeQueue: endpointQueue)
let endpointStrict = try MeshCandidateIngress83(endpointPolicy: .requireSuppliedXZOverPolygon,
                                               decodeQueue: endpointQueue)
let endpointAnchor = UUID()
endpointCheck(endpointLegacy.ingest(anchorID: endpointAnchor, receiptUptime: 1) { capture($0, endpointAnchor) }, "legacy endpoint floor admitted")
endpointCheck(endpointStrict.ingest(anchorID: endpointAnchor, receiptUptime: 1) { capture($0, endpointAnchor) }, "strict endpoint floor admitted")
endpointQueue.sync {}
let endpointStart: [Float] = [-1,-0.05,0], endpointGoal: [Float] = [1,-0.05,0]
let endpointOld = try endpointQuery(endpointLegacy, start: endpointStart, goal: endpointGoal).get()
let endpointInside = try endpointQuery(endpointStrict, start: endpointStart, goal: endpointGoal).get()
guard let endpointReceipt = endpointInside.route.endpointAdmission else { preconditionFailure("strict admission receipt missing") }
endpointCheck(endpointOld.route.complete && endpointInside.route.complete, "strict admitted inside route remains complete")
endpointCheck(endpointOld.route.endpointPolicy == .legacyNearestProjection && endpointOld.route.endpointAdmission == nil, "83 default remains legacy comparator")
endpointCheck(endpointInside.route.endpointPolicy == .requireSuppliedXZOverPolygon && endpointReceipt.policy == .requireSuppliedXZOverPolygon, "83 forwards explicit strict policy")
endpointCheck(endpointOld.route.points.flatMap { $0 }.map(\.bitPattern) == endpointInside.route.points.flatMap { $0 }.map(\.bitPattern), "strict inside path bit-matches legacy")
endpointCheck(endpointOld.route.projectedStart.map(\.bitPattern) == endpointInside.route.projectedStart.map(\.bitPattern) && endpointOld.route.projectedGoal.map(\.bitPattern) == endpointInside.route.projectedGoal.map(\.bitPattern), "strict projected endpoints bit-match legacy")
endpointCheck(endpointReceipt.start.requested == endpointStart && endpointReceipt.goal.requested == endpointGoal, "strict receipt retains both supplied endpoints")
endpointCheck(endpointReceipt.start.found && endpointReceipt.start.isOverPolygon && endpointReceipt.goal.found && endpointReceipt.goal.isOverPolygon, "strict inside receipt confirms both associations")
endpointCheck(endpointInside.route.projectedStart[1] != endpointStart[1] && endpointInside.route.projectedStart[0] == endpointStart[0] && endpointInside.route.projectedStart[2] == endpointStart[2], "strict permits vertical-only association without erasing connector")
endpointCheck(!endpointReceipt.authorizesPhysicalGuidance && !endpointInside.physicalAuthority && !endpointInside.coverageKnown && !endpointInside.route.authorizesPhysicalGuidance, "strict membership does not grant physical authority")
let endpointCenter: [Float] = [0,0,0], endpointOutsideGoal: [Float] = [2.8,0,0]
let endpointOldGoal = try endpointQuery(endpointLegacy, start: endpointCenter, goal: endpointOutsideGoal).get()
endpointCheck(endpointOldGoal.route.complete, "legacy comparator still demonstrates goal projection")
let endpointGoalRefusal = endpointRefusal(endpointQuery(endpointStrict, start: endpointCenter, goal: endpointOutsideGoal))
endpointCheck(endpointGoalRefusal.start.requested == endpointCenter && endpointGoalRefusal.goal.requested == endpointOutsideGoal, "goal refusal retains both supplied endpoints")
endpointCheck(endpointGoalRefusal.start.isOverPolygon && endpointGoalRefusal.goal.found && !endpointGoalRefusal.goal.isOverPolygon, "goal-only projection is typed refusal")
endpointCheck(!endpointGoalRefusal.authorizesPhysicalGuidance && !endpointStrict.isCurrent(endpointInside), "refused request retires old route and carries no authority")
let endpointOutsideStart: [Float] = [-2.8,0,0]
let endpointOldStart = try endpointQuery(endpointLegacy, start: endpointOutsideStart, goal: endpointCenter).get()
endpointCheck(endpointOldStart.route.complete, "legacy comparator still demonstrates start projection")
let endpointStartRefusal = endpointRefusal(endpointQuery(endpointStrict, start: endpointOutsideStart, goal: endpointCenter))
endpointCheck(endpointStartRefusal.start.requested == endpointOutsideStart && endpointStartRefusal.goal.requested == endpointCenter, "start refusal retains both supplied endpoints")
endpointCheck(endpointStartRefusal.start.found && !endpointStartRefusal.start.isOverPolygon && endpointStartRefusal.goal.isOverPolygon, "start-only projection is typed refusal")
endpointCheck(endpointStartRefusal.policy == .requireSuppliedXZOverPolygon && !endpointStartRefusal.authorizesPhysicalGuidance, "strict start refusal identity preserved")
let endpointMissingGoal: [Float] = [20,0,0]
let endpointMissing = endpointRefusal(endpointQuery(endpointStrict, start: endpointCenter, goal: endpointMissingGoal))
endpointCheck(endpointMissing.start.isOverPolygon && !endpointMissing.goal.found && !endpointMissing.goal.isOverPolygon, "missing goal is deterministic typed refusal")
endpointCheck(endpointMissing.goal.requested == endpointMissingGoal && endpointMissing.goal.projected == [0,0,0], "missing goal retains request and zero projection")
try endpointStrict.reset()
endpointCheck(!endpointStrict.isCurrent(endpointInside), "reset retires strict prior epoch")
endpointCheck(endpointStrict.ingest(anchorID: endpointAnchor, receiptUptime: 1) { capture($0, endpointAnchor) }, "strict owner accepts new epoch floor")
endpointQueue.sync {}
let endpointAfterReset = try endpointQuery(endpointStrict, start: endpointStart, goal: endpointGoal).get()
endpointCheck(endpointAfterReset.route.complete && endpointAfterReset.route.endpointPolicy == .requireSuppliedXZOverPolygon, "strict policy survives reset with valid positive control")
let endpointResetRefusal = endpointRefusal(endpointQuery(endpointStrict, start: endpointCenter, goal: endpointOutsideGoal))
endpointCheck(endpointResetRefusal.policy == .requireSuppliedXZOverPolygon && !endpointResetRefusal.goal.isOverPolygon, "reset cannot silently restore legacy projection")
endpointDiscard(endpointLegacy); endpointDiscard(endpointStrict)
print("STRICT_ENDPOINT_INGRESS_RESULT: \(endpointChecks) caller-policy checks passed; original83 comparator retained; no physical authority")
