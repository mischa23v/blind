# Stage86 — origin-bound admission API proposal

**Proposal only; authored Swift is uncompiled/unrun.** No stage83, app, project,
installed workflow or shared tracker is edited by this increment. No live copy, ARSession,
new perception/SLAM/planner, installation, build or GitHub write is performed.
The app remains diagnostic-flag fenced, default-off and **no-copy**.

This follows the [callback-ownership audit](../live-mesh-callback-ownership-audit-20261027/README.md)
and reuses the exact current [stage83 owner](../mesh-candidate-ingress-83/README.md),
stage82 snapshot/ARKit copier, stage81 decoder and stage75 native runtime. The
standalone `OriginBoundMeshIngress86` type is a review alternative, not a second
owner to instantiate alongside stage83. `stage83-to-stage86-review.diff` shows
the complete owner/adapter/manifest difference; it is **not an app patch**.

## The narrow defect and change

Stage83 stamps the current epoch on admission. An event with old producer origin
that first calls `ingest` or `remove` after reset is therefore not distinguishable
from a new-origin event. Its already-admitted copy fence is correct but addresses
a different ordering.

The proposed source introduces one opaque capability:

```swift
let ingress = try OriginBoundMeshIngress86() // closed; no lease available
let lease = try ingress.reset()              // sole successful issuance path
// A separately validated producer owner retains this exact object in `let lease`.
ingress.ingest(lease: lease, anchorID: id, receiptUptime: received) { context in
    /* synchronous owned capture only */
}
ingress.remove(lease: lease, anchorID: id, receiptUptime: received)
```

The snippet illustrates API shape, not permission to connect an ARKit producer.
The lease has no public constructor, fields, serialization, renew method or
`currentLease` accessor. It is an immutable final object compared by identity,
not a caller-controlled epoch, counter or anchor ID. Only a successful `reset`
returns a new object. Copying its reference does not renew it. A retained old
reference prevents identity reuse; repeated reset, same anchor, same receipt and
A→B→A semantic labels cannot reactivate it. Separate ingress owners cannot share
leases. `stop` revokes it; terminal discard revokes it permanently. Failed reset
stays closed rather than retaining the previous capability.

Admission checks the lease **under the existing ingress lock, before** advancing
the result token, consuming receipt/revision/anchor slots, invalidating runtime
coverage or reserving a copy. Old/foreign/revoked leases return `false` without
calling capture and without disturbing a current candidate. An event from a
revoked producer is not a missed current-producer delivery. Current-lease invalid
receipts, ledger overflow and capacity refusal retain stage83's existing token
retirement and sticky-gap behavior. `Bool` still means admission/offer accepted,
not successfully installed, fresh, localized or safe.

The synchronous nonescaping copy, worker queue, aggregate reservations across
reset, pre-decode/install epoch plus exact revision fences, candidate use-time
check, native mailbox, late apply-error fence and terminal drain are reused.
The lease is not queued with geometry and adds no unbounded retained payload.

## API identity is NOT native-origin proof

**A reused ARSession callback reading a new global lease is NOT fixed.** An old
event presented with the currently valid capability will pass this API. The
fixture's deliberate mutable-global negative control demonstrates that remaining
limit; it must not be deleted or reclassified as a failure of the test.

The API does not discover which native run produced an anchor, establish that
ARKit drained callbacks, bind an arbitrary callback to `currentFrame`, synchronize
Metal access, date mesh measurements, validate tracking, or prove coverage.
`receiptUptime` remains actual caller-supplied receipt ordering. `captureUptime`
remains `nil`; no epsilon, wall-clock cutoff, queue marker or arbitrary wait is
introduced as freshness/origin evidence.

The minimal generic owner is closed on construction and open at the **API** level
after reset. A future native coordinator must separately represent
closed → pending-origin → open → closed/terminal, and must not distribute a new
lease to a callback owner until immutable native producer ownership is justified.
There is intentionally no fake `originProven: Bool` unlock. The present app cannot
meet that contract and must keep refusing add/update copies. This source is not
a replacement for the native-owner refactor below.

