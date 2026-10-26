# Independent review: external pose-consistency evidence

**Scope:** six saved official-repository files at `e79385e5a626c17b87e7be708f09fdc166ef5831`, plus original pose metadata for frame IDs. No depth reread, ICP, native fitting, map change, or navigation in this review. All six SHA-256 values and Git blob identities were independently recomputed. `RECOUNT.json` preserves the arithmetic, complete frame-ID mapping, and inputs.

## Bottom line

The packet supports **view-dependent geometric inconsistency** and makes pose error a plausible hypothesis. It does **not** uniquely establish tracking drift, exclude depth/export/calibration or view-selection effects, quantify actual camera displacement from its saved translation columns, or validate any pose correction. Controls demonstrate that the proposed single-frame ICP is not safe to adopt automatically. Stored hits must not be discarded or made free based on this evidence.

## Exact counts and denominators

| Saved plane classification | Offset >2.5 cm OR tilt >1.2° | Offset >3 cm OR tilt >1.2° |
|---|---:|---:|
| Flagged fitted frames | 78 | 77 |
| Fitted, not flagged | 174 | 175 |
| No fitted row | 42 | 42 |
| Total captured frames | 294 | 294 |

There are **252 unique fitted rows**. The README and `gate_check.py` use 2.5 cm; the final print in `cause.py` uses 3 cm. Their sole membership difference is zero-based index119, original **`frame_00120`**, offset−2.8490 cm and tilt0.7877°. This is a reporting/threshold distinction, not78 vs77 failed raw captures. Original image IDs cannot generally be inferred by adding one to the pose index because the capture has filename gaps.

The saved plane tilt matches `degrees(atan(hypot(k[0],k[1])))` within numerical precision for all252 rows. Offset-at-centroid cannot independently be reconstructed from these JSONs because the fitted centroid/inlier coordinates are not saved. README median tilt0.63° and offset p5/median/p95−1.96/−0.37/+3.25 cm reconcile. The saved residual-MAD range across all252 fits is **1.686–65.487 mm**, median4.734 mm; “2.5–5 mm” is not an all-fit bound.

