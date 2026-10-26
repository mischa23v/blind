# Read-only diagnosis of the first phone-only map

Scope: inspect mapper source and the already saved `run-01/map/MAP.npz`; compare projection conventions with the reviewed stage-06 source. No FARO input, original-depth decode, map rebuild, new geometry experiment, route selection, filtering or threshold change. The saved map SHA is `1961eef94bc98f5d89d4986c8b62d7352d0e2046e1dbfa3e6baf767a54e7646d`.

## Useful negative result: no indexing/axis-mixing defect found

The saved artifact contains 811,806 unique voxel-index triples. Independently checked every voxel's actual minimum/maximum endpoint Y against `voxelOrigin.y + indexY*0.05` and the next slab boundary: **zero violations**, allowing only 1e-10 arithmetic tolerance. This does not suggest accidental use of X or Z as height.

The sum of voxel hit counts is **215,670,168**, matching all original pixel endpoints reported in the build. Every voxel frame count lies between 1 and 50 and does not exceed its hit count. Voxel tuples are unique; duplicate pixel evidence has not produced duplicate stored voxels.

Independently reconstructed surface indexing as `(voxelZ//2)*width + voxelX//2`, the four quadrant support bits, ground-band classification, body-height obstruction and below-floor contradiction. The resulting support, blocked, obstacle and contradiction arrays **exactly match** the saved arrays. Surface dimensions are 145 × 141. The 13 candidate indices and sole sampled-clearance cell are consistent with those arrays; there is no apparent flattening-order mismatch.

The phone-to-app matrix has determinant 1 and exact orthogonality at the available precision; product with its stored inverse differs from identity by at most approximately 1.1e-33. For this run it is numerically `[phoneX, phoneZ+1.275, -phoneY]`. The mapper's half-pixel camera ray, signs and row-vector camera-to-world multiplication match stage-06 source. This validates the declared convention, **not that +Z is independently measured gravity**.

## The obstruction is not just the 3 cm threshold

Among 2,637 floor-supported cells, numbers having a declared obstacle voxel with maximum observed Y above the following heights are:

| Height | Supported cells with such a voxel |
|---|---:|
| 0.03 m | 2,623 |
| 0.10 m | 2,614 |
| 0.25 m | 2,605 |
| 0.50 m | 2,603 |
| 1.00 m | 2,123 |
| 1.50 m | 1,439 |

There are 53,696 obstacle voxels above 1 m in supported cells. Their distinct observing-frame quartiles are 1, 2 and 3; the maximum is 35. Of the 2,123 affected supported cells, 1,210 contain at least one such voxel observed in at least two frames, 410 in at least five, and 134 in at least ten. These are **descriptive provenance counts only**. They do not establish which points are real furniture, noisy/fused surfaces or pose/export inconsistencies, and they are not permission to discard low-view-count hits.

## Separate floor-model limitation

The saved floor mode and intercept are -1.275 m, with essentially zero fitted tilt and a reported retained residual about 2.4e-15 m. A fit over **5 cm voxel centres** followed by a **3 cm trim** can collapse to one constant-Z bin. Consequently this tiny residual measures internal quantized-bin consistency, not physical floor uncertainty. The original unknown uncertainty must remain null. This limitation warrants diagnosis using original phone evidence, but alone cannot explain conflicting endpoints above 1 m.

## Consequence

The current endpoint union and finite-sample map yields only 13 supported/unblocked candidates and one cell with all 90 free samples. There is no useful A-to-B game route demonstrated. Launching 100 mostly unavailable-route runs would not establish progress. Preserve the map and diagnose the phone evidence/model association before any separately authorized correction; do not tune to FARO results, enlarge the floor band to force routes, replace starts using evaluator truth, or promote stopped actors to success.

This review excludes the maintainer's separate original-frame/cross-view investigation. It makes no claim that the supplied scene is inherently unwalkable or that the intended phone-plus-belt/additional-sensor project is infeasible.
