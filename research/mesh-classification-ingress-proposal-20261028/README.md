# Preserve ARKit classifications through83 — reviewed source proposal

2026-10-28. Base: `e47b6c9f284dc90603dfee15f7e9295a5b3f647f` (`mischa23v/blind`). The relevant81/82/83/75 source blobs were rechecked at this checkpoint and match the earlier `dc32a9bad9a75566f27924fb9f7aa8fe50a46e95` audit. This folder freezes the reviewed proposal before separately coordinated adoption. It does not activate an AR session, live bench, app route or physical output.

## Bounded change

`classification-preservation.patch` changes only83's owner and its existing source pin. `candidate/` contains the exact resulting files for review. No decoder, mapper, navigation algorithm, native build policy or legacy caller is replaced.

- `MeshCandidateIngress83.init` adds an immutable `supportPolicy: MeshSupportPolicy = .legacySlope`, forwards it to existing75, and keeps it through reset (candidate lines18,34–44). Existing calls remain legacy and emit nil triangle roles.
- In the explicit `.classifiedFloorOnly` branch, one role is supplied for every decoded face. Only ARKit floor label2 maps to `.floor`; all other labels and nil map to `.obstacle` (103–122). All original local vertices, triangles and column-major transform are passed through unchanged; no obstacle face is discarded, and no slope/height fallback promotes furniture.
- Missing, malformed, unsupported or explicit `.none` labels also mark the existing sticky unknown gap. Valid geometry still replaces the old anchor: unknown classes replace old floor with obstacle roles. A subsequent valid classified-floor revision can replace those obstacles and route again, but historical coverage remains unknown until the existing fresh-epoch reset. This is not a permanent blocked-cell policy.
- A whole82 `.unknownGap` contains no geometry to install. Existing83 semantics retain old geometry only as a nonphysical diagnostic with incomplete delivery. This patch does not invent replacement geometry for a refused descriptor or failed copy.
- Roles add a bounded per-face array (existing decoder maximum100k faces; bench producer maximum32k). Existing75 accounts roles in its bounded mailbox. This is not a whole-process/RSS or callback-latency guarantee.

The API name `MeshTriangleSupport` means source semantic role, **not measured body support or live clearance**. Candidate physical authority, actual world coverage and raw-depth availability remain false; raw hazard veto remains true.

## Actual dependency evidence and tests

82 copies classification only after descriptor validation;81 decodes exactly one optional UInt8 per face, recognizes0…7, and returns nil plus diagnostics for absent/malformed/unsupported values. Sources: `arkit-mesh-adapter-82/Sources/{ARKitMeshAdapter,MeshSnapshot}.swift`, `native-mesh-decoder-81/Sources/MeshBufferDecoder.swift:28–41,130–150`. Existing75's `MeshSupportPolicy`, per-face event field and classified native rasterization are reused, not reimplemented.

Apple documents [one classification per face and none=0](https://developer.apple.com/documentation/arkit/armeshgeometry/classification) and the [floor semantic](https://developer.apple.com/documentation/arkit/armeshclassification/floor). Microsoft's maintained [ARKit binding lists Floor=2](https://learn.microsoft.com/en-us/dotnet/api/arkit.armeshclassification). The conditional iOS fixture asserts the constant against the actual Apple SDK; that assertion is authored, not executed. No new dependency or license is introduced; existing platform and pinned75 native licenses remain unchanged.

`Tests/ClassificationIngressTests.swift` has **8 host tests + 1 conditional iOS SDK test**, all unrun:

1. Actual82→81 decoding over all256 label bytes; missing/malformed labels and rejected descriptor count.
2. Actual83→75 classified-floor route and transform applied once, all authority fields remain nonphysical.
3. Default legacy still accepts its previous unclassified synthetic floor without introducing a classification gap.
4. Known nonfloor, absent, none and unsupported classifications cannot promote identical upward planes.
5. An overhead table remains rasterized obstacle geometry, rather than being dropped; removal can restore the synthetic floor route.
6. Floor→unknown replacement→translated valid-floor recovery, sticky historical gap, and policy preserved across reset.
7. Other valid floor can still yield a candidate while absent/none/unsupported companion faces keep delivery unknown.
8. Decoder-malformed classes replace floor as obstacles; whole preflight rejection retains an explicit gap instead of inventing geometry.
9. iOS-only SDK raw-value equivalence, no camera/session run.

Negative fixtures require `.runtime(.nativeFailure)`, not any unavailable/stale failure. Ten-second callback/discard limits are unchanged from established tests; no timeout is accepted as correct withholding. NativeFailure itself has coarse existing error attribution, so failures need native diagnosis. This stage does not resolve the separately observed classified-native timing failures.

`verify_staging.py` checks source contracts and forward/reverse patch bytes only. **No Swift parsing, build, XCTest, simulator, phone, classifier accuracy or physical-support validation occurred.** Neither Swift nor Xcode is installed here;81/82/83 dependencies are not fully materialized locally. Independent source review accepted candidate hash733a7bdc… and tests5acab137…; it found and fixed the originally overbroad negative-result assertion.

## Smallest path into existing hosted native tests

After root review/adoption, apply the two-file patch and copy this exact test source to `ios/BlindAssistTests/ClassificationIngressTests.swift`.

The canonical `tools/generate-xcode-project.mjs` controls membership: add the new filename to `spatialTestFiles` (line22), explicit hosted83 product using existing `meshPackage`, and hosted82 `MeshSnapshot82` product/local package (unit product/framework/target/root-package sections160–175).81 is exercised transitively and needs no extra direct import/product. Keep `MeshSnapshot82.Owned` constructor internal: the synthetic fixture uses `@testable import MeshSnapshot82`, requiring Debug package testability; do not expose a public forged-snapshot initializer merely to make testing convenient.

Regenerate the committed project with the connector-verified complete65-file app inventory in controlled scratch; never derive membership from this partial local app directory or invent placeholder production files. Add a reversible classification-membership project layer before the current Apple-room-route inverse, update only relevant integrated pins, and preserve the independently owned classified→recorder→scene CI helper layers.

The existing `tools/ci/native-apple.sh` unit selector is the whole `BlindAssistTests` target, so the new tests can run without a new workflow, session activation or production feature flag. The separate SwiftPM harness here also needs the applied83 patch and a complete dependency checkout; use the established native-package compatibility build procedure on an approved Apple host, not an unverified default-backend claim.

Remaining after this source step: actual Apple compilation/execution, native timing diagnosis, explicit bench opt-in wiring if chosen, canonical session handoff/UI and truthful monitoring-unavailable confirmation, borrowed Metal lifetime/late callback/device resource proof, calibrated body pose and independently fresh swept whole-body/ground coverage. The already frozen bench remains legacy until a separate deliberate consumer opts in. No safe walking or unfamiliar-room avoidance is demonstrated by these synthetic tests.
