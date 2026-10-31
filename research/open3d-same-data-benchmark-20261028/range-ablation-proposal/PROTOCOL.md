# Prepared single range-ablation experiment — NOT RUN

**Post-hoc development experiment, not untouched holdout validation. Root must release RTAB CPU ownership before execution.** The prior 29-view results motivated this proposal; they are now development evidence. This experiment cannot promote 5 m to production or establish physical clearance.

## Single change and stopping rule

Compare the existing 4 m baseline with **one 5 m depth cutoff variant only**, then stop regardless of improvement, degradation, mixed outcome or resource failure. No automatic retries or future cutoff sweep. No new download, installation, refit, pose optimization, floor smoothing or map correction. Five metres is a fixed one-metre extension, not a claim that returns in [4,5) m are accurate. They may add erroneous surfaces as well as useful evidence.

Retain the same 265 training / 29 excluded-frame IDs, supplied per-frame K and poses, order, millimetre conversion, 4 cm voxel, 20 cm SDF truncation, official Open3D 0.19 CPU runtime, RGB8 integration, random seeds, author-style cloud sampling and unfiltered final mesh extraction. `fusion_5m.py` is the baseline worker with only directory resolution and the depth cutoff/result metadata changed. No confidence or tracking-quality metadata is available.

## Upstream source check: what this does and does not isolate

Inspected official v0.19.0 sources on 2026-10-28:

- [Image.cpp, ConvertDepthToFloatImage](https://github.com/isl-org/Open3D/blob/v0.19.0/cpp/open3d/geometry/Image.cpp#L80-L93): scaled depth >= cutoff is replaced by zero; it is not shortened to an endpoint at the cutoff.
- [UniformTSDFVolume.cpp, integration](https://github.com/isl-org/Open3D/blob/v0.19.0/cpp/open3d/pipelines/integration/UniformTSDFVolume.cpp#L349-L438): zero-depth samples are skipped. Eligible projected voxels use depth-minus-camera-z times a ray-distance multiplier; samples farther behind the measured surface than truncation are skipped. Positive updates are clamped before averaging.
- [ScalableTSDFVolume.cpp, Integrate](https://github.com/isl-org/Open3D/blob/v0.19.0/cpp/open3d/pipelines/integration/ScalableTSDFVolume.cpp#L63-L92): integration visits volume units around sampled depth endpoints within the truncation extent. It does not unconditionally update every old volume unit along every ray.

Thus zeroed far pixels contribute neither their endpoint to block activation nor their sample to an activated block's voxel update. **Raising the cutoff changes endpoint admission AND touched-block coverage together.** It is not an isolated free-space-clearing experiment and cannot by itself settle the cause of the retained near surface. A far endpoint need not activate an old near block; no improvement would not disprove the sparse-conflicting-evidence hypothesis. Improvement would not establish that added geometry is correct. These are source-level algorithm statements, not verification of which exact voxels created the traced triangle.

## Frozen outputs to inspect

1. All 29 unchanged views, all 1,335,885 scheduled rays. Reuse exact saved FARO arrays; raycast the one new unfiltered TSDF mesh with the same established VTK evaluator. Report full availability partitions, pooled and per-frame signed/absolute statistics, existing 2/5/10 cm categories, reference-depth strata and processed-phone-depth consistency. Do not report only paired residual improvement if coverage changes.
2. Exactly the six source pixels in `TRACE_POINT_SELECTION.json`, selected before this variant; baseline/variant/FARO first-hit depths and missing status. Do not relocate points to a better region.
3. Fixed baseline-selected 4,166-ray frame228 component and 5,328-ray frame197 rectangle; retain the same masks, report missing counts as well as residual distributions. They are diagnostic subsets, not a substitute for all29 metrics.
4. Runtime, sampled RSS, aggregate disk and completion/failure receipts. No automatic winner selection. No navigation or physical-hazard percentage.

## Resource and execution contract

One serial worker, one allowed CPU affinity, nice +10; one-thread BLAS/OpenMP. Fusion sampled process-tree RSS stop 2 GiB; evaluation 3 GiB. Total one-variant CPU ceiling 1,200 seconds / wall ceiling 2,700 seconds; abort on cap. These sampled guards are not hard aggregate memory containment. At least 4 GiB available RAM before start, 1 GiB disk reserve. **Combined baseline fresh-run + proposal/run allocation + 5 MiB metadata reserve must stay <=3 GiB**, not 3 GiB extra. Baseline was approximately 1.95 GB; measure actual disk at launch, enforce throughout, preserve failed outputs. Inputs, runtime and reference arrays reused in place, never duplicated. No network operations in the runner.

`run_once.py` refuses an existing run directory and requires `--root-confirmed-rtab-released <FROZEN.json SHA256>`. This flag is not automatic CPU-ownership detection: root must positively confirm RTAB has released the worker before invoking it. Preparation is not authorization to run concurrently. Frozen script/input hashes must match before and after; new output cannot exist before freeze. No variant outputs currently exist.
