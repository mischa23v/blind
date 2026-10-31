# Original saved-room geometry + camera diagnostic — 2026-10-28

## Implemented source scope

This stage supplies original, hash-bound RoomPlan geometry to the separate same-frame camera recorder/view. It does **not** enable navigation, body/feet geometry, pickup, collision confirmation, current furniture position or clearance. Metric error remains unmeasured. Imported Koivu and other unrelated maps are not eligible through this same-frame association.

- `SavedRoomDiagnosticGeometry` retains the complete original floors, walls, doors, windows, openings and furniture groups, feature IDs, full feature-to-saved-world transforms, original X/Y/Z dimensions and original local polygon corners. CapturedRoom identifier and framework story metadata are retained; a story is not a verified floor identifier.
- The whole document is rejected if it exceeds 512 total features, 1,024 corners per feature or 16,384 total polygon corners. It is never prefixed or silently truncated. Counts for every kind must match actual retained features. These are implementation/resource limits, not accuracy thresholds.
- The 32-feature correspondence/matching workflow remains unchanged. This renderer does not use `RoomLayoutAdapter.layout`, including that adapter's 0.06 m wall-depth rendering minimum.
- Where original polygon corners exist, their full transform is applied without substituting a rectangle. Otherwise the twelve edges of the original dimensional bounding box are drawn. Zero dimensions remain zero. These are historical measured **bounds**, not reconstructed furniture legs, a detailed obstacle mesh, or a promise that curved/irregular physical surfaces equal their box.
- Native source bytes are bounded at 8 MiB and hashed against the exact saved descriptor's `roomCaptureSHA256` before decoding `CapturedRoom`. All native arrays are used or the operation explicitly reports unsupported/unavailable. Existing RoomPlan and CryptoKit APIs are reused; no new dependency, recognizer, model or SLAM system is introduced.

## Ownership, IO and privacy

`PlaceStore.diagnosticGeometrySource` prepares an immutable read-only local request without file IO, hashing, SQL or decoding on the camera owner. The utility reader checks the actual memory tombstone before and after reading/decoding. Final main-actor publication additionally checks exact descriptor, memory-store identity/write owner, deletion generation and current place membership.

The provider has one running utility worker and one latest pending selection. Cancel/reselection retire publication without pretending an already-running decoder has stopped. Selection B/C cannot receive delayed A geometry. User deletion retires diagnostic geometry **before** the asynchronous history purge begins; failed erasure leaves new diagnostic reads for that place blocked. Actual `PlaceStore.delete` also retires before durable erasure. A conservatively global deletion generation can withdraw an unrelated cached room, requiring Reload, rather than retaining uncertain ownership.

Repeated selection of the same descriptor does not repeatedly decode the room. It rechecks app-owned descriptor/store/deletion ownership on each view refresh. The cached value is immutable **historical** geometry, not a claim that the file or furniture is currently unchanged. An explicit Reload clears that value and rereads/hashes the original file; missing, changed or malformed bytes produce no fallback. No raw room bytes, images, names or path coordinates are uploaded or logged by this provider.

The default PlaceStore directory and file protections are unchanged. An explicit directory initializer enables actual-owner native tests in isolated temporary directories.

## Existing native callback and recorder connection

`NavigationModel` still owns the only camera/observation bridge. Its existing post-hazard deferred callback obtains `cameraWorldFrameAssociation` for **that frame's** session and capture time, checked at real uptime, and passes the immutable receipt through the existing bridge. No previous recent descriptor is substituted; no raw coordinate or timestamp is rewritten. The Nav-owned provider is injected into the existing diagnostic view.

The separately owned recorder stage converts a genuine native receipt into inert historical metadata paired atomically with its actual sample, retaining session/source/capture/descriptor/recovery provenance. It does not serialize or restore an active receipt and does not use the measured cross-frame `Alignment` field for this purpose. The view can compare the exact saved room's original historical bounds with raw camera-position segments and user problem markers, independently of having an authorized physical route. Missing association, tracking/recovery boundaries or missing/mismatched geometry leave a gap. See `research/navigation-test-recording-20261028/SAME_FRAME_MANIFEST.json` for that separate owned source cut.

## Verification and remaining evidence

- **47/47 selected Node source contracts passed**, including source-group completeness mutations, bounds/hash/deletion ownership, camera receipt hookup and existing hazard/privacy contracts. `node-initial.tap` is retained.
- **Eight new portable Core test methods authored**, covering original 3D transform/dimensions, zero wall thickness, original polygons, more than 32 features without omission, whole-document rejection, exact source counts, invalid measurements and archive validation.
- **Seven hosted native test methods authored**, covering the actual PlaceStore source/deletion owner, bounded worker/latest-selection behavior, cancellation, delayed deletion, cached geometry withdrawal, rejection of malformed/hash-mismatched/oversized sources, and wrong/unsupported loader results.
- **None of those new Swift tests has executed locally.** There is no local Swift compiler; Apple typechecking and runtime are pending.
- **There is no successful genuine CapturedRoom artifact decode/projection fixture in this stage.** Hosted tests inject synthetic valid geometry to test provider ownership and use invalid source bytes for decoder rejection. That does not establish successful original RoomPlan decoding, correct real room reconstruction, physical localization accuracy or supervised device acceptance. A real saved RoomPlan artifact/native/device comparison remains required.
- Main-thread scheduling, rendering cost for maximum bounds, VoiceOver and actual RoomPlan/ARKit lifecycle behavior remain native/device acceptance work.

Independent review is by `review_recorded_route_preview`; canonical native membership and the exact reversible Nav layer are separately owned by `audit_localization_capture_contract`. This package does not edit generator/PBX or the recorder owner's files.

## Exact source boundaries

`CANDIDATE_MANIFEST.json` pins the seven owned implementation/test files. Full Nav preimage `preimage/NavigationModel.swift.txt` is published capture-stage SHA-256 `fcea783bbbbaa4e1bdda04740fc38f11c10f30de1e6160d8eb5072d7b4a01298`. PlaceStore preimage is `f2a4766eabaaaec4e6fbb6f0a43c7593ad5a78830610a8f0ce8313928ce103eb`. Both preserve the prior published saved-frame receipt stage. The original matcher and inflated convenience layout adapter are unchanged.

No model installation, Docker/heavy build, new camera capture, uploaded private data, physical guidance activation, child walk, merge or deployment occurred in this source stage.
