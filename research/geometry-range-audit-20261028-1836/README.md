# Geometry audit addendum — 2026-10-28 18:36 UTC

## Decision: retain the baseline; do not adopt the 5 m cutoff

The single, frozen Open3D 4 → 5 m cutoff experiment improved the selected extreme-error region but worsened pooled median, mean and P95 error. This is a **post-hoc development experiment**, not fresh holdout validation, a general reconstruction fix or a navigation success.

| First-hit absolute error | 4 m baseline | 5 m variant |
|---|---:|---:|
| All paired rays: median | 3.404 cm | 3.475 cm |
| All paired rays: mean | 18.650 cm | 18.969 cm |
| All paired rays: P95 | 1.1383 m | 1.2282 m |
| Fixed frame 228 region, 4,166 rays: median | 3.5677 m | 4.471 cm |
| Same fixed region: P95 | 3.9982 m | 64.218 cm |

All 1,335,885 evaluation rays remain scheduled. Paired hits increase from 1,187,988 to 1,188,709; reference-only decreases from 6,556 to 5,835; prediction-only increases from 138,401 to 139,232. The pooled paired populations therefore differ. Per-frame mean error improves in 11 views, worsens in 17 and is unchanged in one. The fixed 5,328-ray floor control remains essentially unchanged. Three selected problematic first hits move within 2.9–4.4 cm of the reference, but that does not erase the large region-wide error tail.

See the [full experiment result](../open3d-same-data-benchmark-20261028/range-ablation-proposal/RESULTS.md), [frozen protocol](../open3d-same-data-benchmark-20261028/range-ablation-proposal/PROTOCOL.md), [comparison numbers](../open3d-same-data-benchmark-20261028/range-ablation-proposal/run/COMPARISON.json), and [independent review](../open3d-same-data-benchmark-20261028/independent-review/RANGE_5M_REVIEW.json). The independent reviewer passed **11,581 checks**, including 2,348 floating comparisons, maximum discrepancy 6.66e-16, without rerunning geometry queries. This checks computations and recorded inputs, not physical safety.

## What the experiment does and does not isolate

Open3D 0.19 discards depths at or beyond its cutoff; it does not clamp them to that distance. Its scalable TSDF activates volume blocks near measured endpoints. Raising the cutoff changes both admitted measurements and block activation, so this is **not a pure free-space-clearing intervention** and does not establish the exact voxel-level cause of the old false near surface.

Primary implementation evidence:
- [Open3D v0.19 depth conversion](https://github.com/isl-org/Open3D/blob/v0.19.0/cpp/open3d/geometry/Image.cpp#L80-L93)
- [Uniform TSDF integration](https://github.com/isl-org/Open3D/blob/v0.19.0/cpp/open3d/pipelines/integration/UniformTSDFVolume.cpp#L349-L438)
- [Scalable TSDF block activation](https://github.com/isl-org/Open3D/blob/v0.19.0/cpp/open3d/pipelines/integration/ScalableTSDFVolume.cpp#L63-L92)

The fixed training split, poses, per-frame intrinsics, 4 cm voxels and 20 cm truncation remain unchanged. No cleanup, refit or path carving was applied. Only one cutoff attempt was executed. No further range search is authorized by this result.

## Current audit state: not a final all-methods verdict

Verified publication base for this addendum: `ce62bbe38b067592f3703e7276d95791b2cba687` on `codex/recovery-hazard-order-20261027`.

- **Exact Apple export comparison:** OpenUSD demonstrated preserved metric scale and tiny native/reference bounds differences for the compared first failing wall features. The custom source-containment policy incorrectly rejected exported thickness. A separate floor-classification defect treated raw slab side/underside faces as support. The replacement remains a candidate, not an executed Apple result.
- **Apple candidate execution is blocked:** the repository became private; the existing workflow's explicit public-only guard skipped the run. Permission to change that guard is pending. There is no new native pass, no reason to change repository visibility, and no permission inferred from prior publication approval.
- **Actual RTAB-Map fixed-pose and graph arms completed:** both processed 265 frames. The fixed arm improved the common evaluator's reverse visible-surface coverage but had worse forward median/mean than the Open3D representation; graph optimization did not produce an overall winner. Comparison point density and representation differ. Export adapter valid-index handling and the PCL PLY reader incompatibility were repaired and recorded, not hidden.
- **Actual RTAB-Map + OctoMap ray-clearing stage is separate and still pending at this timestamp.** No result is claimed here. The completed RTAB mapping stage did not itself test that clearing configuration.
- **InfiniTAM:** source feasibility reviewed; no actual same-data execution, and noncommercial-license eligibility remains unresolved. CUDA/Windows-dependent alternatives and full IMU-dependent methods are not counted as executed comparisons.

Historical `FULL_REPORT.md` is preserved as its dated snapshot. Consult the later published RTAB checkpoint at commit `ce62bbe` rather than reading that earlier snapshot as current completion status. None of these experiments establishes live obstacle avoidance, a completed table loop, stair safety or child-ready navigation.

## Publication and reproduction boundary

This packet contains text only: exact source scripts, frozen configuration and input hashes, execution receipts, numeric results, independent recount code and review. The original source manifest had 56 entries, including large binary geometry and per-ray arrays. `SOURCE_PUBLICATION_MANIFEST.json` preserves that original inventory and hash chain; **it is provenance, not the upload allowlist**. Its paired original checksum file refers to the original basename `PUBLICATION_MANIFEST.json` before the `SOURCE_` prefix was added.

`PUBLICATION_MANIFEST.json` in this addendum is the **text-only publication allowlist**. Its SHA256 is recorded beside it; the manifest deliberately does not hash itself. No source photos, raw depth, PLY/NPZ outputs, FARO source mesh, runtime/dependencies, private backup identifiers or credentials are included. References to those inputs or derived arrays in receipts/scripts are provenance, not a claim that this packet alone is executable. Reproduction requires the recorded external data and environment; the exact saved binary inputs remain excluded from this publication packet. Original execution paths are retained truthfully in the receipts.

The frozen experiment hash is `0b9e6eeee19565a3ca2112ea926a2ecdbdf4c930528e7bfe8d063323d164d448`; original 56-file source manifest hash is `d6a4ed003715569263a5851743fad95ce58014fa76d0a1b7a24557d629239142`.
