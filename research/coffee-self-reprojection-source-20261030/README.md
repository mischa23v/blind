# Fixed self-view versus fused-map reprojection — prepared, not executed

## Why this test
The held-out observation-only results show disagreement between returned occupied voxel boxes and held-out endpoints. They do not isolate hardware failure. Before changing mapping thresholds, compare each original construction view with its own map and the original fused map using the same released OctoMap code.

## Exact fixed cases
Six cases, always frames **290, 357, 391** in that order:

1. Reconstruct the original combined three-scan map with original supplied poses, 0 < axial depth < 4 m, full accepted rasters, original float arithmetic and native insertion order. Require world-coordinate hashes, insertion counters, defaults/state and canonical map payload equal the original baseline. Query each of the three construction views.
2. Close that map. Build each individual view's map serially, using **local scan ID 0**, because the native adapter requires sequential IDs. The original image/pose/frame identity remains explicit; no pose or point is changed. Query that same construction view.
3. For each single-view map, query the combined-map hit centers from all three views. Save an eight-bin bitmask partition: bits 0/1/2 mean singleton maps from frame 290/357/391 classify the fused hit key as occupied. Also report self-view support, other-view-only support and no singleton occupied support. For each singleton map, keep known-occupied, known-not-occupied and unknown counts separately, plus a known-state bitmask; unknown is never called free. This is actual independent per-map keyed occupancy, not scan identity inferred from aggregated counters. It is not object identity, surface correctness, visibility or proof of occlusion.

One map is resident at a time. No archive extraction or held-out depth is needed. Only the original three depth images are opened. Prior held-out evidence is unchanged.

## Ray and metric contract
- Keep fixed stride-8 image grid, full 11,625-position candidate denominator for every view, original valid-depth rule and no selected/cropped region.
- Query both conservative and observation-only ABIs for every valid grid ray. All unknown/error/range statuses remain separate. Only observation-only status9 is scored here; it never becomes known-prefix clearance.
- Score every observed hit with signed and absolute voxel-box-entry axial, voxel-center axial and entry-along-ray residuals. Same exact inverse transform, native Float32 projection convention, linear quantiles and no clipping as the prior reviewed driver.
- Entry is the upstream ray intersection with the resolution-sized **5 cm voxel box**, not a physical surface; map leaf-size distributions are also recorded separately. No claim that every exported leaf has finest-level size.
- Preserve hit-conflict counts and byte-exact before/after map snapshots for all queries. Preserve per-hit derived pixel index, returned voxel center and residual arrays so paired outputs can be audited without source images. Save attribution masks in the same hit order as each fused-case array.
- Full candidate/valid/excluded counts remain visible. Residual distributions cover hits only; missing hits are not zero error. Pixel samples may be correlated/upscaled and do not constitute independent trials.

A self-map can still yield a nearer voxel than the original depth because voxel boxes combine observations near edges. A fusion change can reflect pose drift, competing surfaces, visibility or occupancy evidence, not necessarily bad depth. No source adjusts thresholds or deletes inconvenient evidence.

## Admission and limits
The already built observation adapter and actual **48 passed controls** are bound by hashes. No new native source, build, install or download. One CPU; 120 CPU seconds; 178-second timeout plus 2-second kill grace; 512 MiB address-space limit; 32 MiB per file; 256-ray batches and original native 8 m range cap. No automatic limit enlargement. Outputs are new-only; preserve failed attempts.

After independent review and publication, from `blind/`:

```sh
bash research/coffee-self-reprojection-source-20261030/run_bounded.sh /opt/codex/runtimes/codex-primary-runtime/dependencies/python/bin/python3.12 research/coffee-octomap-observation-rays-source-20261030/build-observation-01/libblind_octomap.so 82afb6c94b3e0234ee371395b6f7ba17ae159987293ac357463bde43605ebc26 ../coffee-observation-ray-controls-attempt-001/RESULT.json 51624c3c11456971709fd41ef6bd2b63f303e7f0df1b58bec5403d73d607f3e4 ../coffee-self-reprojection-attempt-001
```

Source-only tests: 12 metric tests and 4 support-partition tests. These do not open rasters or load native code. This is diagnostic consistency, never sensor accuracy, path acceptance or human/child safety validation.
