# RTAB-Map same-input benchmark: completed research comparison

2026-10-28. Official RTAB-Map 0.24.2 (`8cd2f81a735722402d1e220147c4e83a1a746eaf`) was built and actually run through `Rtabmap::process`, not replaced by a custom mapper. Both fixed-odometry and graph-optimization arms accepted all 265 frozen Koivu training frames. The 29 held-out views were excluded from reconstruction. Original calibrated RGB/depth bytes were hash-verified. No FARO data entered either mapper.

## Common geometry measurements

All three outputs were evaluated with the same deterministic 4 cm actual-point sampling, unchanged phone-to-FARO registration applied once, and released VTK nearest-triangle/nearest-point queries. Open3D output is its previously frozen mesh-derived point sample; RTAB outputs are depth-derived clouds, not inferred surfaces. Counts and coverage differences remain important despite common spatial sampling.

| Metric | Open3D TSDF | RTAB fixed poses | RTAB graph poses |
|---|---:|---:|---:|
| Raw output points | 1,000,000 | 693,573 | 813,869 |
| Common 4 cm sampled points | 231,472 | 497,307 | 588,726 |
| Output-to-FARO median distance | 4.26 cm | 6.64 cm | 10.36 cm |
| Output-to-FARO mean distance | 10.73 cm | 12.84 cm | 15.74 cm |
| Output-to-FARO 95th percentile | 49.71 cm | 48.28 cm | 49.38 cm |
| Output points within 5 cm of FARO | 54.94% | 41.12% | 26.88% |
| Held-out visible reference samples within 5 cm of output | 81.53% | 94.92% | 78.07% |
| Reference-to-output median distance | 2.71 cm | 2.19 cm | 2.78 cm |
| Reference-to-output 95th percentile | 8.31 cm | 5.03 cm | 10.10 cm |

All scheduled point queries were valid. The reverse comparison used 127,774 spatially sampled reference points derived from 1,194,544 finite held-out FARO ray hits. Another 141,341 original reference rays were missing; they were excluded from that point set, not treated as free space. Forward distance is unsigned distance to a reference triangle; it does not distinguish physical objects, changed furniture, registration mismatch or sensor artifacts.

**Interpretation:** no overall winner is established. The fixed RTAB cloud retains more reference-visible geometry but also contains more distant/extra points than Open3D. In this frozen configuration, RTAB graph correction worsened both forward and reverse metrics relative to fixed poses. It produced 45 loop-closure event frames; median translation change was 14.26 cm, maximum 41.05 cm. These changes are not evidence of better localization. The first pose remained in the original gauge within 1.74e-7, so no post-hoc alignment was used.

These percentages are **not navigation accuracy**, obstacle recall, collision avoidance, floor-support certification or child safety. No pathing/movement trial was performed in this stage. A cloud cannot be substituted for an observed surface in the earlier first-hit ray evaluator. Old ray scores and these point scores must not be ranked together.

## Real failures retained and repaired

1. Initial full mapper exports failed because our adapter omitted native valid indices when voxelizing non-dense organized clouds. Both native mapper runs and their databases were preserved. Released API inspection identified the exact precondition; an export-only helper passed native indices unchanged and re-exported the saved databases. No mapper replay, pose adjustment, threshold change or reference-based repair occurred. See `EXPORT_REPAIR.md` and original exit-2 receipts.
2. Initial common evaluator crashed in VTK's PLY reader on PCL's zero-face/camera-element point-cloud format. The failed protocol is archived. Only point decoding was replaced with the already pinned released Open3D reader, in sequential subprocesses before FARO allocation. A tiny zero-face format fixture, exact asymmetric coordinates, native point counts and hashes passed. No geometry filtering or surface completion was added.
3. The original eight native fixtures passed; a strengthened ninth reproduces the old omitted-index empty result and verifies all 14 expected finite points, native indices, inclusive 4 m boundary and optical/local transform cancellation. Independent source/input review passed 4,777 assertions, including 530 image checks and 795 asymmetric coordinate checks.

## Scope and remaining work

Native `Grid/RayTracing=false`, `Grid/3D=true`, 4 cm cells, maximum range 4 m. No OctoMap was compiled. Local ground/obstacle grids exist, but empty-cell count is zero: this does not test contradictory free-evidence clearing. Default ground segmentation remains an algorithm output, not verified floor support. Native RTAB includes exactly 4 m, whereas the Open3D baseline excludes it; 50,544 training pixel observations fall on that boundary. This difference was frozen and disclosed before scoring.

The next relevant separate arm is released RTAB + OctoMap ray clearing, with frozen hit/miss/unknown policies and native synthetic contradiction fixtures before real-data replay. It remains untested here. No custom floor flattening, obstacle-threshold reduction, unknown-space carving or Poisson completion was used.

The common evaluator finished in 194.4 s with 2,269,650,944 bytes peak sampled process-group RSS, one CPU, no resource stop. The stage stayed below its 3 GiB RSS / 6 GiB temporary-disk / 1.5 GiB download limits. Research build includes bundled TORO under CC BY-NC-SA; this is not approval for redistribution in the app. Full metrics, pins, failed runs and resource logs accompany this report.
