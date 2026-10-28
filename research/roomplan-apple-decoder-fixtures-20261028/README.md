# Original Apple RoomPlan decoder fixtures — 2026-10-28

## Scope and provenance

This test-only increment addresses the prior geometry checkpoint's explicit gap: it had no successful original `CapturedRoom` input fixture. The new hosted tests feed **unchanged Apple prescanned room JSON** into both `JSONDecoder().decode(CapturedRoom.self, ...)` and the actual `SavedRoomDiagnosticGeometryDecoder.decode` production path. They do not inject replacement geometry in the default-provider test.

The user explicitly approved copying/publishing these two public Apple fixtures and their license, then pushing and testing them on 2026-10-28. No personal scans or photographs are included.

Original resources, the exact official 2025 Apple license, and detailed provenance are under [`ios/BlindAssistTests/Fixtures/RoomPlanApple`](../../ios/BlindAssistTests/Fixtures/RoomPlanApple/README.md). Their combined JSON size is 97,091 bytes:

| Original resource | SHA-256 | Features |
| --- | --- | --- |
| Hallway2 | `f4cf3460fd9e746a86fe6538e2b1980e22e18207a2d3c7ea3f7679f58c8c6f4d` | 6 walls, 6 doors, 1 floor |
| Bedroom3 | `44df7bd5f4d1961bf13344916384dcfa20d42c7ef8dc58b0e13d1c2f7c6a4d2e` | 4 walls, 2 doors, 1 floor, 1 window, 3 objects (bed, table, chair) |

Official upstream: [Apple sample page](https://developer.apple.com/documentation/roomplan/merging-multiple-scans-into-a-single-structure), [downloaded source archive](https://developer.apple.com/tutorials/3e2b731b0ef7/MergingMultipleScansIntoASingleStructure.zip). Archive SHA-256 `135cf2ae9c415723f9f32c31a130b4ce9efced61b3e22f50858785a4323d66a1`; per-file mirror revision/blob IDs are retained in the fixture manifest. No new library, model or runtime is adopted.

## Authored hosted scenarios

`SavedRoomDiagnosticGeometryAppleFixtureTests.swift` adds four methods:

1. Decode both original Apple rooms through the native framework and production decoder. Compare all 24 retained feature IDs, kinds, categories, full 16-component transforms, original dimensions and original local polygons with a separate raw-JSON view. Check complete fixed source counts and every original polygon's world points by independent column-major multiplication.
2. Check fixed numeric Bedroom3 floor world-corner witnesses, original zero floor thickness, furniture categories and the bed's original width/height/depth plus transformed dimensional corner. These expected numbers were calculated independently from the original JSON, not obtained from the extractor under test.
3. Reject authentic Bedroom3 bytes with the Hallway2 byte digest instead of borrowing another room's binding.
4. Write the real Bedroom3 bytes into an isolated temporary `PlaceStore`, run the default provider/loader without injection, require ready geometry, then retire deletion ownership and require withdrawal. Timeout fails and throws rather than continuing as if work completed.

The hosted test bundle alone receives the fixture folder. No app runtime or app resource payload changes are part of this increment. Canonical generator/project membership is handled as a separate coordinated slice.

## Evidence status

- **Executed locally:** `node --test --test-concurrency=1 tools/test/roomplan-apple-decoder-fixtures.test.mjs` — 4/4 source/provenance checks passed; output in `node-fixture-checks.tap`. This verifies exact bytes/license/provenance, all-field fixture source contracts with four negative mutations, independent numeric witnesses, and real default-provider test wiring.
- **Executed regression:** the new four checks plus `tools/test/saved-room-diagnostic-geometry.test.mjs` — 10/10 passed; output in `node-geometry-regression.tap`. The previous seven-file geometry/overlay freeze still matched 7/7 hashes afterward; no runtime changes were made for this fixture slice.
- **Independent source review:** `review_recorded_route_preview` reviewed all four hosted methods and found no source/compile-API blocker; independently reran 7/7 fixture plus membership Node checks and the 56/56 integrated proof. Native execution and bundle copying remain unverified by that review.
- **Authored, not locally executed:** four hosted Swift methods above. This Linux workspace has no Swift compiler or Apple RoomPlan framework; no compiler/model installation was attempted.
- **Pending:** native build, test-bundle resource lookup, actual Apple decoder/extractor execution and default provider result on the exact published revision. Use the repository's existing native CI; do not transfer another revision's results to these tests.

An isolated native rerun may select `BlindAssistTests/SavedRoomDiagnosticGeometryAppleFixtureTests` using the existing generated `BlindAssist` scheme and authorized simulator destination. Root coordinates the canonical membership, publication and CI evidence.

## Limits retained

The `SavedWorldFrame` test descriptor has synthetic UUIDs, date and world-map hash solely to exercise byte binding and provider ownership. It is **not** a paired map, a saved-session capture receipt, ARKit relocalization evidence or an imported-map registration. The fixtures contain no live camera path, body/feet pose, clearance proof, current furniture proof, measured uncertainty or physical measurement ground truth. They do not establish the user's phone works, any device model/date, physical guidance readiness, or child/eyes-closed mobility safety. No opaque live association receipt is fabricated. Actual source-level changes are tests, public fixtures, provenance and canonical test-only membership only.
