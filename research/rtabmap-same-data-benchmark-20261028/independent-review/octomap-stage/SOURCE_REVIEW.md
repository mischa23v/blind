# Independent OctoMap stage source review

Reviewed 2026-10-28 18:37 UTC; source review only. Native build, fixtures and real-data replay are pending. This is not a navigation pass or physical safety validation.

## Scope and frozen inputs

Released RTAB-Map revision `8cd2f81a735722402d1e220147c4e83a1a746eaf`, official OctoMap 1.9.7, existing fixed-node database local grids and fixed 265 poses. Reviewed `octomap-stage/adapter/main.cpp` and `PROTOCOL.md`; source can still receive diagnostic assertion additions before execution. Do not overwrite original failed/interrupted receipts.

## Findings

1. **Coordinates:** `LocalGridMaker.cpp:514–563` transforms segmented grids back into the base/node frame, including when `Grid/MapFrameProjection=true`. Therefore the full unchanged node pose, not a yaw-only pose or a second floor transform, belongs in `OctoMap::update`. Adapter's `A * opticalPose * opticalRotation.inverse()` and export `A.inverse()` agree algebraically with the original fixed mapper. The native fixture must still execute; a source identity is not an executed geometry test.
2. **Sensor viewpoint:** `OctoMap.cpp:511–512` adds cached viewpoint translation without rotating it. Adapter stops unless stored viewpoint is zero. This avoids silently guessing a correction for nonzero extrinsics; a future sensor with nonzero translation needs separate validation.
3. **Actual rays:** `OctoMap.cpp:522` enables native rays only when `Grid/RayTracing=true` and cached empty cells are absent. Adapter checks the expected empty-grid premise. Rays end at actual cached observations (with native radial clipping); missing/unseen data does not provide a ray.
4. **Ground is not free support:** Despite a misleading source comment, ground endpoints call `updateNode(key,true)` and are tagged ground (`OctoMap.cpp:567–584`). They are occupied observations distinguished semantically from obstacle endpoints; neither this native ground classification nor a free-space voxel proves traversable supporting floor.
5. **Occupancy is separate from type/history:** Free updates reduce log odds, but only initialize type/refID if prior type was unknown (`OctoMap.cpp:678–696`). A now-free voxel can retain obstacle or ground type and an old reference ID. Use native `isNodeOccupied`/probability for current occupancy. Reference ID is not a last-free-observation timestamp, and this offline tree has no verified freshness policy.
6. **Asymmetric evidence weighting:** Each endpoint calls native `updateNode` individually, while traversed-free keys are deduplicated in a `KeySet` per node. Multiple endpoints quantizing to the same world key can add multiple hits in a frame. Do not repeat the claim that every hit key is updated once per scan for this exact adapter/source path.
7. **Same-frame occupied wins:** Free updates skip cells whose reference ID is the current or newer positive node ID. This prevents a same-frame free ray from undoing an observed endpoint. Repeated later observed-free rays can still reduce occupancy. Native fixture must establish this mechanism, not a custom approximation.
8. **History/prefix:** `GlobalMap::update` assembles previously unassembled positive IDs; complete unchanged pose prefixes should not reintegrate old observations. A repeated-prefix native assertion was requested.
9. **Export:** `createCloud(originalRefPoints=true)` returns reference endpoints for occupied typed nodes; free and untyped fallback coordinates have different voxel-centre/offset conventions. Adapter appropriately uses true leaf centres for the full occupancy ledger and only occupied obstacle+ground endpoint indices for the geometry proxy.
10. **Serialization:** Native `.ot` preserves inherited occupancy/color payload, but the custom RTAB node does not override inherited serialization for type/refID/reference point. The explicit binary leaf ledger preserves its recorded type/refID/occupied state. Do not promise `.ot` alone reconstructs all RTAB provenance.
11. **Native range:** Native source tests/clips a vector adjusted by cell size for endpoint range, not merely a plain axial 4m cutoff. This is frozen released behavior, not identical support to the prior unfiltered sensor cloud.

## Evaluation boundaries

