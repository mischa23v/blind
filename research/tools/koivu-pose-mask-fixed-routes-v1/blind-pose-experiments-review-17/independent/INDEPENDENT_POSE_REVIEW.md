# Independent saved-pose and receipt audit

Commit: `b0be8628b159e0fc0446a7af8c57c13c99553a77`. All **24** acquired files were independently SHA-256 and Git-blob verified. This audit used only saved JSON and the existing level-transform metadata: no raw depth, ICP, fitting, fusion, map construction, reference geometry, or navigation.

## Koivu: exact preservation and nine real changes

**9 of 294** matrices changed, exactly matching the receipt: `[23,24,61,62,63,119,132,229,230]`. The other **285 matrices are numerically identical** to the original local capture. Every per-frame field other than `transform_matrix` is exactly preserved, as are all original top-level non-frame fields. The only added top-level field is `pose_refinement`. All 68 flagged-but-rejected poses remain unchanged.

For each changed pose, this audit derives **`M = L C1 inv(C0) inv(L)`**, with `L` constructed from the original supplied `R,t`. Every relative correction has affine bottom row, orthogonal proper rotation, and singular values equal to one within **4.44×10⁻¹⁶**: no introduced scale. The audit separately records the original camera matrices’ inherited finite-precision orthogonality error; it does not demand idealized original rotations.

**No independent horizontal translation parameter does not mean no horizontal camera displacement.** The correction rotates about a floor centroid. An elevated camera therefore moves horizontally under roll/pitch. Its actual level-frame displacement is `(Q−I)c + u`, not merely the translation column `u`.

| Zero-based pose index | Original frame ID | Actual camera ΔX / ΔY / ΔZ (cm) | Horizontal displacement (cm) |
|---:|---|---|---:|
| 23 | `frame_00024` | +4.7964 / -3.3276 / -4.4123 | 5.8376 |
| 24 | `frame_00025` | +6.1984 / +1.7722 / -9.4910 | 6.4468 |
| 61 | `frame_00062` | -3.1522 / -2.5994 / -9.1308 | 4.0857 |
| 62 | `frame_00063` | -3.2411 / -3.8895 / -10.4570 | 5.0629 |
| 63 | `frame_00064` | -2.8411 / -2.9809 / -8.9446 | 4.1179 |
| 119 | `frame_00120` | +1.7636 / +0.7092 / +3.0640 | 1.9009 |
| 132 | `frame_00133` | +7.1520 / -0.0883 / -3.8175 | 7.1526 |
| 229 | `frame_00245` | +4.0288 / +5.0695 / +2.4224 | 6.4754 |
| 230 | `frame_00246` | -1.7609 / +5.3039 / +7.2556 | 5.5886 |

The actual horizontal shifts span **1.90–7.15 cm**. The rotations have no independently chosen yaw degree of freedom; that is not a claim that every Euler yaw expression is identically zero. Full derived matrices, rotation axes, singular values, original/corrected camera coordinates, and displacement-equation checks are retained in `POSE_RECEIPT_AUDIT.json`.

## Every acceptance and rejection reconciles

| Room | Exported frames | Reported floor fits / no fit | Flagged | Accepted / rejected |
|---|---:|---:|---:|---:|
| Koivu | 294 | 251 /43 | 77 | 9 /68 |
| Coffee | 388 | 190 /198 | 76 | 1 /75 |

For **all 153 decisions**, the displayed nearest-neighbour distances satisfy the declared decision: `before−after >= max(0.10×before, 2 mm)` exactly when the receipt says corrected. Accounting for the scores being rounded to 0.1 mm, none is threshold-ambiguous: the same classification holds throughout each rounding interval. This independently checks the saved decision arithmetic, **not** the underlying point-cloud distance computation. Every accepted and rejected record and its exported frame ID is retained.

Coffee is **receipt/export-only**: its original raw pose JSON is not supplied locally, so this audit does not claim that exactly one original Coffee matrix changed, that other matrices were preserved, or that original non-pose fields match. It confirms the receipt declares one accepted correction at index 303 and validates its saved NN decision; its frame ID comes from the provided corrected export only.

The new Koivu 77 flags are not the old source’s 3 cm threshold result. `floorfix.py` uses original fusion-style Float32 samples and Euclidean camera range with the **2.5 cm /1.2°** gate; the earlier cause audit used Float64 projection and axial depth. Relative to that earlier 78-frame 2.5 cm set, new-only indices are **35,127,186** and old-only indices **22,69,290,292**. No raw recomputation of those fits was performed here.

## Important source limitations

1. **No-fit views are included in the validation target pool.** Source defines `unflagged = [i for i in range(n) if i not in flag]`; a no-fit view never enters `flag`. Before the temporal-distance and non-floor-point-availability filters, Koivu’s pool is **174 fitted-unflagged +43 no-fit =217** frames; Coffee’s is **114 +198 =312**. Thus “unflagged” is not “independently demonstrated consistent.” Per-frame no-fit IDs are not supplied in these receipts, so this audit does not fabricate their exact contribution to each target cloud.
2. **The non-floor set is validation, not a final untouched holdout.** The candidate transform uses floor points, but these non-floor nearest-neighbour distances decide which candidate corrections are accepted. They can test a floor-derived proposal, but final generalization/physical accuracy requires data not used for that selection.
3. The target is processed phone geometry, not independent truth. One-direction median NN improvement is not a bounded camera-pose error, does not establish small-object preservation or support coverage, and remaining wall residuals do not uniquely identify horizontal pose error.
4. Saved rigid/no-scale changes and decision arithmetic do not establish that the correction is physically safe. This audit adopts neither the corrected map nor the external report’s safety wording. No prior loop failures or movement receipts are replaced.

## Primary source links

- [Floor correction source](https://github.com/mischa23v/blind/blob/b0be8628b159e0fc0446a7af8c57c13c99553a77/research/mapping-audit-opus-20261026/scripts/floorfix.py)
- [Koivu correction receipt](https://github.com/mischa23v/blind/blob/b0be8628b159e0fc0446a7af8c57c13c99553a77/research/mapping-audit-opus-20261026/pose-consistency/poses/koivu_floorfix_RECEIPT.json)
- [Koivu corrected pose export](https://github.com/mischa23v/blind/blob/b0be8628b159e0fc0446a7af8c57c13c99553a77/research/mapping-audit-opus-20261026/pose-consistency/poses/koivu_floorfix_transformations.json)
- [Coffee receipt](https://github.com/mischa23v/blind/blob/b0be8628b159e0fc0446a7af8c57c13c99553a77/research/mapping-audit-opus-20261026/pose-consistency/poses/coffee_floorfix_RECEIPT.json)

Execution: **0.119 seconds**, **34.2 MB peak RSS**. Inputs verified before and after. All writes are confined to this independent directory.
