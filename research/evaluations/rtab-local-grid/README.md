# Capture-scoped native RTAB local-grid bridge

This stage implements the missing native map-feedback path. Mapping, transforms, capture association, grid classification, retention and replay checks are **code-owned**. There is no LLM geometry, trajectory, clearance or movement-authority producer in this path.

## Actual implementation

1. `NativeMapping` explicitly enables the pinned RTAB depth/3D local-grid producer. Ray tracing is enabled only when that upstream build reports OctoMap support; otherwise empty-ray evidence remains unavailable.
2. A hash-checked five-file upstream overlay extracts live `RtabmapEvent` data **before renderer ownership transfer**. It reuses existing node-local ground/obstacle/empty grids, not a new SLAM or ray-carving implementation.
3. Original AR capture uptime and all 16 camera-matrix float columns are copied through the native input boundary. A bounded registry binds the exact upstream epoch timestamp to those original values before camera input publication. Unknown/evicted/duplicate associations are not restamped with callback time.
4. A synchronous bounded C packet copy preserves distinct classes, original counts, truncation, node/map IDs, graph/frame revisions, corrected node poses and the RGB-model optical camera pose. The C callback copies into an independent Swift mailbox; it never retains/upgrades the native engine owner. Unregister drains active callbacks before releasing context; owner lookup happens only in the main-queue drain. This mapping owner does not register unused legacy raw-self renderer/UI observers; the native pointer defaults to null until an observer explicitly registers.
5. The Core consumer corrects retained tiles using poses from the same graph event and evicts omitted nodes. A missing current grid does not invent support or prevent valid graph corrections. Current pose expires after 0.5 seconds, history after 30 seconds. Limits are 32 retained tiles, 16,384 retained cells, 64 graph poses, 4,096 copied cells per class and 128 capture associations.
6. Native frame integration retires tracking loss before the app throttle. Original RGB/depth mapping is deferred until urgent hazard handling completes and remains independent of `DepthSampler`'s upright-heading admission. Stale/future frames never reach this deferred mapping work. New map/session ownership and invalid future loss timestamps cannot revive or poison prior captures.

Frames are explicitly RTAB node/base-local 3D and RTAB-map Z-up. The RGB-model optical transform is not the raw ARKit camera convention. No yaw-only conversion, fabricated floor Z, zero uncertainty, fixed-covariance accuracy claim or physical localization acceptance is added.

## Reproduce the bounded checks

With installed C++14, Swift5.9+, Python3 and Node, from a complete merged checkout:

```sh
python3 research/evaluations/rtab-local-grid/run-focused.py
node --test tools/test/observed-scene.test.mjs tools/test/spatial-review-regressions.test.mjs tools/test/contextual-capabilities.test.mjs
```

The runner downloads nothing. It compiles the **production C++ helper**, the actual Core consumer, the exact existing matrix declarations, and the exact Swift C-callback fragment extracted from the committed overlay. Only the ARKit/RTAB engine shell is a fixture. It tests packet bounds, original association, callback draining, copied-buffer lifetime, coalescing, cancellation, owner release, corrections, missing poses and expiry. `--work-dir PATH` reuses a local build directory; `--overlay PATH --skip-source-contracts` permits a pre-merge source projection. Source hashes are printed.

Recorded result: **20 Swift tests passed** (15 Core consumer, 5 actual callback-fragment interoperability), production C++ helper checks passed, **7 new source contracts + 41 existing contracts passed**, and native Swift syntax parsing passed. The five-file patch applies and reverses against exact pinned preimages. See `receipt.json`.

Review found and fixed two callback-lifetime hazards before this freeze: an unretained raw owner could outlive registration; upgrading a weak owner inside a draining C mutex could trigger recursive native destruction. The final independent mailbox avoids both. A source-order mutation initially remained before the throttle and was corrected to actually move after it. Existing exact loss-prefix tests initially rejected the newly added retirement hook; the expected prefix was narrowly extended and missing/asynchronous-hook mutations added. Original failures are retained in the verification record; no planner or evidence threshold was weakened.

## Upstream and native build boundary

Upstream: [RTAB-Map a4e7f13522722878dea3f07e8fd082291e72eb49](https://github.com/introlab/rtabmap/tree/a4e7f13522722878dea3f07e8fd082291e72eb49), BSD-3-Clause. Source APIs/configuration were checked at that exact revision. The overlay is in `integration/rtabmap/`; `tools/prepare-rtabmap.mjs` verifies preimages/postimages and prepares the **actual** `BLIND_RTABMAP` Xcode target.

The portable tests and default app target do **not** compile or execute the full RTAB/ARKit engine. The bounded hosted device-arm64 build plan, exact dependency-archive pin, resource ceilings, simulator incompatibility and transitive-license caveats are in `native-build-plan.md`. No dependency download, hosted activation, native app binary or physical trial is claimed by this receipt.

This stage provides real native map packets/corrected tiles and pose feedback. Existing current-observation planning remains separate from historical RTAB clearance. Measured terrain intervals, body/mount calibration, independent error evaluation and reviewed physical issuance are still needed before this feedback can authorize a walking route. Unknown, absent, occluded, expired or truncated data never becomes full-body clearance.
