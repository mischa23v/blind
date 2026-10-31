# Existing floor-patch diagnostic — not ground truth

This is an additional **standard-library scalar analysis of existing receipts**, not another occupancy run or a new plane fit. It transforms Stage A's three evaluator-only camera-local floor planes into exactly the same supplied-pose coordinate system used by the completed shared map. No raster was decoded and no scientific/native library was loaded.

For camera plane `nᵀx + d = 0` and saved transform `xP = R xC + t`, the transformed covector is `nP = R⁻ᵀ n`, `dP = d − nPᵀt`, then normalized. This uses the exact recorded R, retaining its small floating-point representation error instead of silently orthogonalizing it. For an exact rigid rotation, this equals the usual `nP = R n`. It introduces no world-axis permutation, floor flattening, or geometry-policy change.

## Findings

| Frame | Normal angle from supplied-world +Z | Fitted Z range within its sampled patch (m) | Retained fitted samples |
|---|---:|---:|---:|
| 00290 | 0.150667° | −1.356850 to −1.355643 | 414/414 |
| 00357 | 0.612119° | −1.344546 to −1.339569 | 191/195 |
| 00391 | 0.611053° | −1.352829 to −1.346070 | 480/480 |

Pairwise normal differences are **0.720534°** (00290–00357), **0.517385°** (00290–00391), and **0.830510°** (00357–00391). These are measured differences between supplied-pose-transformed fitted normals, not independent accuracy estimates or a pass criterion.

The sampled fitted-patch XY bounding boxes **do not overlap for any pair**. Therefore **no same-location height residual is reported**. Subtracting world-origin intercepts or extending one patch's fitted plane across the room would introduce unsupported extrapolation. The listed Z ranges occur at different places in an arbitrary supplied-pose frame; they are not comparable true floor heights.

## Restricted support and caveats

Only the original frozen floor rectangles and their existing four-pixel stride are sampled. Each pixel ray is intersected with its already fitted plane, and the predicted axial depth must lie inside that patch's previously recorded positive-depth minimum/maximum. Four fitted predictions in frame 00357 fall outside that recorded interval and are excluded explicitly; no measurement or original fit was changed. These positions are **fitted-plane predictions, not recovered raw depth points**. The JSON records their bounds and all exclusions.

Original local plane-fit maximum residuals were approximately 1.36, 5.31, and 3.82 mm. Small patch fit residuals do not establish sensor calibration, accurate poses, correct surface association, common floor support, or room-wide planarity. The patches were already used in evaluation and are not held out. +Z is a supplied-world axis, not independently measured gravity. No threshold was selected retrospectively to call this a pass.

The useful outcome is a missing-evidence finding: these existing patches cannot test same-location cross-view floor height consistency. The next views should provide independently selected, overlapping observed surfaces; do not turn this diagnostic into a command to average or flatten floors. See `FLOOR_PLANE_DIAGNOSTIC.json` for exact values and input/source hashes. Local diagnostic source is retained under `coordination/shared-pose-independent-review-20261029/floor_plane_diagnostic.py` (SHA256 `ea7060aca82d37c7a763aa583ad0dd434f0408fb7d0eb52f28caecbbed9a0929`).
