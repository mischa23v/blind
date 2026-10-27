# Layered map and localization integration audit

Source checkpoint: `mischa23v/blind` master `5b80e9acfb936931f891062d33e62f9818b700fb`.
Read-only source audit, 2026-10-27. No runtime edits, builds, sensor runs or new test passes.

## Finding

**The layered map architecture already exists. The open work is verified native localization/orientation, continuous deviation measurement, a safe current-pose-to-path connection, and candidate mesh integration—not a second registry or planner.** The localization/orientation acceptance gate in `TRACKER_ADDENDUM.md` is **NOT PASSED** and is independent of the existing live-hazard release blocker.

## Verified existing implementation

All paths below refer to the pinned repository commit. The local `blind-navigation-combined/full-source` snapshot matched 358 audited Swift/context blobs; current `NavigationModel.swift` and `NativeMapping.swift` were fetched separately where that snapshot differed.

| Capability | Source and verified boundary |
|---|---|
| World → place → building → floor → room | `BlindCore/Sources/BlindCore/SpatialFrameRegistry.swift`: durable containment; exact map/frame/revision bindings; measured transforms; doorway, entrance, stairs and elevator transitions. Containment is not current location. |
| Installed map ownership | `SpatialMapInstallation.swift`; `ios/BlindAssist/RegisteredIndoorNavigation.swift`: exact artifact bytes/digests, immutable history and conservative restrictions. Imported unregistered community maps remain previews. |
| Existing app connection | `ios/BlindAssist/NavigationModel.swift:689–705`: installed/removed map state already feeds `ConnectedJourneyRuntime`; preserve this owner instead of adding parallel state. |
| Existing paths and connections | `ConnectedJourneyCatalog.swift`: reuses `IndoorMap.route`, requires installed exact revisions and sourced portal endpoints. `ConnectedJourneyCoordinator.swift:286–357`: portals wait for fresh endpoint associations; no stairs/lift crossing instruction is authorized. |
| Automatic saved-map recovery | `NavigationModel.swift:4935–5014`; `RoomRecoveryCoordinator.swift`: bounded attempts using fresh local appearance/coarse location. `PlaceStore.swift:273–329`: artifact hashes, exact origin anchor and ARKit relocalizing→normal sequence are checked. Failed matching does not prove a new room. |
| Native localization boundary | `NavigationModel.swift:438–470,4606–4617`; `NativeLocalizationIssuer.swift`; `NativeLocalizationRouter.swift`: calibration is unconfigured; no current camera/room-recognition path supplies the calibrated connected-journey capture. Candidate evidence is deliberately withheld from physical release. |
| Return/restart | `ConnectedJourneyRuntime.swift:465–526`; `ConnectedJourneyCoordinator.swift:217–284`; `NavigationModel.swift:4516–4590`: goals/references/history survive; live pose and route authority do not. Recorded camera paths are history, not verified return clearance. |
| Objects in maps | `SavedWorldFrame.swift`; `PlaceStore.swift:333–347`: dated RoomPlan furniture measurements are bound to the exact saved frame, not current presence or personal identity. |
| Progressive observations | `ObservedScene.swift`, `NativeMapping.swift`: existing session observations and optional RTAB-Map private-map accumulation. A stored database or ground/empty-ray classification is not validated navigation localization or live clearance. |

`SpatialIntegrationFixture.swift:8–9` explicitly describes authored map, pose and support inputs. Existing synthetic journey tests exercise contracts; they do not prove automatic physical localization. The genuine ARKit recovery path establishes coordinate association, not calibrated body heading, pose-error bounds, floor support or live clearance.

## Smallest missing wiring

1. Reuse `SpatialMapBinding`, `SavedWorldFrame`, existing installation artifacts and route-owner epochs. Resolve recovered descriptors against active registry records: exactly one match is required; zero is unavailable and multiple are ambiguous. Never match by room name or proximity alone.
2. Add the already-prepared `blind-room-mesh-package-75/BlindRoomMesh` as a candidate-only sidecar through the project generator and existing ARSession owner. Master contains no `BlindRoomMesh` source and `NavigationModel` has no anchor-array add/update/remove callbacks. Copy owned bounded anchor geometry, assign revisions, process removals and invalidate on lifecycle changes. Do not reuse truncated history snapshots as complete meshes.
3. Associate candidate results with exact session/generation, selected map context when legitimately available, goal and body revision. Stage75 supports session-local geometry only. Do not invent an identity transform into a building/floor map, persist unregistered geometry into that map, or promote its paths into localization captures.
4. Use the existing catalog for known routes. Accumulate unknown areas as unknown, session-local candidate evidence; lack of a known route must not cause invented connections, automatic replacement of saved maps or assumed free floor. Retain the destination while recovery is pending.
5. Supply independently measured localization, body-heading/calibration, support and error evidence through the existing issuer seam only after the separate acceptance gate passes. Stage75 remains `authorizesPhysicalGuidance == false`; package compilation is not this gate.
6. Continuously estimate route-relative cross-track distance, along-path progress and heading error with uncertainty, not only an initial map match. Image-derived camera pose and body heading remain separate. Distinguish a measured deviation from unavailable localization; every return-to-route connector needs current collision/support/coverage checks rather than nearest-line snapping.

## Untested source finding: hazard processing during map recovery

At the pinned commit, `NavigationModel.swift:1213–1240` returns from the `awaitingPlace` branch before `DepthSampler` at 1250, `detector.process` at 1279 and `BodyCollisionWarning` at 1284. It publishes uncertainty/localizing; it does not publish clearance. The RGB stairs consumer runs earlier.

This is a **candidate depth-hazard ordering defect requiring regression investigation**, not a measured warning failure or a claim about observed physical behavior. Test recovery-pending frames with fresh valid hazard evidence and unavailable tracking, preserving truthful uncertainty. Recovery and candidate mesh work must not suppress or delay applicable independent warnings. Outside this early-return branch, existing urgent detection correctly precedes supplemental geometry at 1279–1296. No runtime fix was made in this audit.

## Existing regression foundations

`RoomRecoveryCoordinatorTests.swift`, `RoomRecognizerTests.swift`, `SavedWorldFrameTests.swift`, `SpatialFrameRegistryTests.swift`, `ConnectedJourneyTests.swift` and `ConnectedJourneyFailureTests.swift` already cover competing candidates, stale clues, exact saved-frame ownership, rejected GPS/appearance pose, wrong floors/revisions, missing connections, restart and return restrictions. Extend these rather than replacing them. No tests were run by this audit.

Permanent boundaries: private home maps, images, fingerprints and personal observations stay on-device. No new publication, trial or physical-guidance authority follows from this report.
