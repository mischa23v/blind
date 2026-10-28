# Original Apple RoomPlan fixture membership — test only

2026-10-28; user-authorized fixture test/publication stage. The fixture source, original bytes, license and provenance are owned by `research/roomplan-apple-decoder-fixtures-20261028/`. This stage changes only canonical generator/project membership and integrated historical proof.

## Bundle boundary

- Existing 64 app Swift sources, app target/source/resource phase records, packages/frameworks/settings/flags remain unchanged.
- `SavedRoomDiagnosticGeometryAppleFixtureTests.swift` is added only to the hosted test source phase.
- A blue folder reference with `lastKnownFileType = folder`, exact source-root path `BlindAssistTests/Fixtures/RoomPlanApple`, and one build-file entry is owned by a new hosted-test-only `PBXResourcesBuildPhase`.
- The preserved directory name matches `Bundle(for: Self.self).url(..., subdirectory: "RoomPlanApple")` in the tests.
- Exactly two original Apple JSONs, `APPLE-LICENSE.txt`, and local provenance `README.md`/`manifest.json` are bundled. No app target receives this phase or resource. No model/private-image/sensor data or new dependency.

## Historical proof

`integrated/apple-roomplan-fixture-membership.patch` is a separate PBX-only layer, reversed to exact prior `22ade4297e94b13957249b507d422895335958a051821e20407a2df5ff6b6c84` before every prior geometry/capture/recorder/project layer. The independent CI-helper reversal remains unchanged. No app source or old patch/pin was rewritten.

## Bounded executed checks

- Integrated checker: **56/56 source checks passed**.
- Project/photo regression suite: **64/64 passed**, including three new fixture-project tests.
- Four negative mutations reject missing hosted resource phase, missing resource build membership, app phase sharing and direct app resource embedding.
- `MEMBERSHIP_RESULT.json` independently confirms only the new hosted Swift source was added, no source removed, 64 unchanged app sources, unchanged app source/resource/target records and unchanged packages/frameworks/settings.

```sh
python3 research/native-candidate-app-integration-85/integrated/check.py
node --test tools/test/roomplan-fixture-project.test.mjs tools/test/mesh-package-project.test.mjs tools/test/room-reference-photo-trash.test.mjs tools/test/selected-photo-reference.test.mjs tools/test/currency-device-test-project.test.mjs tools/test/currency-reference-project.test.mjs tools/test/object-detector-project.test.mjs
```

**Native bundle copying and RoomPlan decoder/XCTest execution remain untested locally.** No Swift toolchain, new build, workflow or dependency download was invoked. These public historical room JSONs do not establish live localization, collision clearance or physical safety.
