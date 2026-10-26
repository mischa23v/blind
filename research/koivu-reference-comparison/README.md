# Real iPhone room depth versus registered reference surface

**An actual eight-frame offline comparison completed. It is not an obstacle-avoidance or safety pass.** This packet contains the executed source, retained failed first attempt, successful results, saved numerical ray arrays, analytical diagnostics and eight byte-identical licensed RGB exemplars—not merely external links.

## Measured result

The fixed selection was Koivu iPhone long-capture frames 00001, 00005, 00009, 00013, 00017, 00021, 00025 and 00029. These are correlated views of **one furnished room**, not eight independent rooms.

| Measure | Result |
|---|---:|
| Fixed scheduled rays | 368,520 |
| Exported depth and registered reference both available | 334,334 (90.7234%) |
| Exported depth available, reference intersection missing | 34,186 (9.2766%) |
| Reference-only / neither | 0 / 0 |
| Paired mean absolute discrepancy | 0.0963823 nominal m |
| Paired median absolute discrepancy | 0.0505502 nominal m |
| Paired 90th / 95th percentile absolute discrepancy | 0.190912 / 0.356159 nominal m |
| Paired mean signed discrepancy | +0.00838278 nominal m |

Discrepancy is processed phone axial depth minus author-registered reference axial depth. The 34,186 reference-missing rays remain in the denominator but cannot receive a paired discrepancy. **They are not established phone misses.** Dense finite exported depth is not proof of 100% raw/native sensor coverage. Original confidence and tracking are unavailable.

The reference is cleaned/hole-completed FARO-derived geometry with no verified measured-versus-edited surface mask. Fixed author scale/registration, exported poses and processing, and the PLY reader's precision conversion contribute to disagreement. No alignment was fitted during evaluation. No independent hazard-event labels, body calibration or walking ground truth was supplied, so this does not establish raw sensor accuracy, hazard recall, near-feet/tiny-object coverage, clearance or collision-free navigation. It does not decide the sufficiency of the intended phone-plus-belt/additional-sensor system.

## Actual execution history

1. **Stage 05 — retained failure.** The original `vtkOBBTree` implementation hit its 600-CPU-second budget (600.1 sampled CPU seconds; 587.28 wall seconds) before producing frame metrics. Its failure receipt, logs, reviewed source and post-failure hash checks remain included. It is not relabelled as a successful run.
2. **Stage 06 — completed separate attempt.** Existing VTK 9.3.1 `vtkStaticCellLocator` completed the unchanged eight-frame/368,520-ray comparison in **48.51 wall / 49.56 sampled process-tree CPU seconds**, with **2,144,088,064 bytes sampled peak tree RSS**. This is Linux offline evaluator performance, not iPhone runtime or a hard-cgroup peak. Exact authorized caps and source changes are retained in the stage-06 protocol and receipt.
3. **Independent saved-output recount.** All saved frame/tile/bin totals and statistics reconciled, with maximum numerical discrepancy zero. The 1,846 accounting assertions are not additional trials or safety successes.
4. **Derived inspection.** Eight fixed-range 2×3 PNG panels were generated directly from the saved NPZs, with no new VTK, raycast, depth decode or fitting. Eight original RGB JPEGs remain separate and byte-identical. Diagnostic generation took 11.85 wall / 11.68 CPU seconds, peak RSS 96.87 MiB.

## Start here

- [Successful comparison and complete metrics](workspaces/blind-koivu-reference-comparison-06/run-evaluate/comparison/COMPARISON_RESULTS.json)
- [Independent result review](workspaces/blind-koivu-reference-comparison-06/POSTRUN_REVIEW.md)
- [Representative analytical panel](workspaces/blind-koivu-reference-comparison-06/inspection/run/panels/frame_00001-analytic-panel.png)
- [Separate untouched RGB exemplar](workspaces/blind-koivu-reference-comparison-06/inspection/run/original-rgb/frame_00001.jpg)
- [Failed stage-05 receipt](workspaces/blind-koivu-reference-comparison-05/run-evaluate.partial/FAILURE_RECEIPT.json)
- [Stage-06 preregistered protocol](workspaces/blind-koivu-reference-comparison-proposal-06/PROTOCOL.md)
- [Display protocol](workspaces/blind-koivu-reference-comparison-06/inspection/DISPLAY_PROTOCOL.md)

Eight `*-scheduled-rays.npz` files include the saved sampled values, pixel addresses, availability, reference cell IDs and fixed edge categories. The eight panels use nearest-neighbour displays, explicit missing regions and clipped counts; no holes are filled. Panel ranges are display choices, not acceptance thresholds. Original RGB is not blended into or transformed for those analytical images.

## Reproducibility, attribution and large assets

`PUBLIC_NORMALIZATION.md` explains path placeholders and original-versus-public hash meanings. Python code is byte-identical to the executed/reviewed source cuts; copied configuration, receipt and protocol text may be path/prose-normalized. Their original historical hashes remain preserved, so normalized configuration is **not automatically runnable against those original pins**. A new local configuration/source cut and its review are required for a fresh execution. This packet does not claim a complete clean-machine reproduction.

`RELEASE_ASSET_MANIFEST.json` identifies the already acquired, checksum-verified large archives and extracted mesh available locally for a separately authorized GitHub Release upload. They are deliberately excluded from ordinary Git payloads. No release upload or remote link is invented here; upload status is explicitly recorded. Small numerical/image diagnostics are present in this packet.

Dataset attribution: Xuqian Ren / MuSHRoom, [iPhone dataset](https://doi.org/10.5281/zenodo.10230733) and [reference mesh/point cloud](https://doi.org/10.5281/zenodo.10222321), CC BY 4.0. See `DATA_LICENSE_AND_ATTRIBUTION.md` and included official metadata snapshots. All eight RGBs received visual/privacy and embedded-metadata inspection before inclusion; see `RGB_PUBLICATION_REVIEW.json`.
