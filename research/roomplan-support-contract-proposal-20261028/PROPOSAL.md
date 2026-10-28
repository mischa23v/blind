# RoomPlan support contract correction proposal

Status: design and code review only, 2026-10-28. No production predicate, mesh, test expectation, path, or source fixture changed. This proposal is not an implementation or measured improvement.

## Recommended correction

Keep the Apple-exported scene and the original RoomPlan semantic floor polygon as **different representations with explicit provenance**. Do not force a zero-depth semantic surface to contain every vertex of an exported visualization solid. Do not promote the solid's added floor rim or underside into support.

1. Continue importing the exact Apple `.mesh` export through Model I/O, with the unchanged hash, metadata identity, finite-coordinate, index, resource, time and topology checks. Preserve a raw export representation for inspection and independent reference comparison.
2. Validate identity and coordinate frames against source features. A source feature's semantic parent is not an instruction to apply its transform a second time. Match the metadata-bearing feature frame, account for actual USD/MDL ancestry, and verify the complete transform chain. Never assume every future leaf mesh has an identity local transform merely because these fixtures do.
3. Treat planar-versus-solid residuals as recorded representation differences, not automatically as a wrong scale or malformed mesh. Retain strict numerical source checks for comparable quantities: source feature frames, dimensions of the no-model-provider furniture boxes, and original floor boundary. Do not introduce a 0.16 m exception, a guessed extrusion direction, or an inflated numerical epsilon.
4. Construct a separate **historical RoomPlan support polygon** from the original floor `polygonCorners` in their local plane. Use a released tessellator, initially Apple's `SCNShape(path:extrusionDepth: 0)` with a straight-segment path and no bevel. Apple documents this as a flat, one-sided shape; the generated geometry must still pass area, boundary, orientation and concavity tests before use. Extract through documented SceneKit geometry sources/elements or its Model I/O bridge, with the same bounded buffer validation as other geometry.
5. Apply the original floor transform exactly once. Preserve input coordinates. Report orientation; reject unsupported/ambiguous output rather than silently flipping a mesh or guessing the floor. Only this source-bounded floor representation supplies historical route support. The exporter-generated floor slab remains in the raw visualization/evidence scene, not the route-support scene and not a fabricated physical floor obstacle.
6. Retain all exported **non-floor** wall, door, window and furniture geometry, including cutouts and solid extensions, as the conservative historical obstacle representation. Do not shave wall ends or remove raised objects to obtain paths. Such extensions can overblock a real passage and must be measured/reported; this proposal does not assert those solids are surveyed physical thickness.
7. Keep `physicalAuthority == false`, `actualWorldCoverageKnown == false`, and historical-door-state limitations. RoomPlan polygons are processed model output, not a proof that every underlying point was observed clear or that it remains clear now. Live floor/drop/obstacle evidence remains a separate unresolved requirement.

This is a representation adapter, not a new reconstruction algorithm. OpenUSD is the independent reference reader, not a required on-phone dependency.

## Exact current code defects and integration points

- `ios/BlindAssist/SavedRoomRouteMeshAdapter.swift:174-186`: every exported vertex is converted to world coordinates and passed to `verifySourceBounds` before any semantic distinction.
- `:294-306`: the original floor polygon or source dimensions define a zero-depth min/max box. This is a useful diagnostic of representation differences, but an invalid universal containment contract for Apple's exported solids.
- `:220-222`: every face tagged with a floor feature UUID becomes floor support, including underside and sides. The current rejection masks this next defect.
- `:25-31`: snapshot fields conflate raw export and route-support triangles. Add explicitly named raw-export and routing representations, or a separate routing adapter result. Do not silently change what the existing `vertices` field means while documentation still says raw copied export.
- `:37-39`: documentation currently promises no floor filling and no winding repair. Any new source-polygon tessellation must explicitly state that it creates a processed historical support representation. Do not leave this contract misleading.
- `:248-259`: only one non-curved floor with an explicit polygon is admitted. Keep that bounded supported subset for this correction. Multi-level support is a separate feature, not an implicit flattening.
- `ios/BlindAssistTests/SavedRoomRouteMeshAppleFixtureTests.swift:715-757`: existing area, original-boundary and fixed concavity-witness tests are directly valuable. Do not weaken them to fit the exported rim.
- `ios/BlindAssistTests/SavedRoomRouteCollisionOracle.swift:124-128`: a UUID cannot appear as both floor and obstacle. Feeding the exported slab sides as obstacles while its top is floor would break this contract. Separate raw visualization from the routing mesh rather than duplicate one floor UUID into mixed roles.
- Route/journey harnesses currently feed the same snapshot arrays to Recast and SceneKit. Feed the newly explicit historical routing geometry to both, but retain a separate raw-scene overlay and independent ground truth comparison so the oracle cannot merely validate the planner against the same flawed omission.

## Before adoption: complete same-file native parity

The current OpenUSD work proves all 24 reference feature frames, 133 anchor distances, furniture bounds and two native first-wall witnesses. It does **not** prove full native vertex/triangle parity. Extend the diagnostic before calling the importer correct:

