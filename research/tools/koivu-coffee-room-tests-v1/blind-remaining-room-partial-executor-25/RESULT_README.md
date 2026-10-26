# Koivu remaining-room pilot: preserved failures and one partial arrival

## Outcome

| Objective | Phone-only planning | Actual movement |
|---|---|---|
| Main-room horseshoe, camera 92 → 120 → 200 → 220 → 20 | All three profiles admit first leg. All 32 tried centres per profile for 120 → 200 return incomplete native paths. 99 queries total. Later legs unattempted. | No whole-horseshoe episode. |
| VARPU entry and return, outside camera 130 → inside 160 → same outside 130 | 32 entry candidates per profile, none admitted; 96 queries total. Return was not tested as a reachable continuation. | No VARPU episode. No travel beyond its separate closed exit-sign door. |
| Explicit partial first main-room leg, camera 92 → original camera 120 region | Nominal 45 × 30 × 160 cm body, zero margin; frozen candidate length 2.854151 m. | Arrived in offline reference model after **2.760000 m / 139 ticks**, horizontal task-goal error 0.326103 m, full-3D error 0.326130 m, **0 body / 0 margin contacts**. |

**125 of 139 actual ticks had sampled unresolved-low phone-map exposure.** No exposures were erased or treated as known clear. This is not physical safety, live navigation, entire-room coverage, a loop, or small-room entry/return. The raw camera floor projections are proposed simulation-body anchors, not measured body poses.

## Frozen authorities and limits

Planning uses corrected phone masks, original-camera objectives, and fixed 35 cm task regions. Each finite region query retains its attempted native result; steering does not become a new arrival-tolerance origin. The whole-room failures remain failures. The main episode was explicitly narrowed to an admitted partial leg **before** any FARO load and after the user-facing controller's policy was frozen. No post-reference body or route replacement occurred.

The actual 45 cm episode uses stage21 full coordinate/yaw transforms, exact original raw start, stage21/v17 continuous conservative contact enclosures, unchanged nine original support seeds, and exact stage14 active support-plane coefficients. Its support envelope is identical to the earlier north episode: 2,779,693 candidates, below the unchanged 3,000,000 cap. No floor-face policy, map flags, ground residual rule, or collision threshold changed. The controller sees only supplied phone map and delivered simulated body pose. Its original-frame conservative proposed-motion bounds also exclude the western ROI.

Run receipt: 87.554 s wall, 88.15 sampled CPU seconds, 3,040,817,152 bytes peak sampled/waited tree RSS (<3 GiB); 768 MiB disk reserve retained. No network writes, installations, human/device trials, or second heavy scorer. Nine authored controller/physics fixtures passed before execution. Three planning fixtures passed.

## Reproduction and evidence

- Main planning: `../blind-remaining-room-traverse-23/PLANNING_FROZEN.json`, `planning-01/result/`, `planning-01/RUN_RECEIPT.json`.
- VARPU planning: `../blind-small-room-entry-return-24/PLANNING_FROZEN.json`, `planning-01/result/`, `planning-01/RUN_RECEIPT.json`.
- Room identity: `../blind-small-room-identification-23/IDENTIFICATION_EVIDENCE.json`. Doorway threshold samples are semantic/photo associations, not measured clear doorway width.
- Actual selected plan: `SELECTED_PLAN.json`, SHA256 `0c832761ebf4ba7f131416adfad9e63ab39c7c650688fa61395c18d963c4ece6`.
- Episode manifest: `FROZEN.json`, SHA256 `568653ea6cd6c4211add254a0ecdde13732a7958293ead94fe235bb244dd241a`.
- Actual source: `goal_region_map.py`, `goal_region_controller.py`, `episode.py`, `run_north.py`, `run_bounded.py`; source filenames retain historical names without changing outcome scope.
- Terminal evidence: `run-01/result/RESULT.json`, `ACTOR_TRACE.npz`, `QUERY_OPTIMIZATION.json`, `run-01/RUN_RECEIPT.json`.
- Independent saved-data arithmetic: `recount-01/recount_saved.py` and `RECEIPT.json` **PASS**. Reconstructed motion, stop/drained FIFO, exact plane/seed identities, original-goal error, exposure count, runtime exclusion, and all 554 saved query receipts. This is not a second reference geometry rescore. 34,902 tiled native bounds calls; no positive fallback.
- Coverage visualization: `postrun/room-coverage.png`, `plot_coverage.py`, `PLOT_RECEIPT.json`. Shows earlier actual north/south traces, new actual partial trace, the excluded region, unadmitted task links, and later untested links. Dotted task links are **not** candidate paths. Shaded footprints are sampled visited envelopes, not all-floor-area coverage. No FARO geometry is drawn.

To preserve historical outcomes, original wrappers create run directories exclusively; do not overwrite them to rerun. Use a separately versioned reproduction stage while retaining all source/data pins and resource limits. The dependency paths and identities needed for exact reproduction are recorded in the manifests.

## Remaining uncertainty

The failed south/east endpoints share the same raw walk-mask component under both 4- and 8-neighbour connectivity, but native/body-constrained routes were incomplete under this finite policy. This alone does not establish either physical blockage or an erosion-only failure. A separate read-only diagnostic investigates that distinction without changing these frozen outcomes. All earlier stage19/stage22 failures also remain unchanged.
