# Smallest real RTAB map / localization bridge

## Verified reuse point

Pinned upstream: [introlab/rtabmap a4e7f135](https://github.com/introlab/rtabmap/tree/a4e7f13522722878dea3f07e8fd082291e72eb49), BSD-3-Clause; same revision as this repository's integration lock. No new SLAM, ray carving, voxel occupancy or path search should be written.

Actual APIs at that pin:

- `corelib/include/rtabmap/core/SensorData.h:772–827`: `gridGroundCellsRaw()`, `gridObstacleCellsRaw()`, `gridEmptyCellsRaw()`, `gridCellSize()`, `gridViewPoint()`. `uncompressDataConst` can retrieve just grid arrays without decompressing images.
- `corelib/include/rtabmap/core/Parameters.h:430`: **RGBD/CreateOccupancyGrid defaults false**. NativeMapping never enables it. `Grid/Sensor=1` selects depth. `Grid/RayTracing` defaults false; 3D ray tracing requires an OctoMap-enabled build. `Grid/Scan2dUnknownSpaceFilled=false` must remain false.
- `Statistics.h:620–669`: `stamp()`, `getSignaturesData()`, `poses()`, `mapCorrection()`, optional `localizationCovariance()`.
- `LocalGridMaker.h`: existing `createLocalMap(Signature, ground, obstacles, empty, viewpoint)` is the fallback upstream producer if a current SensorData contains no precomputed grid; do not reimplement it in Swift.
- `app/android/jni/RTABMapApp.cpp:1927–1996` already drains actual RtabmapEvent statistics and signature SensorData; this is the narrow packet extraction point. Keep event identity and current-node matching; the highest ID alone is not a freshness proof.

## Minimum concrete source change

1. In `NativeMapping.start`, configure `RGBD/CreateOccupancyGrid=true`, `Grid/Sensor=1` plus explicit finite range/resolution. Choose 3D grid/ray settings against compiled capabilities; do not claim empty rays when unsupported. Keep obstacle and ground output useful independently of ray availability.
2. Add one C-compatible callback declaration/forwarder to pinned `app/ios/RTABMapApp/NativeWrapper.hpp/.cpp`, matching registration in `app/android/jni/RTABMapApp.h/.cpp`. At actual event drain, copy the grid arrays and matching corrected node pose into bounded immutable packet storage. Reuse existing signature grids first. No RGB/image payload in this callback.
3. Extend upstream `RTABMap.swift` with copied Swift packet delivery; attach observer in our actual `NativeMapping`. No callback pointer survives packet destruction. One bounded pending packet, replacement counter, exact original count and truncation flags; any truncated class is incomplete, never whole-footprint coverage.
4. Feed keyed per-node tiles into the scene owner, with current graph-pose corrections updating/replacing those nodes, not append-only stale coordinates. New graph correction, app/mapping session, map load/delete, owner goal or mount revision retires incompatible queued outputs. Historical map tiles support candidate topology/orientation, while live current rays/obstacles still gate a current route leg.

Packet fields: schema + upstream build/config digest; app AR/mapping session generation; node ID and RTAB map ID; original AR capture uptime and exact association ID; upstream SensorData stamp; graph revision; corrected node transform and map-correction full matrices; grid frame convention/local sensor transform; cell size and viewpoint; separate ground/obstacle/empty arrays with counts, class-presence, truncation and capture times; optional covariance with explicit provenance (not a claimed error bound). Do not attach body profile to exported/public map packets.

Timestamp bridge is real work, not arrival-time substitution: `CameraMobile.cpp:181,546` offsets device stamps to epoch via `stampEpochOffset_`. Preserve original AR capture ID/uptime through that conversion, or retain the exact conversion for this camera generation. Do not estimate it anew on callback arrival. Matrix convention is likewise explicit: upstream render uses `opengl_world_T_rtabmap_world * mapToOdom_ * pose * optical_T_opengl` (`RTABMapApp.cpp:1472`); use/test the correct source transforms once, not renderer yaw.

## Why existing stats callback is insufficient

`RTABMapObserver.statsUpdated` includes pose/inliers/counts but no original capture stamp or covariance; `RTABMapApp.cpp:5000` gets that pose from `main_scene_.GetCameraPose()`. It is a rendered-camera report, not exact estimator evidence. `CameraMobile.cpp:551` injects identity covariance times 9999 or 0.00001 (with fixed roll/pitch and poor-tracking multipliers). This heuristic is not a measured accuracy model and cannot satisfy the physical issuer. Optional registration/localization covariance and ICP residuals remain useful diagnostics, not automatically calibrated total body error.

## Measured-terrain and physical producer seam

Do not alter `StoredTerrainPolicy` by zeroing floor uncertainty. Existing authored `NavigationSurface` currently rejects positive floor-height uncertainty. A measured support corridor must retain per-cell observed support-height intervals, obstacle/overhead intervals, footprint coverage, class validity and capture age; absence, occlusion, expired evidence, truncated grids and unobserved footprint remain unknown. Ground classification alone does not prove headroom, no drop, or the body/equipment swept volume. Proposed candidate adapter returns current supported/blocked/unknown legs with reasons; historical ground cannot supply fresh support by itself.

Then implement—not permanently stub—the `NativeLocalizationMeasurements` producer from exact corrected transform, measured camera/body mounting calibration, current support evidence and a retained independently evaluated error model for the tested operating domain. Resolve local calibration/error records by digest/build/config/mount/domain, propagate full transform and timing/support uncertainty, reject outside-domain inputs, and only issue the bound supported by those records. BodyHeading heuristic scores and profile preview missing dimensions must not become measured errors. Bench records exercise the actual producer before routing exact owned results to ConnectedJourneyRuntime; physical release remains separately controlled. Existing gate/route owner and full-footprint checks are reused.

## Build/test availability and next executable check

The portable verification environment has Swift and actual Core; it has **no RTAB-Map/OpenCV/PCL/OctoMap native dependencies, Xcode SDK or local RTAB checkout**. Existing `.github/workflows/native-apple*` do not build this pinned RTAB target. `tools/prepare-rtabmap.mjs` is the repository's real project adapter; it prepares `.tools/rtabmap/app/ios/RTABMapApp.xcodeproj`, adds BlindCore/BlindMemory and `BLIND_RTABMAP`. Upstream `app/ios/RTABMapApp/install_deps.sh` builds large arm64 Apple dependencies; it does not establish OctoMap availability. No native dependency build/install was performed for this receipt.

Smallest end-to-end validation on an already provisioned Mac/native build: apply a hash-checked pinned overlay, prepare existing target, compile it with existing native dependencies, replay sequential RGB/depth/intrinsics plus explicitly supplied odometry into the actual SensorData/local-grid path, and capture the real packet callback. Tests must verify ground/obstacle/empty separation, original stamps, pose corrections, loss/restart, truncation and stale/occluded support. The 596-frame ARKitScenes out-and-back sequence can test causal map/return decisions; provided odometry is estimator input, full mesh/future trajectory remain evaluator-only, and this does not evaluate independent localization accuracy. A separate live ARKit or independent-truth run supplies measured localization/calibration error evidence.

The next source patch can therefore be a small real pinned C++/Swift callback overlay plus NativeMapping parameter/consumer wiring. A protocol without that event extraction would not close the functional gap. Native compilation is pending actual dependency/build availability, not a reason to suppress the implemented candidate pipeline indefinitely.
