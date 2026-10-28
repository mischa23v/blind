# Occupancy diagnostic v3: projected corridors are not requested-state routes

**21 native synthetic fixtures passed. Independent review pending. No recorded-map query or movement executed.** Native C++ source and resulting binary are unchanged from v1; v3 corrects the Python diagnostic's endpoint/completion semantics and expands regression fixtures. Original v1 and v2 evidence is preserved.

## Repaired review finding

The existing Detour nearest-poly query can project a requested start13cm horizontally or23cm vertically and still return a complete corridor between its projected endpoints. v1's `geometryCandidateComplete` field was ambiguous: input immutability did not establish a checked requested-to-projected connector. The reviewer reproduced this, not a physically safe route.

v3 removes that field. It separately reports:

- `projectedCorridorComplete`: native Detour completion between projected endpoints only.
- Original requested and projected start/goal,3D and horizontal offset magnitudes and signed vertical offsets.
- `requestedEndpointConnectionsVerified=false`, `endpointConnectionStatus=notChecked`, `requestedRouteComplete=false`.
- `fullBodyCoverage=unverified`, `fullFootprintSupport=unverified`, `evidenceQualifiedTraversable=false`, `physicalAuthority=false`.

No new connector algorithm, snapping tolerance or physical authority was added. Nonfinite absent endpoint results serialize as null, not fabricated points.

## Important observed raster limitation

The mixed4/8cm topology, near-wall/goal projection, vertical/multilayer projection, diagonal bottleneck and subcell-gap fixtures are new. In the exact saved gap fixture, a **0.01000022888m unknown support gap is bridged by the4cm Recast raster**, producing a projected corridor. This explicitly does NOT pass requested-route/support admission. `rasterMayBridgeSubcellUnknownGaps=true` is retained. The raw ledger is not changed; the coarse candidate navmesh is not treated as continuous support evidence.

The larger unknown-gap fixture still stays disconnected. Neither result establishes a universal resolution/clearance guarantee. Synthetic ground labels at elevated heights remain provisional. The semantic-history/free fixture verifies present occupancy overrides historical labels; it is not a temporal freshness test. The ledger has no per-leaf capture age/decay evidence.

## Executed and preserved outcomes

`python3 research/corrected-map-route-preflight-20261028/occupancy-prototype-v3/run_prototype.py`

- v1:14/14 fixtures passed, but independent review found the completion-semantics gap.
- v2:20/21 passed. New right-edge goal fixture incorrectly assumed its projection exceeded10cm; actual displacement was9cm. This is a retained test-setup failure, not a changed production clearance threshold.
- v3:21/21 passed. Only that fixture changes to the independently reproduced left-edge13cm displacement used as a goal, retaining its >10cm assertion. Native and binding behavior are identical to v2.
- v3 build+tests:5.591s wall,5.495CPU s,66,977,792B sampled aggregate RSS,435,375B stage disk at receipt. OneCPU;1GiB sampled RSS/disk;300s wall bound. Unittest21 cases in0.160s on this producer.
- Native binary SHA256 remains `e5138123cd61aa225c57ea0171d3f05d3fe96bb1f8ef8006c3d85dd420141760`.

`PRE_RUN_FREEZE.json` binds source before execution. `history/v2/` retains the failed exact test source/freeze/log/result; original full folders remain untouched. `history/v1/` retains the ambiguous prior binding and its prior result. Native merge/coordinate semantics and reproduction prerequisites are described in the earlier v1 packet. The immutable parent native snapshot supplies verified released Recast/Detour revision9f4ce64458dfae86e1239c525ddc219c4e9e06f1 and the existing adapter; neither is modified here.

Publication is text-only under `PUBLICATION_MANIFEST.json`; no generated native binary, duplicate third-party source, recorded map/reference/depth or images are included. Independent review must approve this exact revision before any recorded-ledger experiment. Actual named A→B/table/door/return tasks, measured body profile, independent continuous contacts/support and fresh observed-volume admission remain open.
