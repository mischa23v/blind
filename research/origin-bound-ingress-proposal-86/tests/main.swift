// Authored only: no Swift/Apple execution result is claimed.
// Real stage86 API + stage82 owned snapshots + stage75 runtime; not ARKit scheduling.
import Foundation
import MeshBufferDecoder81
@testable import MeshSnapshot82
import OriginBoundMeshIngress86
import BlindRoomMesh

var checks = 0
func check(_ value: @autoclosure () -> Bool, _ label: String) {
    precondition(value(), label); checks += 1
}
let body = try MeshCandidateBody(radius: 0.225, height: 1.75)
let identity: [Float] = [1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1]
func floor(_ context: MeshSnapshot82.Context, _ anchor: UUID, offset: Float = 0) -> MeshSnapshot82.Capture {
    let vertices: [Float] = [-3,0,-3,-3,0,3,3,0,3,3,0,-3]
    let bytes = vertices.flatMap { value in
        (0..<4).map { UInt8(truncatingIfNeeded: value.bitPattern >> ($0 * 8)) }
    }
    let indices: [UInt8] = [0,0,1,0,2,0,0,0,2,0,3,0]
    let plan = try! MeshSnapshot82.preflight(context: context,
        vertices: .init(count: 4, offset: 0, stride: 12, bufferLength: bytes.count, format: .float3),
        indices: .init(count: 6, offset: 0, stride: 2, bufferLength: indices.count, format: .uint16),
        classification: nil)
    var transform = identity; transform[12] = offset
    return .owned(.init(context: context, anchorID: anchor, plan: plan,
        vertexBytes: bytes, indexBytes: indices, classificationBytes: nil, transform: transform))
}
func gap(_ context: MeshSnapshot82.Context, _ anchor: UUID) -> MeshSnapshot82.Capture {
    .unknownGap(.init(context: context, anchorID: anchor, reason: .invalidDescriptor))
}
func query(_ owner: OriginBoundMeshIngress86, offset: Float = 0)
    -> Result<OriginBoundMeshIngress86.Candidate, OriginBoundMeshIngress86.Failure> {
    let done = DispatchSemaphore(value: 0)
    var result: Result<OriginBoundMeshIngress86.Candidate, OriginBoundMeshIngress86.Failure>?
    owner.request(start: [-2+offset,0,0], goal: [2+offset,0,0], body: body) {
        result = $0; done.signal()
    }
    precondition(done.wait(timeout: .now()+10) == .success, "bounded native query completion")
    return result!
}
func candidate(_ owner: OriginBoundMeshIngress86, offset: Float = 0) -> OriginBoundMeshIngress86.Candidate {
    if case .success(let result) = query(owner, offset: offset) { return result }
    preconditionFailure("real native candidate expected")
}
func queryFails(_ owner: OriginBoundMeshIngress86) -> Bool {
    if case .failure = query(owner) { return true }; return false
}
func resetRejected(_ owner: OriginBoundMeshIngress86) -> Bool {
    do { _ = try owner.reset(); return false } catch { return true }
}
func discard(_ owner: OriginBoundMeshIngress86) {
    let done = DispatchSemaphore(value: 0)
    owner.stopAndDiscard { done.signal() }
    check(done.wait(timeout: .now()+10) == .success, "owned resource drain acknowledged")
}
// This is only an immutable synthetic callback holder, not an ARSession emulator
// or a native-origin certifier. Every test calls the actual public ingress seam.
final class SyntheticProducerOwner {
    let lease: OriginBoundMeshIngress86.ProducerLease
    init(_ lease: OriginBoundMeshIngress86.ProducerLease) { self.lease = lease }
}
final class Receipts {
    private let lock = NSLock()
    private var counts: [Int: Int] = [:]
    func record(_ id: Int) { lock.lock(); defer { lock.unlock() }; counts[id, default: 0] += 1 }
    func count(_ id: Int) -> Int { lock.lock(); defer { lock.unlock() }; return counts[id, default: 0] }
    var total: Int { lock.lock(); defer { lock.unlock() }; return counts.values.reduce(0, +) }
}

