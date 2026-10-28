# Saved-room collision backend: bootstrap candidate and diagnostic matrix

## Status and evidence boundary

**Implemented locally, source-reviewed, not compiled or run on Apple.** The exact failure baseline is native [run 40677832625](https://github.com/mischa23v/blind/actions/runs/40677832625), commit `dc32a9bad9a75566f27924fb9f7aa8fe50a46e95`: six oracle cases fail the mandatory bidirectional thin-plane sweep check. That guard short-circuits, so the log does not establish which direction failed or whether later containment/height/clear/floor controls work. This is not six separately measured real-room collision misses. [Independent baseline audit](../native-path-recovery-20261028/README.md).

The prior world had speed zero, no retained renderer and source `collisionBitMask = probeMask`. None is a proven cause. This patch does not label a cause fixed or replace failed positive controls with an empty-hit success.

## Candidate

Only test-target `SavedRoomRouteCollisionOracle.swift` and its tests change. Existing RoomPlan geometry, planner, scene guidance, body/margin dimensions and application authority remain untouched.

- Retain an `SCNRenderer` with the query scene for the oracle's lifetime. There is no view, camera, AR session, display link or render target. Use the platform renderer's synchronous `update(atTime:)`, not a new physics algorithm.
- Scene unpaused; renderer playing; gravity zero; physics speed one; fixed timestep `1 / 60` seconds. There are only static source bodies and kinematic overlap probes, no dynamically integrated actor.
- Update at zero, then one fixed timestep after construction. Every query synchronizes after probe insertion, removal and before sweep. The clock advances by an integer tick, not wall time, sleeps or retry-until-contact loops. A matrix renderer cell makes 52 update calls for its 10 queries, including startup; the no-renderer cell makes none.
- Candidate source bodies keep Apple's default all-category collision mask. Source category 1, probe category 2 and query filter 1 remain explicit. Probe-only source masking is available only in private diagnostic configuration.
- Continue the full `SCNCylinder` initial overlap, continuous sweep and terminal overlap. Preserve zero extra physics margin, two-sided queries, all-contacts search, original concave triangles, separate idealized solid furniture bounds, and the exact typed SIMD rigid-transform repair from `dc32`.
- Every external oracle must pass all controls under the fixed candidate configuration. No matrix cell can be selected as a fallback. A failed or thrown positive control always leaves the backend unavailable.

### Platform references and limits

Reviewed 2026-10-28. Apple platform APIs are used under the installed SDK's terms; no third-party source, library, model, dataset or license is newly adopted.

- [Source-body collision mask](https://developer.apple.com/documentation/scenekit/scnphysicsbody/collisionbitmask): Apple documents its all-category default. This supports leaving that default intact, not a claim that the old restrictive mask caused the observed sweep failure.
- [Physics query test options](https://developer.apple.com/documentation/scenekit/scnphysicsworld/testoption): the query collision mask selects source categories; backface/search-mode options remain unchanged.
- [Scene renderer update](https://developer.apple.com/documentation/scenekit/scnrenderer/update(attime:)) and [renderer initialization](https://developer.apple.com/documentation/scenekit/scnrenderer/init(device:options:)): platform update/renderer entry points. The update page currently returns JavaScript-only content through the research tool; an attempted Markdown fetch was unsupported. Exact SDK compilation and runtime initialization still need Apple verification.
- [Renderer loop](https://developer.apple.com/documentation/scenekit/scnscenerendererdelegate): Apple describes physics evaluation during scene processing. This supports the lifecycle candidate, not a guarantee that the fixed startup sequence works on this simulator.
- [Physics world](https://developer.apple.com/documentation/scenekit/scnphysicsworld): explicit collision-pair reevaluation and queries are retained.

SceneKit is deprecated. Its availability and reputation are not integration proof. No native pass is newly claimed.

## Bounded factorial diagnostic

One test, `SavedRoomRouteCollisionOracleTests/testBackendDiagnosticMatrixRecordsEveryControl`, runs exactly four cells, once each, in this order:

1. `restricted-no-renderer`: probe-only source mask, no renderer.
2. `default-no-renderer`: default source mask, no renderer.
3. `restricted-offscreen-renderer`: probe-only source mask, retained renderer update.
4. `default-offscreen-renderer`: default source mask, retained renderer update (**candidate**).

All four cells share speed 1, timestep `1 / 60`, zero gravity, source category 1, probe category 2 and query mask 1. Thus differences can illuminate mask and renderer effects **within the unpaused world**. This matrix does not isolate the separate effect of old speed 0; the old native baseline is not an extra factorial cell. Do not infer causality from a candidate pass alone.

Each cell evaluates all ten controls even after a failed or thrown query. Construction failure emits ten failed/error controls, not partial success. For each query all three phases are recorded. Required success predicates:

| Ordered query | Required contacts |
|---|---|
| `thinWallForward` | Initial and terminal entirely empty; swept obstacles exactly wall; no floors/bounds. |
| `thinWallReverse` | Same, reverse travel. |
| `wallInitialOverlap` | Initial obstacles wall; terminal entirely empty; union obstacles exactly wall and no floors/bounds. |
| `wallTerminalOverlap` | Terminal obstacles wall; initial entirely empty; union obstacles exactly wall and no floors/bounds. |
| `containedSolid` | Initial and terminal bounds exactly solid; union bounds exactly solid; all obstacle-shell/floor sets empty. |
| `overheadTallForward` | Initial and terminal entirely empty; swept obstacles exactly overhead; no floors/bounds. |
| `overheadTallReverse` | Same, reverse travel. |
| `overheadShort` | Every contact set empty in every phase. |
| `clear` | Every contact set empty in every phase. |
| `floor` | Initial and terminal floors exactly floor; union floors exactly floor; no obstacles/bounds. |

These preserve the original controls and strengthen endpoint/identity checks. Positive controls prevent a nonfunctional empty backend from passing the negatives. Floor contact never establishes whole-footprint support.

## Exact JSON witness contract

Attachment name **`SavedRoomCollisionBackendMatrix-v1.json`**, UTI `public.json`, `.keepAlways`, emitted **before** the candidate readiness assertion. Maximum 131,072 UTF-8 bytes. The collector's aggregate 1 MiB cap is unchanged. The attachment is synthetic-only and admits no caller-supplied room/pose/geometry, arbitrary error text, files or private images.

Top-level exact fields:

- `schemaVersion`: integer `1`
- `evidenceKind`: `"synthetic-collision-backend-matrix"`
- `physicalAuthority`: `false`
- `fullFootprintSupportVerified`: `false`
- `cells`: the four ordered cells above

Each cell has exact fields `configurationID`, `sourceCollisionMask` (`"probe-only"` or `"platform-default-all"`), `rendererMode` (`"none"` or `"retained-offscreen-update"`), `physicsSpeed` (`1`), `timeStepSeconds` (`1 / 60`), `gravity` (`[0,0,0]`), `sourceCategoryMask` (`1`), `probeCategoryMask` (`2`), `queryCollisionMask` (`1`), `backendReady`, `failedControls`, `queries`.

Each query has exact fields `name` (the ten ordered names above), `passed`, `errorCode`, `initial`, `swept`, `terminal`. Each phase has exact fields `obstacleSurfaceIDs`, `floorSurfaceIDs`, `furnitureBoundIDs`, containing sorted unique UUID strings. The only possible IDs are:

- Wall `00000000-0000-0000-0000-000000000001` (obstacle surface).
- Solid `00000000-0000-0000-0000-000000000002` (obstacle surface shell or furniture bound).
- Overhead `00000000-0000-0000-0000-000000000003` (obstacle surface).
- Floor `00000000-0000-0000-0000-000000000004` (floor surface).

`errorCode` is one of `none`, `invalidGeometry`, `invalidQuery`, `invalidFurnitureBox`, `unassociatedContact`, `unexpectedError`. Non-`none` means `passed:false` and all contact arrays empty; this is an error placeholder, not an observed clear result. With `none`, `passed` is exactly the fixed predicate above. `failedControls` equals failed query names in query order; `backendReady` iff every query passes. No omitted controls, alternate IDs or unordered duplicate cells are valid.

Normal creation failure text is exactly `backend controls failed: ` followed by comma-separated ordered nonempty failed control names. The collector is coordinated to admit only that bounded form, not arbitrary Swift errors. The original fixed errors remain historical collector inputs.

## Checks actually run

`python3 research/collision-backend-bootstrap-20261028/check_source.py` completed **18 source assertions passed, 0 failed**. [Machine-readable receipt](verification.json). These verify preservation and source contracts only; they do not parse/typecheck Swift, execute XCTest or prove geometry results. Independent source review found no blocking lifecycle/compile/scope issue; it also explicitly could not run Apple APIs.

The finalized collector was independently compared against all ten Swift predicates and the exact witness/error schema: no mismatch found. `python3 tools/ci/test-native-route-diagnostic-evidence.py` was also independently run here: **51 tests passed** (0.324 seconds). These are synthetic collector/export fixtures, not execution of Swift JSON encoding or SceneKit. Reviewed collector SHA-256: `22dd01fb734d00da33ce23451c8f5cf8d192d9f415b492da0bc4bda6bd6e56af`.

Source SHA-256:

- Oracle: `5954b3e7d2da4cf2ce2c0cbd85f80c52524a8282d1abac73d504a8f12d810d51`
- Tests: `64affe88925c19a97af9227291824890e5c34beffaebe43d806ae9b6a777e814`

### Exact blocker and next verification

- **Action:** compile and execute the changed test-target Swift, then rerun unchanged actual Apple fixture/path/journey tests.
- **Target:** final source revision in the existing Apple native validation workflow / authorized Mac Xcode environment.
- **Reason:** this restored Linux workspace has no `swift`, `swiftc`, `xcodebuild` or Apple SDK.
- **Status:** **not run**. No heavy install, new workflow, push, remote mutation or private upload was attempted.

On authorized native execution, retain this matrix even if candidate fails, verify its exact source/run binding with the collector, and inspect all four cells and every phase. A green diagnostic does not substitute for the existing six oracle tests or real Apple geometry/path fixtures. Keep missing metadata, no-path, backend-unavailable and stopped/unsupported episodes separate from successful routes. Live localization, fresh coverage, body calibration, whole-footprint support, physical guidance and child walking acceptance remain unproven.
