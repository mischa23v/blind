# Preregistered Koivu processed-depth / FARO-reference comparison — stage 06 performance retry

**History: the scientific protocol below was preregistered before reference extraction/evaluation. Extraction and the failed stage 05 attempt are now complete. The stage 06 addendum defines the separately authorized single performance retry; execution follows frozen source review and analytic conventions.** The separately authorized stage-04 operation acquires and inventories one official archive only. After exact member sizes are known, request the minimal reference mesh/alignment and existing phone pose metadata extraction; inspect units/association, independently review the implementation and its convention checks, then seek the single bounded CPU evaluation gate. No navigation episode is proposed.

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

Select stored array addresses `(column,row)` beginning at `(0,0)` every **4** pixels in both axes, without interpolation, random selection, adaptive densification or confidence substitution. For the expected dimensions this is columns 0…736 (185 values) and rows 0…992 (249 values): **46,065 scheduled rays/frame; 368,520 across eight frames**. The source-backed author-renderer screen ray for each selected address uses **u=column+0.5, v=row+0.5**, with unchanged per-frame K. This differs from the raw Record3D/native integer-index example and is not selected by observed errors. This is an offline diagnostic schedule, not the production stride-2 admission policy. Unscheduled pixels are explicitly unsampled, not failed measurements.

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
- Validate each C2W camera as finite, affine and rigid (bottom row within 1e-10 of [0,0,0,1], rotation orthogonality and determinant-one residuals each ≤1e-5); do not silently orthogonalize malformed cameras. Inspect all distortion fields and documented corrected/undistorted export provenance. Preserve the author's pinhole model explicitly; do not invent a calibrated distortion correction. Any nonzero distortion or unresolved association requires review before metrics.
- Preserve each frame's actual intrinsics as exported Double values; do not apply the Record3D Float32/resolution contract to this different processed export or reuse one frame's K.
- Camera poses are OpenGL camera-to-world; forward is negative camera Z and camera Y is up. The author's equivalent OpenCV conversion right-multiplies C2W by `diag(1,-1,-1,1)` before inversion. Do not flip based on `camera_model: OPENCV`, which describes the intrinsic model, not pose axes.
- Query the first surface along each positive camera ray using **installed VTK CPU geometry primitives**, not a new raycaster or the author's hardcoded-CUDA renderer. Preserve original mesh-face handling; document whether both sides are intersected. Reference depth is **axial camera distance −Z**, not Euclidean ray length. Keep double precision and no millimetre quantization on the newly queried reference.
- Choose each ray's far endpoint from the transformed mesh bounds and camera origin with a fixed geometric margin, not from the measured sensor depth, so an erroneous sensor range cannot limit the reference query. Report the bound. No-hit remains unknown.

The existing shared `DepthProjection.cameraPoint` may generate camera-ray directions directly from Double intrinsics; do not call the native confidence policy, construct a live `Observation`, or pass the missing tracking state as true. Implementation must retain the explicitly offline pose authority boundary.

## Required implementation convention checks before recorded metrics

Independent source review and fixed analytic geometry checks must establish: off-centre/asymmetric K; explicit **half-pixel screen-centre** golden (e.g. fx=fy=100,cx=50,cy=40,d=2,address60,45 → camera point(0.21,-0.11,-2)); camera Y/Z signs; camera-to-world versus inverse; a translated/rotated known plane; first versus farther surface; Euclidean length versus axial depth off-axis; and a known similarity-scale transform. Use existing VTK primitives and shared geometry, with exact hand-computed expected intersections. Test no-hit as missing rather than zero. These are implementation checks, not extra scene successes or physical accuracy evidence.

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

