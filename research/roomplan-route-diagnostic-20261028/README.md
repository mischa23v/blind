# Original Apple RoomPlan route/collision candidate stage — 2026-10-28

User authorization: “yes test paths too and guidance and collsion on apple”.
This is implementation plus **authored native tests**, not an Apple pass or a
physical guidance activation. Root owns canonical project membership, independent
review, publication and existing native CI. No workflow or capture is activated.

## Minimal reuse path

1. `ios/BlindAssist/SavedRoomRouteMeshAdapter.swift`: hash-check unchanged original
   CapturedRoom JSON, use Apple `.mesh` export with metadata and no ModelProvider,
   use Model I/O triangle import and full hierarchy transforms, copy bounded owned
   arrays. Every retained triangle maps to an original feature UUID; only original
   floor feature triangles carry the explicit support tag. Curves and multiple
   floors are unsupported in this first slice rather than silently approximated.
2. Existing `BlindRoomMesh`: additive `MeshTriangleSupport` and immutable
   `MeshSupportPolicy`. `.legacySlope` remains default for existing clients;
   `.classifiedFloorOnly` requires exactly one classification per triangle and
   cannot silently mix missing tags with legacy behavior. The existing bounded
   mailbox, native queue, body/goal revision invalidation and discard owner remain.
3. New C adapter `bn_build_classified`: existing upstream Recast/Detour remains
   unchanged at `9f4ce64458dfae86e1239c525ddc219c4e9e06f1` (Zlib). All geometry is
   rasterized. Classified raster uses temporary floor=1 / obstacle=2 priority,
   then maps only retained floor spans to `RC_WALKABLE_AREA` before existing
   filters/erosion. This matters because upstream `addSpan` updates merged height
   before resolving area priority with `max`: floor=63/obstacle=0 would otherwise
   permit promotion of a floor-touching obstruction. No new mapper/search code.
4. New hosted route bench sends actual Detour waypoint sequences to a test-owned
   `RoomMeshPreview` sink only. It retains unknown physical coverage and rejects
   stale owners. There is no fabricated spatial ticket, camera/body heading,
   natural-language direction, speech, haptic or live controller.
5. Independent, **test-only** SceneKit oracle queries continuous idealized cylinder
   sweeps against the original exported triangle surfaces. Original RoomPlan
   furniture boxes are additional unchanged solid-bound probes for contained
   starts; their contacts are separately reported from triangle-shell contacts.
   Floors are separately identified, never blanket-exempted by height. This does
   not establish positive whole-footprint support or unseen obstacle coverage.

## What stays original and what is explicitly assumed

- Apple Hallway2 and Bedroom3 fixture bytes/licenses are unchanged and remain
  test resources. Hallway2 has a concave eight-corner floor; no rectangular or
  naive-fan replacement. Bedroom3 contains bed/table/chair bounds.
- Apple mesh export, unlike the existing saved `.parametric` export, supplies
  wall cutouts. All historical door states/parents are retained. Closed doors
  and windows require associated blocking geometry; missing geometry fails the
  stage. Export-node naming, units, original bounds and upward floor winding must
  be established by actual native tests, not assumed from documentation.
- Source geometry is not inflated. The declared cylinder radius is exactly
  `hypot(width, depth) / 2`, a conservative circumscription, not a two-step
  rectangle→square→circle expansion. Planner radius adds margin once and planner
  height adds margin once, matching current BodyEnvelope policy. Recast's existing
  raster/erosion configuration is retained unchanged. SceneKit collision margins
  are explicitly **zero** on static surfaces, original boxes and moving cylinder.
- Raw-body and margin-envelope contacts are distinct measurements, not additive
  collision-event counts. No-path, invalid starts, partial results, stopped or
  unexecuted cases are not successful arrivals.
- Requested and projected endpoints remain separate. Both association connectors
  are independently scored, never used to teleport the body/camera. Native route
  completion means only the projected goal; the bench labels results as model
  candidate routes, never human/controller arrival.
- RoomPlan furniture bounds omit small objects and detailed shape. No ceiling,
  ground below missing floor, between-room bridge or current door state is inferred.

## Frozen schedules — before any native execution

