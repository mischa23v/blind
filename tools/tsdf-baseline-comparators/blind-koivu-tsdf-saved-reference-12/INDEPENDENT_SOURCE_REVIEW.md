# Independent source review — TSDF versus saved registered reference

## Disposition and scope

No concrete blocker found for the separately approved, fixed eight-view check. This is a source/provenance review, not a result review or physical-safety certification. The reviewer performed only source inspection and SHA-256/byte-count checks: no NPZ decoding, native imports, fixtures, mesh loading, reference rays or TSDF queries.

Final freeze SHA-256: `00516a1182ad3f961ea66017d83561e07bbadbebb996e8c2c355f58d5de333c9`. The freeze and **all 22 listed source/input pins** were independently rehashed and sizes checked; every value matched. Runtime adds the freeze itself as pin 23.

## Scientific adapter

- Existing stage-06 +0.5 camera rays exactly match the saved reference sampling; stage-11 integer-centre rays are deliberately not reused here. This does not alter the TSDF's training calibration.
- The original phone pose and identity phone-to-mesh transform query the unchanged small TSDF. The saved reference depths already include the author's registration and inverse-camera axial conversion. No second similarity scale is applied, and no full FARO mesh is opened.
- Geometry-only far endpoints are independent of saved reference depth. The reviewed nearest-hit two-sided locator and original-double versus VTK readback validation are reused unchanged.
- Every scheduled ray is counted as paired, reference-only, TSDF-only or neither. Errors are **TSDF axial depth minus saved reference axial depth**. All paired finite positive values remain in the primary report, including depths >=4 m; below/above-4 summaries are additional strata only.
- Range strata are reference-depth-based. Stage-11 edge code meanings match the saved stage-06 codes, including -1 for missing centre. Saved sensor depth/status are not used to select rays or pairs.
- Exact view association is seven integrated views and one excluded view. This is not the 29-view held-out check, absolute physical accuracy, obstacle recall, free-space evidence or navigation success. The processed reference has edited/completed surfaces and no measured-versus-filled mask.

## Launcher and provenance

The derivative launcher retains the reviewed external expected-freeze-SHA check before JSON parsing, per-phase same-file-descriptor pin verification, exclusive outputs, independent JSON results and progress, serial worker settings, kill/wait cleanup and sampled tree watchdog. Approved limits are 120 combined CPU seconds, 180 wall seconds, 1 GiB sampled RSS, 32 MiB new output and 768 MiB free reserve. Combined allocated accounting covers the baseline, stage 11 and stage 12 once each plus the existing 5 MiB outside-metadata reservation under 900 MiB. Sampled limits are not a cgroup guarantee.

The freezer anchors the exact eight saved NPZ hashes/sizes, three stage-06 provenance records, original phone pose, unchanged TSDF, training freeze, completed held-out receipt, and both imported reviewed source files. The final narrow addition also pins `POSTRUN_RECOUNT.json` to `73e1b1d67f47b90ee8e080779d2ff70cc53d02af378f396548ab402f9a15b092` and requires `success == true` and `scheduledRays == 1335885` before creating the freeze. Both prerequisite values were independently checked.

## Exact reviewed pin inventory

Paths are relative to `$WORKSPACE`.

