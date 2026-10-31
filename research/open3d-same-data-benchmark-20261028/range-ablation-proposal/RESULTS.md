# Single 5 m ablation: local improvement, overall regression

**Executed once after root released the RTAB CPU lease. Post-hoc development experiment, not untouched holdout validation. No recommendation to replace the baseline with 5 m.** Frozen plan/code SHA256: `0b9e6eeee19565a3ca2112ea926a2ecdbdf4c930528e7bfe8d063323d164d448`.

## All 29 views — required primary comparison

All 1,335,885 rays remain scheduled. Same saved FARO reference arrays, same frame split, intrinsics, poses and evaluator. Only fusion depth cutoff changed from 4 m to 5 m.

| Metric | 4 m baseline | 5 m variant |
|---|---:|---:|
| Paired hits | 1,187,988 | 1,188,709 |
| Reference only | 6,556 | 5,835 |
| TSDF only | 138,401 | 139,232 |
| Neither | 2,940 | 2,109 |
| Paired median absolute error | 3.404 cm | 3.475 cm |
| Paired mean absolute error | 18.650 cm | 18.969 cm |
| Paired P95 absolute error | 1.1383 m | 1.2282 m |
| Paired P99 absolute error | 3.1170 m | 3.0025 m |
| Paired errors earlier than −10 cm | 102,975 | 84,403 |
| Paired errors within ±10 cm | 948,693 | 936,861 |
| Paired errors later than +10 cm | 136,320 | 167,445 |

Coverage changes are explicitly reported; these are not identical paired populations. Per-frame MAE improves in 11 views, worsens in 17 and is unchanged in one. The complete per-frame, range-stratified and processed-phone-consistency results are retained in `run/COMMON_GEOMETRY_RESULTS.json`; baseline and variant are bundled together in `run/COMPARISON.json`. None of these errors is a physical-hazard label or a navigation accuracy percentage.

## Fixed diagnostic regions — not substitutes for the primary comparison

The fixed frame228 component has 4,166 paired samples in both runs, zero missing predictions. Its median absolute FARO error drops from **3.5677 m to 0.04471 m**; P95 drops from **3.9982 m to 0.64218 m**. Substantial residuals remain: the variant signed range is −2.2123 to +2.1253 m.

The fixed frame197 floor rectangle retains 5,328 paired samples, zero missing predictions, and essentially identical median/P95 errors: **4.914 mm / 16.934 mm**.

| Fixed source pixel | 4 m first hit | 5 m first hit | FARO first hit |
|---|---:|---:|---:|
| 228 (640,172) | 0.36665 m | 3.93619 m | 3.89637 m |
| 228 (672,288) | 0.39112 m | 4.15593 m | 4.11163 m |
| 228 (652,452) | 0.41699 m | 4.48886 m | 4.45972 m |
| 197 (600,824) | 2.50399 m | 2.50399 m | 2.48820 m |
| 197 (600,872) | 2.26757 m | 2.26757 m | 2.25871 m |
| 197 (600,920) | 2.07199 m | 2.07199 m | 2.06833 m |

All six source rays return a finite hit in both runs. The new first hit is not necessarily the same physical surface or mesh point; this is a ray-depth comparison, not tracking triangle identity.

## Interpretation

This single intervention demonstrates that the specified range-cutoff change can remove the extreme near-first-hit discrepancy at these three sampled rays and improve their surrounding fixed region under this recording and reference. It does **not** establish the precise voxel-level mechanism, justify an automatic cleanup rule, or make the full reconstruction better: pooled median/MAE/P95 worsen and more paired rays hit too far behind the reference.

As the upstream-source check in `PROTOCOL.md` explains, raising the cutoff changes both admitted depth samples and endpoint-near block activation. This is not a pure clearing ablation. Additional depth may resolve some conflicts while introducing or amplifying others. No further cutoff is tried, no geometry is edited and no 5 m production recommendation is made.

## Resources and preservation

All four phases exited zero. Fusion 91.32 s wall / 91.25 s CPU; evaluation 31.06 s / 31.02 s; summary and fixed comparison 3.25 s / 3.20 s. Peak sampled process-tree RSS **737,439,744 bytes**. Combined baseline, variant, proposal and metadata reserve at receipt **2,013,822,976 bytes**, below the 3 GiB cap. No downloads or installations. CPU released to root after terminal completion. Sampled monitoring is not a hard aggregate memory limit.

Variant mesh: 263,918 vertices / 502,334 triangles; baseline: 242,293 / 461,256. The variant admits 178,133,610 exported-raster positive depth pixels versus 164,771,607 baseline; these are upscaled raster counts, not independent native sensor measurements.

Saved outputs include unfiltered mesh, author-style initialization cloud, per-frame fusion receipt, all 29 TSDF ray arrays, exact configuration/pins and evaluation/summary results. Original baseline remains untouched. Derived cloud/mesh are public-data geometry with RGB vertex colors, not source photographs; root controls publication. Source-photo files and environment caches are excluded.

Independent numerical recount passed **11,581 checks**, including 2,348 floating comparisons (maximum difference 6.66e-16). All 29-view statistics including sensor comparisons, availability, six fixed points and independently reconstructed region masks passed. The reviewer also checked worker AST equivalence after only range/scope normalization and the unchanged summary function. See `../independent-review/RANGE_5M_REVIEW.json` and `recount_5m.py`. This validates the reported computations, not physical safety.