Source: [README](https://github.com/mischa23v/blind/blob/e79385e5a626c17b87e7be708f09fdc166ef5831/research/mapping-audit-opus-20261026/pose-consistency/README.md), [cause.py](https://github.com/mischa23v/blind/blob/e79385e5a626c17b87e7be708f09fdc166ef5831/research/mapping-audit-opus-20261026/scripts/cause.py).

## ICP: all ten saved trials, not just the eight shown

The source declares and JSON contains ten trials in order:62,61,63,60,118,104,200,150,250,30. Classification from the saved per-frame-plane gate is **six flagged fitted frames, three unflagged fitted controls, one no-fit frame**. The README table shows five of those six flagged frames and all three controls.

| Pose index | Actual original image ID | Important saved result |
|---:|---|---|
| 60/61/62/63 | frame_00061/00062/00063/00064 | Absolute floor offsets improve in all four;62 remains at1.71° tilt and+2.72 cm offset. |
| 118 | frame_00119 | Absolute offset improves−3.55→+0.01 cm; tilt worsens0.52→1.05°. |
| **104, omitted** | **frame_00105** | Offset worsens+4.09→+4.62 cm; tilt remains large10.75→9.31°. |
| **150, omitted** | **frame_00164** | **Fitness0**, identity transform. RMSE0 is no-correspondence failure, not perfect alignment or stable control. No original fitted-plane row. |
| control200 | frame_00216 | Absolute offset worsens0.58→3.98 cm; tilt0.17→1.18°. |
| control250 | frame_00266 | Offset changes−1.68→−1.65 cm; tilt0.22→0.36°. |
| control30 | frame_00031 | Absolute offset improves0.90→0.22 cm, but tilt worsens0.25→2.09°. |

Thus **5/6**, not6/6, gate-flagged trials improve absolute centroid offset; the five displayed suspects do improve. Two of three displayed controls deteriorate materially in either offset or tilt; all three have numerically increased tilt. Frame150 is an additional failure, not an omitted fourth successful control. These are selected diagnostic trials, not a representative benchmark or held-out accuracy rate.

Source: [icp_check.py](https://github.com/mischa23v/blind/blob/e79385e5a626c17b87e7be708f09fdc166ef5831/research/mapping-audit-opus-20261026/scripts/icp_check.py), [all ten saved ICP rows](https://github.com/mischa23v/blind/blob/e79385e5a626c17b87e7be708f09fdc166ef5831/research/mapping-audit-opus-20261026/pose-consistency/icp_check.json).

## Projection and selection limitations visible in source

1. `frame_pts` preserves the original stride condition and **pixel+0.5** convention, millimetres×0.001, camera-to-phone transform, and supplied level transform. But it retains **Float64** phone points instead of the earlier fusion's Float32 intermediate. This is not bitwise parity with the mapper; it is not evidence that the rounding difference causes centimetre errors.
2. `rng` is the **axial depth image value**, not Euclidean distance to the camera. Gates`rng<4` and`rng<=2` therefore differ from radial maximum-range fusion and the earlier Euclidean endpoint diagnostic, particularly off axis. No positive-depth mask is applied; zero depth becomes the camera location. Its actual impact requires the authorized reproduction, not speculation.
3. `floor_fit` chooses points within±15 cm of one supplied global plane and axial depth<4 m, requires count and axis spans, then does six trimmed least-squares iterations. It has no independent floor labels, explicit final rank/conditioning guard, or general multilevel support model. The last iteration updates the inlier mask after fitting; returned coefficients are not refitted on that final mask. `resid_mad` is1.4826×median(abs(residual)), not median-centered MAD.
4. Offset is evaluated at **each frame's own median fitted XY**, not a common physical location. Per-frame selection, visible surface coverage, slopes, range/angle-dependent bias, scene change, and processed pose/depth export can vary with time. A shared calibration error need not affect every view identically. `dcx`, `dcy`, and scale parameters exist, but the source never tests non-default values, so calibration is not excluded.
5. ICP uses non-floor geometry by a global0.20–2.2 m height band, voxel2 cm, normals8 cm, point-to-plane correspondence cutoff10 cm, identity initialization,60 iterations. Targets are temporally distant **every-third-frame** clouds, not independently validated ground truth; they can contain the same inconsistent poses/depths. It saves no full transforms, correspondence masks, before-ICP residuals, conditioning/information matrices, or uncertainty. The floor is held out by geometric band from alignment, but is not an independent sensor or truth source.
6. Post-ICP floor refitting changes point coordinates, selected floor band, inlier membership, and evaluated centroid. Its improvement is useful consistency evidence but not a fixed-point floor-error measurement. `icp_check.floorfit` also lacks the minimum-count/XY-span/rejection guards of `cause.floor_fit`; that is why no-fit150 can still emit a steep18.21° quantity.

## Why the saved translation is not the actual camera shift

ICP estimates a transform in the **global level coordinate system**: `p' = Q p + u`. For the old camera centre`c`, its implied corrected position is`Q c + u`, so displacement is **`(Q−I)c + u`**, not merely`u`. A rotation about a point away from the global origin can produce a sizeable translation column with little local displacement. The packet saves only rotation magnitude and a rounded translation vector, not`Q`, so camera-centre correction cannot be recovered. The table's10–20 cm horizontal translation components must not be relabelled measured10–20 cm camera tracking error.

## Gate counts: published arithmetic versus reproducibility

The README's194+65+315=574 cells and reported reference-positive fractions4/194=2.06%,7/65=10.77%,45/315=14.29% are arithmetically consistent. **This six-file packet has no saved per-cell hit arrays or coverage masks to independently reproduce those counts.** The maintainer’s separately authorized exact source reproduction owns that next check.

`onlybad` excludes any good/no-fit hits; `anygood` includes mixed good/bad/no-fit evidence. An additional possible class is no good hits but some no-fit hits, with or without bad hits; it is not one of the three displayed groups and must be counted explicitly when reproducing. “No near-band hits” refers to this raw axial-depth/height selection, **not a proven far-only native voxel provenance**.

The source's `real = coverage & reference_positive` makes all uncovered columns false. Therefore “not reference-real” is not automatically a proven false obstacle. Group coverage and uncovered counts are needed. The proxy is the supplied reference **vertex-column** summary, not a new triangle/continuous-body proof. Also this audit selects original`D1__low1`/support/high flags, not necessarily the active split0.7 routing mask.

Source: [gate_check.py](https://github.com/mischa23v/blind/blob/e79385e5a626c17b87e7be708f09fdc166ef5831/research/mapping-audit-opus-20261026/scripts/gate_check.py).

## Reproduction helper review (source only)

Reviewed `../reproduce_arithmetic.py` and `../run_bounded.py`: extraction of the exact two original function ASTs and gate tail preserves the declared arithmetic without importing/executing the upstream top-level scans or ICP. Original Float64/axial semantics are retained, with Euclidean-membership differences labelled diagnostic. The read-only depth symlink is checked, existing D1 values are unchanged, and saved reference proxy is confined to gate evaluation, not map/planner authority. No concrete source blocker identified. Requested final freeze include all294 depth byte hashes and group reference-covered/uncovered counts. Bound120 CPU/180 wall seconds,768 MiB observed RSS,8 MiB outputs,768 MiB reserve; these are sampled/process limits, not a cgroup guarantee. The maintainer owns execution and any subsequent receipt.

No ICP implementation or pose/map adoption is authorized by this review.
