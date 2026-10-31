# Native Apple result: run 40698547633

**Terminal failure**, exact source `6fe9d5270f23954fa59fc3509cccf23445cefa51`, tree `37c41e6bbaabe693e06a7c748545c9c37a2b89ed`. Run completed 2026-10-28 14:09:39 UTC. Read-only monitoring and collection; no rerun, workflow dispatch, push or test-threshold change.

[Run](https://github.com/mischa23v/blind/actions/runs/40698547633) · [Native job](https://github.com/mischa23v/blind/actions/runs/40698547633/job/122851765905)

## Verified results

| Stage | Actual result |
|---|---|
| BlindCore | 1,434 executed; 1 skipped; zero failures |
| BlindMemory | 58 passed |
| Default unsigned iOS Simulator build | Passed |
| Separate diagnostics-flag compile | Passed |
| Hosted units | 221 cases: **204 passed, 11 failed, 6 skipped** |
| UI | 18 cases: 14 passed, 1 failed, 3 skipped |

Final case extraction is complete, source-verified and aggregate-count matched. All five exact requested attachment reports were collected (36,818 original attachment bytes). A reduced failure count is not a full pass: five conversation/model tests that failed previously are now **skipped**, not repaired/passed.

## Confirmed metadata failure cause

Both original Apple export sidecars are **binary property lists**, not JSON:

| Fixture | Metadata bytes | Format | Meshes/nodes |
|---|---:|---|---|
| Hallway2 | 707 | binaryPlist | 13 / 27 |
| Bedroom3 | 608 | binaryPlist | 11 / 26 |

The adapter still attempts JSONDecoder, producing `metadataDecodeFailed` before mapping. All **12 baseline + 6 width-addendum route cases** and **16 supplied-pose journey stages** remain `unsupported-geometry`. No completed candidate route or production guidance replay is established.

The inventory contains the complete bounded node lists. Section-center descendants are not MDLMesh in either fixture; therefore the earlier section-mesh hypothesis does not explain this failure. No mapping success should be inferred from node names alone: metadata mapping remains undecoded. The next repair should use the demonstrated platform property-list serialization while preserving the typed String-to-UUID map, bounds and strict feature identity.

## Collision results: improvement, still a real blocker

The exact 4-by-10 synthetic startup matrix reports:

| Source collision mask | Renderer | Passed controls |
|---|---|---:|
| probe-only | none | 2 / 10 |
| platform default all | none | 10 / 10 |
| probe-only | retained offscreen | 2 / 10 |
| platform default all | retained offscreen | 10 / 10 |

Both restricted cells fail forward/reverse thin-wall sweeps, initial/terminal wall overlaps, contained solid, forward/reverse tall-overhead sweeps and floor contact; their clear/short-overhead negative controls pass. Under this fixed speed-one setup, the mask explains the observed matrix difference; the renderer does not. This does not isolate the old speed-zero setting.

**The separate wall-plus-floor thin-wall test still fails both sweep directions** at SavedRoomRouteCollisionOracleTests.swift:54: empty swept obstacle IDs instead of the expected wall. Six other oracle cases, including the matrix, pass. Startup controls alone do not certify the mixed-scene query. Coincident floor contact masking the sweep is an investigation hypothesis, not a demonstrated cause or license to lift the query/change geometry.

## Classified runtime timeouts

Three cases fail the unchanged 10-second callback expectation:

- Classified floor route: wait receipt **12,702 ms**.
- Floor-touching bed/low object permutations: **10,064 ms**.
- Identical upward obstacle plane: **10,008 ms**.

Each nil-result failure records terminal discard requested. These elapsed receipts include test scheduling and do not prove internal queue/build/route timing or completed discard. Standalone CLASSIFIED_QUERY_RECEIPT console lines were not retained by the current bounded job log filter; do not infer absent callbacks from their absence alone. Two other Classified cases pass.

## Early-collection defect and terminal recovery

The early uploaded artifact contains an incomplete status record: `unit-summary.json` was absent. The new early step invokes the case exporter before native-apple.sh's final summary creates that prerequisite. Therefore the early artifact has no route reports.

The final summary did create the prerequisite and printed a complete source-verified status JSON in the terminal job log. This collection recovers all five reports from that exact final JSON. The early artifact remains preserved separately rather than replaced or mislabeled complete. Fix early ordering by invoking the existing bounded summary export first; no test rerun is required merely to read the present final reports.

## UI finding

The remaining accessibility audit failure is **Text clipped** in Ask, identifying the label **Everything in view**. The audit extraction is incomplete after that failed phase. This is distinct from routing/collision and does not change their results.

## Evidence files and interpretation

- final-unit-case-statuses-original.json: exact final JSON from the job-log marker, plus terminal newline.
- Five named JSON reports: reserialized semantic copies of the collected reports.
- report-manifest.json: each original attachment's bytes/hash, exact test verdict, source pins and provenance.
- bounded-native-failure-lines.txt: exact selected source/test failure lines.
- early-unit-case-statuses.json and early-collection-observation.json: preserved earlier incomplete observation.
- SHA256SUMS.txt: hashes of these local evidence files.

Reported attachment hashes belong to the original xcresult attachment bytes; they are not hashes of reserialized report files. Raw private files, camera frames, audio, arbitrary model output and full runner logs were not collected into this package.

Native observation is complete for this run. Binary-plist adaptation, mixed-scene collision behavior, classified callback latency and remaining UI accessibility still need fixes and exact-revision validation. Physical-device localization, sustained guidance, whole-footprint support and independent child use remain unproven.