Only the lifecycle coordinator should call `reset`, `stop` or `stopAndDiscard`.
These lifecycle methods do not take a lease; therefore an old native error or
interruption callback also needs the external owner guard **before** calling
them or mutating app state. Admission leases do not fix stale lifecycle callbacks.

## Compatibility impact if separately adopted

| Surface | Proposed impact |
| --- | --- |
| Existing app/stage83 today | None: no files or package imports changed. The new package is not referenced by the app. |
| Initial state | Closed constructor instead of stage83's initially open owner. A successful reset is required to acquire the first lease. |
| `reset()` | Returns a fresh `ProducerLease`; caller must bind it to a newly attributable immutable producer, not overwrite a lease read by old callbacks. Old handles are irrevocable. |
| Add/update/custom capture | Required `lease:` argument; no no-lease/default-current compatibility overload. Both add and update still share `ingest`. |
| ARKit overload | Required `lease:` argument, forwarded to the same pre-copy admission lock; no new delegate/session or borrowed-anchor dispatch. |
| Removal | Required `lease:` argument. This is a real source break for stage85's unleased removal seam; do not silently synthesize a current handle there. |
| Rejection semantics | Wrong-lease rejection now occurs before current result invalidation; real current-producer failures keep existing gap behavior. |
| Routes/queues/budgets/discard | Unchanged schemas and candidate-only authority. Exact outer/current checks and aggregate drain remain mandatory. |

The separate class/module name makes accidental adoption visible. A future
reviewed migration may retain the stage83 type name with the breaking signatures;
do not keep two live ingress/native owners or introduce an implicit legacy bridge.
Existing stage83 fixture results do not transfer automatically to the changed API.

## Authored checks and current evidence

`tests/main.swift` calls the actual proposed public seam and uses the actual
stage82 decoder/snapshot and stage75 native package. `@testable` is used only to
create small synthetic owned snapshots in MeshSnapshot82, not to inject state
into the ingress or substitute a planner. It authors:

- Closed construction, cross-owner lease rejection, and stop revocation before copy.
- Delayed old add/update/remove first admitted after reset: no capture, no current
  candidate retirement, no receipt/revision/ledger pollution, and no false gap.
- Current lease acceptance, exact removal and unchanged strict equal-receipt failure.
- Repeated reset/semantic ABA using identical anchor and receipt values.
- Already-admitted old copy held across reset: aggregate slot remains occupied,
  old completion cannot install, new capacity refusal remains sticky unknown.
- Reset inside synchronous capture: late old gap cannot contaminate the new runtime.
- Terminal discard before/after reset, queued copy and synchronous capture; all
  issued leases rejected, reset forbidden, acknowledgements follow real drain,
  repeated callers acknowledged once.
- **Negative misuse control:** delayed callback reading a new mutable global lease
  is accepted at API level, so it remains an app/native-owner blocker.

Queue holds and synchronous callback positions define the interleavings. Timeout
values are only failure deadlines; no sleep/clock delay stands in for origin proof.
Separate expected-compile-failure fixtures cover lease forgery, unleased custom
ingest/removal and a nonexistent current-lease getter. A positive public-signature
typecheck runs first so missing imports cannot stand in for API rejection.
Portable synthetic diagnostic-parser controls accept both named-initializer and
`'init'` protection diagnostics, require the intended fixture/lease identification,
and reject unrelated errors. These parser controls do not execute a Swift compiler.
No Swift compiler is installed locally. **None of these Swift fixtures ran.**
See [Apple handoff](APPLE_HANDOFF.md); static checks are not compiler/native tests.

`check_static.py` verifies the exact proposal, dependency and app-observation pins,
the unchanged stage83 checker, inherited native-package manifest, admission-order
source contracts and authored fixtures. It preserves the expected historical
audit mismatch instead of hiding it. `STATIC_RESULT.json` is only this portable
source-check result. `apple/ci.py` is an inert, explicit-opt-in harness: it reuses
the unchanged stage83 native SwiftPM builds and keeps its
added stage86/stage75 outputs inside the same bounded scratch tree. The harness
itself is unrun on Apple. See [provenance](PROVENANCE.md) for exact reuse/limits.

