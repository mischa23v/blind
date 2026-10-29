# Coffee tabletop retention — Stage A actual result

**Stage A completed for the three frozen regression frames, and all 8 source controls actually passed.** This confirms the full-raster projection/diagnostic regression checkpoint. It does **not** show that a table corner was recovered, that a route avoids it, or that the app is ready.

This report independently checks existing result evidence; the reviewer did not rerun projection, controls or native code. Source bytes match the published checkpoint `e99637111a1c895b26c9bd1d7eaf76cc2813b714`. The historical source-only descriptions remain unchanged; this separate result packet records the later execution evidence.

## Observed results

| Original frame | Retained depth endpoints | Range-excluded pixels (unknown) | Zero pixels (unknown) | Diagnostic median table/floor signed separation |
|---|---:|---:|---:|---:|
| `frame_00290` | 623,396 | 110,176 | 0 | 0.649590333 m |
| `frame_00357` | 465,044 | 268,528 | 0 | 0.631073256 m |
| `frame_00391` | 733,572 | 0 | 0 | 0.620703330 m |
| **Total** | **1,822,012** | **378,704** | **0** | — |

Each frame accounts for all 733,572 original pixels (738 × 994). The Stage A receipt is `completed`, both retained process exit records are zero, and all three medians reproduce their frozen historical numerical values within `1e-9 m`. That tolerance is a numerical regression tolerance, **not** a depth-sensor accuracy or physical safety claim.

The [verbatim Stage A receipt](STAGE_A.json) retains full-precision diagnostics, depth and projected-point hashes, intrinsics and evidence limitations. The [actual control log](STAGE_A_CONTROLS.txt) names exactly the eight functions present in the pinned test source; every one is `ok`, with `Ran 8 tests` and `OK`. No control result was inferred from planned source or from the separate OctoMap suite.

The eight controls cover original intrinsics/axis convention, zero and far-return exclusion, survival of pixels outside evaluator patches, raster shape/type rejection, invalid intrinsics, separation of projection from semantic annotations, half-open patch bounds, and rejection of an empty floor evaluator.

## Independent evidence checks

[VERIFICATION.json](VERIFICATION.json) records the recount and hashes. It verifies:

- Exact original depth bytes for all three frames, original transformation/calibration bytes and the frozen patch-selection file.
- Original 16-bit grayscale PNG dimensions, exact supplied per-frame intrinsic values, and receipt pixel-count arithmetic.
- Source hashes against the published source packet; exact source/log control-name equality and the three expected frame results.
- Historical median comparison, no native fields in Stage A, and no physical-authority claim.

This is a source/input-byte/receipt/log verification, not a second numerical projection. The projected-array hashes are preserved from the actual Stage A receipt, not independently recomputed here. Original captures and transformations are retained privately outside this public text-only packet.

## Native prerequisites reviewed separately

The [sibling native-build result packet](../coffee-octomap-build-result-20261029/) owns the build/control receipts and exact rebuilt Stage B binding; they are deliberately not duplicated here. [NATIVE_PREREQUISITE_REVIEW.json](NATIVE_PREREQUISITE_REVIEW.json) records this review's verified hashes and receipt chain.

The actual direct compile completed with one zero-exit, retired compiler process group. All 69 pinned inputs were unchanged and still match; the three recorded payload file hashes also match the retained files. The separate original adapter controls report **16/16, zero failures, errors or skips**. Those are native adapter controls, not the eight Stage A controls and not tabletop-retention results.

The new native-library SHA256 is `0a044001b1455634ab881cc42fb5954362d960abf5cd851b7b6dc99b6c3eb963`. It is not silently substituted for the historical digest. The generated binding has exactly three declared source changes: the retention library-digest constant, the wrapper library-digest constant, and the explicit `rebuiltBinding` wrapper-pin lookup. Both resulting Python sources parse; no other source differences were found.

**Stage B remains unrun at this review checkpoint.** Its next permitted check is independent camera-local native retention of the original full-raster endpoints. It remains bounded by 120 CPU seconds, 512 MiB process address space, a parent 180-second wall deadline, one CPU and bounded outputs. A failure, resource stop, crash or missing receipt must remain failed/inconclusive; it does not authorize a retry or larger budget.

## What this does not establish

The positive-depth gate is strictly below 4 m, inherited from the frozen processed-depth diagnostic, not native sensor-confidence filtering. Range-excluded pixels stay unknown. No floor filtering or synthesized tabletop is introduced. The fitted floor and RGB-selected inset patches are evaluator-only and cannot change mapper input.

These are three already-used discovery/regression frames, not held-out real-world accuracy data. Calibration is supplied; each frame remains camera-local. Native confidence, cross-view alignment, depth-to-mesh registration and the actual table-corner extent remain unverified. Stage C is absent. There is no collision, route-clearance, localization, readiness, physical-safety or 90%-accuracy claim; the visually rejected corner-clipping route stays rejected.

## Publication boundary

Only text receipts, logs, verification and this explanation are included. No RGB image, depth raster, transformation file, native binary, host-environment dump or archive is included. [PUBLICATION_MANIFEST.json](PUBLICATION_MANIFEST.json) identifies every payload file by size and SHA256. No Git staging, commit or push was performed by the reviewer.
