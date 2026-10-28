# Recorded room mesh → typed route preview handoff

Status: new source adapter; bounded real-artifact/source checks executed, Swift/native tests **not executed** in this environment. This is not movement or phone localization acceptance.

## Connected seam

`SavedRoomMeshPreview.load` reads the actual stage75 `ROUTE_DIAGNOSTIC.json`, validates its byte digest and schema, selects one upstream native route, and preserves all coordinates. `RoomMeshPreviewOwner.installSaved` retains it for a display consumer. `RoomMeshPreviewOwner.accept` accepts the actual `RoomMeshCandidateRuntime` result instead, fencing its session/generation/revision both on acceptance and every subsequent read. Failed acceptance clears the prior display. Saved/live result replacement and `clear()` retire retained state.

`RoomPreviewContext` requires explicit place/floor/room and coordinate-frame associations plus pose/support provenance. These are supplied labels, **not room recognition or physical registration**. X/Z remain horizontal and +Y is up, in source metres. No transform or rescaling is applied.

The output intentionally cannot be installed as `SpatialMapInstallation`, dispatched as guidance, or turned into a floor rectangle. A Recast line does not supply observed support, body clearance, room boundaries, current hazards or a current pose. Saved routes retain `withheldUnknownCoverage`; complete native paths do not override this. All outputs have immutable `physicalAuthority=false`, `actualWorldCoverageKnown=false`, `bodyHeadingKnown=false`, `clearanceVerified=false`.

The actual app preview consumer is now authored below; native compilation and UI execution are pending. This source handoff is not physical journey acceptance.

## Evidence and upstream

- Unmodified dependency: `../room-mesh-package-75/BlindRoomMesh`, its existing pinned Recast/Detour sources and BSD-style `LICENSE-Recast.txt`. No new planner, mesh simplifier, localization, collision or fusion implementation.
- Input: `../room-mesh-package-75/ROUTE_DIAGNOSTIC.json`, SHA256 `e60c008fd5759ebf81863774f8335c27429a20b19253c95b2b6db45291bb44d2`. Fixture is byte-identical. Contains 15 native results (five original, five replayed, five exclusion-assisted variants), not 15 independent real-world journeys. Source frame: `phone-corrected-level-game-yup-v1`.
- Geometry only; no photos/raw depth copied. Existing geometry/exclusion, supplied query-point and support limitations remain. Excluded variant is explicitly assisted, not automatic object detection.
- Source package recorded native checks are historical evidence. This adapter does not claim those checks test its new code.
- New local check: `python3 research/room-mesh-preview-handoff-20261028/check_portable.py`: validates source receipt and all 15 actual point lists/endpoints plus static adapter boundaries. **52 checks**, not Swift execution.
- Four authored XCTest methods exercise all real saved paths and rejection cases. On an approved Apple toolchain: `swift test --package-path research/room-mesh-preview-handoff-20261028 --jobs 1`. Do not install a toolchain here or activate a new workflow for this.

## Not done

Native compile/XCTest and app surface execution, current phone localization, physical clearance, camera-to-body calibration, support fusion and any physical-device walk. The independent full-owner bench fixture in `../connected-navigation-bench-20261028/` has authored support, not these recorded Koivu paths. Combining those evidence classes without qualification would fabricate an end-to-end real-data navigation result.

## Actual app integration increment

`BlindCore/RoomMeshPreview.swift` now owns the platform-neutral schema/decoder; existing Core dependency makes it available to the app without linking another native planner. `ios/BlindAssist/RecordedRoomRoutePreview.swift` is reachable through a five-line research-tools link in RoomDetailView. It clearly identifies the recording as **not the selected room**, imports only the pinned public Koivu diagnostic using a security-scoped bounded read, and keeps bytes in memory only. Variant/leg changes revalidate the digest. Clear, disappearance and inactive lifecycle release the retained bytes. There is no network, save, speech, camera, map-installation or guidance call.

The X/Z plot uses one common scale for both axes and labels itself a 2D line-only preview: no walls, coverage, object geometry or 3D reconstruction are invented. The hierarchy is source-associated labels, not recognized user location. Five legs do not mean five validated physical journeys.

The four real-fixture XCTest methods are also in the existing `BlindCoreTests/RoomMeshPreviewTests.swift` with the byte-identical `Fixtures/recorded-room-route-diagnostic.json`, so the already-approved native Core test job can run them without a new workflow. CryptoKit-supported platforms run these tests; no Linux cryptography replacement is introduced. App PBX membership is coordinated with the canonical project owner. Compilation and native execution remain pending.

## Independent review correction

The first 48-check source receipt is preserved as `PORTABLE_RECEIPT_v1_source_only.json`. Those checks did not detect a late file-import callback that could repopulate ephemeral bytes after view retirement. This was a real lifecycle gap, not a failing movement test. Revision 2 adds a main-actor view, local-file-only gate, visible/active guard and a per-presentation import lease. Retirement clears the pending token; a late old callback cannot consume a newer presentation. Three authored Core XCTest methods cover retired/reactivated, repeated-picker and ordinary one-shot callback cases. These tests are **not executed locally**. The updated 52 portable checks verify artifact/source structure only; they do not substitute for those Swift tests or actual file-picker UI validation.

The research `RoomMeshPreviewOwner.accept/current` bridge still has no executed native test of stale/failed replacement. The four archived-route XCTest methods do not test that bridge; no held-out room, new mapping or movement result is claimed. This preview is one recording with three existing processing variants, not generalization evidence.

Review of revision 2 found no remaining source publication blocker for this explicitly nonphysical preview. Native UI checks must confirm (1) ordinary Files presentation does not prematurely retire the view, (2) its completion captures the intended presentation token, (3) leaving/backgrounding before completion withholds bytes, and (4) reopening cannot accept an older completion. Source review alone does not establish UIKit/SwiftUI presentation behavior.
