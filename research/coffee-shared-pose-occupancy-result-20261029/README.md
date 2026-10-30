# Coffee shared-pose occupancy: actual bounded observation

**Completed, with conflicts retained; not geometry validation or physical authority.** Root ran the published source checkpoint `1837cc23231881b7225ec2025568d02cd52ea0c1` after external exact-manifest verification. The three frozen processed-depth frames were inserted into one 5 cm occupancy tree using their original supplied camera poses. Exit was 0. OriginalPolycam mesh alignment remains absent.

## Exact result

| Original frame | Accepted depth endpoints | Distinct world-grid endpoint keys | Table-inset keys | Final endpoint conflict keys | Final table-inset conflict keys |
|---|---:|---:|---:|---:|---:|
| 00290 | 623,396 | 9,304 | 31 | 0 | 0 |
| 00357 | 465,044 | 7,863 | 35 | 1,410 | 0 |
| 00391 | 733,572 | 9,441 | 22 | 364 | 2 |

All retained endpoint and table-inset key sets remained known and occupied after the final insertion. Their per-frame counts overlap and must not be added as independent occupied volume. In total, **1,822,012 accepted points** produced **24,935 distinct occupied leaves**. The final map contains **232,014 known leaves**: 24,935 occupied and 207,079 known-not-occupied. The latter are simulated ray observations, not a safe-clearance certificate. No leaf lacks hit/free evidence, and unobserved volume is not serialized as free. All three remote unknown controls remained unknown.

The final map contains **1,774 hit/free-conflicted leaves**, not zero conflict:

- Frame 00290's endpoint keys received no later hit or free updates. Its retention alone provides no overlapping cross-view corroboration.
- Frame 00391 adds hits to 1,673 endpoint keys previously hit by 00357, and free evidence to 1,410 of 00357's other endpoint keys. All 35 keys in 00357's table inset receive a second hit from the **full** frame 00391; this is not proof of a measured table boundary or identical inset annotation.
- Among frame 00391's current endpoints, 364 keys previously carried free evidence. Two are in its 22-key table inset. Their final occupancy is approximately 0.608696, versus 0.844828 for two-hit/no-free keys.

The evidence histogram is exact: 192,527 leaves with zero hits/one free scan; 14,552 with zero hits/two frees; 21,488 with one hit/no frees; 1,774 with one hit/one free; and 1,673 with two hits/no frees. This totals 26,608 hit-scan votes and 223,405 free-scan votes, matching the insertion receipts. No occupied-to-not-occupied or known-to-unknown transition was reported in the retained endpoint sets.

## Resource and integrity evidence

Worker-reported CPU **2.505848 seconds**, wall **2.483479604 seconds**, peak RSS **161,820 KiB**. Source configures 120 CPU seconds, 512 MiB address space, one CPU, 175-second internal alarm, external TERM at 178 seconds/KILL two seconds later, and 32 MiB per-file cap. Final tree nodes: 271,082, below the 500,000 stop. Exit 0 and empty stdout/stderr are retained. Root reported normal command completion; no independent outer wall/RSS/process-group sample was retained, so these worker figures are not relabelled as external measurements.

An independent reviewer verified unchanged source/input hashes, actual original pose/K/origin bindings, per-scan history continuity, and the saved map with a standard-library ZIP/NPY parser, **without loading NumPy/native code or rerunning the mapper**. Every exported leaf is 5 cm, has hit/free evidence, and its probability/log odds agree with that evidence. The largest full-point Float32 conversion difference reported by the worker is `2.3841672813773584e-7` metres; this is numerical conversion error, not pose/depth accuracy.

- Source `MANIFEST.json` SHA256: `7e1f175529b8942704c124e9602a17be8c986261e5e95b69f302d4397929957f`
- Original local `RESULT.json` SHA256: `395321fd55785aa3a81d4edb31065ed50fa5dc0f7bcbd6f2ff6ce7fdc3fb9659`
- Local map: 774,797 bytes; SHA256 `51ffffb8ffdf8eb1850a148035bc789415d90327ab9e0f6f3c66264116155d10`. The map binary is **not included in this publication packet**.
- The preceding 14 pure pose/source controls passed independently. Their passing result is separate from this native observation.

## What this does not establish

The coordinate frame is the original capture's **supplied-pose world**, not a trusted true-world reference. Rigid numerical matrices and plausible output do not prove pose accuracy. The official MuSHRoom convention justifies the camera basis conversion; it does not physically calibrate these selected recordings. No originalPolycam alignment, SLAM validation, complete table extent, support/clearance, room completeness, live localization, or route acceptance follows.

The frames were previously retained and are **not held out**. Three scans with hit probability .7 and miss probability .4 cannot drive an ever-hit key below .5: one hit plus two misses remains about .5099. Thus zero occupied losses here is not a long-term contradiction/de-occupancy result. Conflicts may reflect pose/depth error, visibility/occlusion differences, interpolation, motion, or voxelization; this experiment does not distinguish their cause. Missing and range-excluded rays generate no evidence, rather than invented free space.

## Next gate: two held-out view checks, not a map repair

Prepare and freeze two additional existing views **before scoring**, distinct from 00290/00357/00391 and selected for documented overlap with observed non-table walls/furniture. State which visibility/overlap condition each checks, use original per-frame K and the same pose convention, and retain excluded/insufficient-overlap outcomes. Do not tune poses, flatten floors, change depth ranges, or insert held-out points into the scored training map.

Use an established pinned geometry comparison method with preregistered coverage, bidirectional visible-surface residual and conflict summaries. Define metric tolerances from documented sensor/export limitations before execution, not from whichever result looks favorable. Unknown or non-overlapping regions are unscored, never successful. Two same-capture held-out views can test internal consistency only; they cannot establish independent physical calibration. Keep source review and bounded execution admission separate. Existing evaluator-only floor-patch comparisons may diagnose disagreement but are neither held-out data nor ground truth.

The additional [existing floor-patch diagnostic](FLOOR_PLANE_DIAGNOSTIC.md) found normal differences of 0.52–0.83 degrees, but no overlapping sampled patch domains. It therefore withholds same-location floor-height comparison rather than extrapolating or flattening the planes. These are evaluator-only fitted patches, not ground truth or held-out checks.

Data attribution: Xuqian Ren et al., [MuSHRoom iPhone Basic Data](https://zenodo.org/records/10230733), CC BY 4.0. Source conventions, original nonalignment warning, licenses and code pins are documented in the [source packet](../coffee-shared-pose-occupancy-source-20261029/README.md). This result packet contains text and aggregate scalar metadata only: no photos, depth rasters, mesh, map arrays, or native binaries.
