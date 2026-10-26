# Review of the supplied pose experiments

Reviewed checkpoint: `b0be8628b159e0fc0446a7af8c57c13c99553a77`, tree
`e9f5ac44b0cac1b3a45ec9e261b4f7b3c0b95172`. This directory preserves exact
sources, supplied poses, receipts and derived arrays. No pose refinement,
fusion, map replacement, route query or movement was performed by this review.

## Verified findings

1. **The Koivu export changes exactly nine poses.** Zero-based indices are
   23, 24, 61, 62, 63, 119, 132, 229 and 230. All 285 other matrices and all
   294 frames' non-pose fields match the original export. Relative corrections
   are rigid: maximum singular-value deviation from one is 4.44e-16. Original
   pixel/depth metadata is not discarded or rescaled. This verifies the saved
   transform contract, not that each transform is physically correct.
2. **There is actual horizontal movement.** Rotating about a floor centroid has
   no independently estimated horizontal translation parameter, but it moves
   camera centres horizontally by 1.90–7.15 cm. The report's “no horizontal
   change” wording must not be interpreted as zero camera/obstacle XY change.
3. **All 153 Koivu/coffee decisions match the stated rounded NN rule.** The
   acceptance rule is at least 10% AND 2 mm median nearest-neighbour improvement.
   None of the saved decisions is ambiguous under its rounding interval.
   Coffee's original capture was not acquired here: its receipt/export identity
   is checked, not independently compared to its unavailable original poses.
4. **The new 251-fit/77-flag count differs legitimately from the earlier 252/78.**
   `floorfix.py` uses the pipeline's Float32 world points and Euclidean range.
   Earlier `cause.py` used Float64 points and axial depth. Both use the 2.5 cm
   flag threshold in the relevant receipts; this is not the earlier 3 cm
   console-print discrepancy. No conventions were silently substituted.
5. **The supplied mask metric is reproduced.** Exact saved-array results:

   | Candidate | Raw walk cells | Reference-covered walk cells | Edge-miss proxy | Open-floor-miss proxy | Reference-walk cells blocked |
   |---|---:|---:|---:|---:|---:|
   | Koivu original split-0.7 | 11,559 | 11,501 | 359 | 4 | 1,287 |
   | Koivu corrected split-0.7 | 11,827 | 11,766 | 363 | 4 | 1,030 |
   | Coffee corrected split-0.7 | 6,790 | 6,779 | 154 | 0 | 1,220 |

   These are the exact `openfloor.py` predicates, cross-checked with its
   unchanged reporting function. The four Koivu open-miss indices are unchanged,
   with zero new or removed indices. The level transform is refitted, however:
   their nominal physical column centres shift about 1.05–1.07 mm. This is a
   column association check, not a new surface-distance measurement. Coffee's
   original arrays were not acquired for this recount.

## Limits that matter before adoption

- `floorfix.py` builds targets from **unflagged**, not exclusively successfully
  fitted consistent frames. That pool contains all 43 Koivu and 198 coffee
  no-fit frames, before temporal exclusions and available non-floor samples.
  No-fit means unavailable, not established consistency.
- The non-floor points are not used to fit the candidate transform, which is a
  useful separation. But their NN score also decides acceptance. It is a
  **validation set**, not a fresh untouched final test. The same physical
  surfaces can appear in multiple views. A new claimed generalization result
  needs an additional frozen test, not merely the acceptance scores again.
- Floor compatibility alone cannot distinguish pose drift, range/view-dependent
  depth bias or real surface variation. Temporal predictability versus one
  linear range regressor is evidence of correlated error, not an exhaustive
  causal exclusion. The temporal score uses neighbours on both sides and is
  not a causal online predictor or an out-of-time test.
- The metric called “safe” is a **vertex-column/EDT non-regression proxy**.
  It does not query continuous triangles, a swept body, head/foot support or
  dynamic obstacles. A miss within 15 cm of *any* blocked column is counted as
  an edge miss; that alone does not prove the body's margin protects that
  surface. Low geometry below 2.5 cm and missing reference coverage remain
  outside the asserted pass. Four open-floor misses remain on Koivu.
- Each rebuilt map independently refits its level frame and grid/reference
  columns. Old/new route objectives must be carried through original phone
  coordinates; simply reusing numeric X/Z or choosing a new convenient start
  would not be a paired comparison.
- The repeated global-optimization failures describe these supplied graph
  configurations and data, not a general failure of Open3D or all joint
  registration. Their retained receipts are reviewed separately; neither
  rejected pose set is adopted.

## Immediate use boundary

The supplied corrected mask is eligible for an **explicitly unvalidated,
known-provided-map simulation candidate**, not a live safety authority. A
separate paired route check will reuse unchanged 45 cm / 55 cm envelope / abstract
28 cm profiles, native engine and sampled rectangle/turn tests. It will preserve
the original objectives in phone coordinates, all association failures and all
old results. Reference geometry must remain absent from route selection and be
used only later for independent movement scoring.

The earlier local-floor layer proposal remains unimplemented. No suspect frame
or low-object evidence is deleted or called free by this review.

## Evidence locations

- `SOURCE_PINS.json`, `ADDITIONAL_SOURCE_PINS.json`: exact source/receipt identities.
- `ASSET_PLAN.json`, `ASSET_ACQUISITION.json`: four exact derived arrays,
  12,150,161 bytes, SHA256 and Git blob verified, no new raw dataset.
- `independent/POSE_RECEIPT_AUDIT.json`, `independent/INDEPENDENT_POSE_REVIEW.md`:
  all changed matrices, full frame identities and receipt decisions.
- `mask-recount-01/INPUT_PINS.json`, `mask-recount-01/RESULT.json`: saved-mask
  counts and miss-column associations; no native reconstruction rerun.

Primary supplied sources: [experiment report](https://github.com/mischa23v/blind/blob/b0be8628b159e0fc0446a7af8c57c13c99553a77/research/mapping-audit-opus-20261026/pose-consistency/POSE_EXPERIMENTS.md),
[floor correction source](https://github.com/mischa23v/blind/blob/b0be8628b159e0fc0446a7af8c57c13c99553a77/research/mapping-audit-opus-20261026/scripts/floorfix.py),
[proxy score source](https://github.com/mischa23v/blind/blob/b0be8628b159e0fc0446a7af8c57c13c99553a77/research/mapping-audit-opus-20261026/scripts/openfloor.py).
