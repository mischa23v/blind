# Proposed preregistered camera-relative geometry audit — review before execution

**Status: proposal only. No geometry execution, new harness build, point-cloud generation or diagnostic rendering has been performed.** The earlier scalar-admission and metadata results are prerequisites, not new geometry results. Maintainer approval is required before implementing/running this proposal.

## Fixed input, scope and ownership

- Same genuine iPhone recording `EM1-0387.r3d`, dataset revision `a285cd1249fe9762085713a1c796ab68b1810ac2`, clip SHA-256 `aa200931b3769084043b4cd45ae76aef52151971194b079735756aca186749d4`.
- Exactly frames **0–7**, original decoded Float32 little-endian metres and original UInt8 confidence, plus each frame's author-verified **[fx, fy, tx, ty]** coefficients, original dimensions and relative timestamp. Global K is first-frame-only and must not replace later rows.
- Existing shared `NativeDepthObservationPolicy.projection`, `acceptedDepth`, and `DepthProjection.cameraPoint` own all forward projection. No new projection implementation or planner. Keep Float→Double conversion before resolution scaling, as production does.
- All outputs remain **in each individual camera's coordinates**. Never merge successive clouds into a common frame. No pose, `initPose`, gravity, tracking status, body/mount/belt transform, floor, goal or saved mesh is an input to the Swift audit runner. Do not construct an `Observation` or call a detector, route owner or controller.
- No additional download, package/OS installation, model, GPU display or scene renderer. Frozen stage-01 and stage-02 packets remain unchanged.

## Source convention review

The existing shared camera point is:

```text
x = (u - cx) * d / fx
y = -(v - cy) * d / fy
z = -d
```

`u/v` are integer image pixel coordinates, x points right, y points up **relative to the camera**, and optical forward is negative z. This is not a gravity-aligned frame. Record3D's official Unity streaming-library example uses the same formula and integer indices, without +0.5 or normalizing the ray; that example is not a recording-app-version attestation. Apple describes scene depth as distance from the camera plane, not Euclidean ray range. Preserve original axial depth; a separately reported point norm must not replace it. Exact primary references are retained in `CONVENTION_SOURCE_REVIEW.md`.

Relevant existing source pins, inspected without modification:

- `Geometry.swift`: `f7a27aff67ed97dda0550463e70ee9df9c85381024ce02f2f091a2b35f353eb5`.
- `NativeDepthObservationPolicy.swift`: `0e6e55ddc3321b6b89998ca43c9fcd3711ec8e54d7395ea99b6edeb52e2b6e7c`.
- Native `DepthSampler.swift`: `e659262705258516fed4db98b333743c1342b5397087bf0f13ec7941a55f8171`.

The existing built Core geometry source is byte-identical to the inspected production source. Before any execution, verify exact module/binary/source hashes and actual loader paths again.

## Proposed execution and consistency checks

1. Verify all original/decoded hashes from the frozen data audit. Build a minimal input manifest containing only frame ID, data paths, width/height, that frame's four coefficients and original relative timestamp. Explicitly prohibit world/body/tracking fields.
2. Call the shared `projection` using original coefficients converted back to their exactly representable Float32 values, then the production Float→Double/scaling sequence. The already checked recording is RGB 1920×1440 and native depth 256×192; use actual fields, not hardcoded aspect-ratio assumptions.
3. Traverse native pixels from row/column zero with shared stride 2. Guard finite/in-bounds row/column, valid finite positive focal parameters and matching dimensions in this diagnostic boundary: the existing shared helper does not itself reject every invalid coordinate or overflowed output. Call actual `acceptedDepth`, then actual `cameraPoint` only for admitted values; require each returned x/y/z to be finite and z negative. Preserve each point's frame ID, row, column, original depth and confidence. Any projection failure stays a failure, not an invented point. No shared-core behavior is modified.
4. Reconcile admission against the already observed stage-02 result: 98,304 attempted stride pixels and 31,648 scalar admissions across the same eight records. These are reproducibility expectations, not a target to reach by changing data or policy. Stop and investigate any difference; do not tune thresholds.
5. For every returned point, compute the **diagnostic inverse**:

   ```text
   d_back = -z
   u_back = fx * x / d_back + cx
   v_back = cy - fy * y / d_back
   ```

   Require finite results, positive d_back, absolute pixel residual ≤ **1e-8 pixels** and depth residual ≤ **1e-12 metres**. These are numerical consistency tolerances, not measured sensor-accuracy bounds. Report actual maxima and any failures.
6. Add five hand-computed convention probes through the same shared projection function, with golden arithmetic agreement tolerance **1e-10 metres**:
   - `(fx,fy,cx,cy)=(100,100,50,40)`, unchanged resolution, pixel `(60,45)`, d=2 → `(0.2,-0.1,-2)`.
   - Asymmetric/off-centre `(120,80,17,23)`, unchanged resolution, pixel `(29,31)`, d=2 → `(0.2,-0.2,-2)`.
   - Raw coefficients `(300,200,90,68)`, RGB 300×200 and depth 150×50 → scaled `(150,50,45,17)`; pixel `(60,22)`, d=2 → `(0.2,-0.2,-2)`.
   - Asymmetric case principal pixel `(17,23)`, d=2 → `(0,0,-2)`.
   - Asymmetric case left/up pixel `(5,15)`, d=2 → `(-0.2,0.2,-2)`.

   All coefficient values must be finite; only fx/fy require positivity (principal points are not generally required to be positive). Assert expected scaled intrinsics as well as expected points, so a wrong calibration can not pass merely by round-tripping through itself. The asymmetric points also distinguish axial d from Euclidean range. These are arithmetic probes, not extra recorded scenes or physical-accuracy evidence.
