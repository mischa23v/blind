# Preregistered Koivu processed-depth / FARO-reference comparison — proposal 05

**Status: prepared before reference extraction or evaluation. Not an execution approval.** The separately authorized stage-04 operation acquires and inventories one official archive only. After exact member sizes are known, request the minimal reference mesh/alignment and existing phone pose metadata extraction; inspect units/association, independently review the implementation and its convention checks, then seek the single bounded CPU evaluation gate. No navigation episode is proposed.

## Purpose and evidence level

Measure actual exported iPhone room-depth discrepancies against the separately scanned, author-processed FARO reference under the **fixed author registration**. This is not repeated pixel/projection self-consistency and not synthetic phone sensing: measured phone depth is the tested input, while the laser-derived mesh supplies the comparison surface.

The reference is cleaned/manually hole-completed and registered with device-derived reconstruction and global scaling. Therefore report **offline, author-registered processed-depth/reference-surface disagreement**, not an isolated raw sensor error, unadjusted absolute metric accuracy, perfect ground truth or a hazard miss rate. The mesh alone has no verified measured-support/edit mask. Mark that support unknown, never label filled faces measured. No confidence, tracking, original capture time, gravity, body/rig transform or response latency is fabricated. Their absence does not prevent this deliberately narrower processed-depth comparison; it does prevent a production confidence-gated detector/navigation claim.

## Frozen inputs and source association

- Already retained iPhone archive: `koivu_iphone.tar.gz`, 146,575,749 bytes, SHA-256 `68735cfa0758e1288a006c30dc8b95ffb4caa3392bc9c68c0c3ea6c111966518`; original long-capture `transformations.json` and previously selected first 32 RGB/depth pairs.
- Authorized FARO archive: `koivu_mesh_pd.tar.gz`, 455,583,916 bytes, published MD5 `1fc9598ff73fc833b6e4db90af604062`, official open CC BY 4.0 Zenodo record 10222321. Its actual SHA and exact member paths/sizes must be copied from the completed inventory, not guessed here.
- Intended minimal extraction: author cleaned `gt_mesh.ply`, `icp_iphone.json`, and the **239,934-byte** `room_datasets/koivu/iphone/long_capture/transformations_colmap.json` from the existing phone archive. No reference point-cloud extraction is currently authorized. A mesh-only result cannot resolve measured-versus-completed surface provenance.
- Use original pose-entry indices **0, 4, 8, 12, 16, 20, 24, 28**, as already proposed before reference errors existed. Their current original basenames are `frame_00001`, `frame_00005`, `frame_00009`, `frame_00013`, `frame_00017`, `frame_00021`, `frame_00025`, `frame_00029`. Require exact filename matches in the author-associated pose file, with unchanged RGB/depth bytes; never substitute missing entries. These are eight correlated frames from one room, not independent journeys or held-out scenes.
- Preserve original and author-associated pose files separately; report any differences. Koivu's COLMAP reconstruction reportedly failed, so the filename `transformations_colmap.json` is not evidence of successful COLMAP or causal ARKit. Use the file association required by the author evaluator, not an inferred provenance claim.
- Report source/metadata/mesh/alignment/input and binary/tool versions/hashes before and after. No acquisition, extraction or evaluation may overwrite prior receipts.

## Fixed deterministic sampling and complete denominators

Each processed depth image is expected to be 738 columns × 994 rows, unsigned 16-bit with author conversion **0.001 to nominal metres**. Verify actual dimensions, dtype and per-frame intrinsics; mismatch stops the run rather than resizing/interpolating either input.

Sample integer pixel centres `(column,row)` beginning at `(0,0)` every **4** pixels in both axes, without interpolation, random selection, adaptive densification or confidence substitution. For the expected dimensions this is columns 0…736 (185 values) and rows 0…992 (249 values): **46,065 scheduled rays/frame; 368,520 across eight frames**. This is an offline diagnostic schedule, not the production stride-2 admission policy. Unscheduled pixels are explicitly unsampled, not failed measurements.

For every scheduled ray count exactly one category:
1. Positive finite sensor depth and valid positive reference intersection.
2. Sensor depth available, reference no-hit/invalid (reference unknown).
3. Reference valid, sensor zero/nonfinite/invalid.
4. Both unavailable.

Do not coerce missing reference depth to physical zero, remove bad frames, stop after favourable frames, fill holes, or exclude data because its discrepancy is large. Preserve all ray identities and separate failure reasons. Original confidence/tracking/time remain unavailable and unused.

## Author mapping, scale and axial-depth convention gates

Reuse the pinned author association, not a new registration/SLAM algorithm. DN-Splatter revision `97588b4290128ce7ba6fdbfaac3020b42b17de4c`, `render_gt_depth.py`, applies inverse `icp_iphone.json['gt_transformation']` to the FARO mesh and pairs it with `transformations_colmap.json`. The paper's device-derived global scale/RANSAC/ICP is historical upstream processing; **no refit, per-frame translation, ICP, scale optimization or error-minimizing adjustment is permitted here**.