Pixel-centre convention evidence: pinned DN-Splatter requires Nerfstudio 1.1.3; [its cameras.py](https://github.com/nerfstudio-project/nerfstudio/blob/9b3cbc79bf239eb3c69e7c288632aab02c4f0bb1/nerfstudio/cameras/cameras.py#L292-L317) adds default pixel_offset 0.5 to array indices. [PyTorch3D rasterizer](https://github.com/facebookresearch/pytorch3d/blob/f34104cf6ebefacd7b7e07955ee7aaa823e616ac/pytorch3d/renderer/mesh/rasterize_meshes.py#L397-L400) and [screen-camera mapping](https://github.com/facebookresearch/pytorch3d/blob/f34104cf6ebefacd7b7e07955ee7aaa823e616ac/pytorch3d/renderer/cameras.py#L1204-L1223) independently support the half-pixel screen sample. The exact historical PyTorch3D runtime used by dataset authors is not attested; this is source-backed reproducibility of the inspected mapping, not a historical bit-identical renderer claim. The pre-review integer-centre proposal is preserved separately; no reference errors were computed under it.

Primary references and exact acquisition/author-code pins are in stage 04 `PAIRED_REFERENCE_FEASIBILITY.md` and `SOURCE_EVIDENCE.json`.

## Frozen implementation/resource addendum before execution

- Installed VTK **9.3.1**, **vtkStaticCellLocator** first-hit overload with a reused `vtkGenericCell`. `BuildLocator()` is explicit, then positive built divisions are checked. Automatic divisions, number of cells per node **16**, maximum buckets **2,097,152**, intersection tolerance **1e-7 in original FARO coordinate units**. Triangle tests are two-sided and the first-hit implementation retains the minimum segment parameter. Source: [VTK9.3.1 StaticCellLocator](https://github.com/Kitware/VTK/blob/v9.3.1/Common/DataModel/vtkStaticCellLocator.cxx#L1135-L1234). It retains an approximately 2.23 MB visited bitmap per query for this mesh (~819 GB cumulative writes across the fixed schedule if every ray enters the root bounds), **not 819 GB RSS**. This is a disclosed performance cost, not a measured improvement. No PCA-oriented node construction is used.
- Keep one original reference mesh. Transform camera origins/rays by **A×C**, where A is the fixed phone-to-FARO author registration and C is the OpenGL camera-to-phone-export pose. This is mathematically equivalent to applying A inverse to the mesh. Analytic similarity/rotation/translation fixtures must demonstrate equivalence before recorded evaluation; no actual transformed duplicate mesh is created.
- For each camera, the far endpoint distance is **maximum Euclidean distance from the transformed camera origin to the eight original mesh-bounds corners, plus 1.0 FARO coordinate unit**. Normalize each transformed direction only to place this endpoint. Convert the returned hit back through inverse(A×C) to axial camera depth; independently cross-check axial depth against segment parameter × far distance / norm(transformed unit-axial ray), tolerance 1e-6 nominal metre. This bound does not depend on the tested phone depth.
- Preserve exact vertex/face counts; no simplification, hole filling, scaling fit or scene edit. The built-in PLY reader's actual coordinate scalar type is reported (original PLY coordinates are Float64); any reader precision conversion must be disclosed rather than treated as exact original-coordinate preservation. Unused point/cell normal/colour attributes may be released to reduce memory without changing vertex positions or topology. Source bytes remain unchanged.
- Image tiles are **6 rows ×8 columns** using `tile_row=floor(row*6/994)` and `tile_col=floor(column*8/738)` on the fixed scheduled addresses. Every scheduled ray belongs to exactly one tile. This is image-domain coverage, not body zones.
- Empty statistical bins return count 0 and **null**, not zero error. Computation/VTK exceptions, invalid hit parameters and nonpositive/contradictory hit depths fail the run explicitly; they are never converted into benign reference-no-hit counts.
- Conventional analytic fixtures: **30 CPU /45 wall seconds**. Single recorded evaluation: **1800 CPU /2700 wall seconds**, **3 GiB sampled process-tree RSS**, **64 MiB new outputs**, at least **768 MiB disk reserve**. Use one serial VTK process with sequential backend; no GPU or installs. The watchdog checks live plus waited descendant CPU and tree RSS; these are sampled Linux limits, not a hard cgroup. Failures/partial output remain preserved; no favourable-subset result substitutes for the fixed denominator.
- Preserve each scheduled ray in compressed derived arrays: row/column, original processed sensor axial value, queried reference axial value, availability category, edge category and reference cell index. These are diagnostics, not synthetic sensor data. Per-frame results are written before moving to the next fixed frame, so a later budget failure cannot erase earlier bad results, but completion claims require all 368,520 scheduled rays and all 8 fixed frames.


## Separate performance retry provenance

Stage 05 is frozen as a failed evaluator attempt: 600.10 sampled CPU seconds /587.28 wall seconds, ~1.34 GiB peak sampled tree RSS, no completed frame metrics. Its mesh validation succeeded, but the original progress trace cannot distinguish continued OBB construction from first-frame queries. All 22 pinned source/input files separately rehashed unchanged after the failure. This is not a phone-accuracy or navigation failure.

Stage 06 changes only the installed acceleration backend and progress instrumentation; fixed frames/rays, transforms, sampling, sensor inputs, metric bins, no-refit policy remain the same. The user requested relief from the earlier self-imposed compute cap; the maintainer authorized **1800 CPU /2700 wall seconds** for this one offline retry, while RSS/output/disk bounds remain unchanged. This is an offline evaluation budget, not a phone-runtime target. It adds an unsorted plane order 2,4,1 m nearest-hit fixture: installed StaticCellLocator returns the true nearest 1 m surface. The same tiny local diagnostic found CellTree first-hit returning 2 m for that ordering; this specific tested result is retained, not generalized into an unmeasured upstream claim. All prior five analytic fixtures are retained, giving six numerical convention fixtures, not six real scenes.

Live append-only resource heartbeat every approximately 2 s reports elapsed wall, sampled process-tree CPU/current/peak RSS, output/free bytes. Child logs explicitly timestamp mesh load/validation, locator construction start/completion, query start/completion and every 4,096-ray checkpoint, then each frame's completed metrics. This is instrumentation only; no data selection depends on progress or errors. No additional recorded rerun beyond this single maintainer-authorized performance retry is implied.

Execution-environment receipt records actual Linux kernel/architecture, reported CPU model, logical CPU affinity count, memory snapshot, installed VTK version and sequential backend. CPU quota is not inferred from affinity. This is an offline CPU evaluation; no iPhone/GPU runtime or cross-device performance guarantee is asserted.
