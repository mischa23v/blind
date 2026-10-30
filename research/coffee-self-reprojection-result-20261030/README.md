# Coffee room self-reprojection: disagreement is not only fusion

**The same-view maps already produce substantial first-voxel-hit disagreement with their own depth pixels. Cross-view pose drift/fusion cannot be the only cause. The projection and saved pixel association checks passed; neighboring source pixels demonstrably populate many of the earlier hit voxels.**

This is a diagnostic of the current representation, not phone accuracy or navigation safety. All construction inputs, 5 cm resolution, default probabilities and supplied poses were frozen. No thresholds were tuned.

## Six actual cases

Each construction view was queried against its own single-view map and the exact original three-view map. All observed hits were scored, using the same stride-8 grid and voxel-box-entry axial residual. Values are absolute errors in centimetres, not detection percentages.

| View | Valid rays | Observed hits | Single median / p95 | Fused median / p95 |
|---|---:|---:|---:|---:|
| 290 | 9,902 | 9,899 | 5.92 / 47.48 cm | 5.92 / 47.48 cm |
| 357 | 7,436 | 7,433 | 7.21 / 77.64 cm | 7.57 / 80.40 cm |
| 391 | 11,625 | 11,625 | 3.95 / 21.06 cm | 5.62 / 49.27 cm |

All leaves in every map were 5 cm; larger pruned leaves do not explain this run. The fused map exactly reproduced the primary baseline and remained unchanged. All query cases were read-only. Runtime: 3.39 seconds wall (full precision in JSON). Conservative known/unknown/range statuses are retained separately; observation-only hits remain visibility-unverified. Neither successful rays nor this table establish clearance.

Per-singleton keyed support for fused hit centers shows:
- View 290: all 9,899 hits supported by its own single-view map; no other-view-only hits.
- View 357: 247 of 7,433 fused hits supported only by another view.
- View 391: 3,231 of 11,625 fused hits supported only by another view (frame 357).

These are occupancy-support identities, not physical object identities or proof of occlusion. Unknown and known-not-occupied support states remain separate in `RESULT.json` and the saved masks.

## Additional saved-array and original-depth audit

No OctoMap library was loaded for this follow-up. The script read the original three depth images, supplied metadata and saved derived arrays. It did not read held-out rasters or change maps.

1. Recomputed full-raster world projection equals the ray-origin-plus-direction-times-depth expression to within **1.8 × 10⁻¹⁵ m**.
2. Saved per-hit pixel indices lie on the fixed grid and are unique and valid. Recomputed center residuals agree with the saved values within **8.9 × 10⁻¹⁶ m**. Saved residual distributions reproduce exactly. This rules out the suspected row/column versus saved-hit association mismatch in this code path, not an externally wrong camera calibration.
3. For every singleton hit, the returned native voxel key contains at least one original measured endpoint from that same image. The hit is not an unsupported cell invented by the saved-result adapter.
4. The queried pixel's own endpoint is in that first-hit key only in the counts below. Most other first hits are populated by neighboring image samples. We chose no depth-jump cutoff: for each returned key, all original contributing pixels were considered, then the closest image pixel was located; equal-distance ties were summarized by their median depth.

| Singleton view | Own endpoint in first-hit key | Nearest supporting pixel distance, median | Supporting depth minus target, median | Absolute depth difference, p95 |
|---|---:|---:|---:|---:|
| 290 | 2,156 / 9,899 | 5 pixels | −2.5 cm | 45.10 cm |
| 357 | 1,344 / 7,433 | 8 pixels | −4.4 cm | 77.54 cm |
| 391 | 4,282 / 11,625 | 2 pixels | −0.2 cm | 20.40 cm |

Pixel distances refer to the supplied raster, not independent native LiDAR samples. The tendency is consistent with a nearer neighboring surface's occupied voxel box intruding into a ray whose own endpoint is farther away. It can occur at real depth discontinuities, slanted surfaces, or noisy depth edges. These numbers do **not** prove the nearer points are erroneous or safe to discard. RGB shadows have not been established as the cause.

## Independent analytical box check

The saved rays were also intersected analytically with their returned 5 cm boxes using the slab method, separately from the released native intersection routine. **Every saved hit intersects its box.** The largest difference between analytical and saved axial entry is **0.000000728 m (under one micrometre)** across all six cases. This supports the interpretation that the returned entry is geometrically expected for the occupied boxes, rather than a large ray-intersection arithmetic defect. This check reads saved arrays and metadata only; no native mapper or raster is opened.

The recorded entry-face angles concern axis-aligned **voxel faces**, not measured physical floor normals. No physical surface normal or semantic label was invented.

## What follows logically

- This is not solely a cross-frame fusion problem: it exists before fusion.
- The tested projection/association arithmetic is internally consistent; that is not proof of physical calibration accuracy.
- Finite occupied boxes and neighboring depth samples are a demonstrated contributing mechanism. A 5 cm cell can obscure a much farther background ray at an edge, so a 70 cm depth residual does not mean a 70 cm dimension/scale error. At grazing incidence, a small displacement perpendicular to a surface can also produce a large axial/range displacement along the ray. Thus neither a 0.8 m residual nor the large p95 alone establishes a room dimension error of that size. Physical surface incidence has not been independently estimated here.
- Fusion adds further competing hits in view 391. Pose error, real occlusion and conflicting visibility remain possible; support counts alone do not separate them.
- Nothing here supports deleting blockers because an LLM thinks the floor looks empty.

## Concrete next diagnostic, not a production tuning decision

The independent box-intersection check above has now passed. A bounded **2.5 cm versus 5 cm singleton-map ablation** using the same released OctoMap engine, original points, views and grids would test the voxel-size contribution. Predeclare the two resolutions and all reporting/stop limits; preserve every unknown/no-hit denominator and report retained endpoints as well. Do not pick a winning threshold from these three views or claim safety from smaller residuals. Keep the current CPU/memory limits and stop rather than silently raising them if finer maps exceed them. This ablation is proposed, not run.

## Files

- `RESULT.json`: byte-identical actual six-case runtime receipt.
- `audit_boxes.py`, `ANALYTICAL_BOX_AUDIT.json`: completed independent slab intersection check of all saved hit boxes.
- `audit_saved.py`, `PIXEL_ASSOCIATION_AUDIT.json`: completed source-pixel association diagnostic, reproducible without loading the mapper library.
- `DERIVED_LOCAL_FILES.json`: hashes and sizes of all nine local derived arrays; source images are not included.
- Source protocol: `../coffee-self-reprojection-source-20261030/README.md`.
- Earlier held-out result remains unchanged: `../coffee-heldout-observation-result-20261030/README.md`.

No scene, route, stair or real-person safety verdict is claimed.
