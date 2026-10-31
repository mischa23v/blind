# Live mesh callback ownership: next gate

Source audit, 2026-10-27. **No production edits, patch application, live copying,
build, push or physical guidance.** Read alongside stage85's default-off proposal.
`SOURCE_PINS.json` identifies the inspected source; the shared checkout is dirty.

## What is already guaranteed

- Stage85 compiles its bridge only with `DEBUG && BLIND_MESH_CANDIDATE_DIAGNOSTICS`;
  its runtime opt-in starts false. Adds/updates unconditionally refuse copying and
  stop the owner. This is a counters/lifecycle seam, not live ingress.
  [Bridge](../native-candidate-app-integration-85/proposal/MeshCandidateDiagnostics.swift):1–54.
- Stage82 validates descriptor spans/formats and logical byte bounds before
  copying; only owned values go to decode. Its `captureUptime` is deliberately
  `nil`. It does not issue native origin, tracking, map or freshness authority.
  [Snapshot](../arkit-mesh-adapter-82/Sources/MeshSnapshot.swift):4–16;
  [adapter](../arkit-mesh-adapter-82/Sources/ARKitMeshAdapter.swift):10–56.
- Stage83 invalidates the outer result before copy, retains aggregate reservations
  across reset, and checks the admitted epoch/exact anchor revision before decode
  and install. Stop is a fence, not purge; terminal discard awaits owned-resource
  drain and prohibits reset. These protect work **already admitted**.
  [Ingress](../mesh-candidate-ingress-83/Sources/MeshCandidateIngress.swift):48–168.

## Blockers before replacing refusal with ingest

1. **Fresh tagging does not prove callback origin.** `NavigationModel` owns one
   `let session = ARSession()` (line292), reused by `launch` (1009–1046). The
   proposed anchor callbacks check only that object (patch75–94), then read
   current receipt uptime. Stage83 `admit` stamps its current epoch (48–57).
   An event originating before reset but first delivered afterward therefore
   receives the new epoch. This is different from an old admitted decode job,
   which the existing epoch check correctly rejects. A delayed removal has the
   same attribution gap. Neither UUID rotation nor a fresh clock read fixes it.
   The separate bridge `epoch` is not passed into stage83 admission at all.
2. **Reopen precedes evidence of a new producer run.** `beginEpoch` immediately
   resets/open stage83; `setEnabled(true)` does so without checking foreground,
   running, scanning or current tracking. The proposed anchor callbacks lack
   those checks. `launch` calls `beginEpoch` before `run`; scan finish resets twice
   but resumes the same session with `run(configuration)` and the same
   `observationFrameID` (NavigationModel958–971). RoomPlan uses that ARSession
   (PlaceStore121–125); finish/cancel explicitly leave it unpaused (160–178).
   The two diagnostic epochs fence old *admitted* work, not native mesh origin.
3. **No current copying location satisfies the complete contract.** NavigationModel
   sets `.main` as its delegate queue (668). Stage83 explicitly requires copying
   on the serialized producer owner, after independent hazards, but not on the
   main/hazard callback. Stage82 forbids queuing borrowed anchors/Metal pointers
   for later copying. Merely adding `ingest` to an anchor callback, moving all of
   NavigationModel off main, or dispatching the anchor to a worker is not an
   established solution. Byte limits are not a callback-latency bound. The
   proposed per-anchor loops also have no batch-inspection cap.
4. **Lifecycle hook presence is not complete ordering proof.** The watchdog's
   proposed stop occurs after `tickEverydayRetry`, `tickAutomaticRoomRecovery`
   and a branch that can call `launch` (1111–1131). Launch updates the frame-time
   baseline before a new frame exists. Require loss fencing before any recovery
   reopens admission. The frame/error/interruption callbacks currently lack the
   anchor callbacks' session-identity guard (1165,1570,1608,1628); a future
   session-owner replacement must guard *all* callbacks before side effects.
5. **Receipt, frame capture and mesh measurement age are different.** Strictly
   increasing stage83 receipt values provide ingress order, not capture freshness.
   Equal clock readings in a batch are conservatively rejected today; do not
   fabricate epsilon-adjusted times. A future event ordinal may order callbacks
   independently of their actual receipt timestamps. An ARFrame timestamp can
   date its camera capture, but must not become an invented per-triangle timestamp.

These are blockers for future live admission, **not claims that stage85 currently
copies unsafe geometry**. Its refusal remains intact.

## Minimal API-based next boundary (proposal only)

- Keep the existing no-copy bridge. Make the next isolated boundary an explicit
  closed/pending-origin/open/terminal lifecycle owner; observation of a current
  process flag is not an origin credential. Fence before pause/reset/scan handoff,
  starvation/recovery, interruption and permission loss. Recheck before install
  and use, retaining stage83's real aggregate reservations and stage75 runtime.
