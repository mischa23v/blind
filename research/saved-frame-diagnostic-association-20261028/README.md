# Same-saved-frame camera association — 2026-10-28

## Decision

**Yes, a clearly labelled diagnostic CAMERA coordinate association can use the existing saved RoomPlan/world-map recovery, independently of missing body/support calibration.** This is the SAME restored world-coordinate basis, not a guessed identity transform between unrelated frames. It does not establish physical accuracy, body/feet position, support, clearance, current furniture location or guidance authority.

Imported Koivu/other route geometry remains unrelated. Normal AR tracking, a room selection/name, appearance, GPS, equal-looking coordinates or a plan cannot connect those frames. Their measured registration remains absent.

Apple's [RoomPlan WWDC23 session](https://developer.apple.com/videos/play/wwdc2023/10192/) describes using a supplied ARSession, continuing that session between scans, and relocalizing a saved ARWorldMap so scans share a coordinate system. This supports the basis association, **not** a numeric localization-error or safety claim. The session transcript was retrieved on 2026-10-28. The documentation pages for `initialWorldMap` and tracking lifecycle required JavaScript, and their linked Markdown could not be fetched by this web tool; no additional claim depends on those unavailable pages.

## Existing code-backed producer

1. `PlaceStore.startScan` creates `RoomCaptureSession(arSession: session)` from the existing owner. `finishScan` uses `stop(pauseARSession: false)`.
2. `PlaceStore.captureSession(_:didEndWith:error:)` obtains `session.arSession.getCurrentWorldMap`, appends a named identity-origin ARAnchor, and hashes the exact archived world-map and original encoded `CapturedRoom` bytes into `SavedWorldFrame`. Metadata is committed last.
3. `worldMapArtifacts` checks deletion, exact place ID, both hashes, anchor UUID/name, and every finite origin-matrix element within its existing 0.0001 identity tolerance. That tolerance checks coordinate-basis consistency; it is **not** measured physical error.
4. `beginWorldMapRecovery` begins the gate for the fresh session UUID. `NavigationModel.launch` installs that map as `initialWorldMap`, uses gravity alignment, and starts that same owner epoch.
5. Recovery requires an observed relocalizing transition, three distinct increasing normal frames, mapped/extending status and the matching restored origin. Each capture must be at/after begin, no later than the receipt clock and no older than 0.5 seconds. Gaps, ownership loss, anchor loss and lifecycle invalidation withdraw association. Recovery is not serialized across process restart.
6. The raw recorder separately labels camera transforms `arkit-session:<UUID>`, retains original ARFrame capture time, and uses the camera translation without snapping to a route. Its selected `mapTarget` is explicitly a storage target, not alignment.

`NativeLocalizationEvidenceGate` remains separate and still needs independently validated body/mount calibration, floor support and an error model; its current producer does not authorize physical output. There is no production saved-room-to-registered-route installation adapter in the inspected app sources.

## Implemented source slice

- `SavedWorldFrameCameraAssociation`: opaque, non-Codable, capture-bound evidence with exact descriptor, source session, recovery epoch and capture time. Its explicit reference is camera, uncertainty is unmeasured, and `permitsPhysicalGuidance` is false. It contains no transform, body or support conversion.
- `cameraAssociation` returns only the exact **latest accepted** capture at the real receipt clock. A previous frame's recent descriptor cannot associate a newer/older capture. New begin/reset and loss of an accepted recovery retire its epoch. Retaining a value as history does not maintain live eligibility.
- `observeTrackingInterruption` is an O(1), nonnormal-only native seam before the ordinary 15 Hz throttle. It does not inspect anchors or produce a successful association. It preserves an actual relocalizing callback even when that callback is throttled, and immediately withdraws accepted evidence on a fresh tracking interruption. Foreign-session, pre-begin, duplicate and older interruption callbacks do not mutate a newer recovery.
- The existing strict `observe` API retains its prior fail-closed handling of wrong-session/pre-begin calls. The interruption seam deliberately ignores obsolete native callbacks instead of forwarding them into that mutating failure path.
- `PlaceStore` maps actual AR tracking state into this seam and exposes exact-capture diagnostic association. `NavigationModel` checks exact ARSession object identity before any frame/failure/interruption mutation; failure/interruption now reset saved-world recovery. Normal recovery observations use real `receivedAt`, not the capture-time alias `lastFrameWallTime`.
- No recorder/route-store/view/PBX files were edited by this slice. No new diagnostic consumer is connected yet, no room geometry is rendered, and no physical authority is broadened.

