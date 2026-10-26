# Fixed held-out depth reprojection proposal

**Status: source-only proposal; no reprojection executed. Execution requires approval.**

Question: How well does the frozen, unfiltered 265-frame TSDF mesh reproduce the **29 excluded depth images from the same processed Koivu capture**, using supplied poses and intrinsics? This is a held-out reconstruction-consistency check, not independently measured physical accuracy, obstacle recall, clearance or navigation validation.

## 1. Freeze inputs and schedule

- Mesh: `koivu/unfiltered-tsdf-mesh.ply`, 12,538,508 bytes; SHA-256 `5a75ebce93a3c65928344ce486223aa17a01a2c196982fc97edff8c41dd56e2e`; expected 242,293 vertices / 461,256 triangles. No cleaning, component selection, simplification, smoothing or hole filling.
- Training freeze: `KOIVU_FROZEN.json`, SHA-256 `89e4f8add800d85b772a5314f88c45dbecb1dd5536c0b61c9f5f533727f942d4`. Use exactly its `excludedTestIDs` in recorded order; assert 29 unique IDs and no overlap with its 265 training frames.
- The excluded IDs are `frame_00011, 00021, 00031, 00041, 00051, 00061, 00071, 00081, 00091, 00102, 00112, 00122, 00132, 00142, 00165, 00176, 00187, 00197, 00207, 00218, 00228, 00238, 00248, 00258, 00268, 00278, 00288, 00298, 00308` (the `frame_` prefix applies to each).
- Reuse the existing 294-depth collection at `blind-koivu-game-07/map/depths/`; verify the selected 29 files against `DEPTH_INPUT_MANIFEST.json`, SHA-256 `8795ad2625e49336031a6a826e8247b6cbcc8bb3867f7c27a640a89ee049c82c`. No RGB acquisition is needed. Decode uint16 PNG unchanged and convert to nominal axial metres by division by 1000.
- Use each matching supplied frame's original `fx, fy, cx, cy`, width, height and OpenGL camera-to-phone pose. Hash the same pose file pinned by the training freeze; no replacement, scale estimation, alignment or pose refinement.
- Fixed pixels: rows `range(0,994,4)` and columns `range(0,738,4)`, starting at zero. **249 × 185 = 46,065 rays per frame; 1,335,885 scheduled rays total.** Never select pixels by depth validity, predicted agreement or apparent room structure. Retain original row/column addresses.

## 2. Reuse geometry, explicitly change the pixel convention

Reuse the reviewed `ReferenceSurface`/`checked_camera`/`serial_vtk` implementation in `blind-koivu-reference-comparison-06/reference_geometry.py`, SHA-256 `266026051a781f122a59187f599688e8c5eb38807984b7e607401e7b4356386d`. Its `vtkStaticCellLocator` first-hit overload, reused `vtkGenericCell`, two-sided intersection, tolerance `1e-7`, cells-per-node 16 and maximum buckets 2,097,152 remain unchanged. Do not reuse the old stage's frame selection, Faro transform or `.5` ray builder.

This mesh is already in the supplied phone-map coordinate frame. Pass **identity** as the old helper's second transform; its legacy parameter name `phone_to_faro` does not authorize a Faro input. Do not read Faro geometry, registration or floor data. Rename output labels in the thin adapter to `phoneMap`/`predictedMesh`, avoiding an assertion that the TSDF is a physical reference.

For column `u`, row `v`, construct the unnormalized OpenGL camera ray:

`[(u-cx)/fx, -(v-cy)/fy, -1]`.

The author Open3D integration passes supplied K unchanged and uses integer pixel centres. Thus **no `+0.5`, no `-0.5` and no K adjustment** are added. Stage 06 used a different, explicitly half-pixel Nerfstudio/PyTorch3D convention; it must not be copied silently or selected by which version scores better. Record `pixelOffset=0.0` and this deliberate difference. There is no alternate-offset Koivu experiment in this proposal.

Transform rays with the supplied OpenGL camera-to-phone pose. Query the nearest positive triangle intersection, including reverse-wound faces. Use the existing geometry-only far endpoint: maximum camera-to-mesh-bounds-corner distance plus one metre; **never use the held-out depth to choose ray length**. Transform hit points back into the original camera frame and report axial `-z`, not Euclidean ray distance. Keep existing inverse-pose versus ray-parameter consistency checks. A query/geometry error is a terminal error, not a missing ray that can be omitted.

Before recorded rays, a small separate analytic fixture must check integer-pixel projection/backprojection, pose inversion, front/back-axis sign, axial-versus-range distinction, reverse winding, out-of-order planes (2 m, 4 m, 1 m → nearest 1 m), and no-hit preservation. An asymmetric integer fixture is `u=60,v=45,fx=fy=100,cx=50,cy=40,z=2`, giving `[0.20,-0.10,-2]`; the old half-pixel fixture gives `[0.21,-0.11,-2]`. Expected fixture coordinates are analytic, not fitted to Koivu. Do not call the old `convention_tests()` unchanged because its first golden explicitly requires `.5`.

