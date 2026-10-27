// Authored source-only witness. Compile separately against the actual stage83 graph.
// This is NOT an ARKit scheduling test and creates no anchors, mesh or camera data.
import Foundation
import MeshSnapshot82
import MeshCandidateIngress83

var checks = 0
func check(_ value: @autoclosure () -> Bool, _ label: String) {
    precondition(value(), label); checks += 1
}
func gap(_ context: MeshSnapshot82.Context, anchor: UUID) -> MeshSnapshot82.Capture {
    .unknownGap(.init(context: context, anchorID: anchor, reason: .invalidDescriptor))
}
func discard(_ owner: MeshCandidateIngress83) {
    let done = DispatchSemaphore(value: 0)
    owner.stopAndDiscard { done.signal() }
    check(done.wait(timeout: .now() + 10) == .success, "owned resources acknowledged")
}

let queue = DispatchQueue(label: "test.origin-witness.decode")
let owner = try MeshCandidateIngress83(decodeQueue: queue)
let anchor = UUID()
var originalEpoch: UUID?
check(owner.ingest(anchorID: anchor, receiptUptime: 10) { context in
    originalEpoch = context.sessionID
    return gap(context, anchor: anchor)
}, "original admission establishes test epoch label")
queue.sync {}
let testKnownOldOrigin = originalEpoch!

// The fixture knows this event originated in A. The real ingest API cannot be
// given that native origin; its clock is read only when this closure is delivered.
let delayedOldCallback: () -> Bool = {
    owner.ingest(anchorID: anchor, receiptUptime: 20) { context in
        check(context.sessionID != testKnownOldOrigin, "old-origin event gets fresh epoch")
        check(context.revision == 1, "old-origin event gets fresh revision")
        check(context.receiptUptime == 20, "fresh receipt is preserved")
        check(context.captureUptime == nil, "receipt never becomes capture time")
        return gap(context, anchor: anchor)
    }
}
owner.stop()
var copiedWhileStopped = false
check(!owner.ingest(anchorID: anchor, receiptUptime: 11) { context in
    copiedWhileStopped = true
    return gap(context, anchor: anchor)
}, "stopped owner rejects before copy")
check(!copiedWhileStopped, "stopped capture closure not invoked")
try owner.reset()
check(delayedOldCallback(), "delivered-after-reset old event is admitted, not origin-checked")
queue.sync {}
check(owner.remove(anchorID: anchor, receiptUptime: 21),
      "delayed old-origin removal has no origin field and is admitted")
discard(owner)

// Contrast: work ALREADY admitted before reset retains its original reservation
// and context. This is the earlier failure mode stage83 really does fence.
let heldQueue = DispatchQueue(label: "test.origin-witness.held")
let heldOwner = try MeshCandidateIngress83(decodeQueue: heldQueue)
let release = DispatchSemaphore(value: 0)
heldQueue.async { precondition(release.wait(timeout: .now() + 10) == .success) }
var admittedEpoch: UUID?
check(heldOwner.ingest(anchorID: anchor, receiptUptime: 1) { context in
    admittedEpoch = context.sessionID
    return gap(context, anchor: anchor)
}, "pre-reset owned copy queued")
try heldOwner.reset()
var copiedBeforeDrain = false
check(!heldOwner.ingest(anchorID: anchor, receiptUptime: 1) { context in
    copiedBeforeDrain = true
    return gap(context, anchor: anchor)
}, "old reservation survives reset")
check(!copiedBeforeDrain, "reservation refusal precedes capture")
release.signal(); heldQueue.sync {}
check(heldOwner.ingest(anchorID: anchor, receiptUptime: 2) { context in
    check(context.sessionID != admittedEpoch!, "later admission has different epoch")
    return gap(context, anchor: anchor)
}, "new work can enter only after original reservation drains")
heldQueue.sync {}
discard(heldOwner)
print("RESULT: \(checks) stage83 origin-gap witness checks passed; no ARKit execution")
