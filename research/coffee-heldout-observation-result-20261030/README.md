# Coffee room: observation-only held-out voxel agreement

**The adapter ran correctly, but this sparse three-view map does not closely reproduce both held-out views. This is not a measurement of iPhone sensor accuracy, navigation safety, or general room-mapping capability.**

The exact original map was reconstructed from frames 290, 357 and 391; held-out frames remain 232 and 370. Geometry, supplied poses, resolution, thresholds and pixels were unchanged. Official OctoMap rays now also ran in a separate observation-only `ignoreUnknown=true` mode. This can find an occupied voxel beyond unknown space; it cannot certify the path to it.

## Actual results

Residual means predicted voxel-box entry depth minus measured held-out axial depth. Negative values mean the recorded occupied voxel was nearer than the measured endpoint. Values below are centimetres, not percentages of accuracy.

| Metric | Frame 232 | Frame 370 |
|---|---:|---:|
| Fixed grid candidate pixels | 11,625 | 11,625 |
| Valid depth rays | 9,593 | 9,311 |
| Observation-only occupied hits | 2,654 | 7,404 |
| Range exhausted without observed hit | 6,939 | 1,907 |
| Absolute entry residual median | 10.84 cm | 9.34 cm |
| Absolute entry residual p95 | 92.35 cm | 99.25 cm |
| Signed entry residual median | −10.83 cm | −9.26 cm |
| Absolute voxel-center residual median | 10.16 cm | 8.70 cm |
| Signed voxel-center residual median | −10.15 cm | −8.58 cm |
| Hit voxels carrying both hit/free evidence | 0 | 2,204 |

All other observation statuses were zero. Every occupied hit was scored; range-exhausted rays were not assigned zero error and are not evidence of clearance. The residual distributions apply only to returned hits, not to all candidate pixels. The saved JSON also retains signed/absolute distributions and along-ray residuals, full raster/range denominators, and pixel-weighted and distinct-key endpoint coverage. Repeated/interpolated pixels are not independent measurements.

**The original conservative result remains: 18,904 origin-unknown rays and 0 scored residuals.** Both native camera-origin cells remain unknown. Those primary records are preserved verbatim and their counts were reproduced before interpreting the separate observation mode.

Map state, defaults and all canonical arrays were unchanged. Runtime was 3.80 seconds wall, 3.83 seconds CPU; peak RSS 129,740 KiB. The separately built adapter had passed all 48 controls. This audit checked the saved result and its arithmetic/contracts; it did not rerun native code.

## What these numbers do and do not identify

1. **Voxel representation:** rays intersect occupied voxel boxes, not a reconstructed physical surface. A boundary-expanded box can be encountered before the true object. Changing entry to center reduces the reported median only slightly here, so that reporting choice alone does not explain the disagreement. Do not assume all occupied leaves necessarily have the finest size without inspecting their recorded sizes.
2. **Cross-view alignment:** supplied camera poses and their drift can place surfaces in different locations. These rays and held-out depths share the capture's supplied calibration; there is no independent truth reference in this test.
3. **Occlusion and sparse coverage:** the first recorded occupied cell can belong to a different foreground surface than the held-out pixel observes. Conversely, a nearer real surface may be absent from the three-view map. Ignoring unknown cells does not resolve either ambiguity.
4. **Fusion and conflicting evidence:** frame 370 hits 2,204 voxels carrying both hit and free evidence. That is a diagnostic signal, not proof of corruption or permission to delete them. Frame 232 has no such hit conflicts, so that flag alone cannot explain both views.
5. **Capture/depth correspondence:** upscaling, depth edges, registration, pose timing and real scene change remain possible contributors. This result does not isolate any of these or establish that visible RGB shadows caused errors.

No threshold was tuned from these results. No free-space carving, pose correction or deletion of inconvenient rays occurred. There is no route, collision, stair-recall or real-person safety result in this packet.

## Next bounded diagnostic: self-reprojection before hardware conclusions

Use the same released OctoMap insertion and reviewed ray adapter, with no new mapper and no new data selection:

1. Freeze the original three training views 290/357/391, original accepted pixels, fixed stride-8 grid, supplied poses, 5 cm resolution and occupancy defaults.
2. Build one **single-view map at a time** and query its own original camera rays. Record the same conservative and observation-only status partitions, entry/center/along-ray residual distributions and hit/free conflicts. This is a representation/self-consistency baseline, not independent validation.
3. Reconstruct the exact original three-view map and query the same three training views on the same grids. Compare each view's single-view and combined-map results without changing denominators or hiding no-hit cases. Preserve the held-out results above unchanged.
4. Report actual occupied leaf sizes at hit points to distinguish voxel-box extent from surface position; do not infer scan identity from aggregated hit counts. If later attribution is needed, compare separately built per-scan maps rather than inventing scan IDs from counts.
5. Keep one CPU and the existing 120 CPU-second / 180 wall-second / 512 MiB / 32 MiB-file bounds, serial maps and read-only queries. Prepare and review source before execution; stop on bounds rather than enlarging them.

If self-view agreement is poor, investigate projection, voxelization, ray conventions and boundary behavior first. If self-view agreement is much tighter but combined-map agreement worsens, cross-view fusion/pose consistency becomes a stronger candidate. Neither outcome alone diagnoses hardware. This comparison is **proposed, not executed**.

## Reproducibility

- Driver: `../coffee-heldout-observation-source-20261030/`
- Driver manifest: `479da47b81278835c8427783b9fe6214fdff797e60bcd663caf20c7269f835bd`
- Primary conservative result: `../coffee-heldout-depth-result-20261030/README.md`
- `RESULT.json` is the byte-identical actual runtime receipt; `SOURCE_RECEIPT.json` records its hash and the saved-result audit checks.
- Only text evidence is included here, not source RGB/depth images or native binaries.