Before evaluation:
- Inspect the actual 4×4 matrix and its finite/invertible affine form, determinant, singular values and similarity/scale structure. Do not assume determinant one or silently rigidize it. Record actual scale and how applying its inverse changes mesh units relative to nominal phone metres. If nonuniform/sheared or otherwise inconsistent with documented association, stop for review.
- Inspect raw and transformed mesh bounds, vertex/triangle counts and finite coordinates; do not auto-fill holes, simplify or repair geometry. Do not apply the separate reconstruction converter's unit-box normalization.
- Preserve each frame's actual intrinsics as exported Double values; do not apply the Record3D Float32/resolution contract to this different processed export or reuse one frame's K.
- Camera poses are OpenGL camera-to-world; forward is negative camera Z and camera Y is up. The author's equivalent OpenCV conversion right-multiplies C2W by `diag(1,-1,-1,1)` before inversion. Do not flip based on `camera_model: OPENCV`, which describes the intrinsic model, not pose axes.
- Query the first surface along each positive camera ray using **installed VTK CPU geometry primitives**, not a new raycaster or the author's hardcoded-CUDA renderer. Preserve original mesh-face handling; document whether both sides are intersected. Reference depth is **axial camera distance −Z**, not Euclidean ray length. Keep double precision and no millimetre quantization on the newly queried reference.
- Choose each ray's far endpoint from the transformed mesh bounds and camera origin with a fixed geometric margin, not from the measured sensor depth, so an erroneous sensor range cannot limit the reference query. Report the bound. No-hit remains unknown.

The existing shared `DepthProjection.cameraPoint` may generate camera-ray directions directly from Double intrinsics; do not call the native confidence policy, construct a live `Observation`, or pass the missing tracking state as true. Implementation must retain the explicitly offline pose authority boundary.

## Required implementation convention checks before recorded metrics

Independent source review and fixed analytic geometry checks must establish: off-centre/asymmetric K; integer pixel convention; camera Y/Z signs; camera-to-world versus inverse; a translated/rotated known plane; first versus farther surface; Euclidean length versus axial depth off-axis; and a known similarity-scale transform. Use existing VTK primitives and shared geometry, with exact hand-computed expected intersections. Test no-hit as missing rather than zero. These are implementation checks, not extra scene successes or physical accuracy evidence.

A visual overlay may inspect whether the author association is grossly wrong, but cannot authorize fitting it to the tested depth. Preserve any misalignment/disagreement; stop if the source association itself is unresolved. Record all convention failures before any later correction and keep a distinct source cut.

## Metrics, deterministic edge categories and no hidden exclusions

For category 1, compute signed axial discrepancy `sensor_z − reference_z`, absolute discrepancy, per-frame signed mean/median, MAE, median absolute error, and 90th/95th percentiles (explicitly use linear quantile interpolation). Positive discrepancy means exported depth is farther than the registered reference surface; it is not by itself a proven collision hazard. The global author registration can absorb scale error, so label units and adjustment explicitly.

Report all paired-ray metrics and counts per frame, then aggregate sums and pooled quantiles **without calling correlated rays independent trials**. Also report reference-depth bins: `(0,0.15)`, `[0.15,1)`, `[1,2)`, `[2,3)`, `[3,5]`, and `(5,∞)` nominal metres. No native 5 m cut or confidence-2 gate is applied; out-of-range bins remain visible.

For deterministic edge reporting on the stride-4 sampled grid, classify each reference-valid ray in this precedence order:
1. **Raster boundary:** any of its four cardinal sample neighbours lies outside the scheduled grid.
2. **Reference support boundary:** at least one in-grid cardinal neighbour has no valid reference depth.
3. Otherwise, use maximum absolute reference axial-depth difference to those four neighbours, with fixed bins **≤0.02 m**, **>0.02 to ≤0.10 m**, **>0.10 m**.

These are reporting categories only, not detector thresholds, error acceptance criteria, measured object labels or exclusions. Every paired ray remains in the all-ray metric, and every category has its denominator. Keep per-frame, depth-bin and edge-bin results even when poor. Do not adapt thresholds after viewing results. Reference ray-support categories do not identify manually repaired mesh faces; that provenance remains unknown.

Report image-tile counts for scheduled/paired/sensor-only/reference-only/neither rays; tiles are image regions, not body clearance zones. Any future measured-support/edit mask must have an independent source and be frozen before using it, with its excluded denominator reported separately.

## Resource gate and stop conditions

Exact mesh sizes and counts are not yet available. Do not claim a numerical evaluation resource envelope has been verified. After inventory and authorized extraction, propose one concrete CPU/RSS/wall/output budget using the actual mesh size and installed VTK capability, with no GPU/package install. Preserve at least 768 MiB free. Any budget/geometry/association failure is a terminal diagnostic result, not permission to reduce the denominator silently or weaken the sensor policy.

## What this can and cannot establish

This first room test can expose observed exported-depth discrepancies, missing sensor returns, absent reference support and edge behaviour in a real furnished room under the author's fixed registration. A cleaned/hole-completed reference and device-derived alignment prevent treating residuals as an absolute raw-LiDAR accuracy bound. Missing source confidence prevents evaluating the native confidence gate, but is explicitly not a reason to abandon the scoped processed-depth/reference test.

An actual obstacle-miss or clearance test still needs independently labelled hazard surfaces/objects and visibility, measured body/foot/head geometry and trajectory, phone/belt/gimbal extrinsics, synchronized timing and warning deadlines. No body, phone-only or final multisensor feasibility verdict follows from this comparison. Phone is the starting platform; the intended belt/additional sensors must later be compared against the same measured requirements. No map/route/controller or LLM geometry authority is introduced here.

Primary references and exact acquisition/author-code pins are in stage 04 `PAIRED_REFERENCE_FEASIBILITY.md` and `SOURCE_EVIDENCE.json`.