let queue = DispatchQueue(label: "test.stage86.decode")
let owner = try OriginBoundMeshIngress86(maxAnchors: 2, decodeQueue: queue)
let other = try OriginBoundMeshIngress86()
let foreign = try other.reset()
let anchor = UUID(), secondAnchor = UUID()
var forbiddenCopies = 0
check(!owner.ingest(lease: foreign, anchorID: anchor, receiptUptime: 1) {
    forbiddenCopies += 1; return floor($0, anchor)
}, "constructor is closed, even with another owner's issued lease")
check(!owner.remove(lease: foreign, anchorID: anchor, receiptUptime: 1), "closed removal rejected")
check(queryFails(owner), "constructor cannot return a route")
check(forbiddenCopies == 0, "closed admission never copied")

let neverOpened = try OriginBoundMeshIngress86()
discard(neverOpened)
check(resetRejected(neverOpened), "discard before first reset prohibits any lease issuance")
check(!neverOpened.ingest(lease: foreign, anchorID: anchor, receiptUptime: 1) {
    forbiddenCopies += 1; return floor($0, anchor)
}, "never-opened terminal owner rejects foreign lease before copy")

let producerA = SyntheticProducerOwner(try owner.reset())
var epochA: UUID?
check(owner.ingest(lease: producerA.lease, anchorID: anchor, receiptUptime: 1) {
    epochA = $0.sessionID; return floor($0, anchor)
}, "A admission")
queue.sync {}
let oldCandidate = candidate(owner)
check(owner.isCurrent(oldCandidate), "A candidate initially current")

// These closures retain A at creation, but first enter the API AFTER reset.
let delayedAdd: () -> Bool = { [producerA] in
    owner.ingest(lease: producerA.lease, anchorID: secondAnchor, receiptUptime: 1000) {
        forbiddenCopies += 1; return floor($0, secondAnchor, offset: 10)
    }
}
let delayedUpdate: () -> Bool = { [producerA] in
    owner.ingest(lease: producerA.lease, anchorID: anchor, receiptUptime: 1001) {
        forbiddenCopies += 1; return floor($0, anchor, offset: 10)
    }
}
let delayedRemove: () -> Bool = { [producerA] in
    owner.remove(lease: producerA.lease, anchorID: anchor, receiptUptime: 1002)
}
owner.stop()
check(!owner.ingest(lease: producerA.lease, anchorID: anchor, receiptUptime: 2) {
    forbiddenCopies += 1; return floor($0, anchor)
}, "stop revokes A before copy")
let producerB = SyntheticProducerOwner(try owner.reset())
var epochB: UUID?
check(owner.ingest(lease: producerB.lease, anchorID: anchor, receiptUptime: 1) {
    epochB = $0.sessionID; return floor($0, anchor)
}, "B floor admitted")
queue.sync {}
let current = candidate(owner)
check(!owner.isCurrent(oldCandidate), "reset fences A result")
check(!delayedAdd(), "delayed old add rejected at actual API")
check(owner.isCurrent(current), "rejected old add cannot retire B candidate")
check(!delayedUpdate(), "delayed old update rejected at actual API")
check(owner.isCurrent(current), "rejected old update cannot retire B candidate")
check(!delayedRemove(), "delayed old removal rejected at actual API")
check(owner.isCurrent(current), "rejected old removal cannot delete or retire B")
check(!owner.ingest(lease: foreign, anchorID: UUID(), receiptUptime: .nan) {
    forbiddenCopies += 1; return floor($0, anchor)
}, "foreign malformed event rejected before receipt or ledger mutation")
check(owner.isCurrent(current), "foreign event is not a B delivery gap")
check(forbiddenCopies == 0, "no rejected callback invokes capture")
check(owner.ingest(lease: producerB.lease, anchorID: anchor, receiptUptime: 2) {
    check($0.revision == 2, "old updates did not advance current revision")
    check($0.captureUptime == nil, "receipt is never promoted to capture freshness")
    return floor($0, anchor)
}, "old high receipts did not poison B ordering")
queue.sync {}
let afterOld = candidate(owner)
check(afterOld.route.sourceDeliveryComplete, "rejected leases did not introduce sticky gap")
check(!afterOld.physicalAuthority && !afterOld.coverageKnown && !afterOld.route.authorizesPhysicalGuidance,
      "candidate remains nonphysical and world coverage unknown")
check(owner.ingest(lease: producerB.lease, anchorID: secondAnchor, receiptUptime: 3) {
    check($0.revision == 1, "old add did not consume revision or anchor slot")
    return floor($0, secondAnchor, offset: 10)
}, "second current anchor fits bounded ledger")
queue.sync {}
check(owner.remove(lease: producerB.lease, anchorID: secondAnchor, receiptUptime: 4),
      "current exact removal still reaches real runtime")
