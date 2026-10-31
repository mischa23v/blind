# Native Apple result: run 40706611490

**Terminal failure**, source `43e33d4b8a59a2a0431ab514c8821fabcf622a08`, tree `9c8ccae13110ab8ee355c010ce5682b0ae3fca60`. Completed 2026-10-28 15:00:25 UTC. Read-only monitoring; no rerun, dispatch, push or test-gate change performed by this observer.

[Run](https://github.com/mischa23v/blind/actions/runs/40706611490) · [Native job](https://github.com/mischa23v/blind/actions/runs/40706611490/job/122880338505)

## Results

| Stage | Result |
|---|---|
| BlindCore | 1,434 executed; 1 skipped; zero failures |
| BlindMemory | 58 passed |
| Default unsigned iOS Simulator build | Passed |
| Separate diagnostics-flag compile | Passed |
| Hosted units | 223 cases: **209 passed, 8 failed, 6 skipped** |
| UI | 18 cases: **14 passed, 1 failed, 3 skipped** |

The early case-status extraction now succeeds: complete, exact-source verified, aggregate-count matched, all five requested reports collected. Early artifact and final log JSON are semantically identical. Original attachment total is 44,083 bytes. Separate report files are semantic reserializations; original attachment hashes in report-manifest.json do not describe the reserialized file bytes.

## Plist repair succeeded; source bounds are now the blocker

Both original export sidecars decode as binary property lists. Hallway2 has 13 entries/13 meshes, Bedroom3 11 entries/11 meshes. Every mesh has a direct known feature UUID; unmatched and unknown-feature mesh counts are zero. The adapter now rejects both fixtures as `sourceGeometryMismatch`, after metadata mapping. All 12 baseline + 6 width-addendum route outcomes and all 16 supplied-pose journey stages remain unsupported geometry. No candidate route or production guidance formatter/cadence replay completed.

Hash-verified source has one `sourceGeometryMismatch` throw: SavedRoomRouteMeshAdapter.swift:292 in verifySourceBounds. A world vertex is converted through inverse feature transform and checked against polygonCorner min/max or feature half-dimensions, plus unchanged roundoff allowance. This receipt does not identify offending feature, vertex, axis or numeric delta; coordinate convention versus exporter geometry/thickness is not resolved. Do not widen tolerances or infer physical authority from the mapping improvement.

## Collision and timing

The collision backend matrix is identical to the preceding run: platform-default source collision mask passes 10/10 isolated controls with or without renderer; restricted probe-only mask passes 2/10 with or without renderer. The separate mixed wall-plus-floor thin-wall test fails both sweep directions (empty obstacle IDs, expected wall). Other six collision oracle cases pass. The later mixed-scene candidate is not part of this source.

All five ClassifiedRoomMeshTests pass on this run, including the three previous timeout cases, without the later timing instrumentation. This is one observed pass, not proof of latency stability. The eight failing hosted cases are the mixed-scene collision test, two route scenarios, supplied-pose journey and four real-Apple-mesh fixture tests.

## UI

The camera/Ask audit fails **Contrast**, in Ask, at LaunchTests.swift:373. Exact callback metadata identifies a SwiftUI.AccessibilityNode but no element (`elementPresent=false`, `snapshotStatus=not_available`). It does not name the previous “Everything in view” clipping label. Camera before/after evidence is complete; Ask after-shot is absent after the failed audit, so extraction is truthfully incomplete. Bounded synthetic UI evidence is retained in ui-audit/ with its original evidence.json. No private camera/audio/model data is included.

## Provenance

- Unit artifact 12824364131, ZIP 15,459 bytes, SHA256 `6c80909ef0713cf86974a5a0a2171743cff41d52aaba723b848587c7d9068019`.
- Exact original early unit JSON: 122,430 bytes, SHA256 `1d139e569a8818940fa65c9cb87e1835f8a60ac74a2ffd012a752beddc9fdf39`.
- UI artifact 12826122739, ZIP 828,456 bytes, SHA256 `134eb7be1ea9491a37ecc0e717fb61db05acf925ff075907e1562c1c64489b75`.
- terminal-run.json holds terminal source and status. report-manifest.json holds individual original attachment hashes, source pins and clean-source evidence. bounded-native-failure-lines.txt preserves exact relevant errors. SHA256SUMS.txt hashes local evidence files.

Native observation is complete for this source. Actual-device localization, sustained spoken guidance, full-footprint support and independent child use remain unproven.
