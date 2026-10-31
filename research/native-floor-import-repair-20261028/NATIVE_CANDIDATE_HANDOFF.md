# Native floor-import candidate handoff

## Exact scope and readiness

`CANDIDATE_SOURCE_PINS.json` enumerates the eight production/test files for this checkpoint. Root owns publication and active-pin overlays. No project membership edit is required: the existing app/test files remain in their targets, and the already-linked local BlindRoomMesh package discovers its new Swift source and declared CEarcut target.

**Implemented and independently code-reviewed; Swift/iOS execution pending.** Linux C++ bridge tests are not iOS evidence. Preserve failed run40765137795 and both empty-buffer platform probes. No activation of physical guidance, tolerance relaxation, guessed floor fill, or renderer-dependent production path.

## CPU tessellation and provenance

- [Mapbox earcut.hpp v3.2.4](https://github.com/mapbox/earcut.hpp/tree/92acda9e2ed96ff1f910cda35de444727e9da7b0), revision `92acda9e2ed96ff1f910cda35de444727e9da7b0`, ISC license; header git blob `35365e38f61bdfefe95688970afa9fae91528cbe`, SHA256 `ded9fbf9922d7d16374d4f55e1f7f76d605e53fb7fc2ef5c9e146bb669ed3d51`. Header and license are unchanged. Upstream build/test outcomes, including Format failure, are retained in `UPSTREAM_BUILD_RECEIPT.json`.
- Minimal C ABI supplies one already-validated ring, at most 1,024 original Double XY coordinates, bounded output of at most 3,066 indices; no holes, refinement or generated positions. It catches C++ exceptions at the boundary. Swift bridge validates bounded finite input and returned indices. The app still rejects malformed/non-simple rings and independently verifies winding, positive triangle area, total area and complete oriented boundary. Upstream is not trusted to repair an invalid ring.
- Routing vertices are the original RoomPlan Float32-decoded corners, including their local plane offset, transformed once through the existing verified source frame. Concavity is retained. Existing source bounds and numeric allowance are unchanged. Raw floor slab remains available for audit but its artificial rim/underside cannot become routing support.
- Package C++ standard changes from C++11 to C++14 because the released header requires C++14. CDetour/Recast source and its existing compiler flags are unchanged. The new CEarcut target alone allows exceptions. The next native run must rerun baseline wrapper fixtures and manual package clients; CI owner updates their explicit object/module-map link inputs without rewriting historical receipts.

## Narrow raw-triangle normalization

- Actual same-export Apple/OpenUSD witnesses identify four Hallway2 Wall4 faces with exact duplicate source positions; their world positions preserve the same duplicate pairs. Bedroom3 has none. This is separate from the empty SCNShape failure.
- Only those exact duplicate-position faces can be omitted from the triangle-collision representation. No area epsilon, thin-face deletion, coordinate merging, feature removal or invented line thickness. Distinct-collinear faces, nonfinite data, source/world duplicate disagreement, transform-induced collapse, unwitnessed/bogus duplicate receipt and all-degenerate mesh/feature remain failures.
- Raw vertices, triangle order/indices, semantic IDs and raw triangle budget are unchanged. A bounded receipt retains each removed face's raw global triangle index, feature ID, indices, source positions and world positions. Its JSON export exists only in the unchanged two-public-fixture digest-gated test inventory; private app rooms are not logged or uploaded.
- [Open3D 0.19 exact duplicate-vertex and degenerate-index cleanup](https://github.com/isl-org/Open3D/blob/v0.19.0/cpp/open3d/geometry/TriangleMesh.cpp) is the established cleaning precedent, adapted narrowly without importing Open3D or epsilon merging. Independent actual-USD review verifies unchanged positive-area triangles and bounds; removed line interiors are not covered by the retained surfaces. **Do not claim full geometric-pointset equivalence or current physical clearance.**

## Authored native regressions (not executed locally)

In `SavedRoomRouteMeshAppleFixtureTests.swift`:

- Original public fixture raw counts 334/236, omitted counts 4/0, receipt identity/index/endpoints, and every remaining non-floor corner's exact Double bits, ordered face and semantic ID.
- All three duplicate pairs/all-identical; distinct-collinear, transform-collapse/mismatched pairs, malformed/nonfinite, and tiny positive-area behavior.
- Valid wall plus duplicate plus tiny furniture retains exact non-floor geometry/order/labels and bounds; missing/extra/duplicate/out-of-range receipt and all-degenerate non-floor feature reject.
- Both source windings; exact original concave vertices/nonzero plane; crossing, duplicate corner, nonadjacent touch, adjacent backtrack, repeated closing corner and nonplanarity rejection.
- Existing raw-slab, source-frame, complete-boundary, door/furniture, collision-oracle and route/journey suites remain required. Native metadata captures SCNShape buffer inventory alongside the CPU adapter failure stage, without interpreting empty generated buffers as support.

The independent C++ reviewer rebuilt and reran all ten bridge tests; the independent exact-degeneracy reviewer approved the adapter and authored regressions. This is review evidence only until the free public Apple checkpoint executes successfully.
