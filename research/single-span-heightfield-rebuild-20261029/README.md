# Single-span heightfield envelope — rebuild 2026-10-29

**SOURCE ONLY. Not compiled or executed.** This distinct research candidate has receipt schema **4**, rebuild identity `single-span-heightfield-rebuild-20261029-v1`. It does not inherit the lost candidate’s reported 34 mask comparisons / 20 refusals. Old flat/disk helpers, app policy/default, C ABI and Swift wrappers are unchanged. No activation, route/device trial or physical navigation authority.

## Reuse and exact boundary

Adapted from the published `research/maurer-native-adapter-result-20261029/native/CDetour/exact_seed_radius_envelope.h` at repository commit `c79fbd33171f78608f9eb2a1484fbc9266e3a695`. The existing Maurer integer kernel is included unchanged, with its Apache-2.0 LICENSE/NOTICE and ITK source pin `2e353bf3975631defae25f1432e3333d97ff0a95` retained in that packet. This is domain glue, not a newly invented distance algorithm.

Connection admission reuses the exact overlap/climb predicate in published `research/room-mesh-package-75/BlindRoomMesh/Sources/CDetour/upstream/Recast/Source/Recast.cpp`, `rcBuildCompactHeightfield`; unchanged `RecastArea.cpp::rcErodeWalkableArea` must run between prepare and apply. Recast source and Zlib license are already published. File SHA-256 pins accompany this candidate; a release-tag claim is not inferred merely from the file layout.

At most one span per column; absent columns remain absent. Quantized Y/H, cells and connections are never rewritten. Every span must meet walkableHeight, including isolated spans. Existing connections must be reciprocal and satisfy released overlap/climb; missing connections are preserved, not repaired. Original null-area/boundary/missing-connection/adjacent-null seeds and padded exterior seeds are frozen before stock erosion. Only extra XZ exclusion with squared distance **strictly less than radius²** is applied. Equality is retained only if stock retained it. This does not establish 3D swept clearance or traversable support.

## Ownership and transaction contract

The trusted caller owns valid, live, nonaliasing Recast arrays of declared lengths and must serialize all use. This raw-pointer helper cannot establish allocation lengths, detect freed/reused storage, or defend concurrent mutation. Prepare records the exact field/cell/span/area/receipt addresses, full cell/span bytes, cs/ch/bounds and all compact metadata. Apply accepts only unchanged topology/metadata/receipt and area values unchanged or removed. Receipt storage is opaque until apply completes; identity checks compare every field semantically, not padding. XZ extents must reproduce released rcCalcGridSize nearest-integer arithmetic. All attempts, including partial allocation or rejected apply, consume the helper; no retry/fallback. Caller must actually run unchanged stock erosion: monotone area validation alone cannot prove erosion provenance.

The exact-radius step commits area removals only after validation and kernel success; refusal leaves apply-entry area bytes untouched. It does not roll back stock erosion. Budget is internal after prepare; changing the public receipt cannot raise it. Work counts remain kernel loop/comparison visits, not topology/build work. Caps remain 65,536 spans, 250,000 padded cells, radius 1–80, 10M kernel units, and 2MiB declared scratch including topology snapshots and nine 64-byte allocation reserves. Declared bytes are not a heap/RSS proof; extra snapshots may refuse cases the flat helper admits.

## Pending gates

Source review first, then only a separately admitted serial synthetic run (60 CPU seconds, 120 wall seconds, 512MiB observed RSS, no installs/network/heavy builds). See TEST_PLAN.md when added. No comparison has passed for this rebuild. Native Apple compilation, route acceptance, qualified callers, sensor/full-body/current-hazard evidence and supervised validation remain separate gates.