- **Reused ARSession:** remain closed after reset/handoff until independently
  attributable origin exists. A first normal-tracking callback, receipt time,
  queue marker, delegate replacement, new app UUID or same-ID anchor membership
  is insufficient by itself. No documented callback-drain/FIFO/reset barrier was
  established by this review. Do not use an arbitrary wait as one.
- A future **single-active-session owner replacement** can give a stronger
  discriminator: an immutable delegate/owner bound to one actual ARSession
  object/lifetime, never retagged for a different run. Retire/pause the old
  producer first, reject every old-session callback before it mutates new state,
  and preserve outstanding copy reservations until discard acknowledgement.
  Never operate a second competing camera session. This is a separately reviewed
  lifecycle refactor, not permission to change the current app. Reusing even that
  new object for another reset reintroduces the run-origin problem.
- A frame-associated design may use ARKit's actual `ARFrame.anchors` snapshot and
  `ARFrame.timestamp`, with an explicitly recorded restart boundary and exact
  provenance. Keep frame capture time separate from unknown mesh measurement age;
  do not join an arbitrary anchor callback to `session.currentFrame` by timestamp
  or UUID alone. It still needs a supported ownership/copy-queue contract and
  producer-origin proof; post-reset frames do not prove fresh observation of every
  mesh surface. Reuse ARKit/RoomPlan and the existing decoder/runtime, not new SLAM.

## Deterministic work possible without a device

[`tests/main.swift`](tests/main.swift) is an **authored, uncompiled/unrun** gap
witness using the real public stage83 API, not a replacement state machine:

1. Stop rejects a callback without invoking its capture closure.
2. A callback with test-known old origin, held until *after* reset, is admitted
   under the new epoch/revision; the API has no origin argument to reject it.
3. A delayed removal is likewise accepted with a new receipt timestamp.
4. In contrast, a copy admitted *before* reset retains its reservation until
   drain, and its old context cannot be retagged by the next reset.

The witness deliberately returns `unknownGap`, allocates no mesh or camera data,
and does not claim a usable route. Link it as a separate host fixture against the
same exact stage83/82/81/75 products built by the existing Apple harness; preserve
existing fixture totals. No Swift compiler is installed here, so no Swift result
is reported. `check_static.py` only verifies source pins and the authored witness.

Then test a proposed boundary with delayed old add/update/remove/frame/error,
reset while copy is held, scanning/foreground/off transitions, repeated opt-in,
equal receipt times, oversized batches, and loss-before-recovery event ordering.
Require refusal before any copy closure when origin is unknown. These fixtures
can establish adapter logic, not prove which scheduling interleavings ARKit emits.
Device work remains for actual callback/Metal lifetime, batch/copy/main-thread
latency, hazard priority, memory, scan transitions and sensor coverage/lead time.

## Apple primary API evidence checked

- [delegateQueue](https://developer.apple.com/documentation/arkit/arsession/delegatequeue):
  selects the dispatch queue; nil defaults to main. It supplies no per-run token.
- [anchor updates](https://developer.apple.com/documentation/arkit/arsessiondelegate/session(_:didupdate:)-3qtt8):
  session and changed anchors, not a capture timestamp or run identifier.
- [resetTracking](https://developer.apple.com/documentation/arkit/arsession/runoptions/resettracking)
  resets tracking/removes existing anchors; ordinary same-configuration run resumes
  prior state. [resetSceneReconstruction](https://developer.apple.com/documentation/arkit/arsession/runoptions/resetscenereconstruction)
  removes existing mesh anchors. Neither page establishes a queued-callback barrier.
- [ARFrame.timestamp](https://developer.apple.com/documentation/arkit/arframe/timestamp)
  dates frame capture. [ARAnchorCopying](https://developer.apple.com/documentation/arkit/aranchorcopying)
  describes frame-associated immutable anchor copies; do not infer a general
  deep Metal-buffer copy/synchronization guarantee from that alone.
- [ARMeshAnchor](https://developer.apple.com/documentation/arkit/armeshanchor)
  explicitly warns that reconstructed physical changes are not reflected in real
  time. Mesh delivery alone cannot authorize dynamic-obstacle clearance.
- [pause](https://developer.apple.com/documentation/arkit/arsession/pause())
  pauses processing/capture/delegate coordination, but its page does not promise
  cancellation/drain of already queued callbacks. Absence of such a guarantee is
  an evidence limit, not a claim that a particular late callback occurs on-device.

The official Markdown variants were read directly when the web renderer rejected
their `text/markdown` content type. No secondary API source was relied upon.
