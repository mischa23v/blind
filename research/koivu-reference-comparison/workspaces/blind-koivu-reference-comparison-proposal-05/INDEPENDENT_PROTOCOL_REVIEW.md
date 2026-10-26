# Independent protocol review: Koivu processed depth versus FARO reference

2026-10-26 04:00 UTC. Read-only protocol/source review. No extraction, raycast, recorded-depth metric, registration fit, test or geometry computation was executed by this reviewer.

## Outcome and reviewed revisions

**The corrected scientific comparison protocol is ready for the subsequent bounded implementation review. It is not an execution approval.** Actual mesh/resource checks, implementation conventions and the maintainer evaluation gate remain required.

- Corrected `PROTOCOL.md`: **`1d787aaca1cd97d7ca335822f9c98055485e9238f1c8680a8b5c0ce45999b216`**.
- `blind-room-reference-research-04/PAIRED_REFERENCE_FEASIBILITY.md`: `c91cba0b92e2f263388e748bebe11ddf37d1f83ff574092e87838d9d75ffab3e`.
- The initially reviewed protocol (`3784bef4d3b8c75acd4399a80b08da0469f7570a0cdfbfcc632fe8e7d745cd78`) incorrectly carried forward an integer ray-coordinate convention. The author preserved that pre-review version and corrected it before any reference-error evaluation.

## Source-derived half-pixel correction

The recorded array addresses remain exactly `(0,0), (4,0), ...`, but this processed export/author renderer is not the previous raw Record3D stream. Use **`u = column + 0.5`, `v = row + 0.5`** for its camera rays, without modifying its exported K or resampling depth.

Primary evidence:

1. [DN-Splatter reference renderer, exact revision `97588b4290128ce7ba6fdbfaac3020b42b17de4c`](https://github.com/maturk/dn-splatter/blob/97588b4290128ce7ba6fdbfaac3020b42b17de4c/dn_splatter/data/mushroom_utils/render_gt_depth.py#L127-L157) uses screen-space PyTorch3D `PerspectiveCameras`, the original frame intrinsics and the inspected OpenGL/OpenCV conversion. The same revision's [project dependencies](https://github.com/maturk/dn-splatter/blob/97588b4290128ce7ba6fdbfaac3020b42b17de4c/pyproject.toml#L7) require Nerfstudio 1.1.3.
2. Nerfstudio 1.1.3 resolves to commit **`9b3cbc79bf239eb3c69e7c288632aab02c4f0bb1`**. Its [camera-coordinate generator, lines 292–317](https://github.com/nerfstudio-project/nerfstudio/blob/9b3cbc79bf239eb3c69e7c288632aab02c4f0bb1/nerfstudio/cameras/cameras.py#L292-L317), defaults to pixel offset 0.5 and adds it to integer row/column indices.
3. PyTorch3D v0.7.6 resolves to commit **`f34104cf6ebefacd7b7e07955ee7aaa823e616ac`**. Its [pixel-to-NDC function](https://github.com/facebookresearch/pytorch3d/blob/f34104cf6ebefacd7b7e07955ee7aaa823e616ac/pytorch3d/renderer/mesh/rasterize_meshes.py#L378-L400) samples cell centers. Its [screen-camera principal-point adjustment](https://github.com/facebookresearch/pytorch3d/blob/f34104cf6ebefacd7b7e07955ee7aaa823e616ac/pytorch3d/renderer/cameras.py#L1196-L1225) and [NDC/screen scale and offset](https://github.com/facebookresearch/pytorch3d/blob/f34104cf6ebefacd7b7e07955ee7aaa823e616ac/pytorch3d/renderer/cameras.py#L1788-L1798) map these samples to `(column+0.5,row+0.5)` in the source image coordinate system.

For example, in X, the reversed raster NDC sample is `(W/2-(column+0.5))/s`, while the screen camera maps an image coordinate u to `(W/2-u)/s`; equating them gives the half-pixel coordinate above. This is an algebraic source derivation, not a choice based on smaller observed errors. The precise historical PyTorch3D binary used by dataset authors remains unattested; no bit-identical historical-renderer claim is warranted.

The revised golden example is correct: `fx=fy=100, cx=50, cy=40, d=2`, stored address `(60,45)` gives camera `(0.21,-0.11,-2)`. The earlier Record3D/native integer-index convention remains unchanged in its separate frozen audit; its adapter must not be imported wholesale here.

## Protocol properties that inspect correctly

- Exactly eight original pose-entry indices `0,4,8,12,16,20,24,28`, matched by their original image/depth names in the author-associated pose file, without frame substitution. The filename `transformations_colmap.json` is not asserted to prove successful COLMAP or causal tracking.
- Stride-4 scheduling gives **185 columns × 249 rows = 46,065 rays per frame; 368,520 over eight frames**. These are correlated samples in one room, not independent walking trials. Every scheduled ray enters paired, sensor-only, reference-only or neither; unscheduled pixels remain separately unsampled.
- The fixed author's `gt_transformation` is inverted onto the reference mesh, matching the pinned renderer. Historical device-derived scale/RANSAC/ICP is disclosed, not rerun. The protocol correctly forbids rigidizing, refitting, per-frame offsets, unit-box normalization and error-driven scale changes.
- Each C2W camera now has explicit finite/affine/rigid validation, with no silent orthogonalization. The mesh registration has a distinct similarity/scale check; it is not incorrectly forced to determinant one.
- Missing distortion fields are not proof of physically distortion-free optics. Preserve the inspected author's pinhole model as an explicit assumption; do not synthesize distortion correction. Nonzero supplied coefficients or unresolved source association require review. The original metadata's lack of confidence/tracking does not block this narrower offline processed-depth comparison and must not be replaced with synthetic confidence-2 or normal tracking.
- The metric is positive axial camera depth, not Euclidean ray length. Double-precision reference query results remain unquantized. Existing VTK geometry queries and shared projection are reused; no custom planner/raycaster or LLM geometry authority is introduced.
- Signed/absolute discrepancies, pooled and per-frame quantiles, range bins and reference-derived edge bins are fixed before errors. Large residuals, unsupported rays and bad frames are not silently excluded. An admitted ray envelope or mesh surface is not asserted to be collision-free space.
- The cleaned/hole-completed reference has no verified edit/support mask. Separate laser capture does not make the device-derived registration wholly independent. “Author-registered processed-depth/reference-surface disagreement” is the defensible evidence label, not absolute raw LiDAR accuracy, measured hazard recall or a navigation pass.

## Freeze these remaining implementation choices before metrics

These are implementation/resource-gate items, not reasons to substitute more plumbing for the requested real comparison:

1. Exact installed VTK locator/API, line tolerance, first-positive-hit policy and two-sided/back-face handling. Include near/far surfaces, off-axis axial depth, transformed planes and similarity-scale golden checks; preserve any failed source cut. Do not equate a VTK exception/nonfinite computation with a legitimate reference no-hit.
2. Explicit geometry-only far-endpoint formula and margin from transformed mesh bounds/camera origin, independent of sensor depth. State precision promotion when source PLY coordinates were originally stored at lower precision.
3. Exact image-tile partition, empty-bin/count-zero output semantics, and denominator reconciliation. Empty metrics should be explicitly absent/null, not silently zero error or omitted frames.
4. Actual mesh counts/size, permitted memory/CPU/wall/output envelope, unchanged free-space reserve, and one-pass stopping policy. Resource exhaustion must be a retained failed diagnostic, not an unreported change of sample set or mesh simplification.

No geometry metrics were computed during this review. The next useful result is the bounded real processed-depth/reference comparison under these fixed conventions, subject to the still-separate maintainer approval and implementation review.
