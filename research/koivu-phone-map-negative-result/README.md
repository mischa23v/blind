> Storage note: the original 15 MB MAP.npz is preserved in two byte-exact parts in its original map directory, with MAP_STORAGE.json and restore_map.py. Run the helper to reconstruct and verify the unchanged original. This addresses the connector request limit, not a GitHub file-size restriction. Historical packaging receipts describe the original 44-file packet; this transport representation adds three files and changes only this README note. No model results or executed source bytes changed.

# First recorded-phone map: build completed, useful navigation map did not

**Zero real-room game journeys were executed. The proposed 100 journeys remain unrun.** A completed map-building process is not a successful navigation result; standing still or manufacturing 100 unavailable-route records would not meet the goal.

This additive evidence snapshot preserves the original first map, source/protocol pins, test logs and subsequent diagnostic results. It does not replace or repair that failed-usefulness model.

## Actual first-map result

The offline mapper used **294 original processed iPhone depth-frame entries**, fixed associated poses/intrinsics and no FARO input. It retained **215,670,168 positive depth endpoints** in **811,806 occupied 5 cm voxels**, then produced a **145×141 surface grid**.

| Recorded map count | Value |
|---|---:|
| Surface cells | 20,445 |
| Floor-supported cells | 2,637 |
| Supported and unblocked candidate cells | 13 |
| Cells passing all declared finite clearance samples | **1** |
| Real-room game journeys executed | **0** |

The build exited normally in **98.03 wall / 96.70 CPU seconds**, with **435,204,096 bytes peak sampled-or-waited RSS**. It did not produce a useful demonstrated A-to-B route for the declared body model. Confidence and original tracking were unavailable, gravity/floor were estimated, and sampled clearance is not a continuous swept-body or physical safety guarantee.

The **same 17 map unit tests passed** in retained logs. Re-running those fixtures does not turn them into 34 independent tests or real journeys. Sibling game/controller/Swift-worker files are outside this map/diagnosis packet and are not presented as real-data integration evidence. No passing fixture count overrides the actual unusable first-map outcome.

## What diagnosis established

Read-only saved-map inspection found no apparent voxel-height or flattened surface-index mixing defect. The floor fit's extremely small residual was over quantized voxel centres and can collapse to one height bin; it is **not measured physical floor uncertainty**. The model retained widespread endpoint obstruction, including many hits well above the 3 cm floor band. The evidence did not authorize discarding points, broadening tolerances or using evaluator/FARO truth to force routes.

A separately fixed phone-only multiview diagnostic retained **all 557 directed pairs**: 293 at lag 1 and 264 at lag 30. It completed in **14.24 wall / 14.57 CPU seconds**, observed peak RSS **240,181,248 bytes**. The independent review verified pair ordering, category reconciliation and all 294 patch records; it did not recompute pooled quantiles from raw residual arrays, which were not retained.

| Fixed lag | Scheduled source samples | Available target comparisons | Cross-view inconsistency candidates | Candidates / available |
|---|---:|---:|---:|---:|
| 1 frame | 3,406,125 | 2,329,759 | 207,735 | 8.92% |
| 30 frames | 3,069,000 | 143,306 | 42,722 | 29.81% |

The lag-30 fraction describes a **small-overlap subset** (4.67% available), not the whole sequence. Candidate inconsistencies can involve pose/export processing, motion, sampling, thin surfaces and disocclusion; they do not isolate phone hardware error or provide a valid point-removal rule. No original confidence was invented. This one processed recording does not establish that the room is unwalkable or that the intended phone-plus-belt/additional-sensor system is infeasible.

## Evidence and assets

- [Frozen map protocol](workspaces/blind-koivu-game-07/map/MAP_PROTOCOL.md) and [source/data pins](workspaces/blind-koivu-game-07/map/FROZEN.json)
- [Map counts and output hashes](workspaces/blind-koivu-game-07/map/run-01/map/MAP_RECEIPT.json)
- [Exact original map NPZ](workspaces/blind-koivu-game-07/map/run-01/map/MAP.npz) — 14,921,426 bytes
- [Exact original surface JSON](workspaces/blind-koivu-game-07/map/run-01/map/SURFACE.json) — 1,449,098 bytes
- [Saved-map diagnosis](workspaces/blind-koivu-game-07/map/MAP_INDEX_DIAGNOSIS.md)
- [Fixed multiview diagnostic](workspaces/blind-koivu-game-07/map/diagnosis/DIAGNOSTIC_PROTOCOL.md), [all results](workspaces/blind-koivu-game-07/map/diagnosis/multiview-run/RESULTS.json), [independent review](workspaces/blind-koivu-game-07/map/diagnosis/INDEPENDENT_MULTIVIEW_REVIEW.md)

The top-down PNG is preserved **only as an ad-hoc diagnostic display**: its generating command/source was not saved, so an exact reproducible invocation is unavailable. Its red curve is an exported camera trajectory, not measured body motion or free-space truth. It is not used as independent numerical evidence.

Early/middle/late original RGBs are kept separate and byte-identical after inspection. The middle image visibly contains a closed door and an institutional evacuation diagram; no people or personal identifiers were apparent. This disclosure is not a general privacy guarantee. No full 294-frame depth-image collection, original full pose file, compiled worker, large archive or reference mesh is included in Git. The depth selection/manifests retain exact hashes; the source archive has been separately released by the maintainer and is identified in `SOURCE_ASSET_REQUIREMENTS.json`.

Dataset attribution: Xuqian Ren / MuSHRoom, [iPhone dataset](https://doi.org/10.5281/zenodo.10230733), CC BY 4.0. This is an offline processed-input/model diagnostic, not live iPhone validation, obstacle recall, body-clearance evidence, or a completed navigation game.

See `PUBLIC_NORMALIZATION.md` for original/public hash semantics, omitted artifacts and strict limits on reproduction claims. All original private evidence remains unchanged; no heavy run or external publication was performed during packaging.
