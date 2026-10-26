# Small eight-frame implementation proposal — not implemented or run

Reuse the already built, hash-verified production policy/Core modules. Do not modify application or firmware source. The proposed audit has only three small local files:

## 1. `CameraGeometryAudit.swift`

Extend the already reviewed stage-02 counting harness **in a new audit directory**, not in the frozen packet. Add per-frame original intrinsic fields and call:

```text
NativeDepthObservationPolicy.projection(original Float coefficients, actual dimensions)
NativeDepthObservationPolicy.acceptedDepth(original Float depth, original UInt8 confidence)
DepthProjection.cameraPoint(integer column, integer row, admitted Double depth)
```

Return per-frame actual scaled intrinsics, admitted/projection counts, numeric inverse residual maxima, and bounded camera-point rows `(frame, row, column, original_depth, original_confidence, x_camera, y_camera, z_camera)`. Retain the native stride. Include `camera_relative_only=true`, `physical_authority=false`, and `world_projection_executed=false` in every summary.

The input type has no pose, tracking, gravity, body, mount, floor, map or goal fields. The code has no `Observation`, hazard detector, body warning, navigation runtime or route-owner call. Original timestamps are output provenance only. No RGB inference is performed.

## 2. `run_geometry_audit.py`

Pin protocol, source/modules/libraries and actual original input hashes; create the minimal manifest; compile the small harness with the already installed Swift toolchain; verify resolved library paths; execute once under bounds; recheck source/data unchanged. Parse results and check count reconciliation. Independent inverse/metadata calculations are verification diagnostics only, not forward-projection or navigation authority.

The driver should refuse overwrite of prior completed or partial runs, distinguish incomplete artifacts and retain failure logs. It should enforce the fixed eight IDs and a path whitelist, original metadata hash, all finite intrinsic coefficients with positive fx/fy only, matching frame dimensions and exact Float32 representability already observed. Never substitute global K for subsequent frames or quantize raw depth to uint16 millimetres.

## 3. `plot_camera_diagnostics.py`

Read returned camera points plus original arrays/metadata and make separate analytical PNGs using installed Matplotlib Agg/NumPy/Pillow. No custom raycaster or scene renderer is needed. Preserve every original image; copy/reference RGB frame 0 unchanged. Label depth units, confidence categories, camera coordinate axes, pixel-centre-span convention, original relative timestamp and any display clipping.

Proposed compact output set: eight per-frame depth/confidence/admission panels, eight separate camera-point scatter plots, one intrinsics/span/count summary plot, summary JSON/CSV, original-frame reference/copy and manifests. Keep complete numeric counters even if the protocol maintainer later approves a display-only subsample. No cumulative map or mesh.

## Approval checklist

- [ ] Protocol maintainer accepts fixed scope, numeric tolerances, pixel-centre span definition and artifact bounds.
- [ ] Primary-source convention note reviewed; no unresolved sign or axial-depth assumption remains.
- [ ] New harness input/output contract reviewed before execution.
- [ ] Dataset license/attribution and no-raw-assets publication boundary retained.
- [ ] Independent-label limitations retained; no obstacle/miss/clearance/navigation claim planned.

This document authorizes no execution by itself. No proposed files above have been implemented as part of this protocol-only task.
