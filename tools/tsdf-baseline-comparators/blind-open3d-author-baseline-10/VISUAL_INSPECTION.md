# Frozen Koivu TSDF mesh: analytical inspection

## What was inspected

Both plots are derived from the unchanged mesh `koivu/unfiltered-tsdf-mesh.ply`, SHA-256 `5a75ebce93a3c65928344ce486223aa17a01a2c196982fc97edff8c41dd56e2e`. It has 242,293 vertices and 461,256 triangles. The mesh was produced by Open3D CPU 0.19 using DN-Splatter's direct iPhone initialization settings, with 265 supplied-pose training frames. The 29 author test frames were excluded.

- `mesh-inspection/all-vertices-projections.png`: all vertices in three orthographic coordinate projections and a height histogram. Overlaid ceiling, lower surfaces and walls obscure each other in this plot. The colored patch pattern is not an occupancy classification.
- `height-slices/fixed-height-slices.png`: all vertices assigned exactly once to seven fixed half-open, absolute exported-Z display bands: [-1.5, -1), [-1, -0.5), [-0.5, 0), [0, 0.5), [0.5, 1), [1, 1.5), [1.5, 2) metres. Counts are 59,796; 52,084; 26,948; 20,973; 21,989; 59,084; 1,419. These bands are only visualization bins, not floor or obstacle thresholds.

## Observation and limits

The slices visually show a coherent room-scale boundary and broad upper and lower surfaces, with a long central lower-height surface and smaller interior structures. This is a substantial improvement in interpretability over the earlier custom all-hit-union model. No object identity or geometric accuracy is established by this inspection.

The wide lower-height display band does not isolate a floor and does not prove continuity beneath furniture. White pixels mean no vertex was plotted in that projected band; they do not mean observed-free space. Surface gaps, smoothed details, near-floor protrusions and omitted thin objects remain unresolved. The retained legacy mesh does not contain a complete TSDF weight/free-coverage layer. No floor plane was fitted, no geometry was filtered, and no body, route, collision or FARO evaluation was performed by the plotting scripts.

The VTK 9.3.1 PLY reader uses Float32 coordinates for these display-only readbacks; the archived source PLY and its hash remain unchanged. This rounding is not substituted into a reconstruction result or safety metric.

The projection plot took 7.91 seconds with 237 MiB peak process RSS; the fixed-slice plot took 1.98 seconds with 178 MiB peak. Both scripts verified the input mesh hash before and after. Their JSON receipts retain source and plot hashes. Fontconfig emitted cache-directory warnings during rendering, but the plot commands completed and the images were visually inspected.

## Provenance

Koivu processed iPhone data: MuSHRoom, official Zenodo record 10230733, CC BY 4.0. Reconstruction logic: `maturk/dn-splatter`, commit `97588b4290128ce7ba6fdbfaac3020b42b17de4c`, `dn_splatter/data/mushroom_utils/pointcloud_utils.py`, function `generate_iPhone_pointcloud_within_sequence`, Apache-2.0. Open3D is MIT licensed. See the frozen protocol and acquisition receipts for exact versions, input hashes, author-versus-run differences and the preserved report-parser failure/recovery.
