# Fixed resolution ablation: smaller voxels improve same-view agreement

**With identical source data, poses and occupancy probabilities, reducing singleton-map resolution from 5 cm to 2.5 cm materially improved observed-ray depth agreement in all three views. This is evidence of a representation contribution—not improved sensor hardware, validated obstacle recall, or safe navigation.**

All three 5 cm baselines reproduced their previous map hashes, ray statistics and per-hit arrays exactly before finer cases ran. The separate 1M enumeration protocol completed all six cases under unchanged actual process limits. The original 500k-guard failure remains preserved and is not relabeled as success.

## Actual measurements

Entry residual compares the first observed voxel-box entry with the source pixel's axial depth. Values below cover observed hits, not all possible scene geometry.

| View | Valid rays | Observed hits 5 cm → 2.5 cm | Absolute median | Absolute p95 |
|---|---:|---:|---:|---:|
| 290 | 9,902 | 9,899 → 9,902 | 5.92 → **2.91 cm** | 47.48 → **12.80 cm** |
| 357 | 7,436 | 7,433 → 7,436 | 7.21 → **3.61 cm** | 77.64 → **25.32 cm** |
| 391 | 11,625 | 11,625 → 11,625 | 3.95 → **2.29 cm** | 21.06 → **8.95 cm** |

No coarse-hit pixel disappeared at finer resolution. Finer maps added the three previously unhit valid rays in each of views 290 and 357. All accepted source endpoints remained occupied at both resolutions, both pixel-weighted and distinct-key-weighted. This is retention of the input observations, **not independent evidence that all real hazards were detected**.

### Same-pixel comparison

The saved-array audit paired the exact same pixel indices, reproduced all saved residual statistics and checked denominator/map-state contracts. Counts below compare absolute entry residuals; equality is exact numerical equality, not a tuned tolerance.

| View | Common hits | Improved | Equal | Worsened | Median paired absolute-error change |
|---|---:|---:|---:|---:|---:|
| 290 | 9,899 | 8,066 | 1,123 | 710 | −2.85 cm |
| 357 | 7,433 | 5,665 | 1,046 | 722 | −3.15 cm |
| 391 | 11,625 | 6,533 | 2,444 | 2,648 | −1.43 cm |

Thus the aggregate improvement is not created by dropping difficult hit rays, but it is not uniform across pixels either. The source/ground-truth limitations from the prior self-view audit remain.

### Important coverage tradeoff

Conservative `unknown-before-hit` counts **increased**:
- View 290: 400 → 489.
- View 357: 251 → 302.
- View 391: 272 → 379.

The finer map gives better agreement in the separate observation-only mode while exposing more unknown gaps in the conservative known-prefix mode. Unknown is not clear. This tradeoff prevents treating the finer setting as a production navigation winner from this experiment alone.

## Memory, state and scope

| Fine singleton | Tree nodes | Leaves |
|---|---:|---:|
| 290 | 740,624 | 637,567 |
| 357 | 488,841 | 417,215 |
| 391 | 915,773 | 794,111 |

All case queries left map state, defaults and canonical payloads unchanged. Runtime was **10.12 seconds wall**, peak RSS **243,852 KiB**. The process limits stayed at 512 MiB address space, 120 CPU seconds, 180 wall seconds, one CPU and 32 MiB per file. The separately declared enumeration caps were 1M nodes and leaves; actual native probability defaults were explicitly checked unchanged. Streaming canonical hashing preserved historical hashes and avoided full NPY buffer copies.

Only map resolution changed geometrically. No endpoint filtering, pose adjustment, LLM clearing, unknown-space carving, success-threshold tuning or new data selection occurred. This finding supports coarse occupied boxes as a contributor to earlier near-surface ray bias. It does not quantify hardware accuracy or show that 2.5 cm is sufficient for children, stairs, toys, live localization or full-room routes.

## Prospective fine fused-map comparison: size is not yet established

The three singleton maps give bounds, not an exact fused size. On their shared fixed lattice, the fused known-cell union may be between the largest singleton and the sum:

- Leaves: **794,111 to 1,848,893**.
- Nodes: **915,773 to 2,145,238** (sum is a loose upper bound with shared ancestors).

A coarse-map overlap ratio would suggest a fine union substantially above the current 1M enumeration guard, but that is only a heuristic and must not be reported as measured. The exact fine union has not been constructed. At the summed-leaf upper bound, exported arrays alone would contain about **96.14 MB**, excluding the native tree/evidence map, projection/query arrays and interpreter/allocator overhead. Streaming hashes avoid a second whole-array buffer but cannot make native map memory disappear. Peak RSS from singleton runs is not a guarantee about the fused map's virtual-address requirement.

**Do not schedule fine fused scoring as if it were known to fit.** A separately frozen, build-only sizing preflight could insert the same three views in order under the same 512 MiB/time and current 1M enumeration limits, checking state after each insertion and stopping before export/scoring if exceeded. It would produce a capacity result, not held-out accuracy. No guard increase is implied by this proposal.

If full fusion cannot fit, a different explicitly labeled diagnostic could compare the fixed held-out views 232/370 against each fine singleton separately, serially. That tests out-of-view consistency without requiring a large fused map; it is **not a substitute for a fused-map result**, and it must not select the most favorable map/ray after seeing results. Neither proposed comparison has run.

## Reproducible evidence

- `RESULT.json`: exact runtime receipt.
- `audit_pairs.py`, `PAIRED_AUDIT.json`: completed saved-array audit; no mapper or raster reads.
- `DERIVED_LOCAL_FILES.json`: hashes/sizes of six local per-hit arrays.
- Source: `../coffee-resolution-ablation-v2-source-20261030/README.md`.
- Preserved first-attempt failure: `../coffee-resolution-ablation-result-20261030/README.md`.

Production resolution remains undecided. No physical safety or navigation acceptance claim is made.