1. Reuse the exact two retained public USDZ files and metadata; pin their hashes. Import those same bytes in Model I/O and OpenUSD. If an Apple test re-exports, retain the new bytes and compare that new pair instead; never mix old reference data with a new export.
2. Collect every feature's metadata UUID, ancestry, local-to-world transform, local/world positions, triangle connectivity, orientation, face counts, bounds and duplicate counts. Fail on missing, unknown or duplicated identity assignments rather than nearest-neighbour matching.
3. Compare vertex and triangle geometry in world metres with a written Float32 roundoff budget. Parser vertex ordering may differ, so use canonical coordinate/triangle multisets while checking duplicate counts and winding separately. A bounding-box match alone is insufficient: it cannot detect a missing chair leg, filled doorway or interior triangulation difference.
4. Require zero unmatched source features and zero unmatched geometry within the stated arithmetic allowance. Check every non-floor mesh used for collision; distinguish production export from diagnostic export.
5. Mutation regressions: centimetre/metre factor, transposed matrix, parent transform applied twice, wrong axis, shifted vertex, missing face, reversed orientation, unknown metadata UUID and dropped furniture must fail the appropriate integrity/geometry test. A matching overall bounding box must not let the missing-face mutation pass.

No universal extrusion limit should be inferred from these two rooms. Separate ingestion validity, source consistency, independent import parity and physical accuracy in results.

## Tessellation and support regressions

Run first on the exact source Hallway2 8-corner concave polygon and Bedroom3 4-corner polygon, then bounded synthetic witnesses:

- Generated support boundary equals the source polygon in both directions; total nonoverlapping triangle area equals polygon area within numerical roundoff.
- Every support triangle lies on the source floor plane and in the polygon; no bounding-rectangle or naive-fan bridge across a concavity.
- Hallway fixed unsupported witness `(0, 0.5)` remains unsupported.
- Points in the measured export-only rim remain unsupported, including near each side and concave regions. Slab side/underside faces cannot support a route.
- Both polygon winding orders, repeated closing vertex, degenerate/zero-length edge, self-intersection, nonplanar polygon, nonfinite coordinate and out-of-budget polygon have explicit tested outcomes. Do not silently repair malformed inputs.
- Rotation/translation and nonidentity scene ancestors preserve the same metric polygon. No global recenter or rescale.
- Furniture tops, table tops and every non-floor UUID remain non-support. Closed doors remain blockers; openings stay open only as historical geometry.
- Full-body footprint support rejects positions spanning the floor boundary, gaps or unsupported regions even when the centre is supported. Centre-point floor contact is not enough.
- Full non-floor collision parity is unchanged before/after the support substitution. Report floor raw-export-to-source deltas explicitly rather than treating them as lost hazards.

Apple's tessellator is a candidate until these tests run. If it cannot expose usable bounded triangles or fails the concave tests, use a pinned released polygon library under its licence, not a new handwritten fan. Mapbox Earcut is a possible comparator but explicitly does not guarantee correct output for arbitrary malformed polygons; its own disclaimer means independent boundary/area tests are still required.

## Staged decision and stopping conditions

A. Complete same-file native parity and preserve all raw inputs and manifests.

B. Implement the support adapter behind a diagnostic-only policy. Run synthetic and original two-room tests with unchanged body dimensions, margins and route pairs. No moving goalposts and no automatic production activation.

C. Publish raw-scene versus routing-scene overlays with obstacle edges, source floor boundary and export-only rim visually distinguished. Measure every formerly blocked route start and path separately. If an obstacle disappears or a support triangle extends beyond the source polygon, reject the candidate.

D. Only after geometry gates pass, rerun existing route attempts and independent full-body sweeps. Record invalid starts, actual moved episodes, stops, arrivals and contact/unknown-support results separately. A successful route in this processed historical model still does not certify live navigation.

## Verified primary sources

- Apple, `CapturedRoom.Surface.polygonCorners`: local-plane polygon for floor shapes and nonuniform walls. https://developer.apple.com/documentation/roomplan/capturedroom/surface/polygoncorners
- Apple, `SCNShape(path:extrusionDepth:)`: zero extrusion creates a flat one-sided shape; even-odd fill; self-intersecting paths have undefined results. https://developer.apple.com/documentation/scenekit/scnshape/init(path:extrusiondepth:)
- Apple, WWDC23 *Explore enhancements to RoomPlan*, transcript representation/export sections: floor polygon is beautified after scanning; metadata maps unique node names to feature UUIDs; source API and USDZ contain different information. https://developer.apple.com/videos/play/wwdc2023/10192/
- Apple, export options: mesh preserves polygonal walls and opening cutouts, unlike replacing the scene with plain boxes. https://developer.apple.com/documentation/roomplan/capturedroom/usdexportoptions
- OpenUSD, `UsdGeomXformCache.GetLocalToWorldTransform`: complete authored transform chain, one cache per thread and invalidation responsibilities. https://openusd.org/release/api/class_usd_geom_xform_cache.html
- Mapbox Earcut C++ upstream README, robustness limitations and 2D polygon contract. https://github.com/mapbox/earcut.hpp

No third-party code installed or copied in this proposal. No claim that any released geometry component independently makes a blind-navigation system safe.
