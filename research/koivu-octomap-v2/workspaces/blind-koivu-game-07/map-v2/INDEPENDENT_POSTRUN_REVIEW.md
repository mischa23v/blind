# Independent recorded-map-v2 post-run review

**Saved evidence reconciles. Construction succeeded; navigation success is not established.** This is a separate addendum. All frozen sources, protocols, v1 artifacts and v2 run outputs were left unchanged.

## Independent recount scope

`recount_saved_map.py` reads saved NPZ/JSON/log files and hashes pinned artifacts only. It does not import or call the native engine, re-fuse scans, decode original phone depth, load FARO/VTK, select routes or execute motion. The recount completed in about **0.96 seconds**, with **354,660,352 bytes peak RSS**. Its 21,488 internal assertions mostly reconcile individual stored cells; they are **not additional trials or navigation tests**.

Verified all 69 frozen file pins and every output hash in the map receipt; exact 294 ordered scan identities/source hashes; full endpoint and native update totals; unique raw/native key associations; association membership in the saved native leaf export; exact score/log-odds/hit/free agreement between corresponding arrays; and saved upstream occupied-flag consistency with its frozen zero log-odds threshold. The latter is an audit of saved output, not a replacement classification authority.

Independently reconstructed support quadrants, raw ground/obstacle/below-floor classifications, all-key native evidence conditions, blocked cells, ground-conflict diagnostics, coverage Boolean logic and every emitted SurfaceCell. Original support and contradiction arrays equal v1 exactly. Original PNG bytes were not reread here; their use/verification belongs to the reviewed builder and retained manifest.

## Reconciled evidence

| Item | Count |
|---|---:|
| Recorded frames | 294 |
| Original nonzero endpoints | 215,670,168 |
| Original raw voxels | 811,806 |
| Actual raw/native association pairs | 812,380 |
| Non-centre-key associations | 574 |
| Float32 boundary-different input pixels | 577 |
| Unique associated native keys | 811,806 |
| Exported native leaves | 1,422,787 |
| Native per-scan occupied updates | 3,482,488 |
| Native per-scan free updates | 34,705,032 |
| Native leaves with both hit/free history | 699,667 |
| Original supported surface cells | 2,637 |
| V2 unblocked cells before coverage | 372 |
| V2 cells satisfying all sampled-clearance checks | 359 |

The sum of each leaf's hit/free scan counts exactly equals the corresponding sum of per-scan update counts. The final scan conflict count equals the number of exported leaves with both evidence types. No missing raw/native association was promoted to free.

The 372 candidate cells contain **33,480 fixed coverage samples**; **33,330** are admitted. Missing original projection is reported for 150 samples and native unknown for 115 samples. Those reason masks overlap; they must not be summed as disjoint failure categories. Surface blockage reasons likewise overlap. All 20,445 emitted cells match the independent Boolean reconstruction, including nullable floor/clearance and null uncertainty.

## Important retained-support limitation

There are **222 surface cells** with a raw ground voxel later marked native-free with explicit evidence. **Six of the 359 sampled-clearance cells** also have that retained-ground/native-free conflict. This matches the frozen controlled model: its original floor prior is retained and the conflict is reported, not hidden. It does **not** establish current physical support, absence of a drop, or a safe body footprint. The 3 cm ground-band/quantized floor limitation remains unchanged. No cell or route should be relabeled physical safety based on the larger candidate count.

## Resources and outcome interpretation

The runner receipt reports exit code 0 and successful bounded completion: **138.0494 wall seconds**, **136.1554 combined parent/child CPU seconds**, **452,489,216 bytes sampled/waited combined peak RSS bound**, and **15,585,849 output bytes before its receipt**. The receipt field named `waitedChildCPUSeconds` includes parent CPU in this source cut. Stderr is empty. This is an offline Linux construction measurement, not phone real-time performance.

The change from one v1 sampled-clearance cell to 359 v2 cells demonstrates a changed model output under the preregistered established fusion method. It does not show that a body fits any start, that two points are connected, that a route completes or that no collision occurs. Those questions remain with the separately authorized native-footprint/route checks and independent reference scoring. No 100-run success count follows from this recount.

## New addendum pins

- `recount_saved_map.py`: `ad9c9bab9f299f820ba1cf267c9f8d57f922fb679b6bf296663c9a032aa5b43b`.
- `POSTRUN_RECOUNT.json`: `81c49ce98389177b8144369b25b6ca43cb1b2d72add49a4df78a2b046763a74f`.
- Original map receipt: `8b5ad93b9f35b3cb7ac852f4375c208cd5e24e2b1e0b5ec076c6c8e6387d61dd`.
- Original runner receipt: `9d55f3f22ca8d6bdec904345b03e08ec3a7104ad8da8fc7906cc2a9c206eba41`.
- Original frozen cut: `c2980ab5da6c841fe86b08542439ddb745b5f85c394efccf99f816d5371cc817`.

Keep this completed review unchanged after handoff. Any later route/game review belongs in a new addendum.
