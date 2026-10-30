# Separate observed-map ray diagnostic — source only

**Not compiled, loaded or executed.** The actual primary held-out run remains unchanged: exact three-frame reconstruction, both held-out camera origins unknown, 18,904 valid rays unscored, null residuals. See `../coffee-heldout-depth-result-20261030/README.md`. This addition cannot promote that result into clearance.

## Minimal upstream reuse

This sibling is derived from the successfully built and 38-control-tested `coffee-octomap-readonly-rays-v2-source-20261030`. It retains the exact owned Handle and official OctoMap 1.10.0 source. The original `om_ro_rays` entry point still calls the shared query helper with `observed_only=false`, retaining unknown-origin and unknown-gap refusal, range/bounds behavior and status values 0–8.

A **separately named C entry point** `om_ro_observed_rays` calls the same helper with `observed_only=true`. Only this explicit offline mode:

1. Allows an unknown origin to enter upstream traversal; occupied origins remain refused, never scored as zero error.
2. Uses official `castRay(..., ignoreUnknownCells=true, maxRange)` to locate the first *recorded* occupied voxel on the ray.
3. Returns new status **9: observed-hit-visibility-unverified**, never `hit-known-prefix`.

The same official `getRayIntersection` returns voxel entry. No custom traversal, insertion, clearing, occupancy parameter, range extension, geometry change or map update is added. All original double-domain bounds, batch/range limits and conservative unresolved errors remain. C++ Vector3 continues using its actual operator(); ordinary arrays retain []. `OBSERVATION_ADAPTATION.diff` records the complete C++/binding/runner changes.

`ReadOnlyRays.cast` still selects the original ABI. Only explicit `cast_observed` selects the new one. There is no automatic retry or fallback from conservative queries to observation queries. This code is not wired to the app or live navigation.

## What this can and cannot measure

A recorded occupied hit can provide a directional view-to-map depth comparison even if the map lacks evidence between the camera and that hit. It does **not** establish visibility: a nearer unseen physical obstacle may exist in unknown space. Range exhaustion, empty map, unknown traversal and no observed hit are never clear-space evidence. Even a good depth match is not evidence that walking along that ray is safe.

The later data driver must retain the same build frames 290/357/391, held-out frames 232/370, 8-pixel grid, original pose/K convention, exact canonical map replay and immutable maps. It must preserve the original conservative status counts alongside new observation-only counts. It must label every new residual visibility-unverified, retain every valid ray and failure, and publish both denominators. **That data driver is not changed or executed by this packet.** No frame, grid, threshold or range was tuned after viewing residuals; the original test had zero scored residuals.

Nearest-neighbor center distance is deferred. It can match a different nearby surface and hide directional mismatch; the selected next comparator preserves the actual camera ray instead.

## Controls and exact bounded build

All 16 original occupancy tests and all 22 conservative ray tests are preserved byte-for-byte. The prepared runner requires those 38 plus 10 newly authored observation-mode controls:

- Unknown origin can find a recorded surface but primary remains origin-unknown.
- Unknown gap can reach a recorded surface but primary remains unknown-before-hit.
- Occupied origin remains refused.
- Known-prefix case still receives the distinct observation status.
- Empty map reaches range exhaustion, not clear or a hit.
- Center-based range censoring is unchanged.
- Oblique entry agrees with the conservative query when a known prefix exists.
- Invalid/huge input rejection remains.
- Both modes and errors preserve all state/default/payload bytes.
- Maximum batch returns only observation hits and preserves map state.

These 10 controls are **authored, not passing**. AST and shell syntax checks do not replace a native build/control run.

The separate fresh output is `build-observation-01` in this sibling directory. Existing v1 failed build and v2 successful build are untouched. Build limits are unchanged: one CPU, 120 aggregate CPU seconds, 180 wall seconds, 1 GiB observed RSS/address-space backstop and 50 MiB output. Controls keep the earlier 512 MiB/120 CPU/180 wall limits. No new installs, downloads, namespaces, security changes or paid resources.

After independent review and verified publication, from `blind/`:

```sh
/opt/codex/runtimes/codex-primary-runtime/dependencies/python/bin/python3.12 -B -I research/coffee-octomap-observation-rays-source-20261030/build_readonly.py --admitted-source-commit <exact-published-head>
```

Review the completed guard receipt and binary SHA before the receipt finalizer, then separately admit the existing bounded control launcher with the new exact library and receipt hashes. Never reuse the prior binary hash for this changed ABI. No held-out data should run until all 48 controls complete with no failures/skips and its own data-driver source has been reviewed.

Only source, diffs, text receipts and hashes should be published. No native library, map arrays, depth or image bytes are included here. Official OctoMap BSD-3-Clause notices remain in the retained source dependency.
