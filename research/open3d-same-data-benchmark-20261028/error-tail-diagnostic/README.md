# Localizing the Open3D residual tail

**Post-hoc diagnostic, 2026-10-28. No new reconstruction, raycast, fitting, cleanup or main-score change.** This uses the already evaluated 29-view arrays, recorded phone depth and three exact public RGB frames. The original pixels were inspected before making the descriptions below. Region labels are human visual descriptions, not a semantic ground-truth annotation or physical-hazard test.

## Useful finding

The large discrepancy is not uniformly spread over the floor. In one view, a clearly visible central floor region agrees closely, while other regions show substantial near surfaces or lost foreground geometry in the fused output.

- **frame_00228, largest connected discrepancy region:** 4,166 sampled rays at the image's right side (component bounding rectangle x=552–736, y=32–636). Median TSDF first-hit axial depth is **0.398 m**, versus **3.939 m FARO** and **3.990 m recorded phone depth**. Median absolute FARO–phone difference is **0.053 m**; TSDF–phone is **3.606 m**. The upper part of this region projects over the wall/display in the RGB image. The component is not a rectangular semantic mask: its lower part includes other image content. This is evidence of a substantial reconstructed near-surface disagreement supported by both comparators, not merely a long-range floor ripple.
- **frame_00228, second component:** 1,689 sampled rays, bounding rectangle x=0–428, y=368–508, overlapping the far chair-back silhouettes and their boundaries. Median TSDF–FARO signed difference is **+1.086 m** (TSDF hits farther away). A separately stated post-hoc interior rectangle of the central far chair back, x=220–300, y=390–460, has **378 paired samples**, median absolute discrepancy **0.999 m**; median FARO–phone difference is **0.044 m**. This identifies lost/shifted foreground structure in this view, not an accurate room despite a small pooled median.
- **frame_00197, doorway view:** large residuals concentrate at both doorway margins and foreground furniture silhouettes. A visually selected central floor rectangle, x=160–600, y=780–970, contains **5,328 paired samples**, with median absolute TSDF–FARO discrepancy **0.00491 m**, P95 **0.01693 m**, and **zero samples over 0.5 m**. That narrow result does not certify all floor support or doorway traversal.
- **frame_00031, low-tail control:** selected because it has the lowest per-frame P95, not randomly. Its overall P95 is **0.1146 m**. A thin vertical component at x=252–284, y=352–792 overlaps the coat-stand region and has median TSDF–FARO difference **0.670 m**. Here the recorded phone depth instead agrees with TSDF (median absolute difference **0.054 m**) and differs from FARO (**0.700 m**). This illustrates that some mismatches are shared by the original processed phone depth, and cannot all be attributed to fusion alone.

## What this does and does not establish

In the first two frame_00228 regions, FARO and held-out phone depth independently of fusion both support much of the same foreground/background ordering, while TSDF differs strongly. The recorded phone depth and supplied camera poses are from the same capture as the training data, so they are not independent physical ground truth. The FARO capture may differ in scene state and includes unknown measured/completed surface provenance. Images provide appearance evidence but cannot prove clearance.

The largest frame_00228 component includes 2,038 of 4,166 recorded phone depths at or beyond 4 m, the baseline integration cutoff. Consequently, this view alone cannot establish that all corresponding far surfaces were eligible for integration; training observations must be checked separately. The presence of a nearer reconstructed first hit remains a measured discrepancy.

The immediate causes of the fused near geometry and missing/shifted chair surfaces remain unmeasured. Candidate explanations include pose inconsistency, conflicting training views, moving objects, integration near discontinuities, TSDF configuration and reference/capture differences. This diagnostic does **not** select one of those causes, label a shadow as a depth error, discard the offending geometry or promote anything to free space.

The floor rectangle demonstrates that a bad whole-frame tail can coexist with good local floor agreement. Conversely, the major object regions demonstrate why the small median must not be presented as a safety result. Future investigation should trace the training observations contributing to these fixed world-space regions and compare another released reconstruction method on the unchanged input split. Do not tune on these held-out examples and report the resulting score as a fresh holdout success.

## Reproduction and coordinate contract

- `inspect_tail.py`: reads exact saved TSDF/FARO arrays, asserts identical row/column coordinates, labels four-connected components of finite paired rays with absolute residual greater than 0.5 m, records all component statistics and a fixed 3×3 image partition.
- The `0.5 m` criterion is an exploratory display/description threshold, **not a safety tolerance**. No ray is removed from the main evaluation.
- Sample grid is 249 rows × 185 columns, from integer image rows `0,4,…,992` and columns `0,4,…,736`. Original RGB/depth resolution is 738×994. Depth PNG millimetres are divided by 1,000; zero depth is excluded only from sensor-comparison statistics.
- `visual_boxes.py`: exact post-hoc rectangle coordinates and closed boundary conventions; writes `VISUAL_BOX_RESULTS.json`.
- `REGIONAL_RESULTS.json`: per-frame, 3×3-region and eight largest connected-component counts/statistics. Bounding rectangles are reported for location, but all component statistics use the actual nonrectangular mask.
- `IMAGE_INPUTS.json`: exact archive member hashes. Held-out RGB was not in the original training extraction; only these three files were read from the already downloaded SHA-pinned archive into this diagnostic's separate directory. No training/holdout input was added, removed or modified.
- `INPUT_HASHES.json`: the six ray arrays and three recorded depth files used here.

Local figures show unaltered RGB beside independently plotted sensor, TSDF, FARO and signed-residual panels at common image coordinates. Color clipping at ±1 m affects display only; numerical statistics are unclipped. White is an unavailable paired hit, never free space. The public RGB files and RGB-bearing figures are **excluded from the publication allowlist pending parent review**; text/scripts/technical JSON can be reviewed independently. These diagnostic images are not replacement geometry and are not used by the planner.

## Independent review

A separate reviewer independently recomputed component membership using a four-neighbour breadth-first search, all region statistics, inclusive visual-box masks, image dimensions/hash/EXIF and projection algebra. 1,155 checks passed exactly. The review does not establish physical object identity, sensor calibration accuracy or root cause. See `../independent-review/TAIL_REVIEW.json` and `recount_tail.py`.
