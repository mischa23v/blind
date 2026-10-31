# N00 / N02 / R09–R15: same-owner saved-world diagnostic recovery

**Isolated source implementation; not a native result or physical-navigation release.** Base is actual `79951a34966f0881cd942fc27c833e020aacde2b` plus the reviewed, not-yet-published map17 layer (`f7861dd0…`). No shared source was changed. IDs refer to `research/tracker-reconciliation-20261028/TRACKER.json`, not historical similarly named requirement rows.

## Completed source connection

The helper may explicitly select **Restore selected destination’s paired saved world** before confirming the existing exclusive seated camera handoff. `NavigationModel` resolves the actual installed catalog destination and `PlaceStore.diagnosticGeometrySource` ownership before stopping the normal camera. The default remains a new unregistered world. A room name, equal coordinates, GPS, old pose or normal owner's recovery cannot supply alignment.

`SeatedMeshDiagnosticController` asynchronously reads the actual local paired bytes through `SpatialMapFileStorage.readBounded` and validates MemoryStore ownership/deletion before and after. The only `LiveMeshBenchSession.SavedWorldSeed` factory checks the saved frame's two SHA256 values, securely decodes ARWorldMap and requires its exact restored origin UUID/name/identity transform. It installs `initialWorldMap` only in the already-exclusive, prepared bench ARSession before its original reset/run. Producer callbacks feed existing `SavedWorldFrameRecovery` with the same ingress session generation, original frame timestamp, tracking/mapping state and origin anchor. No new relocalizer, transform fit or planner was written.

The same producer now supplies the actual controller's map17 association API. Its exact camera capture and the native source session/generation/revision remain independently bound. Fresh recovery may permit mapped candidate coordinates, never a body pose, uncertainty estimate, floor support, current room identity or guidance. Ordinary frames maintain an epoch without replacing the captured matrix. Reset/loss/map replacement/deletion stop or retire; goal edits within the same installed frame retire the preview, not silently rebind it.

Loading is an owned pending operation. Stop cannot return exclusive camera ownership until the actual loader stack and native/render/route/audit work drain. Deletion, replacement and goal change are rechecked after loading, before activation. No archive or capture is exported or logged; only existing local private storage is read. No normal-camera behavior, calibrated authority or independent-hazard behavior is enabled by this helper.

## Limits and required execution

- Serialized inputs: world ≤32 MiB, room ≤8 MiB; origin scan ≤128 anchors. These are **not a bound on NSKeyedUnarchiver's decoded-object memory** or a decoder wall deadline. Loader is one owned utility task; cancellation fences publication and waits for disposal, not synchronous decode preemption.
- Existing 10-second startup and 0.5-second current-frame lease are unchanged. Existing explicit frozen preview lease is unchanged. No retry/QoS/deadline expansion.
- Six new executable pure recovery tests are authored; the strict classified selection must become 71 (previous65 retained). Existing seated21 methods are retained. Their actual native mapped-consumer fixture now uses the production recovery adapter; refusal tests add real malformed/empty/wrong-pair seed-decoder inputs. Held-loader delete/goal/cancel cases run the real controller and full drain, using a deliberately failing decoder result, never a forged successful archive.
- **No Swift compilation, native run or device capture was performed.** Positive ARWorldMap decode/ARSession activation/relocalization, simulator/controller results, actual on-device timings and physical accuracy remain unexecuted. The six scalar tests are not evidence for Apple relocalization. Existing failures are not superseded.
- Imported maps without a paired local RoomPlan world remain unregistered. Nonidentity external registration, calibrated camera→body/foot pose, full-footprint support, current obstacle geometry and physical guidance/device/O&M gates remain open. This completes a diagnostic producer hookup, not N00/N02 acceptance.

## Upstream reuse / integration

Existing repository `SavedWorldFrameRecovery`, `SavedWorldFrame`, protected PlaceStore source, bounded file reader and AR session owner are reused. Apple API references: https://developer.apple.com/documentation/arkit/arworldtrackingconfiguration/initialworldmap and https://developer.apple.com/documentation/arkit/managing-session-life-cycle-and-tracking-quality . No new third-party dependency or license is added; the bench gains the existing local BlindCore package dependency.

N03's normal-camera hazard receipt is a separate output veto, not available in this deliberately seated camera owner. N04's destination localization context likewise cannot borrow this helper's association or declare a calibrated journey pose.
