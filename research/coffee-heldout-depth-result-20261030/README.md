# Held-out camera depth: exact reconstruction, missing known-prefix visibility

The bounded evaluator completed in **3.488 wall seconds  / 3.518 CPU seconds**, peak worker RSS **129,812 KiB**. These are worker receipt metrics, not independent aggregate process-tree measurements. The original three-frame map was recreated byte-identically, and every map payload, default and state count remained unchanged before/after both held-out queries. No holdout insertion occurred.

**All 18,904 valid fixed-grid rays started in unknown camera-origin voxels. Therefore 0 rays received depth residuals.** The archived residual distributions are null, not zero-error. Original frame 232 produced 9,593 origin-unknown rays; frame 370 produced 9,311. No alternate frame was substituted and unknown space was never marked clear.

This says the three construction scans did not establish the free-prefix visibility required by this particular ray test from the held-out viewpoints. It is **not evidence that the baseline failed to reconstruct**, nor that all observed room surfaces disagree, nor that either position is physically blocked. The exact same map was recovered successfully. Occupied endpoint overlaps exist independently of the missing prefix.

## Endpoint observations, with full denominators

| Heldout | Valid raster endpoints | Known occupied | Known not occupied | Unknown | Hit/free conflicts |
|---|---:|---:|---:|---:|---:|
|232|603,284|123,827|18,075|461,382|0|
|370|586,204|365,844|42,635|177,725|18,878|

| Heldout | Distinct endpoint keys | Known occupied | Known not occupied | Unknown | Hit/free conflicts |
|---|---:|---:|---:|---:|---:|
|232|8,018|857|353|6,808|0|
|370|9,219|4,580|1,130|3,509|357|

Conflicts overlap the primary partition and are not an additional mutually exclusive category. Each raster has 733,572 pixels; zero-depth 0 for both; >=4m exclusions 130,288 and 147,368. Each fixed grid has 11,625 candidates; >=4m exclusions 2,032 and 2,314. No data was silently omitted from these denominators.

The first view's occupied-key overlap is 10.69% of its distinct endpoint keys; the second is 49.68%. These are **endpoint occupancy overlap**, not reconstruction accuracy, obstacle recall or safe-navigation percentages. Pixel-weighted counts include repeated/upscaled depth evidence and must not be treated as independent samples. Known-not-occupied is a posterior map classification, not certified physical clearance.

## Next bounded diagnostic, proposed separately

Preserve this primary visibility result unchanged. The next candidate is an explicitly separate **observed-surface query** using official OctoMap castRay(ignoreUnknown=true). It may locate an already recorded occupied voxel along the same camera ray even when the origin or intervening space is unknown. It must expose a distinct observed-hit-with-unknown-visibility status, never hit-known-prefix, and retain occupied-origin refusal, the same range limits, all fixed rays and exact map immutability. Original ray ABI/defaults and all 38 passing controls remain unchanged.

This mode can measure directional recorded-map consistency without pretending to certify visibility. A hit behind unknown space is not a safe path, nor proof no nearer unseen obstacle exists. Zero observed hits/range-exhaustion is not free space. It is an offline diagnostic only, not a live-guidance fallback. Nearest-neighbor voxel-center distance was considered but deferred: it can match a different nearby surface and hide directional error. No nearest-neighbor implementation or new native run was performed for this report.

Only text results/source hashes are published. The two extracted depth PNGs remain local. Neither this result nor the proposed next diagnostic aligns the original Polycam mesh or permits real navigation.
