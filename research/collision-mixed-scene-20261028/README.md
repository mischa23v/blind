# Mixed wall/floor collision query candidate

## Finding first

Exact native [run 40698547633](https://github.com/mischa23v/blind/actions/runs/40698547633), source `6fe9d5270f23954fa59fc3509cccf23445cefa51`, establishes that both default-source-mask bootstrap cells pass all ten controls, with and without the retained renderer; both probe-only-mask cells fail the eight positive controls. Thus the source mask explains that factorial difference **at speed one**. It does not prove the renderer was needed or isolate the old speed-zero effect.

However, the unchanged `testThinWallSweepBothDirectionsAndNegativeControl` fails **both** swept wall assertions in the wall-plus-floor scene. Its endpoints do not overlap the wall, and the test requires the swept phase, not an endpoint substitute. The startup matrix places its floor away from the wall, so its success did not cover this mixed scene. [Native evidence and raw fixed-control reports](../native-path-recovery-20261028/run40698547633/README.md).

**Coincident floor interference remains a hypothesis.** That run did not attach raw mixed-scene phase contacts. No claim is made that the wall was missed because of the floor, that category separation fixes it, or that any physical route is safe.

## Narrow candidate implemented locally

The test-only oracle now assigns source categories separately: obstacle surfaces and solid furniture bounds are category **1**, floors are category **4**, and the ephemeral kinematic probe remains category **2**. Source collision masks retain the platform default all-category mask. The probe's collision/contact masks cover both source categories.

For **initial overlap, continuous sweep and terminal overlap**, the candidate queries category 1 and then category 4 with the exact same full cylinder and start/end transforms, and unions every returned contact. Floor IDs stay separate in the result. All original source triangles and furniture bounds are still installed in the same scene. No floor is dropped from scoring, no body is lifted/shrunk, no extra collision margin is added, no geometry or path is replaced, and no floor contact grants support authority.

The renderer/gravity/timestep/lifecycle settings remain unchanged from the tested candidate, keeping this next comparison narrow. The earlier matrix showed renderer use was unnecessary for its isolated controls, not that changing lifecycle again would improve the mixed case.

Every external oracle now requires **all ten original controls plus six wall-and-floor controls** to pass under the separated-query mode. Failed or thrown positive controls keep `backendUnavailable`; negative empty queries alone cannot certify readiness. There is no combined-mode fallback. Failure names are deduplicated and emitted in the original ten-name order under the existing bounded `backend controls failed: ` prefix, so the collector grammar does not widen.

The old `SavedRoomCollisionBackendMatrix-v1.json` is intentionally still generated in combined-query mode. Its factorial meaning is not rewritten retroactively. It is a bootstrap witness, no longer a complete statement of external candidate readiness.

### Platform evidence

Apple's [query collision-mask documentation](https://developer.apple.com/documentation/scenekit/scnphysicsworld/testoption/collisionbitmask) explicitly selects source physics-body categories. Apple's [search-mode documentation](https://developer.apple.com/documentation/scenekit/scnphysicsworld/testoption/searchmode) says this option applies to ray and convex-sweep tests, so the current `.all` use is not discarded as unsupported. [Source-body collision masks](https://developer.apple.com/documentation/scenekit/scnphysicsbody/collisionbitmask) remain at their documented all-category default.

These documented APIs justify the query adapter, not its success on this runtime. SceneKit remains deprecated; no replacement collision algorithm, third-party dependency, model, dataset or new license is introduced. Geometry/query semantics must be judged by the next exact-source native result.

## Paired diagnostic and exact witness contract

New exact test identifier:

`SavedRoomRouteCollisionOracleTests/testMixedSceneCombinedAndSeparatedQueriesRecordEveryPhase`

New attachment: **`SavedRoomCollisionMixedScene-v1.json`**, `public.json`, `.keepAlways`, attached before readiness assertions. Limit **131,072 bytes**; the collector's shared **1 MiB** cap is unchanged. Only fixed authored geometry/IDs appear; no private input, arbitrary error text or source room is accepted.

Top-level exact fields: `schemaVersion:1`, `evidenceKind:"synthetic-collision-mixed-scene"`, `physicalAuthority:false`, `fullFootprintSupportVerified:false`, `cells`.

Four ordered cells:

1. `wall-only-combined`
2. `wall-and-floor-combined`
3. `wall-only-separated`
4. `wall-and-floor-separated`

The wall-only cells are diagnostic controls, never a reduced-geometry route candidate or a substitute readiness gate. Both layouts keep the original eight vertices. The mixed layout keeps the original four triangles/ordering; only the diagnostic wall-only layout omits floor faces. The mixed vertices, triangles and UUIDs exactly match the existing failing `wallAndFloor()` fixture.

Each cell has exact fields:

- `configurationID`, `layout` (`wall-only` or `wall-and-floor`), `queryMode` (`combined` or `separated`).
- `rendererMode:"retained-offscreen-update"`, `physicsSpeed:1`, `timeStepSeconds:1/60`, `gravity:[0,0,0]`.
- `obstacleCategoryMask:1`, `probeCategoryMask:2`, `floorCategoryMask` (1 combined / 4 separated), `queryCollisionMasks` ([1] combined / [1,4] separated).
- `backendReady`, `failedControls`, `queries`.

Each cell executes six ordered queries: `thinWallForward`, `thinWallReverse`, `wallInitialOverlap`, `wallTerminalOverlap`, `clear`, `floor`. Each query retains the existing exact fields `name`, `passed`, `errorCode`, `initial`, `swept`, `terminal`. Each phase contains sorted unique `obstacleSurfaceIDs`, `floorSurfaceIDs`, `furnitureBoundIDs` arrays.

Only wall UUID `10000000-0000-0000-0000-000000000001` and floor UUID `10000000-0000-0000-0000-000000000002` are permitted in their corresponding arrays; furniture arrays are empty. These match the failing test and are distinct from the old matrix's `000...` IDs.

All sweeps use radius **0.2**, height **1.6**, and the original foot position **y=0**, except the explicit floor-overlap control at **y=-0.1**. There is no query-lifting epsilon. Success predicates:

| Query | Required obstacle result |
|---|---|
| `thinWallForward`, `thinWallReverse` | Initial/terminal obstacle arrays empty; swept obstacles exactly wall. |
| `wallInitialOverlap` | Initial obstacles exactly wall; terminal obstacles empty; union obstacles exactly wall. |
| `wallTerminalOverlap` | Terminal obstacles exactly wall; initial obstacles empty; union obstacles exactly wall. |
| `clear` | No obstacle or furniture contacts in any phase. |
| `floor` | No obstacle/furniture contacts; wall-only requires all arrays empty, mixed requires initial and terminal floor exactly floor and floor union exactly floor. |

Every wall-only query also requires no floor contacts. Mixed queries allow retained fixed floor contacts in any phase; touching-floor absence is not treated as support proof. An unexpected fixed floor ID in a wall-only query is retained as **failed evidence**, not silently discarded. Any non-`none` error requires `passed:false` and empty contact arrays, explicitly an error placeholder rather than clear-space evidence. Error enum is unchanged: `none`, `invalidGeometry`, `invalidQuery`, `invalidFurnitureBox`, `unassociatedContact`, `unexpectedError`.

`failedControls` equals failed query names in order; `backendReady` iff all six pass. Both separated diagnostic cells are asserted, and the unchanged original mixed-scene test must also pass. Combined cells may record failure; their output cannot override the candidate. The external gate additionally requires every original containment, overhead, floor and negative control.

## Actual verification

- **24 source assertions passed, 0 failed**: `python3 research/collision-mixed-scene-20261028/check_source.py`. [Receipt](verification.json). Checks include unchanged six original test bodies, unchanged ten original control query/predicate implementations, unchanged typed SIMD repair, exact mixed fixture geometry, full-cylinder query reuse, all-phase union and mandatory combined original/mixed readiness requirements. These are text/source checks, not a Swift parser or execution.
- **9 canonical Node source contracts passed**: `node --test --test-concurrency=1 tools/test/roomplan-route-diagnostic.test.mjs`. The three stale bootstrap regex assertions were updated and strengthened for the new fail-closed gate, category separation, phase unions and unchanged combined-mode old matrix.
- **61 synthetic collector tests passed**: `python3 tools/ci/test-native-route-diagnostic-evidence.py`. Independently reviewed `validate_mixed_collision_matrix` and `mixed_collision_control_passed` against the Swift witness and all six predicates; no mismatch found. This is not Swift encoder or physics execution.
- Additional `node --test --test-concurrency=1 tools/test/room-route-project.test.mjs`: **1 passed, 1 failed**. Graph membership assertions pass, but the full generated-project equality fails because this checkout restores only needed `ios/BlindAssist` source files while the canonical project lists the full application. The generator derives its source list from that incomplete directory. No project file was regenerated or changed; full project equality is not verified in this partial checkout.
- Independent source reviewer found no blocking issue in the two Swift files; all geometry/body/phase guards and the mixed gate are preserved. Maintainability note: the private mixed fixture uses fixed `.candidate`; this matches the only external constructor's fixed configuration. No alternate public configuration exists.

SHA-256:

- Oracle: `30941a88fda667560962fc1baca7f980ba534f613d093b79662b3951e0da5fd9`
- Oracle tests: `139de1ae5309296c6efa96225040b816b08b40f75e1f0c5c7c118194bc3a2256`
- Canonical Node contract: `badcaf3f878c4784509fa821f516cd8b29354253f815cf59e4935c3888d8e49b`
- Reviewed mixed collector (owned separately): `130b6a69db39eabfe58fbede2d151d8adfc20b3b518459272dbf0f9ebf56cc59`

## Exact remaining blocker

**Action:** compile and execute the changed oracle/test target, retain the paired mixed witness, and rerun unchanged Apple path/journey fixtures on the final exact source. **Target:** existing authorized Apple validation workflow or Mac Xcode environment. **Reason:** this Linux workspace has no Swift/Xcode/Apple SDK. **Status:** native candidate **not run**, no successful collision repair or movement claimed.

No push, workflow dispatch/activation, heavy install or private upload was performed in this workstream. Passing source/collector checks cannot close the native gate. If the mixed separated cell fails, keep it unavailable and use the recorded phases to diagnose; do not reduce geometry/body dimensions or weaken the assertions. Live localization, current coverage, whole-footprint support, physical guidance and child use remain unproven.
