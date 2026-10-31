# Saved-room geometry/recorder overlay canonical membership

2026-10-28. Implementation source is separately reviewed/frozen by the geometry and recorder owners. This stage edits only the generator, checked project and reversible integrated verification layer.

## Exact changes

- Preserve all prior 63 app Swift files; add `SavedRoomDiagnosticGeometryProvider.swift`: **64 app files**.
- Preserve all hosted test members; add `SavedRoomDiagnosticGeometryProviderTests.swift` to the actual hosted source phase.
- Core geometry/recorder sources and tests are discovered by the existing Swift package, requiring no PBX source entries.
- Existing local/remote package references, products, frameworks, build settings and flags remain byte-identical. No workflow, helper, package version, dependency download or runtime source changes by this stage.

`integrated/saved-room-geometry-membership.patch` reverses the separately authored Nav handoff/factory/deletion hook and this project delta to exact prior Nav `fcea783bbbbaa4e1bdda04740fc38f11c10f30de1e6160d8eb5072d7b4a01298` and PBX `63fc5fcd1d9ef153c87ca48b9fa195f270fec3c039ee58887d407d46b300d87c`, before all previous app layers. The published CI helper extraction/reversal proof is retained unchanged; old patches/pins are not rewritten.

Current project SHA: `22ade4297e94b13957249b507d422895335958a051821e20407a2df5ff6b6c84`.

## Executed bounded evidence

- `check-membership.mjs`: exact current generator parity; only two approved source paths added; none removed; hosted source-phase membership; unchanged package/product/framework/settings records.
- Integrated historical checker: **54/54 source checks passed**, including the CI helper and every app historical reversal.
- Bounded generator/photo/geometry source regressions: **67/67 passed**.

```sh
node research/localization-contract-review-20261028/geometry-membership-stage/check-membership.mjs
python3 research/native-candidate-app-integration-85/integrated/check.py
node --test tools/test/mesh-package-project.test.mjs tools/test/room-reference-photo-trash.test.mjs tools/test/selected-photo-reference.test.mjs tools/test/currency-device-test-project.test.mjs tools/test/currency-reference-project.test.mjs tools/test/object-detector-project.test.mjs tools/test/saved-room-diagnostic-geometry.test.mjs
```

No native compilation, XCTest execution, RoomPlan positive decoding or device accuracy test was run. This diagnostic overlay is not a collision mesh, measured body/camera calibration, reliable clearance or physical guidance. Earlier membership receipts remain historical fixed-count snapshots, superseded for the current tree by this checker.