After independent source review, an isolated, bounded
[workflow proposal](apple/workflow-proposal.yml) and dated
[execution plan](APPLE_EXECUTION_PLAN_20261027.md) were prepared for parent review.
No `.github` workflow was installed or launched here. The original authored/unrun
188-check source-review receipt is preserved under `history/pre-apple-workflow-20261027/`;
it is not relabelled as Apple evidence.

The unchanged stage83 checker passed 42 source checks during this proposal.
The historical ownership-audit checker did **not** pass against today's integrated
app: its `NavigationModel.swift` hash is `6193f6c…`, while the current local stage85
integration is `ef35a58e…`. All other audit pins matched. The historical audit is
preserved, not repinned or represented as a fresh full-app audit. Current source
still has one reused `ARSession`, `.main` delegate ownership and the no-copy bridge.
Exact digests and this mismatch are in `AUDIT_RECHECK.json` and `SOURCE_PINS.json`.

## Exact remaining native-owner gates — before implementation adoption

1. **N1 — Attributable producer identity.** Review and implement a native owner with
   an immutable association between the actual session/run lifetime and its lease.
   A new app UUID, delegate replacement, first normal frame, same anchor ID, receipt
   time or queue marker is not sufficient. For reused ARSession runs, establish a
   supported attributable boundary or remain pending/closed. A separately reviewed
   single-active-session replacement may be explored: retire/pause the old producer,
   preserve/drain old reservations, reject all old-session callbacks, then admit
   only the new owner's callbacks. Never run a second competing camera session.
   Reusing a replacement session for another reset reopens the same run-origin gap.
2. **N2 — All-callback guards.** Before any side effect, guard add/update/remove,
   frame, tracking, error, interruption/end and recovery callbacks against their
   immutable native owner. No callback may retrieve a latest global lease or
   retag a borrowed anchor/old frame. The current same-object session check is not
   a per-run proof. Preserve exact goal/candidate ownership at delivery too.
3. **N3 — Complete lifecycle ordering.** Fence before camera off/end, background,
   permission/tracking loss, starvation, pause/reset, RoomPlan scan start/finish/
   cancel and recovery. Loss fencing must precede any watchdog recovery/launch.
   Opt-in or foreground alone cannot open admission. Reconcile RoomPlan's shared
   ARSession and current resume behavior; do not build a parallel sensing session.
   If the ingress itself is replaced, await terminal owned-resource acknowledgement
   rather than bypassing existing reservations with a fresh owner.
4. **N4 — Supported copy ownership and measured bounds.** Establish the serialized
   producer-owned, non-main/non-hazard copying location and actual Metal lifetime/
   synchronization. Hazards run independently first. Do not queue borrowed anchors,
   buffers or pointers to solve this. Add a reviewed callback batch-inspection cap
   and measure copy/batch latency, main/hazard delay, peak retained memory and
   overload behavior. Logical byte ceilings do not establish those bounds.
5. **N5 — Honest time/provenance.** Preserve receipt versus camera capture versus
   unknown mesh-measurement age. A frame-associated alternative needs exact
   `ARFrame.anchors` provenance and a supported origin/copy contract; post-reset
   frames do not prove every reconstructed surface was freshly observed. Any
   event ordinal is separate ordering metadata, not fabricated timestamps.
6. **N6 — Exact native verification.** Apple-compile this proposal and its actual
   ARKit overload, run its real-runtime and negative-compile fixtures, retain
   unchanged stage83/stage75 regression evidence, and validate the eventual actual
   native owner under delayed callbacks, held copying, repeated reset/opt-in,
   scan/foreground/loss-recovery ordering and terminal teardown on device. This
   source-only fixture cannot establish which ARKit interleavings occur.
7. **N7 — Physical guidance remains a separate closed gate.** API/native ownership
   does not establish localization, metric body/phone calibration, fresh floor-to-
   head/reachable-body coverage, dynamic hazards, warning lead time or supervised
   participant acceptance. Candidate-only results never authorize movement.

N1–N6 remain open; this proposal does not authorize application adoption or live
copying. N7 cannot be satisfied by an origin lease, a build or a synthetic route.