## 3. Account for every scheduled ray

Retain predicted hit depth as NaN and cell ID `-1` on no hit; never zero-fill a hole as free space. Cross-tabulate these sensor states against mesh hit/no hit, per frame and pooled:

1. sensor zero/missing;
2. sensor in author integration domain: **`0 < d_sensor < 4 m`**;
3. positive sensor outside author domain: **`d_sensor >= 4 m`**, including exactly 4 m.

These six counts must sum to 1,335,885. Also expose the familiar four availability counts: both positive sensor and mesh, sensor-only, mesh-only, neither. Report denominator-based fractions, not only paired-ray error. Invalid PNG type/shape, nonfinite geometry or inconsistent query output aborts rather than silently shrinking the denominator.

Primary paired error: `e = z_mesh - d_sensor` for **all** mesh hits with `0 < d_sensor < 4`. Do not additionally require predicted depth below 4 m: a mesh prediction beyond 4 m against a near measured depth is retained as a potentially large discrepancy. Separately report positive out-of-domain sensor pairs and all-positive pairs; never mix these into an apparently favorable primary score. Positive error means the mesh surface is farther than the observed processed depth, not a proven obstacle miss. Mesh-only support and mesh no-hit do not establish occupancy or clearance.

## 4. Fixed statistics and stratification

For every frame, pooled primary pairs, all-positive pairs and out-of-domain pairs, report counts, mean signed error (bias), signed p05/p50/p95, MAE, absolute p50/p90/p95/p99 and maximum absolute error, in metres. Use NumPy's explicit linear quantile method. Empty bins yield count zero and null statistics, not zero error. Label pooled ray-weighted statistics; if adding equal-frame averages, report them separately and never average percentiles as if they were pooled percentiles.

Range bins are defined by **held-out sensor depth**, not predicted depth: `(0,0.15)`, `[0.15,1)`, `[1,2)`, `[2,3)`, `[3,4)`, `[4,5)`, `[5,infinity)`. Sensor zero is its own availability category. These ranges are diagnostic strata, not a fabricated native confidence or 5 m admission gate.

Retain edge strata without deleting any samples. Reuse the stage-06 four-neighbour logic on the **scheduled stride-4 raster**: scheduled-raster boundary; positive centre with a missing neighbour; all-positive neighbours with maximum axial-depth difference `<=0.02`, `>0.02 and <=0.10`, or `>0.10 m`. Label missing centres explicitly. Compute this separately for held-out sensor depth and predicted mesh depth, and report discrepancy/counts by each classification. The thresholds are fixed diagnostic bins; no adaptive erosion, discontinuity rejection, post-hoc threshold choice or extra dense rays. They characterize differences four original pixels apart, not full-resolution semantic object boundaries.

## 5. Outputs, bounds and acceptance of the check

Proposed serial limits, subject to approval: existing VTK 9.3.1/NumPy/Pillow only; one CPU thread, 300 CPU seconds / 450 wall seconds, 1.5 GiB RSS, at most 64 MiB new outputs, 768 MiB free-space reserve and existing 900 MiB whole-stage cap. Preflight actual current disk and coordinate the CPU slot. No downloads, installs, Open3D reintegration, mapper parameter changes or navigation calls.

Save one derived array group per frame containing original pixel addresses, original uint16 sensor depths, float64 predicted axial depths, hit cell IDs, availability and both edge codes. Pin each artifact; keep raw/derived images local under existing data-publication limits. Save per-frame/pooled JSON, frozen inputs/source hashes, resource receipt and progress counts. Verify source/input hashes before and after. An independent recount can reproduce all six categories, range/edge assignments and aggregate statistics from saved arrays without repeating ray queries.

The check is **complete only if all 29 frames and all scheduled rays are accounted for**, source/data pins match, numeric fixtures pass and independent arithmetic totals reconcile. Resource termination or geometry failure is incomplete; do not reduce the schedule to obtain a passing result. No discrepancy threshold is invented as a safety pass/fail. Preserve unfavorable distances, missing support and failure records.

## Interpretation boundary

These depth images were excluded from TSDF integration, but they are from the same processed capture and share camera calibration, supplied pose estimation and scene content with training. They are not an independent room, causal live-sensor replay or independent physical ground truth; supplied poses may incorporate information across the capture. Agreement may share systematic errors. TSDF hole/no-hit is unknown, not free. This experiment cannot establish floor support, body/head clearance, small-object recall, dynamic-obstacle latency, tracking reliability or collision-free walking. No floor classification, Faro comparison, LLM geometry or alignment fitting is permitted here.
