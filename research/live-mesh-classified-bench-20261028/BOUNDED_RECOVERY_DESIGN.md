# Next implementation: recover observed delivery gaps, do not permanently veto the room

**Proposed next patch, not implemented by this checkpoint.** Root requested a concrete way past the conservative sticky-refusal checkpoint. The current one-anchor budget plus permanent gap makes multi-anchor room previews unusable; it must not become the final product. The remedy is revision-scoped evidence recovery, not dropping unknown gates, inventing floor or replacing ARKit/Recast.

## Why the current APIs cannot express recovery correctly

- `MeshSnapshot82.Capture.unknownGap` already identifies a specific anchor and exact owner/revision/context.83 validates that context but currently reduces the failure to unscoped `runtime.invalidate()` (`MeshCandidateIngress.swift:53,94–96`). The identity/revision needed to recover it is lost.
-75's `Replay` already owns per-anchor `ledger`, `tiles` and latest revision/timestamp checks (`Bridge.swift:12–68`). Its `unknown` set and runtime `gap` Boolean are permanent until reset. A later complete same-anchor revision can replace geometry but cannot discharge the original delivery uncertainty.
-83 accepts only owned snapshots for asynchronous decode, and75 already carries immutable owned vertices/indices/roles and a rigid transform. Reuse these. Do not cache borrowed ARMeshAnchor/Metal pointers, introduce a second mapper, or reset the whole runtime merely to erase a real gap.
- `sourceDeliveryComplete`, `unknownCoverage` and `actualWorldCoverageKnown` must retain distinct meanings. A delivered removal can settle which anchor belongs to the **latest observed model** while still leaving the physical region unobserved. Missing source delivery can be recovered; real-world clearance never follows from that bookkeeping.

## Smallest coherent metadata/API change

Proposed shared ownership must be approved separately. Exact production paths:

1. `research/mesh-candidate-ingress-83/Sources/MeshCandidateIngress.swift`
2. `research/room-mesh-package-75/BlindRoomMesh/Sources/BlindRoomMesh/RoomMeshCandidate.swift`
3. `research/room-mesh-package-75/BlindRoomMesh/Sources/BlindRoomMesh/Bridge.swift`
4. The new bench consumer/producer, plus focused dependency/hosted fixtures and corresponding source-pin updates.

**83:** retain a bounded map of unresolved anchor revisions/reasons, separate from whole-session uncertainty. Admit every update/removal by owner, UUID and revision before copying, as now. On refused/omitted/malformed replacement, call a proposed metadata-only `invalidateAnchor` API carrying that same identity/revision; do not synthesize empty geometry. A complete owned decode for the exact latest revision can resolve only that anchor's earlier missing-revision state. Stale or foreign completion cannot resolve anything. Missing classification remains unresolved unless a later complete classification is actually acquired; valid nonfloor faces replace floor as obstacles. Global tracking/run-generation ambiguity is not recoverable by an unrelated good anchor.

**75:** extend existing runtime/Replay metadata, not its geometry/planner, to represent (a) latest complete observed anchor, (b) known removal tombstone, (c) unresolved replacement revision, and (d) global session uncertainty. An immediate revision fence retires all old candidates; an unresolved update/removal quarantines that anchor's old tile from every subsequent build/snapshot. A later worker job cannot reinstall it below the latest tombstone/unresolved revision. Use a bounded per-anchor coalescing status map/single scheduled drain or an equivalent bounded existing mailbox extension; do not enqueue unlimited invalidation closures. Overflow remains global unknown until a verified reconciliation/new session.

The smallest reusable geometry operation is to let existing `Replay.geometry()` and `geometrySupport()` read the **same immutable excluded-anchor set at the same query revision**, retaining their existing stable tile order and transform-once code. This avoids exposing stale tiles while native work drains. Do not allow a query to see new role ordering with old triangle ordering. A dropped metadata drain must not silently restore a quarantined tile.

**Resolution rule:** only an actually admitted, validated, complete latest owned replacement clears that anchor's unresolved-delivery entry after its geometry is installed. Removal is immediately terminal for that anchor revision and removes/quarantines geometry; its transport event can be accounted separately from the still-unknown physical space. Neither successful replacement nor removal sets `actualWorldCoverageKnown`, installs support/body authority, or claims safe clearance. Inherent physical-coverage uncertainty must remain visible rather than becoming a permanent transport veto or being silently discarded.

**Consumer:** gate candidate publication on no unresolved delivery/global uncertainty for the exact built snapshot, with world coverage still explicitly unknown and physical authority false. Keep the current stricter gate until the typed distinction and regression evidence exist. Do not simply remove `unknownCoverage.isEmpty` from this checkpoint to manufacture useful paths.

## How an omitted stable anchor can actually be recovered

Round-robin selection only within future add/update batches is insufficient: an anchor omitted once may never receive another change callback. Keep only a bounded set of pending UUID/revision metadata, not borrowed anchors.

Investigate the existing ARSession's **subsequent real frame/anchor callbacks** as a reacquisition source: on the same serialized native owner, inspect a bounded current delivered anchor list and synchronously use existing82 to copy one pending/latest anchor within an aggregate byte/face/time admission budget. That is a new owned observation of the delivered model, never a fabricated mesh-capture timestamp. No retained ARFrame/ARMeshAnchor escapes for later copying. Copy reservation, source revision and frame association must be recorded together.

The exact Apple callback/frame ordering and anchor-generation relationship must be established on the supported SDK/device before this path is called current. If a current-frame snapshot cannot be shown to supersede the pending revision, keep that anchor unresolved; do not guess ordering. A lifecycle UUID cannot prove native generation. A callback aggregate byte/face budget can permit multiple small **complete** snapshots if reviewed and measured; a blanket count of one is a resource policy, not a collision/semantic rule. Never truncate geometry to fit.

## Required bounded fixtures and device evidence

- Miss anchor A revision1, install A revision2 completely: only A's delivery gap clears; no old tile survives. B's unresolved gap remains.
- A revision1 capture blocked; remove A revision2/refuse its mailbox event; release revision1: A is excluded immediately and can never reappear.
- Malformed/unknown-class revision replaces prior floor: old floor quarantined; later known nonfloor remains obstacle; later complete floor can recover delivery only, not physical support.
- Valid A update cannot clear global tracking/session ambiguity, an uninspected anchor-budget overflow, or missing B.
- Native query already running when an update/removal arrives cannot publish its old revision. Fresh query snapshots geometry and role/exclusion order atomically.
- Duplicate, stale, equal-time, UUID reuse/new owner and ledger-cap cases preserve tombstones and bounds. Repeated valid recovery does not grow memory or permanently block usable known geometry.
- Multi-anchor acquisition under bounded budget eventually resolves every actually reobserved pending identity; no test declares an unobserved anchor recovered. Static source checks are not proof of real callback delivery.
- On device: record original callbacks, exact copy/queue/end-to-end latency, interrupted native run, frame clock association, buffer stability and actual geometry changes. Test app restart fencing, background and the accessible warning/stop flow before any walking.

**Stop/acceptance condition for that next patch:** reproducible revision-scoped recovery over real owned snapshots with old tiles excluded immediately, bounded memory/work, and no fabricated coverage. A subsequent connected app diagnostic still needs the exclusive handoff, geometry snapshot/view, independent freshness lease and native proof in `ACTIVATION_HANDOFF.md`. Useful mapping is the goal; permanent refusal due solely to our artificial budget is an unresolved engineering defect, not a successful navigation outcome.