- `PROTOCOL.json`: SHA-256
  `ee8f183ca4d7b6fd9aabecf2f7cd8d39bc472ce071873bceafe4c557f65f8123`.
  Six pairs × two labelled nominal/wide profiles = **12 original baseline outcomes**.
- `PROFILE_28CM_ADDENDUM.json`: SHA-256
  `c52792a1213a1b3969e97a6201d43bac2426a444f3f39e8b906a5feb0e0f701d`.
  Same six pairs × separate 28cm-width diagnostic = **6 additional outcomes**.
  Depth20cm/height120cm are explicit test assumptions, not a child's measurements.
  Original15cm margin remains unchanged; no zero/5cm replacement variant.
- Exact copies are bundled only in `ios/BlindAssistTests/Fixtures/RoomRouteDiagnostic`.
  The native tests check the byte digests. Failed pairs/profiles may not be replaced
  after results. Delay/jitter and sustained controller trials are subsequent work.
- `JOURNEY_ADDENDUM.json`: SHA-256
  `8e060627d0f570820fd00a427e22f6672eb50048611dfc9682986cac5c30cc9a`.
  Separately preregistered after the user's chair/bed request, before native
  execution: **five supplied-pose journeys /16 candidate-stage schedules**.
  The original18 schedules above remain unchanged. These include bed/chair
  post-rise supplied poses, actual connectors to existing route anchors,
  around-room legs, closed-door approach/withheld outbound, in-room return,
  inside-bed/chair invalid-standing controls, and a separate hallway historically
  open-door/outside-unknown-floor control. No fixture frames are joined.

## Posture, localization and production guidance distinctions

The original room JSON contains no person observations. A named bed/chair is
historical room context, not evidence of where the person sits. The new journey
test explicitly supplies seated context and a **separate** post-rise standing
floor pose. It neither reconstructs nor scores the intervening get-up motion.
Standing inside the original bed/chair remains invalid; furniture is never removed.
Unknown/wrong-frame position and missing heading withhold test output.

`SavedRoomRouteJourneyAppleTests.swift` runs the existing production
`SpatialFacts.relation`, `SpatialFacts.phrase` and `GuidanceCadence.label` into a
test-owned text array. Guidance and collision evaluation consume the same exact
named segments, including both requested/projected endpoint connectors and any
Detour straight-path boundary-clamping discrepancy; no direct unscored shortcut
is formatted. Each receipt retains its scored segment's exact endpoints. A purely
vertical or zero-length connector is still collision-scored, but has no horizontal
cue. Its fixed floor-local+X heading and2-second cue clock are
declared test inputs, not camera/body calibration. This is stronger than waypoint
receipt-only checking, but still not `SpatialRouteOwner`, live localization,
VoiceOver or sustained closed-loop controller proof. The ideal scripted replay
advances an endpoint only after a complete candidate and independently checked
raw-body/margin sweeps including both projection connectors; a failed stage stops
that journey and preserves remaining stages as unexecuted. An expected withheld
outbound leaves the pose unchanged so a separately queried in-room return can run.

## Authored native coverage

- `ClassifiedRoomMeshTests.swift`: five methods, including floor-only versus
  identical obstacle plane, missing/malformed classification, unchanged legacy
  API, lifecycle retirement, and six bed/low-object triangle-order permutations.
- `SavedRoomRouteMeshAppleFixtureTests.swift`: four methods for actual Apple
  export inventory/source binding, concave floor area/corners, wall cutouts versus
  closed-door barriers, and incorrect source digest rejection.
  Before any native outcomes, its overstrict collinear-vertex requirement was
  corrected to bidirectional original/exported boundary coverage plus unchanged
  area and concavity witnesses. Valid tessellation may remove collinear vertices;
  it may not invent support, erase a boundary or create unsupported holes. Original
  polygon coordinates remain independently compared in the source-feature DTO.
- `SavedRoomRouteCollisionOracleTests.swift`: six methods. Every oracle initializer
  additionally requires native positive/negative controls: wall sweeps both ways,
  contained-solid start, overhead sweeps both ways, low-height and free-space
  negatives, and separately reported floor contact. A headless backend that is not
  ready throws `backendUnavailable`; empty results never certify readiness.
