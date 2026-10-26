# Camera-relative geometry: source review and proposed acceptance contract

2026-10-26. **Proposal only; no geometry execution or frame processing performed by this review.** Scope is the same eight original EM1-0387 frames, IDs 0–7. Stages 01/02 remain unchanged. This is an algebra/convention diagnostic proposal, not sensor-accuracy, obstacle-detection, navigation or safety evidence.

## 1. Reuse the existing camera-point implementation

The Record3D author explicitly links the official Unity streaming example in [issue 6, comment 886559644](https://github.com/marek-simonik/record3d/issues/6#issuecomment-886559644). Its [unprojection at revision `49152244daa10686220c06c4f80dd9a823357e0f`, lines 60–75](https://github.com/marek-simonik/record3d_unity_streaming/blob/49152244daa10686220c06c4f80dd9a823357e0f/Record3DUnityStreaming.cpp#L60-L75) iterates integer column/row indices, multiplies inverse-intrinsic coordinates by depth, and flips image Y and optical Z. Algebraically:

```
X = (column - cx) * d / fx
Y = -(row - cy) * d / fy
Z = -d
```

This is camera-right X, camera-up Y, negative-Z forward. There is no ray normalization or added half pixel. Do not infer another sign flip merely because the historical consumer is Unity. Its old frame-size/API assumptions and lack of the present admission policy are not being adopted.

The existing shared `DepthProjection.cameraPoint` implements exactly this algebra:

- `$SHARED/blind-body-warning-build/Sources/BlindCore/Geometry.swift`
- Identical repository copy: `blind-navigation-combined/full-source/BlindCore/Sources/BlindCore/Geometry.swift`.
- SHA-256: `f7a27aff67ed97dda0550463e70ee9df9c85381024ce02f2f091a2b35f353eb5`.

**Reuse that compiled/shared implementation if execution is later authorized, not a replacement geometry authority.** An independent analytic formula is appropriate as a test oracle only. The cited historical example establishes the mathematical convention; it does not attest the unknown Record3D app version that produced this recording.

## 2. Depth, pixels and resolution

- Apple’s [WWDC20 ARKit 4 explanation](https://developer.apple.com/videos/play/wwdc2020/10611/?time=848) defines scene depth relative to the camera plane, not Euclidean distance along a normalized ray. [ARDepthData.depthMap](https://developer.apple.com/documentation/arkit/ardepthdata/depthmap) specifies metres. Thus preserve `-Z=d`; Euclidean camera distance is a distinct derived quantity and generally exceeds `d` off axis. Do not treat the buffer as graphics z-buffer values.
- The author confirms the original four values are `[fx, fy, tx, ty]`, where `tx/ty` are the principal point, in [issue 99, comment 2459540413](https://github.com/marek-simonik/record3d/issues/99#issuecomment-2459540413). The linked [official demo at `0c6e7692da100aad2d5195e307f01e75427a6a2a`](https://github.com/marek-simonik/record3d/blob/0c6e7692da100aad2d5195e307f01e75427a6a2a/demo-main.py#L40-L43) constructs the corresponding matrix. Use each frame’s original array; global `K` is the first frame’s matrix, not a substitute for every frame.
- [Author issue 94](https://github.com/marek-simonik/record3d/issues/94) and [issue 108](https://github.com/marek-simonik/record3d/issues/108) support RGB-resolution intrinsics, aligned RGB/depth and resolution-ratio scaling. For native depth dimensions `dw,dh` and RGB dimensions `w,h`, use `sx=dw/w`, `sy=dh/h`; multiply `fx,cx` by `sx` and `fy,cy` by `sy`. Keep the two axes explicit even where ratios happen to agree. This guidance is not an independently measured registration-error bound.
- [Apple’s intrinsic documentation](https://developer.apple.com/documentation/arkit/arcamera/intrinsics) defines pixel focal lengths and principal-point offsets from the image top-left. The author example and [Apple’s point-cloud sample](https://developer.apple.com/documentation/arkit/displaying-a-point-cloud-using-scene-depth) both use integer pixel indices for geometry. Preserve that **implementation convention**; do not assert subpixel calibration accuracy from it.
- Apple’s sample separately uses `width-1`/`height-1` normalization for color-texture lookup. It is not the metric unprojection equation. Likewise, do not mix the publisher README’s `px/(dw-1)*w` mapping with the author’s `dw/w` intrinsic scaling. Do not introduce `+0.5`, a resize-library half-pixel correction, UI portrait rotation, principal-point recentering, depth interpolation, confidence interpolation or hole filling.

The existing `NativeDepthObservationPolicy.projection` already accepts Float intrinsics, promotes to Double, and applies separate resolution ratios. SHA-256 of its reviewed source is `0e6e55ddc3321b6b89998ca43c9fcd3711ec8e54d7395ea99b6edeb52e2b6e7c`. Reuse this exact Float-to-Double seam and the same `acceptedDepth(Float32, actualConfidence)`/stride-2 lane from stage 02. Stop before the native sampler’s world transform; do not use its separate portrait/median helper.

## 3. Field-of-view labels must state the angular interval

[OpenCV 4.11.0, `calibrationMatrixValues`, lines 1513–1517](https://github.com/opencv/opencv/blob/31b0eeea0b44b370fd0712312df4214d4ae1b158/modules/calib3d/src/calibration.cpp#L1513-L1517) computes nominal horizontal FoV as `atan2(cx,fx)+atan2(W-cx,fx)`, converting radians to degrees; vertical is analogous. Tag 4.11.0 resolves through annotated tag `1d3b34ddd080bbf3e3d3cec58e11038fca21dcfe` to commit **`31b0eeea0b44b370fd0712312df4214d4ae1b158`**. No OpenCV installation/import is proposed.

For diagnostics, distinguish explicitly:

1. **Nominal 0..W model extent:** the OpenCV convention above.
2. **First-to-last sample-center angular span:** `atan((W-1-cx)/fx)-atan((0-cx)/fx)`.
3. **Actually scheduled stride-2 center span:** replace `W-1` with the last scheduled column; use the analogous last scheduled row vertically.

Do not silently substitute pixel-cell edges `-0.5..W-0.5`, or the centered shortcut `2*atan(W/(2*fx))` when the principal point is off center. Use explicit radians/degrees. These are intrinsic-model angular extents, **not valid-depth coverage, observed free space or hardware coverage**. Any optional admitted-pixel angular extrema must be separately labeled, not called full FoV.

## 4. Proposed preflight and numeric acceptance contract

The following are proposed thresholds and fixtures, **not observed results**. Freeze them before a separately approved execution.

1. Verify the existing stage-01 capture/metadata/decoded hashes and stage-02 source/binary pins. Permit only original IDs 0–7. Check frame association, exact dimensions and buffer lengths, original confidence, four finite coefficients, positive focal lengths and finite positive dimension ratios. Convert intrinsic coefficients through the exact native Float seam, then recheck finiteness/positivity. No replacement values or frame borrowing.
2. Preserve the original stride-2 schedule and unchanged native admission result for every attempted pixel. Match the stage-02 per-frame attempted/accepted/rejection totals. Reject malformed coordinate input before calling the core: finite integer row/column, within the declared depth raster. **The current `DepthProjection` itself does not reject nonfinite/out-of-bounds row/column or verify finite output after arithmetic; the diagnostic wrapper must do so.** Every admitted sample must produce finite XYZ with negative Z, or the diagnostic fails explicitly rather than silently changing the admission denominator.
3. Run independent analytic convention fixtures before recorded inputs: principal point maps to `(0,0,-d)`; increasing column increases X; increasing row decreases Y; separate `fx/fy`; asymmetric principal point; independent x/y scale factors; first/last raster and scheduled indices. Golden example: `fx=100, fy=80, cx=50, cy=40, d=2, column=60, row=56` gives `(0.2,-0.4,-2)`. Include invalid depth/intrinsics and guarded invalid coordinates. These are source-derived fixtures, not obstacle labels.
4. For each admitted recorded point, check exact `-Z == Double(originalFloat32Depth)`. Independently reproject using `d=-Z`, `u=cx+fx*X/d`, `v=cy-fy*Y/d`. Proposed Double thresholds for this bounded dataset are maximum absolute XYZ disagreement **1e-10 m** versus the independent expression and maximum pixel round-trip residual **1e-8 pixel**. Record maxima and failures; do not loosen thresholds after seeing failures without a versioned protocol change. These tolerances concern arithmetic consistency only, not physical accuracy.
5. Separately verify native-depth versus RGB-coordinate algebra using the same Float-backed coefficients and exact ratio mapping `u_rgb=u_depth*w/dw`, `v_rgb=v_depth*h/dh`, without resampling either image. The same XYZ tolerance applies. Check that off-axis Euclidean norm exceeds z-depth in the golden fixture. Negative-control fixtures must catch a normalized-ray implementation, a Y/Z sign reversal, global-K substitution when coefficients differ, and a width-1 or half-pixel convention mixed into geometry.
6. Round-trip consistency alone can pass if forward and inverse share the same mistake. Therefore both the source-backed convention fixtures and independent inverse/reference are mandatory. Do not call an internal round trip an external registration, distance or sensor-accuracy test.

## 5. Proposed output and authority boundary

If approved later, output immutable source/data pins, exact conventions, per-frame attempted/admitted/projected counts, rejection agreement, finite/sign checks, numeric residual maxima, fixture outcomes and explicitly named angular spans. Keep the unit of evidence **eight correlated recorded frames**, not additional scenes or trials.

Do not consume `poses`, `initPose`, inferred gravity, tracking defaults, body/mount/gimbal/belt transforms, floor estimates, collision truth, route goals or object labels. Do not construct an `Observation` with invented tracking or world fields. No world map, obstacle miss-rate, safe-distance threshold, physical coverage, controller or navigation claim follows. Phone-plus-belt remains the intended architecture; this narrow camera-relative check neither validates nor rules it out.

**Review conclusion:** a camera-relative convention diagnostic can reuse the existing production projection without waiting for world-pose resolution. Execution remains gated on review of the complete protocol and its bounds.