| Role | Path | Bytes | SHA-256 |
|---|---|---:|---|
| trainingFreeze | `blind-open3d-author-baseline-10/KOIVU_FROZEN.json` | 172958 | `89e4f8add800d85b772a5314f88c45dbecb1dd5536c0b61c9f5f533727f942d4` |
| pose | `blind-mushroom-koivu-acquisition-01/selected/room_datasets/koivu/iphone/long_capture/transformations.json` | 239937 | `c496c8dc6474679766db8abd92da9c756104a752bb9e4519fd462fe294af90c3` |
| protocol | `blind-koivu-tsdf-saved-reference-12/PROTOCOL.md` | 6896 | `88386d8d0c74852f93a589911fc7ed79937e64489ce21354cd855e050d0000b0` |
| mesh | `blind-open3d-author-baseline-10/koivu/unfiltered-tsdf-mesh.ply` | 12538508 | `5a75ebce93a3c65928344ce486223aa17a01a2c196982fc97edff8c41dd56e2e` |
| referenceResult | `blind-koivu-reference-comparison-06/run-evaluate/comparison/COMPARISON_RESULTS.json` | 131189 | `3dd8431ea152ac1019fc52e70cdeb49c2dfa8065917d92d546cf8a33f47f48cd` |
| associationReport | `blind-koivu-reference-comparison-06/run-evaluate/comparison/ASSOCIATION_REPORT.json` | 3348 | `c84075e2be6cb4be7e9f247335eb28d78aafda0eeda68aeec89621f20c6f416b` |
| referenceReceipt | `blind-koivu-reference-comparison-06/run-evaluate/RUN_RECEIPT.json` | 7743 | `fd36b71d05aff5b149b70affb3e8caa100f668fa27911fee5707854c114440f4` |
| heldoutReceipt | `blind-koivu-tsdf-heldout-11/run-01/RUN_RECEIPT.json` | 11261 | `995e9e1dad642eb120194a7029f791b8b3169760cda68e0fe52887ebd25b9436` |
| heldoutRecount | `blind-koivu-tsdf-heldout-11/POSTRUN_RECOUNT.json` | 106868 | `73e1b1d67f47b90ee8e080779d2ff70cc53d02af378f396548ab402f9a15b092` |
| source | `blind-koivu-tsdf-saved-reference-12/evaluate.py` | 7997 | `ec79ac2ca43be4e1b60c621c8f02e8df0ad29f65baf7d1a853c947f47ab75ec8` |
| source | `blind-koivu-tsdf-saved-reference-12/run_bounded.py` | 11872 | `5154829b5555ea73dee314b3eb2d13e4f5199a80dee1aab09e7c23bcb1c2b951` |
| source | `blind-koivu-tsdf-saved-reference-12/freeze_inputs.py` | 7191 | `40b9c5f63d72058af1697a1fb6b57431a2fe2914869c108a3bcb42f0f967945e` |
| source | `blind-koivu-reference-comparison-06/reference_geometry.py` | 10435 | `266026051a781f122a59187f599688e8c5eb38807984b7e607401e7b4356386d` |
| source | `blind-koivu-tsdf-heldout-11/evaluate.py` | 12757 | `30b7fa320f9f2d369080e75e96f5f20fcdce5f2793ade3b698b51c7560b23cf2` |
| savedReferenceRays | `blind-koivu-reference-comparison-06/run-evaluate/comparison/frame_00001-scheduled-rays.npz` | 432127 | `a70edf131ae109854530d9a1102aa15c6aa4249ff181696c8c385211d7f93e4c` |
| savedReferenceRays | `blind-koivu-reference-comparison-06/run-evaluate/comparison/frame_00005-scheduled-rays.npz` | 465661 | `f4c03bea01bcc9a2a6c73d3d3b5d397ae4624318d00ee6d249b8e9c9851dae6c` |
| savedReferenceRays | `blind-koivu-reference-comparison-06/run-evaluate/comparison/frame_00009-scheduled-rays.npz` | 504221 | `3bd8c91426a601968e048b2d90b0f97e87c792b3a10ac78f9526e2bb4168d321` |
| savedReferenceRays | `blind-koivu-reference-comparison-06/run-evaluate/comparison/frame_00013-scheduled-rays.npz` | 495895 | `6c75c9c50ac30b7348cc2cc3a9a16fb9239857a790f03bc34b8d8b57e568b20c` |
| savedReferenceRays | `blind-koivu-reference-comparison-06/run-evaluate/comparison/frame_00017-scheduled-rays.npz` | 496836 | `e241759c94334fe7c3d2c5c3330fd4b0cd347c7be3258f10630d1d045177999c` |
| savedReferenceRays | `blind-koivu-reference-comparison-06/run-evaluate/comparison/frame_00021-scheduled-rays.npz` | 473463 | `7074d6da51ab6eafc2d6d4074ef7ff04bc2d92bd9886ef3d90783ca5c05ef5ca` |
| savedReferenceRays | `blind-koivu-reference-comparison-06/run-evaluate/comparison/frame_00025-scheduled-rays.npz` | 440400 | `9f4808bfc1b6dc15c1966ba4f9739d6e4babba6bb9749573b95681078ba1b3ce` |
| savedReferenceRays | `blind-koivu-reference-comparison-06/run-evaluate/comparison/frame_00029-scheduled-rays.npz` | 496013 | `1b2a846146496499ac176a45f7cc782bdf079e2dd9054b63592bff20b8362b45` |
