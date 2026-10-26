# Bounded OctoMap core reuse proposal

## Why this implementation

The first phone-only mapper intentionally retained every positive endpoint forever. It produced 811,806 occupied 5 cm voxels but only one fully sampled-clearance surface cell. A separate fixed cross-view diagnostic found incompatible recorded surface observations; this does not identify a hardware failure. Simply increasing the floor exclusion band cannot resolve the above-floor conflicts and would risk erasing low objects.

Use the established OctoMap occupancy update rather than author another probabilistic mapper. Explicit traversed-ray free evidence may update an earlier occupied estimate; absence/no-return never becomes free. Preserve the entire original endpoint map, source imagery, failure result and per-key hit/free-conflict counts. OctoMap model probabilities are **not calibrated physical confidence** and must never satisfy production clearance authority by themselves.

## Exact source and installed-component check

- Official release: https://github.com/OctoMap/octomap/releases/tag/v1.10.0
- Exact commit: `007a0b5b6e4d3bb6c54f2c65a12234e03adcd72f` (official tag resolves directly to this commit).
- `OFFICIAL_TREE.json` records the untruncated official Git tree; `SOURCE_SELECTION.json` lists all selected blob IDs/sizes.
- Selected 48 files / 380,478 bytes: all core headers, 9 core source files, 3 math source files, license and build-list evidence.
- Library license: New BSD / 3-clause, https://github.com/OctoMap/octomap/blob/007a0b5b6e4d3bb6c54f2c65a12234e03adcd72f/octomap/LICENSE.txt . Preserve attribution in source and binary distribution.
- Inspected installed headers/libraries and workspace: no OctoMap or Open3D installation found. Existing g++ 14.2 can compile the standalone core; no ROS, Qt, Eigen, Boost, CUDA or display dependency required by the selected core build. Own octomath sources are included. OpenMP defaults OFF and stays OFF.

## Bounded acquisition/build proposal (not yet executed)

Acquire only selected raw files at the exact commit, at most 1 MiB aggregate source bytes; verify official Git SHA1 blob identity and local SHA256 per file. No archive extraction, remote writes, package manager or system installation. Reject unexpected paths/type/size/hash and preserve partial receipts. Work directory cap 50 MiB; disk reserve 768 MiB. Direct serial g++ compilation of the 12 official translation units plus a narrow local C ABI; no CMake installation/viewer/tests unrelated to this adapter. Proposed build bound 300 CPU / 450 wall seconds, 1 GiB observed RSS. Library and ABI fixture hashes will be recorded.

## Upstream semantics to preserve

Source: https://github.com/OctoMap/octomap/blob/007a0b5b6e4d3bb6c54f2c65a12234e03adcd72f/octomap/include/octomap/OccupancyOcTreeBase.hxx

`insertPointCloud` computes unique per-scan occupied/free key sets; occupied keys win over free keys within the same scan. It then applies upstream `updateNode` log-odds updates. `discretize=true` groups endpoints into native voxel cells before tracing native rays, not image-stride sampling. This preserves endpoint occupancy at the chosen voxel resolution, not every physical thin object. Unknown absent nodes remain distinct from observed model-free cells.

Default constants (freeze unchanged, not fitted to reference or route outcomes): hit 0.7, miss 0.4, occupied threshold 0.5, lower clamp 0.1192, upper clamp 0.971. Source: https://github.com/OctoMap/octomap/blob/007a0b5b6e4d3bb6c54f2c65a12234e03adcd72f/octomap/src/AbstractOccupancyOcTree.cpp . Retain non-thresholded scores rather than converting the only saved tree to maximum likelihood; upstream `writeBinary` can discard scores and must not be the sole evidence artifact.

## Narrow next adapter, after build review

- Native core owns ray traversal, voxel indexing and occupancy updates; Python only decodes pinned original processed depth and passes original per-frame pose/intrinsics-derived points. No custom A*, raycaster or SLAM.
- Per-frame native scan update with all finite positive in-ROI endpoints; no fabricated confidence, tracking, capture time or body mount. Original Float64 projection to OctoMap's Float32 point type is explicit and measured, not claimed bit-identical to raw sensor data.
- Query returns unknown versus node score/occupied state; exposes immutable copied leaf geometry and score. Never moves/snaps the actor.
- Keep the original raw hit layer and a separate hit/free conflict history; an occupancy-model update is not a declaration that an object was absent or safe to ignore.
- A new recorded map protocol must freeze resolution, source frames/order, range/ROI, level-support model and map eligibility before construction. No FARO fitting or route-success parameter tuning. The ±3 cm floor ambiguity remains unresolved; real toys, steps and drop-offs need independent acceptance evidence.
- The separate existing Detour/NavigationSurface/actor/FARO scorer is unchanged. No 100-run game launch until a useful fixed map and route protocol exist and receive the planned review.
