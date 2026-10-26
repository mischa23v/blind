# Independent OctoMap adapter review — build 04

**No remaining concrete blocker found for the reviewed serial, simulation-only native ABI.** This is not approval of a recorded-map import, body-clearance decision or navigation trial. The reviewer inspected source, upstream implementation and saved build/test receipts; independently hashed files; and did not compile, run tests, trace rays, load a dataset or modify any frozen cut.

## Exact reviewed evidence

| Item | SHA-256 |
|---|---|
| `octomap_adapter.cpp` | `715b3e544dff913a82ec43f49c0255297af0c3a799397faceaa66ebe97f9dff7` |
| `octomap_engine.py` | `3dc587cf7086078ff4362906fe2fbe723ea43e4bcdc6a6c6acf946f8aa308186` |
| `test_octomap_engine.py` | `d1e032ae6be16dbb99255118d1776b0df14ec5c5ffc3271bb47867ed4a434fd5` |
| `ADAPTER_PROTOCOL.md` | `42f427f9437c28fcc8c0f58014a20bae9badf428723358be746896085e359ebf` |
| `build-04/libblind_octomap.so` | `3c0a88593d07540d93dbbc3e404ee44b3f5167ff7bda74f16fc8075aab83b1db` |
| `build-04/BUILD_RECEIPT.json` | `865c81ead3e46f9e6296d459ae53baed01eb5c0db163a753b83849193280aaca` |
| `build-04/native-tests.log` | `763fb54019f4aa2a15c853278e6493cf6f9c1f94a3eeef75c2206acb2f519444` |
| `NATIVE_TEST_SOURCE_PINS.json` | `21105e8b7307602c15d6c043a462d85844d80fc44462ab45718a4b7e05776897` |

All seven manifest entries were independently rehashed and match. The build receipt's adapter and library hashes also match. Saved build-01, build-02 and build-03 source/binary hashes were checked against their own receipts; the original cuts remain preserved rather than being relabeled as the final build.

Official source is **OctoMap v1.10.0**, commit `007a0b5b6e4d3bb6c54f2c65a12234e03adcd72f`. All **48 selected files / 380,478 bytes** were independently checked against acquisition-receipt sizes, Git blob SHA-1 identities and local SHA-256 values. The [upstream New BSD license](https://github.com/OctoMap/octomap/blob/007a0b5b6e4d3bb6c54f2c65a12234e03adcd72f/octomap/LICENSE.txt) is retained; source and binary redistribution must retain its required notice/disclaimer. This review does not claim a whole-repository audit or an iPhone binary build.

## Semantics confirmed

- Native `coordToKeyChecked` supplies the actual Float32 occupied-key identity. Per-key deduplication retains the **first actual input point**, not an invented voxel centre. Native `computeUpdate` then traces those measured representative rays. Runtime checks compare occupied keys against every supplied original Float32 endpoint key. Thus occupied-key equivalence is exact at that representation; free-space evidence is a disclosed subset of full-cloud rays, not full-cloud equivalence.
- The native [compute/update implementation](https://github.com/OctoMap/octomap/blob/007a0b5b6e4d3bb6c54f2c65a12234e03adcd72f/octomap/include/octomap/OccupancyOcTreeBase.hxx#L169-L267) makes occupied keys win within a scan. The adapter checks disjointness, performs the same free-then-hit `updateNode` operations and calls `updateInnerOccupancy`. With `lazy=true`, recursive updating skips pruning; `updateInnerOccupancy` only updates parents. Finest-key hit/free evidence therefore remains associated with the exported leaf keys in this cut.
- Hit/free counters count distinct scans per key, not independent statistical measurements. Sequential ownership requires frames 0, 1, …, no repeat, at most 8,192 scans. A failed insertion retires the handle, including partial native updates. The original raw endpoint/conflict evidence is not destroyed by a later model-free update.
- Unknown is explicit: `known=0`, NaN probability/log odds and zero occupancy flag. **Zero occupancy alone is not evidence of free space.** `om_query_occupied` and keyed queries delegate classification to upstream `isNodeOccupied`; no Python threshold substitute is introduced. Non-thresholded scores remain exported, with no maximum-likelihood conversion.
- `om_keys` and `om_query_keys` avoid associating raw Float64 evidence by a reconstructed Float64 voxel centre that can map to a different Float32 native key at boundaries. Keyed Python inputs must be actual uint16 triples; negative/integer-wide inputs cannot silently wrap.
- Python uses a per-handle `RLock` for native operations and close, important because ctypes releases the GIL. Direct C ABI users still require exclusive serial ownership and valid caller-owned buffers. Query/export arrays are new Python-owned arrays. Callers must not mutate input arrays during a native call.

## Concrete blocker found and resolved

The initial adapter accepted arbitrary native-bounded coordinates while using `-DNDEBUG`. Upstream [KeyRay](https://github.com/OctoMap/octomap/blob/007a0b5b6e4d3bb6c54f2c65a12234e03adcd72f/octomap/include/octomap/OcTreeKey.h#L139-L181) has a 100,000-key backing array and assert-only capacity checks; a sufficiently long valid-coordinate diagonal could exceed it. The final native adapter checks the sum of absolute native key-coordinate differences **plus two** against actual `KeyRay.sizeMax()` before any traversal. Overlong rays are rejected and retire the handle, not truncated or passed to native code. The saved fixture verifies this refusal without attempting the unsafe traversal.

Wrapper count limits now precede conversion/output allocation: two million insert/key-conversion points, five million query points/export leaves. These and the scan cap are not an overall map-memory bound; recorded integration still needs its separately approved CPU/RSS/output/disk watchdog.

## Existing execution evidence and remaining boundary

The owner's build-04 receipt reports success, approximately **14.95 wall seconds / 14.76 CPU seconds**, and **167,321,600 bytes peak sampled/waited build-tree RSS**. The 16 saved native fixtures passed in **0.058 seconds**, including unknown handling, duplicate pixel/scan distinction, actual representative-ray geometry, occupied-wins, later explicit free-ray updates, invalid/repeated scan retirement, ray-capacity refusal, native key/occupancy equivalence, preallocation limits and serialized queries. These are adapter checks, not recorded frames, obstacle detections, rooms or safe journeys.

The default hit/miss/clamp values are upstream mapping parameters, **not calibrated physical confidence**. Recorded import must separately freeze frame order, original input/pose/intrinsics, range/ROI, Float64→Float32 conversion accounting, floor/support/clearance rules and unknown handling. No FARO-informed tuning, production confidence/tracking fabrication, actor snapping or physical-clearance authority follows from this review. The first failed endpoint-union map and all earlier evidence remain valid records and must remain preserved.

This review is complete. Keep it unchanged after handoff; review later import/results in separate addenda.
