# Frozen common 4 cm cloud / unchanged FARO comparison

**Prepared, not executed.** This is a geometry-output comparison, not a navigation test. No reconstruction, triangle queries, or dataset scoring was performed while preparing it. Syntax compilation alone was run. Root must release the single CPU and authorize execution; never compete with the RTAB mapper. Target completion before 18:29 UTC on 2026-10-28; otherwise preserve as the next stage rather than relax checks.

## Inputs and coordinate contract

- Open3D: existing `fresh-run/fusion/author-style-initialization-cloud.ply`, 1,000,000 surface samples from its native TSDF mesh. This is not a new mesh or Poisson reconstruction. Its already-published mesh remains the source of the previous first-hit metric, a separate metric.
- RTAB: native `fresh-run/fixed/cloud.ply` and `fresh-run/graph/cloud.ply`, XYZRGB PCL output. The mapper transforms native points by `B * nodePose`; native SensorData cloud conversion has already applied the camera's optical local transform. Exports are in the original phone/OpenGL world, not RTAB robot axes. Fixed and graph are separate named arms; graph uses optimized poses, without FARO fitting.
- RTAB export has already undergone 4 cm per-frame and global native PCL centroid voxelization. Open3D cloud is surface-sampled. Applying a common final sampling rule does **not** erase these upstream representation differences; this is a common reporting representation, not an identical reconstruction estimator.
- Existing author `icp_iphone.json[gt_transformation]` maps phone world to FARO. Apply it to each output point exactly once. FARO mesh is left unchanged. No ICP, scale fit, alignment correction, cleaning, triangle replacement, or truth masking is permitted. The author similarity includes scale 1.0207908442387768. All reported distances and final voxel sizes are in FARO metric coordinates.
- All exact cloud hashes are pinned only after completed exports, in a separate launch manifest binding the already-frozen protocol SHA. No thresholds may change based on scores. Existing source/fusion/evaluation hashes and all 29 FARO arrays are pinned in FROZEN.json.

## Fixed spatial sampling

Register first. Use a 4 cm cubic grid with origin exactly FARO (0,0,0), half-open cells indexed by floor(x / .04), including negative coordinates. Each occupied cell contributes one **actual input point**, the one closest to its cell centre. Break exact distance ties lexicographically by x, y, z. Sort by cell key. Do not use a new averaged centroid or move a point to the voxel centre. Reject any nonfinite input or empty cloud; never silently filter failures. One point per occupied cell gets one vote; no point-density weighting. Report raw and sampled counts and bounds externally if desired. Surface orientation creates unavoidable voxel-sampling weighting; this is not area-uniform error.

## Forward metric (every retained output point)

Use released VTK `vtkStaticCellLocator.FindClosestPoint` on unchanged FARO triangles, reusing the reviewed ReferenceSurface construction (one CPU, 16 cells/node, 2,097,152 maximum buckets). Record exact unsigned Euclidean nearest-triangle distance and reference cell ID. Validate returned squared distance against returned closest coordinate. No distance threshold excludes points. Report scheduled, valid, invalid, mean, median, P95, P99, maximum, and counts/fractions of scheduled within 2, 5, 10, 20, 50 cm. An invalid native query aborts; it is not dropped from the denominator.

This measures agreement of the **returned output geometry**, not missing geometry, collision correctness, false-clear rate, obstacle recall, or observed free space. A sparse or selectively missing output can score well forward; never choose a winner from forward alone. A phantom face near a different real surface, wrong occlusion, or an output behind the correct foreground can also have a small nearest-surface distance. This metric does not replace first-hit/view-consistency diagnostics or collision tests; do not rank “best” by mean distance alone.

## Reverse coverage diagnostic (common and explicitly limited)

Reuse **all finite first hits in the existing 29 held-out FARO evaluation arrays**. Recover the original ray point using that frame's per-frame intrinsics, integer-pixel convention and axial depth, then the original OpenGL C2W, then the same author registration once. Apply the identical 4 cm FARO grid / actual-point representative rule. This fixed reference sample set is shared by every arm; it is not restricted to rays where any method hit, nor to the method's output bounding box.

Record original scheduled rays, finite hits, and missing reference rays. Missing reference rays are excluded only because they supply no point; **they are not free-space evidence**. Find each retained reference sample's nearest sampled output point using released VTK `vtkStaticPointLocator`. Report the same thresholds and summaries with all sampled reference points in the denominator.

Reverse results are **29-view visible-reference-to-output-point coverage gaps**, not full-mesh recall or exact distance to an output surface. Point sampling adds a discretization floor; a reverse distance can be nonzero on an otherwise correct continuous surface. No synthetic mesh is constructed for RTAB. This diagnostic exposes missing visible geometry but does not prove why it is missing. FARO has no measured-versus-completed mask and no per-point uncertainty; reconstructed reference holes/occlusion and possible scene changes remain confounds. There is no measured physical false-clear/false-block rate from this experiment.

## Fixtures, provenance and resource gate

Before recorded queries, execute bounded analytic fixtures: deterministic negative-coordinate voxel handling, input-order invariance, known plane distances, explicit similarity once, nearest-output-point distances. Fixtures have not yet been run. Verify frozen hashes before and after; pin launch manifest plus exact exports before running. Runtime records native VTK version/backend, CPU affinity and array hashes. Existing 265/29 split and per-frame intrinsics were independently reviewed elsewhere; no re-use of held-out frames in fusion is permitted. No image or semantic model is involved in this metric.

Run under an external process-tree RSS supervisor: **one CPU, maximum 3 GiB sampled RSS, maximum 12 minutes, no concurrent RTAB reconstruction**. Existing FARO locator peak was approximately 2.13 GB, but that does not guarantee this program's peak. Abort on budget overrun, missing inputs, triangle query errors or failed fixtures. No smaller point sample, altered voxel size, changed metric, or denominator reduction is allowed as a recovery inside this run. Keep partial output explicitly incomplete. If less than enough time remains before the stated deadline, freeze and defer rather than rush.

## Invocation after authorization

Use the same Python / VTK environment as the already-executed common FARO evaluator. `make_launch.py --out <new-launch.json>` hashes completed outputs and refuses overwrite; supply `--labels open3d,fixed` only if graph export is not complete, and disclose graph pending rather than omit silently. `compare.py --inputs <launch.json> --out <fresh-output-dir> --expected-freeze <SHA256-of-FROZEN.json>` must be wrapped in the existing resource supervisor. Root alone publishes. The protocol is frozen before any RTAB geometry scores exist; launch manifests pin late-arriving data, not protocol choices.