let afterRemove = candidate(owner)
check(afterRemove.route.complete && afterRemove.route.unknownCoverage.contains("removed:" + secondAnchor.uuidString),
      "only selected anchor removed; other floor survives")
check(!owner.ingest(lease: producerB.lease, anchorID: anchor, receiptUptime: 4) {
    forbiddenCopies += 1; return floor($0, anchor)
}, "equal current receipt rejected without invented epsilon")
check(!owner.isCurrent(afterRemove), "current malformed delivery still retires candidate")
check(candidate(owner).route.unknownCoverage.contains("ingress-or-lifecycle-gap"),
      "current receipt failure retains existing sticky gap")

// Same anchor/receipt values are reused, not the revoked identity: A -> B -> A-label.
let producerAAgain = SyntheticProducerOwner(try owner.reset())
check(producerAAgain.lease !== producerA.lease && producerAAgain.lease !== producerB.lease,
      "reset issues distinct immutable capability despite semantic ABA")
check(!delayedUpdate() && !delayedRemove(), "original A never revives in A-label run")
check(!owner.ingest(lease: producerB.lease, anchorID: anchor, receiptUptime: 5000) {
    forbiddenCopies += 1; return floor($0, anchor)
}, "intermediate B lease also revoked")
check(owner.ingest(lease: producerAAgain.lease, anchorID: anchor, receiptUptime: 1) {
    check($0.revision == 1 && $0.sessionID != epochA! && $0.sessionID != epochB!,
          "same anchor/time restart has fresh downstream epoch")
    return floor($0, anchor)
}, "new ABA lease admits")
queue.sync {}
check(candidate(owner).route.sourceDeliveryComplete, "explicit reset alone clears prior gap")

// ALREADY-admitted work retains the original reservation and context across reset.
let heldQueue = DispatchQueue(label: "test.stage86.held")
let heldOwner = try OriginBoundMeshIngress86(decodeQueue: heldQueue)
let heldA = SyntheticProducerOwner(try heldOwner.reset())
let release = DispatchSemaphore(value: 0), entered = DispatchSemaphore(value: 0)
heldQueue.async { entered.signal(); precondition(release.wait(timeout: .now()+10) == .success) }
check(entered.wait(timeout: .now()+5) == .success, "decoder hold established")
check(heldOwner.ingest(lease: heldA.lease, anchorID: anchor, receiptUptime: 1) { floor($0, anchor) },
      "old owned floor admitted before reset")
let heldB = SyntheticProducerOwner(try heldOwner.reset())
check(!heldOwner.ingest(lease: heldA.lease, anchorID: anchor, receiptUptime: 100) {
    forbiddenCopies += 1; return floor($0, anchor)
}, "held old lease cannot newly admit")
check(!heldOwner.ingest(lease: heldB.lease, anchorID: anchor, receiptUptime: 1) {
    forbiddenCopies += 1; return floor($0, anchor)
}, "new lease cannot bypass old aggregate reservation")
check(queryFails(heldOwner), "query unavailable while copy reservation held")
release.signal(); heldQueue.sync {}
check(queryFails(heldOwner), "old admitted floor did not install in B")
check(heldOwner.ingest(lease: heldB.lease, anchorID: anchor, receiptUptime: 2) { floor($0, anchor) },
      "slot is reusable only after actual old completion")
heldQueue.sync {}
check(!candidate(heldOwner).route.sourceDeliveryComplete, "new-epoch capacity refusal remains unknown")
discard(heldOwner)

// Reset while synchronous copy runs keeps its admitted epoch and slot; its gap
// must not contaminate the newer runtime when the original capture returns.
let inlineQueue = DispatchQueue(label: "test.stage86.inline")
let inlineOwner = try OriginBoundMeshIngress86(decodeQueue: inlineQueue)
let inlineA = SyntheticProducerOwner(try inlineOwner.reset())
var inlineB: SyntheticProducerOwner?
check(inlineOwner.ingest(lease: inlineA.lease, anchorID: anchor, receiptUptime: 1) { context in
    inlineB = SyntheticProducerOwner(try! inlineOwner.reset())
    return gap(context, anchor)
}, "reset during already-admitted synchronous capture")
inlineQueue.sync {}
check(inlineOwner.ingest(lease: inlineB!.lease, anchorID: anchor, receiptUptime: 1) { floor($0, anchor) },
      "new owner follows actual old capture return")
inlineQueue.sync {}
check(candidate(inlineOwner).route.sourceDeliveryComplete, "late old gap cannot contaminate current epoch")
discard(inlineOwner)