- `SavedRoomRouteDiagnosticAppleTests.swift`: two methods, preserving12+6 frozen
  candidate schedules, source exports, actual runtime queries, nonphysical waypoint
  receipts, stale-output rejection and independent body/margin sweeps. Attachments
  preserve result dictionaries before assertions; early aborts preserve the prefix
  and explicitly mark remaining schedules unexecuted. Complete candidates with
  model contacts fail; zero completed candidates also fails rather than counting
  no-path as success.
- `SavedRoomRouteJourneyAppleTests.swift`: two additional methods for withheld
  unknown/seated/wrong-frame/heading cases and the separate16-stage supplied-pose
  candidate journey protocol, including existing production direction/distance
  formatting and cadence. It does not alter the original18 candidate schedules.

## Executed checks and pending evidence

- **Passed locally:** eight bounded Node source/protocol checks,
  `node --test --test-concurrency=1 tools/test/roomplan-route-diagnostic.test.mjs`.
  Output: `source-checks.tap`. These are source contracts, not native behavior.
- **Passed locally:** existing `g++` C++11 `-fsyntax-only` on the package adapter,
  with pinned include paths and existing contraction/exception/RTTI flags. No
  linked library, Swift package, Apple export, route or physics execution occurred.
- **Passed locally, separately authorized:** actual pinned-Recast synthetic raster
  micro-control,52 observations: floor-only positive, obstacle-only negatives,
  and eight triangle-order permutations each for touching1cm object, touching65cm
  bed and separated55–65cm box. Naive floor63/obstacle0 reproduced promotion;
  temporary floor1/obstacle2+remap yielded zero promotions and order-identical
  classified grids. `RASTER_PRIORITY_RESULT.json` retains source hashes and
  compilation/run receipts. Final total child CPU1.446s and peak child RSS59,112KiB;
  enforced256MiB address-space/20CPU-s/30wall-s bounds. This verifies only synthetic
  raster classification—not Apple, a full path, a real room or physical safety.
- **Independent read-only source review completed:** reviewer
  `/root/review_recorded_route_preview` verified all15 implementation manifest
  hashes and52 micro-control source pins, reran8 source checks, identified a
  guidance-versus-scored-segment mismatch, then confirmed the shared exact-segment
  repair with no remaining identified source blocker. Reviewed manifest SHA-256:
  `e002c883b043363637405ac51f1ec13adef6f613d2d951e37e63a70c551635e2`.
  This is not native compilation or behavioral evidence.
- **Pending:** direct app/hosted-test product linkage to BlindRoomMesh; canonical new-source/test-only-resource membership;
  refreshed current package source pins; Apple compilation and all19 native methods.
- **No new dependency installation**, model weights, AR capture, physical output,
  workflow activation or external upload was performed in this task. The bounded
  standalone C++ raster-control executable is separate from any app/package build.

SceneKit is deprecated but remains Apple's existing supported compatibility
physics API on this test target; it is used only in hosted tests, not introduced
as a production navigation dependency. A passing model query would not establish
Apple sensor accuracy, floor-to-head coverage, localization or child/device safety.

## Primary sources

- [Apple export option feature table](https://developer.apple.com/documentation/roomplan/capturedroom/usdexportoptions?changes=latest_min_2_6): triangle mesh and wall cutouts versus parametric primitives.
- [Apple metadata export](https://developer.apple.com/documentation/roomplan/capturedroom/export(to:metadataURL:modelProvider:exportOptions:)) and [WWDC23 explanation](https://developer.apple.com/videos/play/wwdc2023/10192/): node-name↔original-feature UUID mapping.
- [Apple polygon coordinates](https://developer.apple.com/documentation/roomplan/capturedroom/surface/polygoncorners): local-plane floor/wall polygons.
- [Model I/O mesh](https://developer.apple.com/documentation/modelio/mdlmesh) and [submesh conversion](https://developer.apple.com/documentation/modelio/mdlsubmesh/init(mdlsubmesh:indextype:geometrytype:)-4czyc): existing triangle import/conversion, not custom tessellation.
- [Recast API](https://recastnav.com/group__recast.html): classification, rasterization and existing erosion/filter operations.
- [Apple physics shapes](https://developer.apple.com/documentation/scenekit/scnphysicsshape): idealized primitive physics shapes; [concave static shapes](https://developer.apple.com/documentation/scenekit/scnphysicsshape/shapetype/concavepolyhedron).
