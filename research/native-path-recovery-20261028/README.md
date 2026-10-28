# Native path recovery — verified baseline evidence

## Result, not a repair claim

GitHub run [40677832625](https://github.com/mischa23v/blind/actions/runs/40677832625), native job [122780656018](https://github.com/mischa23v/blind/actions/runs/40677832625/job/122780656018), completed **failure** on exact commit `dc32a9bad9a75566f27924fb9f7aa8fe50a46e95`. Retrieved read-only through the GitHub connector on 2026-10-28. No external code was executed or published during this evidence audit.

- BlindCore: 1,434 tests, one skipped, zero failures.
- BlindMemory: 58 tests, zero failures.
- Unsigned iOS Simulator build and separate mesh-diagnostics compile: passed.
- Hosted unit record: 218 cases, 198 passed, 2 skipped, 18 failed; aggregate counts match.
- Native UI/accessibility tests: failed; Ask reports text clipped. This report focuses on paths/collision.

## Exact path and journey evidence

The retained xcresult attachment reports were collected and marked failed:

| Attachment | Cases/stages | Observed outcome |
|---|---:|---|
| APPLE_ROOM_ROUTE_original-baseline_OUTCOMES.json | 12 | All unsupported-geometry / missingMetadata |
| APPLE_ROOM_ROUTE_width28-addendum_OUTCOMES.json | 6 | All unsupported-geometry / missingMetadata |
| APPLE_SUPPLIED_POSTURE_JOURNEY_OUTCOMES.json | 16 | All unsupported-geometry / missingMetadata |

Both original Apple fixtures, Bedroom3 and Hallway2, fail adapter decoding. The original 18-case path schedule is unchanged. No complete candidate route or production formatter/cadence execution was established. No path, stopped motion, and refusal are **not** successful route execution.

The two path test entry points fail at `SavedRoomRouteDiagnosticAppleTests.swift:338–339`; journey replay fails at `SavedRoomRouteJourneyAppleTests.swift:329–331`. All three mesh fixture tests also fail with `SavedRoomRouteMeshAdapter.Failure error 5` (the missingMetadata enum case).

## Collision evidence

All six `SavedRoomRouteCollisionOracleTests` cases fail at `SavedRoomRouteCollisionOracle.swift:255` with:

`backendUnavailable("bidirectional thin-plane continuous sweep")`

This is the oracle's mandatory startup self-check, before each test's specific claims are exercised. The guard requires both forward and reverse swept contacts to contain the authored thin wall. Current logs do not retain direction-specific or raw contact results. Later contained-cylinder, overhead, negative-control and floor-contact startup checks are not reached. These results must not be described as six independent real-room collision misses.

Source creates an unrendered SCNScene with physics speed zero, static concave shapes and explicit resetTransform/updateCollisionPairs calls. Whether this environment needs an explicit supported engine initialization/update, whether a direction is unsupported, or whether source geometry is missing is **not established** by the current evidence. Preserve the fail-closed self-check while diagnosing it.

## Actionable metadata boundary

`SavedRoomRouteMeshAdapter.swift` collapses several distinct problems to missingMetadata:

1. Metadata data/JSON decode failure.
2. Empty/invalid metadata mapping.
3. MDLMesh node has no mapped/inherited identity, or maps outside original feature IDs.

It deletes exported files in defer and records none of the node names or metadata parse diagnostics. Thus the baseline cannot distinguish these paths. Add bounded diagnostics for the public fixtures before selecting a schema/name repair; do not silently assign identities, omit unclassified collision geometry or repair it from guessed geometry.

Apple's [WWDC23 explanation](https://developer.apple.com/videos/play/wwdc2023/10192/) explicitly describes a USDZ-node-name-to-CapturedRoom-UUID map, so the String-to-UUID direction in source is not itself a demonstrated bug. Apple also describes exported section-center nodes. Both fixtures have one section; the adapter's originalFeatures excludes sections. Section nodes or ModelIO naming differences are hypotheses requiring actual exported-node evidence, not a confirmed root cause.

## Classified synthetic floor callback

`ClassifiedRoomMeshTests/testClassifiedFloorRoutesWithoutGrantingPhysicalAuthority()` fails after its 10-second wait; `ClassifiedRoomMeshTests.swift:27–28` reports an unfulfilled native candidate result and a nil result. The other four ClassifiedRoomMeshTests cases passed, including a later valid classified-floor query. The log does not establish a permanent deadlock or a routing result.

Source diagnostic:

- RoomMeshCandidateRuntime serializes all native work on process-global utility queue `blind.room-mesh.native` (RoomMeshCandidate.swift:55).
- The query synchronously constructs Native and requests its route on that queue (166–167).
- Completion then dispatches to the global utility queue (154).
- All inspected request return/error paths schedule completion; baseline lacks enqueue/start/build/route/callback timing, so queue delay, first native execution and callback delay cannot be separated.
- The failing test throws in query before reaching `await discard(runtime)` at the bottom of its test body. Ensure failure cleanup also requests stopAndDiscard; do not increase the timeout and call this a performance fix.

## Files and hashes

- `native-run-40677832625-unit-statuses-original.json`: exact JSON text following NATIVE_UNIT_CASE_STATUSES= in the connector-fetched job log, with a terminal newline.
- `native-run-40677832625-evidence.json`: public-safe structured excerpt, attachment payloads, reported original attachment hashes, failure cases and exact failure lines. This is a reserialized semantic copy; reported attachment SHA256 values refer to original xcresult bytes, not this wrapper.
- `SHA256SUMS.txt`: hashes of retained evidence/report files.
- Source SHA256 pins supplied by the CI record are retained inside the JSON evidence.

## Scope and stopping condition

This is a verified failure baseline plus source review, not execution of a repair. Review workers' patches against these boundaries and rerun the existing Apple tests on the final published commit only when authorized. Passing source checks, package tests or compile jobs cannot substitute for the blocked native export/collision/path tests. Physical localization, sustained controller behavior, live VoiceOver, whole-footprint support and physical guidance remain unproven.