// Terminal discard after reset waits for OLD reservations; all issued leases die.
let terminalQueue = DispatchQueue(label: "test.stage86.terminal")
let terminal = try OriginBoundMeshIngress86(decodeQueue: terminalQueue)
let terminalA = SyntheticProducerOwner(try terminal.reset())
let terminalRelease = DispatchSemaphore(value: 0), terminalEntered = DispatchSemaphore(value: 0)
terminalQueue.async {
    terminalEntered.signal(); precondition(terminalRelease.wait(timeout: .now()+10) == .success)
}
check(terminalEntered.wait(timeout: .now()+5) == .success, "terminal decoder hold established")
check(terminal.ingest(lease: terminalA.lease, anchorID: anchor, receiptUptime: 1) { floor($0, anchor) },
      "old terminal reservation established")
let terminalB = SyntheticProducerOwner(try terminal.reset())
let receipts = Receipts(), allDone = DispatchGroup()
for id in 0..<3 {
    allDone.enter()
    terminal.stopAndDiscard { receipts.record(id); allDone.leave() }
}
check(receipts.total == 0, "acknowledgement cannot precede held copy release")
check(resetRejected(terminal), "terminal reset rejected before drain")
for lease in [terminalA.lease, terminalB.lease] {
    check(!terminal.ingest(lease: lease, anchorID: anchor, receiptUptime: 2) {
        forbiddenCopies += 1; return floor($0, anchor)
    }, "terminal rejects every issued lease before copy")
    check(!terminal.remove(lease: lease, anchorID: anchor, receiptUptime: 3), "terminal removal rejected")
}
terminalRelease.signal(); terminalQueue.sync {}
check(allDone.wait(timeout: .now()+10) == .success, "terminal acknowledgement follows real reservation drain")
check((0..<3).allSatisfy { receipts.count($0) == 1 }, "duplicate discard callers acknowledged exactly once")
check(resetRejected(terminal) && queryFails(terminal), "terminal cannot reopen after acknowledgement")
let repeated = DispatchSemaphore(value: 0)
terminal.stopAndDiscard { receipts.record(3); repeated.signal() }
check(repeated.wait(timeout: .now()+5) == .success && receipts.count(3) == 1,
      "post-drain repeated discard acknowledged once")

// Discard also waits for capture BEFORE it has returned an owned value.
let syncQueue = DispatchQueue(label: "test.stage86.capture-discard")
let syncOwner = try OriginBoundMeshIngress86(decodeQueue: syncQueue)
let syncLease = try syncOwner.reset()
let syncReceipts = Receipts(), syncDone = DispatchSemaphore(value: 0)
check(syncOwner.ingest(lease: syncLease, anchorID: anchor, receiptUptime: 1) { context in
    syncOwner.stopAndDiscard { syncReceipts.record(0); syncDone.signal() }
    check(syncReceipts.total == 0, "capture reservation prevents terminal acknowledgement")
    check(resetRejected(syncOwner), "discard during copy permanently rejects reset")
    return floor(context, anchor)
}, "already-admitted capture may return after terminal fence")
syncQueue.sync {}
check(syncDone.wait(timeout: .now()+5) == .success && syncReceipts.count(0) == 1,
      "late owned capture released before acknowledgement")
check(queryFails(syncOwner), "late capture never restores discarded runtime")

// REQUIRED negative control: a global mutable lease is NOT native-origin proof.
// This deliberately MISUSES the API; it is a witness of the remaining app gate.
let misuseQueue = DispatchQueue(label: "test.stage86.misuse")
let misuse = try OriginBoundMeshIngress86(decodeQueue: misuseQueue)
var globalLease = try misuse.reset()
let originalLease = globalLease
let testKnownOldCallback: () -> Bool = {
    // Deliberately wrong: reads latest mutable state at delivery, not creation.
    misuse.ingest(lease: globalLease, anchorID: anchor, receiptUptime: 100) { gap($0, anchor) }
}
globalLease = try misuse.reset()
check(globalLease !== originalLease, "misuse fixture did rotate API lease")
check(testKnownOldCallback(), "API cannot detect old native event rebound to new global lease")
misuseQueue.sync {}
discard(misuse)
check(forbiddenCopies == 0, "all rejected-origin or capacity callbacks avoided capture")
discard(owner); discard(other)
print("RESULT: \(checks) stage86 real-runtime synthetic checks passed; no ARKit-origin or device proof")
