# Frozen TSDF versus saved Faro-rendered rays

**Proposal only. No implementation, geometry load or evaluation has occurred.** Execution requires the held-out stage to be terminal, an available serial CPU slot, and approval of this separate check.

## Purpose and fixed scope

Compare the frozen unfiltered TSDF with the **already saved stage-06 Faro-mesh axial-depth rays**, without reopening or raycasting the large Faro mesh. These are mostly training-view positions: `frame_00001, 00005, 00009, 00013, 00017, 00025, 00029` were integrated; only `frame_00021` was excluded. This is **not the 29-frame held-out evaluation**. It measures agreement with an independently acquired but author-processed, registered reference, not absolute physical accuracy or obstacle recall.

TSDF: `blind-open3d-author-baseline-10/koivu/unfiltered-tsdf-mesh.ply`, SHA-256 `5a75ebce93a3c65928344ce486223aa17a01a2c196982fc97edff8c41dd56e2e`, expected 242,293 vertices / 461,256 triangles. Preserve every triangle: no cleanup, completion, component selection, filtering, refusion, pose/K fitting or ICP.

## Exact saved inputs

All eight files are beneath **`blind-koivu-reference-comparison-06/run-evaluate/comparison/`**. Their current byte counts and SHA-256 values were checked against the saved stage-06 artifact manifest during protocol preparation; arrays were not decoded or evaluated.

| File | Bytes | SHA-256 |
|---|---:|---|
| `frame_00001-scheduled-rays.npz` | 432127 | `a70edf131ae109854530d9a1102aa15c6aa4249ff181696c8c385211d7f93e4c` |
| `frame_00005-scheduled-rays.npz` | 465661 | `f4c03bea01bcc9a2a6c73d3d3b5d397ae4624318d00ee6d249b8e9c9851dae6c` |
| `frame_00009-scheduled-rays.npz` | 504221 | `3bd8c91426a601968e048b2d90b0f97e87c792b3a10ac78f9526e2bb4168d321` |
| `frame_00013-scheduled-rays.npz` | 495895 | `6c75c9c50ac30b7348cc2cc3a9a16fb9239857a790f03bc34b8d8b57e568b20c` |
| `frame_00017-scheduled-rays.npz` | 496836 | `e241759c94334fe7c3d2c5c3330fd4b0cd347c7be3258f10630d1d045177999c` |
| `frame_00021-scheduled-rays.npz` | 473463 | `7074d6da51ab6eafc2d6d4074ef7ff04bc2d92bd9886ef3d90783ca5c05ef5ca` |
| `frame_00025-scheduled-rays.npz` | 440400 | `9f4808bfc1b6dc15c1966ba4f9739d6e4babba6bb9749573b95681078ba1b3ce` |
| `frame_00029-scheduled-rays.npz` | 496013 | `1b2a846146496499ac176a45f7cc782bdf079e2dd9054b63592bff20b8362b45` |

Use saved `row`, `column`, `referenceAxialRegisteredNominalMetres` and reference cell/edge evidence. **Do not use the saved sensor depth or its paired-status field to select rays.** Assert each original grid equals rows `0:994:4`, columns `0:738:4`: 249×185 = 46,065 rays, **368,520 total**, with no new pixel selection.

Pin the small existing provenance records, not the giant Faro file: stage-06 `COMPARISON_RESULTS.json` SHA `3dd8431ea152ac1019fc52e70cdeb49c2dfa8065917d92d546cf8a33f47f48cd`; `ASSOCIATION_REPORT.json` SHA `c84075e2be6cb4be7e9f247335eb28d78aafda0eeda68aeec89621f20c6f416b`; `run-evaluate/RUN_RECEIPT.json` SHA `fd36b71d05aff5b149b70affb3e8caa100f668fa27911fee5707854c114440f4`. The prior receipt verifies input/source hashes before and after that run.

Original phone pose file: `blind-mushroom-koivu-acquisition-01/selected/room_datasets/koivu/iphone/long_capture/transformations.json`, SHA `c496c8dc6474679766db8abd92da9c756104a752bb9e4519fd462fe294af90c3`. Stage-06 associated-pose SHA is `6f523cef70f1f97d4be4ef4d15650c3d242b9c70613b94ca13970951bc13ebdc`; their matched frame matrices/K were checked equal. Original fixed `icp_iphone.json` SHA `95b4e26d6d260bd9b06cff801648fc38c030a510cf4055af2294490cf49938d4` supplied a similarity scale **1.0207908442387768**. Saved reference depths already incorporate that registration and inverse-camera axial conversion; **do not apply the scale a second time**. Registration evidence is provenance, not a transform for the new TSDF query.

## Geometry and accounting

Reuse the reviewed stage-06 `reference_geometry.py` (SHA `266026051a781f122a59187f599688e8c5eb38807984b7e607401e7b4356386d`) nearest-hit, two-sided VTK locator against **only the small frozen TSDF**, in its unchanged phone-map coordinates. Use the original per-frame pose and K, and **identity phone-to-mesh transform**. Far endpoints depend only on TSDF bounds, never on saved reference depth. Retain numerical hit/axial checks and missing values.

For this comparator, reproduce stage 06 exactly: camera ray `[(u+0.5-cx)/fx, -(v+0.5-cy)/fy, -1]`. This deliberate **+0.5 convention** matches the saved reference samples; it is not the integer-centre convention of stage 11 and does not modify the TSDF's training K. No offset sweep or selection by better agreement. Run only tiny analytic convention/nearest-surface fixtures before any recorded queries.

Cross-tabulate every ray as **paired, reference-only, TSDF-only, or neither**; counts must sum to 368,520, with per-frame counts also reported. A missing reference or TSDF hit remains unknown, never zero depth/free space. Geometry errors abort; no ray is discarded as an outlier.

For all paired positive finite depths, report `e = z_TSDF - z_saved_reference`: count, signed mean and p05/p50/p95, MAE, absolute p50/p90/p95/p99 and maximum, using explicit linear quantiles. Report pooled ray-weighted and per-frame results. Stratify by **reference depth**, not phone depth: `(0,0.15)`, `[0.15,1)`, `[1,2)`, `[2,3)`, `[3,4)`, `[4,5)`, `[5,infinity)`. Provide `<4 m` and `>=4 m` summaries separately without removing either from the all-paired report; these are evaluation-camera range strata, not proof that a surface was outside every training camera's 4 m range. Preserve saved reference edge/support-boundary categories as additional strata, never an agreement mask. No adaptive erosion or selected-agreement filtering.

## Execution proposal and interpretation

Proposed limits: **120 CPU seconds, 180 wall seconds, 1 GiB sampled tree RSS, 32 MiB new outputs, 768 MiB free reserve**, serial existing VTK/NumPy only. Preflight allocated disk including other active baseline artifacts and the existing whole-experiment cap. No acquisitions, installs, large-Faro reads, mapper changes, floor classification or navigation calls. Freeze and verify source/input hashes before and after; progress JSONL stays separate from result JSON. Save per-ray derived arrays and auditable counts for independent arithmetic recount. Partial execution is incomplete, not a successful reduced subset.

The reference mesh has author edits/completion and no measured-versus-filled face mask; registration uncertainty is not bounded by the scanner specification. Native phone confidence/tracking and independent hazard/body labels are unavailable and must not be fabricated. Mostly integrated-view agreement cannot establish unseen-view generalization, physical clearance, small-object detection, causal obstacle avoidance or safe walking. No numerical safety-pass threshold is proposed.
