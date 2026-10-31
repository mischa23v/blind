# Independent corrected-Z-up OctoMap result review

2026-10-28 19:05 UTC. Review of actual saved records, frozen source, native fixture logs and saved metric arrays. No mapping/closest-triangle query rerun, no device test, no navigation or physical-safety pass.

## Result

**98 independent checks passed:** 27 full leaf-ledger/category checks, 62 saved-metric/launch/freeze checks, and 9 coordinate-input/sampling checks. Scripts and machine-readable receipts accompany this review. The ledger checker is `../octomap-stage/recount.py`; run with the corrected `leaves_dataset_world.bin` option.

- All 2,268,956 binary leaf records decoded, finite and category-index arrays reproduced exactly.
- 325,714 occupied leaves: 63,720 ground-tagged and 261,994 other occupied; 1,943,242 free leaves.
- Native occupancy is consistent with the frozen 0.5 threshold, clamp [0.1192,0.971], and hit/miss settings 0.7/0.4. No exported probability lies within 1e-7 of threshold.
- **174,769 currently free leaves retain historical obstacle type, and 17,686 retain ground type.** Therefore type/refID cannot be used as current obstruction or observation-freshness evidence.
- All 265 ordered frame records contain observations and no cached empty-cell grid; native ray tracing constructs the free updates. Unrepresented space remains unknown, not free.
- Native grid resolution is 0.04 m. Between corrected mapper and global occupancy parameters the sole change is `Grid/RayTracing: false -> true`.

## Coordinates and provenance

All 265 recovered optical poses match original frozen input rows within 3.278e-7 (small text-export rounding difference from worker's DB-direct check). Input TSV hash agrees with the pre-run freeze. Frozen source, binaries, protocols, fixture logs and comparator launch pins all match.

Source uses `nodePose=P*O.inverse()` and export world coordinates directly, preserving the documented dataset WORLD +Z up rather than incorrectly applying the OpenGL CAMERA convention to world axes. Actual world-plane fixture log reports 400 ground points, zero obstacles; its source also checks asymmetric point `(5,3.8,1.3)` and roundtrip. Reviewed native occupancy assertions/logs establish hit0.7 -> repeated free0.1192, missing data unchanged, unseen unknown, stale semantics, repeated-prefix behavior, low/head endpoints and nonidentity transform. These synthetic assertions do not establish real low-hazard recall.

This is the documented format contract, not independent measurement of capture gravity. The input is the pinned public MuSHRoom Koivu recording; no user photographs/health/body measurements were introduced. Captured raw exporter/tracking/gravity metadata remain unavailable. Source-image upscaling and correlated observations are not resolved by this review.

## Frozen common-surface comparison

The same 127,774 reference sample bytes are used as in the earlier comparison. Independently regenerated the actual-point 4 cm representative selection (different grouping/minimum implementation): all 247,832 points match exactly. Recounted every saved distance summary, threshold numerator and denominator. No independent closest-distance recomputation was performed.

| Arm | Common points | Forward median | Forward P95 | Visible-reference samples within 5 cm |
|---|---:|---:|---:|---:|
| Prior Open3D | 231,472 | 4.26 cm | 49.71 cm | 81.53% |
| Prior RTAB fixed cloud | 497,307 | 6.64 cm | 48.28 cm | 94.92% |
| Prior RTAB graph cloud | 588,726 | 10.36 cm | 49.38 cm | 78.07% |
| Corrected-Z-up native OctoMap occupied endpoints | 247,832 | 4.19 cm | 43.25 cm | 90.84% |

Forward measures unsigned distance from output representatives to FARO triangles. Reverse is distance from visible held-out reference samples to sampled output points—not whole-room recall, obstacle recall, navigation accuracy or safe free-space correctness. 141,341 missing reference rays stay unknown, not clear. Different output representations and densities remain confounds. Corrected OctoMap changes segmentation, filtering and occupancy together relative to the old raw cloud: **do not attribute the improvement entirely to coordinate correction or ray clearing**. No single overall winner is established. Registered FARO transform includes supplied scale1.020790844; it was not fitted here, and its uncertainty remains unmeasured.

## Serialization and use boundaries

Reviewed native `RtabmapColorOcTreeNode` extends ColorOcTreeNode but does not override inherited serialization for custom type/refID/reference-point fields. `.ot` preserves native occupancy/color, not complete RTAB semantic provenance. The 32-byte ledger preserves centres, sizes, probability, historical type/refID and occupied flag; original reference-endpoint geometry is separately exported in the PLY. Do not claim the ledger alone reconstructs all original reference points or sensor history.

Ground-tagged occupied endpoints are **not verified floor support**. Free rays do not prove support under the body. Default segmentation may remove low objects before fusion, and stale labels require careful use even when occupied. No real full-body route/collision/low-object assessment, freshness policy, moving-obstacle test, incremental localization or iPhone runtime test follows from these outputs.

## Publication assessment

Suitable to publish as a bounded, reproducible **geometry/occupancy experiment**, with original failed/interrupted receipts retained and the limitations above. Keep large raw RGB/depth/database files out of the text-only publication; they are not necessary for this receipt. Existing dependency/licence restrictions remain; publication of research evidence does not authorize bundling the RTAB build into the app.

The corrected mapper interruption happened during export; the worker recovered all saved poses without rerunning mapping. This review checked the recovered outputs against frozen inputs but did not independently rerun SQLite recovery. Interrupted-run CPU/RSS are not measured; conservative charges and limited process visibility must remain disclosed.

Next useful test: assess support and real hazard retention in these actual corrected grids before pathing; use an untouched holdout and live incremental observations. A better nearest-surface score is insufficient to let a person move.