7. Preserve/check source and input hashes after execution. Keep any failed run/log rather than quietly selecting another frame, convention or threshold.

The inverse and sign probes verify algebra/implementation conventions only. They must never be described as an independent accuracy test against real geometry: they derive from the same input calibration/model.

## Field of view and observed-ray coverage — precise definitions

The requested FoV diagnostic will report **per-frame intrinsic-derived pixel-centre angular spans**, not an independently measured lens/depth-sensor FoV specification. Use each frame's actual intrinsics and actual RGB/native-depth dimensions, and preserve their time variation.

For width W, height H and matching scaled intrinsics:

```text
horizontal_span = atan((W - 1 - cx)/fx) - atan((0 - cx)/fx)
vertical_span   = atan((H - 1 - cy)/fy) - atan((0 - cy)/fy)
```

Also report left/right/up/down ray angles separately because principal points need not be centred. The bounds use integer pixel centres 0…W−1 and 0…H−1, matching the inspected native/exporter convention. Do not silently add half-pixel image-edge bounds or label the result a calibrated physical FoV measurement.

For the **admitted observed rays**, report their angular extrema and density/unknown distribution separately. A bounding envelope does not imply that its interior is observed or free. No convex-hull fill, interpolation, hole filling or volumetric clearance inference.

## Confidence and missing-depth distributions

Report per frame and in an aligned **8×6 image-tile grid** (32×32 native-depth pixels per tile):

- Full-raster original confidence counts 0/1/2/other.
- Original depth finite-positive, zero, negative and nonfinite counts.
- Positive depth outside the unchanged admission range as **policy-range exclusion**, not missing data.
- Native stride attempted/admitted/rejected counts and projection failures.
- Unsampled pixels separately from rejected/invalid pixels.

Confidence rejection is neither a measured obstacle miss nor proof of free space. A finite depth value is not proof of correct geometry. Tiles are camera-image regions, not body sectors or foot/head coverage. No labels such as “safe floor” are assigned.

## Maintainer-inspection artifacts, if execution is approved

1. **Untouched RGB frame 0**, copied byte-for-byte or referenced at its original path with matching SHA-256 and dataset attribution. No annotations, rotation, rescaling or AI editing of that original file.
2. Separate analytical native-depth images, with a fixed **0.15–1.25 metre display scale** across these already known close-tabletop frames; invalid pixels visually distinct, no invented pixels or inpainting. This is a display choice only, not a change to the native 0.15–5 m admission range. Visibly mark and count finite positive values clipped below/above the display scale, even if the count is zero; retain all original numeric values and statistics.
3. Separate categorical confidence images with values 0/1/2 clearly labelled; avoid implying confidence-2 means safe. Also plot the actual admission mask and 8×6 distribution tiles, explicitly labelled analytical diagnostics.
4. Separate point-cloud scatter diagnostics made **only from the shared projection's returned points**, with x/y/z camera-axis labels and negative-z-forward caption. Each frame stays separate, with no registration, accumulated map, synthetic sensor rendering or mesh.
5. A compact table/JSON of per-frame intrinsics, relative time, intrinsic-derived spans, counts and numeric round-trip residuals; a small time-series plot may show original intrinsics/span variation.

Matplotlib's noninteractive CPU backend, NumPy and Pillow are already installed. These proposed images are deterministic plots of actual recorded arrays/returned points, **not AI-generated sensor images**. Preserve original pixel/confidence data; use only separate diagnostics. Any display clipping or plotting subsample must be declared and must not change the complete stored counts. Proposed default is no point subsampling for the small admitted set.

Local diagnostics/raw copies are for maintainer inspection only. Later source-only GitHub publication excludes original frames, point-cloud payloads and binaries; it contains code, attribution, hashes, aggregate results and protocol only.

## Independent evidence still required

This sample remains close tabletop manipulation, with no independent obstacle dimensions/locations, body trajectory, calibrated rig extrinsics or collision truth. It cannot supply hazard recall or clearance labels. `INDEPENDENT_LABEL_REQUIREMENTS.md` specifies the independent references needed before any detector/miss/body-clearance study. Correct camera projection does not resolve missing gravity, tracking or body/belt association.

## Bounds and stopping condition

Proposed limits after approval: one serial small Swift harness compile, then one eight-frame pass and bounded CPU diagnostics; **no additional acquisition**, derived outputs ≤ **24 MiB**, free-space reserve ≥ **768 MiB**, 60 CPU seconds/90 wall seconds total for execution/plots, measured peak RSS budget 512 MiB. Abort and preserve evidence if limits or associations fail.

Stop after source/data/convention consistency and declared coverage diagnostics are established, or an exact blocker is recorded. Do not expand to world mapping, perception scoring, phone/belt fusion or navigation without a separate approved protocol.
