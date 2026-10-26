# Direct author-configured Koivu RGB-D fusion — proposed frozen baseline

## Scope and reuse

Use the actual installed Open3D CPU0.19.0 ScalableTSDFVolume and the observed-iPhone integration logic from DN-Splatter commit97588b4290128ce7ba6fdbfaac3020b42b17de4c, `dn_splatter/data/mushroom_utils/pointcloud_utils.py`, function `generate_iPhone_pointcloud_within_sequence` (Apache-2.0). This is **not** the original MuSHRoom repository's neural rendered-depth exporter. The author lock used Open3D0.18/Python3.10; current0.19/Python3.12 is a disclosed substitution. Six relevant0.18→0.19 core source files differ only in copyright year, not function bodies; this is not whole-binary equivalence.

The official five-frame integration smoke has already completed on the installed engine. Koivu is a separate real-iPhone-derived, processed-depth, supplied-pose offline reconstruction. It does not estimate live pose, confidence, gravity, body extrinsics, current free space or navigation safety.

## Inputs and exact algorithm

Use all265 author-training frames, in the original294-frame pose-list order, excluding the29 original `test.txt` IDs. No input selected using Faro, routes, confidence yield or reconstruction outcome. All original pose matrices and per-frame K remain unchanged. Existing verified uint16-millimetre depth PNGs are reused; acquire only the matching265 RGB files and348-byte split from the already verified local archive after the bounded member-size inventory. Pin every input before fusion.

Preserve the author's exact parameters: voxel length0.04m, SDF truncation0.2m, colorRGB8, RGBD depth scale1000 and depth cutoff4m. For each frame, construct actual Open3D PinholeCameraIntrinsic(W,H,fl_x,fl_y,cx,cy), convert C2W_OpenGL with right multiplication by diag(1,-1,-1,1), and pass its inverse to volume.integrate. Do not silently shift cx/cy by half a pixel: reproduce the author API convention as released and disclose the difference from the earlier half-pixel ray evaluator. Tiny analytic pose-conversion fixtures must verify the adapter before recorded integration.

The thin loader uses Open3D's PNG/JPEG readers instead of importing the author's OpenCV/Torch training stack. Require actual image/depth dimensions to match supplied W/H, so the author's resize would be a no-op; fail on mismatch rather than resample. This loader change and any RGB decoder difference are explicit. Do not reconstruct a native ARKit stream from these upscaled/cropped processed exports. Pixel counts describe exported raster samples, not independent LiDAR measurements; original confidence/tracking remain unavailable.

Preserve the author's cumulative point-cloud extraction/sampling algorithm, including its evolving min(samples_per_frame,len(cloud)) behavior, but freeze Python and NumPy random seeds to0 (the author did not publish a seed). Save this author-style initialization cloud separately. Also call unmodified Open3D extract_triangle_mesh once on the final volume and save its unfiltered mesh. That mesh export is a disclosed extension; no smoothing, decimation, component removal, hole filling, floor fitting or bespoke occupancy/traversability rules.

## Results and held-out separation

Report all265 frame statuses, original raster dimensions, zero pixels, actual native converted positive-depth counts, source-depth range, clipped pixels, final vertices/triangles/point count, finite bounds, times and sampled RSS. Preserve intermediate source/input hashes and the final mesh before any reference scoring or route selection. A top-down analytical mesh-height view may be generated from the frozen mesh, clearly labeled geometry rather than clearance.

The29 held-out RGB-D frames are not integrated. A later fixed held-out reprojection and/or independent fixed-registration Faro comparison must be a separate evaluator, with every miss/unknown retained and no fitting/tuning. No evaluator or Faro geometry is loaded by this fusion worker. Missing triangles or smooth surfaces are not free-space evidence; the legacy Python API's mesh output alone is not a complete TSDF weight/coverage layer. No floor/support/low-toy claim follows from this mesh.

## Proposed bounds and stop condition

One serial worker with CPU affinity fixed to one available logical CPU; OMP/BLAS thread environments1. Proposed600CPU/900wall seconds,2GiB sampled process-tree RSS,128MiB reconstruction outputs,900MiB total stage added disk and768MiB reserve. Original wheel archives, sample, failures, inputs and outputs are retained. Stop on resource/input/shape mismatch; do not rerun a favorable subset or change parameters after results. Successful completion means all265 frames processed and finite nonempty native outputs saved, **not** acceptable reconstruction accuracy or an A→B/game pass.