Nearest-surface forward/reverse scores on occupied+ground endpoints can compare a geometry proxy, not traversability, obstacle recall, free-space correctness or current safety. Report output density and missing geometry alongside precision. Do not fit the map to FARO, carve camera paths, infer support from unknown, or select thresholds after scoring. The global tree can only clear where its admitted rays cross; no conclusion that every artifact is removed follows from a successful synthetic contradiction fixture.

## Requested native assertions (pending)

- Hit probability 0.7; repeated later observed free lowers probability and clears old hit.
- Missing/empty evidence leaves old occupancy unchanged; unseen remains unknown.
- Low/head observations retained separately from ground.
- Nonidentity node transform and basis round-trip agree analytically.
- Cleared voxel retains stale type/refID while occupied=false.
- Identical pose-prefix resubmission does not reintegrate hits.

No blocking source-level coordinate/API defect identified as of this review. Runtime assertions and real output still required.

## Gravity qualification (18:42 UTC)

The coordinate identity above does **not** prove correct world gravity. `LocalMapMaker.hpp:128–194` removes yaw, applies roll/pitch and pose.z(), then performs z-height filtering and normal/ground segmentation. Camera optical/OpenGL convention alone does not establish the dataset world's up axis. Original protocol explicitly reports unavailable gravity/tracking metadata. Thus original cached semantic ground labels may be inappropriate even though point-coordinate algebra round-trips. Segmentation also can omit points (cluster/noise/height rules), so combined ground+obstacle endpoint output is not simply the original raw cloud with harmless labels. Current stage freezes and measures that pipeline, without silently changing axes or using FARO to set gravity. Floor support, body-height classification and navigation readiness remain unvalidated.

## Documented Z-up conflict and explicit correction proposal (18:46 UTC)

The independent dataset-source reviewer found the pinned bundled MuSHRoom/Nerfstudio `polycam_utils.py` exporter permutes raw world rows `[Z,X,Y]`, emits `orientation_override=none`, and bundled `data_conventions.md` distinguishes **world +Z up** from **camera OpenGL +Y up**. Exact per-capture exporter execution metadata remains unavailable, but camera convention does not justify treating this documented world as Y-up.

For the documented format, the existing adapter's left world rotation `A` is inappropriate for gravity-dependent segmentation. Let `P` be saved optical-camera-to-dataset-world pose and `O` the native camera optical local transform. Corrected node pose is `P * O.inverse()`, with final node-frame geometry already expressed in original dataset world after this transform. No `A` on input and no `B` on output are required. `nodePose * O == P` must be independently asserted. All original data, intrinsics and scale remain unchanged.

**Regenerate native local grids from original SensorData** through released LocalGridMaker with corrected poses in a separately frozen arm. Do not merely rotate already segmented grids: omitted points and ground assignments cannot be recovered that way. Preserve the old arm as an explicitly misconfigured/historical diagnostic, without silently changing its inputs. This is a concrete coordinate-contract correction, not threshold tuning or a FARO-assisted gravity fit. The historical raw-cloud point metric's final basis cancellation remains mathematically valid; its geometry result cannot establish that the original intermediate ground segmentation was gravity-correct.

## Native fixture and corrected source review (18:50 UTC)

Primary worker's native fixture executable completed successfully: `hitProbability=0.7 afterFree=0.1192`, followed by `NATIVE_OCCUPANCY_FIXTURES_PASSED`. Reviewed against its assertion source, not independently re-executed. Assertions include stale type/refID after clearing, unchanged-prefix no reintegration, duplicate same-key endpoints giving `0.49/0.58` occupancy, missing evidence, unknown, ground distinction, low/head endpoints, and nonidentity transform.

Reviewed new, separate `mapper_zup.cpp` and `main_zup.cpp`: original fixed full `Rtabmap::process` pipeline regenerates local grids, with `P*O.inverse()` node pose and no global `A/B`; explicit validIndices export fix retained. The new native world fixture uses an asymmetric optical point with independently checked expected world `(5,3.8,1.3)` and an actual LocalGridMaker horizontal-plane classification fixture. Source has no blocking coordinate defect identified. Real-data corrected run and fixture result remain pending at this timestamp; identity plane does not prove capture gravity metadata.
