# Independent stage-06 post-run review

**Result: saved evidence reconciles; no accounting or safety-overclaim blocker found.** This is a separate addendum. All frozen implementation, protocol, source-review notes and original run outputs were left unchanged.

## What was independently checked

The new `postrun_recount.py` reads only the eight saved derived NPZ arrays and JSON/log/receipt files. It imports no VTK, decodes no original images, performs no ray tracing or geometry fitting and does not run a detector or planner. It checks exact scheduled pixel addresses and frame order; array shapes and hash pins; reference cell IDs and missing values; availability reconstructed from saved depths; every per-frame and pooled statistic; disjoint/exhaustive range bins; independently vectorized cardinal-neighbour edge categories; all 48 tiles per frame; per-frame/pooled reconciliation; and progress/receipt consistency. Quantiles are independently calculated by sorting and linear rank interpolation rather than calling the evaluator's function.

All checks passed. The maximum discrepancy from the reported numerical statistics was **0**. The 1,846 internal assertions are accounting checks over **the same eight frames**, not additional trials, rooms, hazards or navigation episodes. This recount does not independently establish that a traced surface is physical ground truth.

## Reconciled result

- Fixed frames: **8**, indices **0, 4, 8, 12, 16, 20, 24, 28**.
- Scheduled rays: **368,520**.
- Paired exported-depth/reference surface: **334,334 (90.7234%)**.
- Exported depth present but no reference hit: **34,186 (9.2766%)**.
- Reference-only and neither: **0 each**.
- All eight derived-array hashes match the evaluator's report; standalone frame JSON equals the corresponding aggregate frame entry.

Paired differences are exported phone axial depth minus registered reference axial depth, in nominal metres:

| Statistic | Value |
|---|---:|
| Mean absolute difference | 0.0963823 m |
| Median absolute difference | 0.0505502 m |
| 90th percentile absolute difference | 0.190912 m |
| 95th percentile absolute difference | 0.356159 m |
| Mean signed difference | +0.00838278 m |

The small signed mean must not hide the substantially larger absolute discrepancies and tails. The 34,186 unpaired rays are retained in the denominator but have no calculable reference difference; they are **not established sensor misses or false positives**.

Reference-depth paired counts, in preregistered order, are **0, 714, 83,288, 178,310, 57,957, 14,065** for positive below 0.15 m; 0.15–<1 m; 1–<2 m; 2–<3 m; 3–5 m inclusive; above 5 m. These sum to 334,334. No below-0.15 m paired coverage was established. The five preregistered edge-bin paired counts are **5,404; 2,331; 238,996; 65,815; 21,788**, also summing to 334,334. All per-bin statistics and all **384 image-domain tile** counts match the saved arrays. Tiles are not body-coverage zones.

## Resources and provenance

The terminal receipt reports exit code 0; source/input hash verification before and after; **48.5095 wall seconds**, **49.56 sampled process-tree CPU seconds**, **2,144,088,064 bytes sampled peak tree RSS**, and **4,093,337 output bytes before the receipt**. The log records a **2.80712-second StaticCellLocator build**, eight first-native-query returns and eight completed frames. Twenty-five resource heartbeat records are ordered and consistent with the terminal receipt; stderr is empty. These are Linux offline evaluator observations, not iPhone runtime measurements or hard-cgroup peaks.

This reviewer directly checked the saved report/receipt and derived-array hashes. The original 660 MB mesh and original phone images were not reread here; their before/after verification claim is the separately reviewed runner's receipt. The original stage-05 CPU-budget failure remains retained and must not be rewritten as a successful attempt.

## Interpretation and limits

The supported label remains **offline fixed-author-registration processed iPhone depth versus cleaned FARO-derived reference-surface disagreement**. The fixed author scale, poses, export processing, cleaned/hole-completed reference and Float64-to-Float32 PLY-reader conversion remain contributors. There is no verified measured-versus-edited reference mask and no original confidence or tracking. Eight correlated views of one room are not eight independent environments.

No prerecorded numerical pass threshold was supplied for physical obstacle safety. The result therefore establishes neither a safety pass nor raw sensor accuracy, hazard recall, near-feet/tiny-object coverage, body clearance or collision-free goal completion. Nothing here rules out the intended phone-plus-belt/additional-sensor architecture. The result is useful measured evidence for its narrower scope, not an app release gate.

## Addendum pins

- Original `COMPARISON_RESULTS.json`: `3dd8431ea152ac1019fc52e70cdeb49c2dfa8065917d92d546cf8a33f47f48cd`.
- Original `RUN_RECEIPT.json`: `fd36b71d05aff5b149b70affb3e8caa100f668fa27911fee5707854c114440f4`.
- New `postrun_recount.py`: `d85f1300421e0a8779643560c1c131a31b40125dea832da6ff1428a0994e3cdd`.
- New `POSTRUN_RECOUNT.json`: `fa0608bdb7d6b79e52f6e18adf02df2aaf60d74b48f6658d386f45bf24e84299`.

This review is complete and should remain unchanged after handoff. Any later claim or presentation review belongs in another addendum.