## Verification

| Check | Result |
|---|---|
| Narrow Node source contracts, including exact retirement-prefix mutations | **30/30 passed**, `node-initial.tap` |
| Broader affected Node source contracts | **67/69 passed**, two existing source-contract failures retained in `node-affected.tap` |
| Reproduce those same two tests against exact unchanged Nav preimage | **9/11 passed, same two failures**, `node-baseline-two-failures.tap` |
| New Core behavior methods | Eight authored, **not executed**; no local Swift compiler available |
| Apple compile/ARKit callbacks/device accuracy/VoiceOver | **Not executed by this slice** |

The pre-existing failures are `native-depth-policy.test.mjs` (one mutation no longer rejects because the searched token also occurs elsewhere) and `passive-object-memory.test.mjs` (expects an inline detector before RGB, while the baseline already extracts the synchronous detector helper). Neither test was weakened or changed here. Their exact baseline reproduction uses the preserved Nav preimage and unchanged current supporting files via read-only symlinks; see `BASELINE_FIXTURE.json`.

Independent source review was requested from `audit_localization_capture_contract`, including reset/high-water semantics rather than only source patterns. Its separate report/reversible provenance layer is owned by that reviewer.

## Provenance and ownership

The recorder checkpoint `26bfa69e8fb7a9f32df6d4c581477d91e95dfaed` was remote-verified by the root; this checkout's local Git object database does not contain that commit. Its `PUBLICATION_MANIFEST.json` was checked against current files before editing. Full Nav preimage SHA-256 is `f101f67cb88c6b2ea8847a380ce09a351322f73e01df0dcb9e0893146d4264d1`, including all recorder hooks, retained as `preimage/NavigationModel.swift.txt`. Candidate file hashes are in `CANDIDATE_MANIFEST.json`; original owned-file hashes are in `PREIMAGE.json`. Other workers own recorder durability and unrelated current working changes. No reset, install, model download, Docker or physical activation occurred.

## Smallest next consumer/overlay slice

1. At the existing native frame callback, after that exact frame passes saved-world recovery and urgent sensor handling, obtain its diagnostic receipt using real current uptime. Carry it with the **same** immutable native camera sample through existing recorder ownership/generation checks. Do not query a previous descriptor later, renew capture time at completion, rewrite raw coordinates, or use `NavigationTestRecording.Alignment(identity)`.
2. Add a separate same-saved-frame association type to the recorder, not a fake measured cross-frame registration/calibration. Bind exact session/source frame/capture/recovery epoch; preserve tracking, queue and discontinuity gaps. Unknown metric uncertainty remains explicit. Archived receipts are historical evidence only.
3. Prepare bounded original `CapturedRoom` geometry from the exact hash-checked `.room.json` bytes on a utility owner, bound to descriptor and deletion/selection epoch. Do not assume the generic current-layout/export path has supplied that artifact proof. Reuse RoomLayoutAdapter for a labelled historical X/Z rendering; the rendering is not live furniture or a body collision model.
4. Keep room comparison independent of having an approved physical route. Overlay a planned polyline only when its artifact/frame/revision is demonstrably that exact saved frame. Imported Koivu remains a separate plot without measured registration.
5. Test mismatched saved descriptor/hash/session, changed room selection, deletion/replacement during decode, delayed sample/new recording, lost tracking, last relocalizing callback throttled, stale receipt, exact recovery epoch, no-plan room comparison and unrelated imported route. Run actual native lifecycle and supervised device comparison before claiming the displayed path is accurate.
