# Next executable diagnostic: native occupancy spans into existing Recast

**Proposed, not implemented or run.** Separate geometry-only candidate connectivity from evidence-qualified traversability. The latter remains unavailable until independent body/support/unknown-space checks exist.

## Exact existing inputs and entry points

- Corrected source: `research/rtabmap-same-data-benchmark-20261028/fresh-run/octomap-stage/zup-native-grid/leaves_dataset_world.bin`, schema `ZUP_LEAF_FORMAT.json`, freeze `ZUP_PRE_RUN_FREEZE.json`, derived output pins `ZUP_DERIVED_OUTPUT_MANIFEST.json`.
- Reuse released Recast/Detour `9f4ce64458dfae86e1239c525ddc219c4e9e06f1` and current `research/room-mesh-package-75/BlindRoomMesh/Sources/CDetour/blind_detour_exclusion.cpp`. Preserve `bn_path` unchanged.
- Keep existing triangle builds unchanged. Add one separately named occupancy build entry point and factor only the current post-rasterization build tail for reuse. Do not create a replacement planner, floor fitter or smoother.
- Build/tests already work locally with the isolated library in this preflight directory. New code must use a separate versioned source snapshot/result directory, not mutate this passed receipt.

## Minimal representation

1. Read the frozen 32-byte little-endian leaf rows. `occupiedFlag` (validated against probability >=0.5) owns occupied/free state. `nativeHistoricalType` is semantic history only; a current free row is never made an obstacle by its old type. Missing octree space stays unknown.
2. Preserve each original leaf ID, center, `sizeMetres`, probability, type and state. Convert dataset-world coordinates to the planner with the proper rigid basis `Q=(X,Z,-Y)` exactly once; inverse `P=(Qx,-Qz,Qy)`. Metres remain metres. No fitting, global leveling, FARO correction or camera-path carving.
3. Feed occupied leaf **box intervals**, not endpoint points, through released `rcCreateHeightfield` / `rcAddSpan`, using conservative floor/ceil raster bounds and the actual 4/8 cm size. Then use the existing upstream ledge/low-height filtering, radius erosion, contours, mesh and Detour construction. Preserve current hard grid/node limits; do not truncate input silently.
4. Keep the current area-priority convention: provisional native-ground spans tag1, occupied nonground spans tag2, overlapping obstacle wins; map only surviving tag1 to `RC_WALKABLE_AREA`. Ground remains a **support hypothesis** for candidate connectivity, not measured supporting floor. Its original ledger label must accompany every candidate span. Do not import the old 2 mm floor classifier or choose a new band around the ground median.
5. Keep free/unknown volume outside the navmesh as a separate evidence ledger. Recast's absence of an obstruction is NOT observed free volume. First diagnostic result reports `geometryCandidateComplete`, projected endpoints, exact candidate path, `fullBodyCoverage=unverified`, `fullFootprintSupport=unverified`, `evidenceQualifiedTraversable=false`, and `physicalAuthority=false`. This honest geometry output is useful for inspecting false barriers but cannot count as successful navigation.

Why not naïve triangle cubes: 325,714 occupied leaves ×12 triangles =3,908,568 triangles, beyond the current500,000-triangle bound before vertices. Marking every ground cube side as an obstacle can additionally make obstacle-priority span merging erase its own top support. Native span insertion preserves the existing library geometry model without that huge expansion. Raster quantization must be recorded and independently fixture-checked; it is not physical measurement accuracy.

## First fixture before recorded queries

Freeze a tiny metric Z-up fixture (no dataset/FARO input): a 4×3 m supported plane, occupied columns forming a wall with an opening, an isolated low block and an overhead crossbar. All cells explicitly identify occupied-ground, occupied-obstacle, observed-free or absent/unknown. Fixture profile is synthetic and named as such, never called the user's measured body. Configure fixed planner radius/height/resolution before checking outcomes.

Required checks:

1. Basis transform/inverse preserve metric pair distances, handedness, height and box bounds.
2. An 8 cm leaf covers its whole interval; no assumed4cm truncation.
3. A free row with historical obstacle/ground type does not add an occupied span.
4. Insertion order does not change floor-touching obstacle priority or topology.
5. Open floor produces a candidate; a floor gap stays disconnected rather than filled.
6. Low occupied block and overhead crossbar obstruct the declared body; ground labels cannot erase nonground occupancy.
7. Native-ground at elevated height remains explicitly unverified support, even if Recast can propose connectivity there.
8. Identical candidate meshes with observed-free versus missing head/body volume produce the same geometry-only route but neither is misreported as evidence-qualified until the separate coverage checker exists.
9. Invalid/overflow/nonfinite inputs fail explicitly; projected start/goal remain outputs and never replace requested state; partial paths remain incomplete.

After these pass, freeze one source-only room region and endpoints, then run one bounded `bn_path` diagnostic and registered raw-ledger/path view. Keep no-path, invalid start, partial path and complete candidate separate. Do not launch the old100-episode controller.

## Prerequisites for actual A→B/table/door/return scoring

- **Endpoint frame:** historical `MATRIX.json` is recoverable at repository3750788, but its points are in an earlier fitted/leveled model frame, not documented dataset-world. The known mapping is `P=R_original.T*(B*q-t_original)`, with `B=[[1,0,0],[0,0,-1],[0,1,0]]`; the matching original R/t payload is absent from the current local/remote packet. Recover and hash it or freeze new source-observed anchors in dataset-world. Never just swap axes of the old pairs. Landmark identities for table/door/return must be checked, not inferred from the20 anonymous pair indices.
- **Body:** freeze one actual measured width/depth/height, phone-to-body transform, heading and declared uncertainty/margin profile; apply each allowance once. Existing45×30×160cm zero-margin and28cm addendum profiles are declared historical/synthetic settings, not recovered measurement evidence. Synthetic component fixtures can proceed; a user-specific route claim cannot.
- **Independent scorer:** old stage84 `run_bounded.py` episodes use reference collision/support vetoes, fitted ground exemptions, finite9-ray support and up to3.5GiB; do not reuse them unchanged. Reuse only audited upstream geometry query primitives with a new explicit scorer contract. Ground contacts, raw-body/margin contacts, connectors, turns, whole-footprint support, unknown exposure, actual executed distance and true arrivals must be reported separately. FARO remains evaluation-only, with original registration and edited-reference limitations retained, never mapper/route input.
- **No claimed support from this build:** current Apple `SavedRoomRouteCollisionOracle.swift` explicitly sets `fullFootprintSupportVerified=false`; it is not a Linux scorer or a completed whole-footprint implementation. The existing 12 wrapper tests are not an independent recorded-room collision/support evaluation.

The next practical implementation is the small span adapter + these fixtures, then one explicitly unqualified recorded-map candidate—not another mapper run and not a claim that the remaining traversability gate is solved.
